package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

// The fixed destination is deployment policy, never caller input. The front
// door's POST /v1/search (the LiteLLM/Perplexity search schema) chooses the
// search source; this client names no model or source.
type webSearchClient struct {
	url, key string
	client   *http.Client
}

// Longer than the front door's 60-second search deadline, so its own 429 or
// 503 reaches the agent instead of a local timeout. Below the 75-second write
// timeout of the endpoint mode.
const webSearchTimeout = 70 * time.Second

func newWebSearchClient(url, key string) *webSearchClient {
	return &webSearchClient{url: url, key: key, client: &http.Client{
		Timeout: webSearchTimeout, Transport: &http.Transport{},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}
}

type webSearchSource struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
}
type webSearchResult struct {
	Results []webSearchSource `json:"results"`
}

// The front door's answer. Unknown fields (such as date) are ignored.
type frontDoorSearch struct {
	Object  string `json:"object"`
	Results []struct {
		Title   string `json:"title"`
		URL     string `json:"url"`
		Snippet string `json:"snippet"`
	} `json:"results"`
}

func searchText(text string, limit int) string {
	runes := []rune(text)
	if len(runes) > limit {
		return string(runes[:limit])
	}
	return text
}

// Seconds until a rate-limited search may be retried, from Retry-After
// (seconds or an HTTP date). Zero when unknown.
func retryAfterSeconds(value string, now time.Time) int {
	value = strings.TrimSpace(value)
	if seconds, err := strconv.Atoi(value); err == nil && seconds > 0 {
		return seconds
	}
	if at, err := http.ParseTime(value); err == nil && at.After(now) {
		return int(at.Sub(now).Seconds() + 0.999)
	}
	return 0
}

func (s *webSearchClient) search(ctx context.Context, query string, maxResults int) (any, bool) {
	failure := func(kind string, status int) (any, bool) {
		return map[string]any{"kind": kind, "status": status, "message": "Front-door web search failed; no upstream body is disclosed"}, true
	}
	body, _ := json.Marshal(map[string]any{"query": query, "max_results": maxResults})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.url, bytes.NewReader(body))
	if err != nil {
		return failure("upstream_unavailable", 0)
	}
	req.Header.Set("Authorization", "Bearer "+s.key)
	req.Header.Set("Content-Type", "application/json")
	response, err := s.client.Do(req)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil {
			return failure("upstream_timeout", 0)
		}
		return failure("upstream_unavailable", 0)
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusTooManyRequests {
		// Every search source is rate limited. Tell the agent when to retry.
		return map[string]any{"kind": "rate_limited", "status": response.StatusCode, "retry_after": retryAfterSeconds(response.Header.Get("Retry-After"), time.Now()), "message": "Front-door web search is rate limited; no upstream body is disclosed"}, true
	}
	if response.StatusCode != http.StatusOK {
		return failure("upstream_http_error", response.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, mcpMaxBody+1))
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil {
			return failure("upstream_timeout", 0)
		}
		return failure("invalid_response", 0)
	}
	if len(data) > mcpMaxBody {
		return failure("invalid_response", 0)
	}
	var parsed frontDoorSearch
	if json.Unmarshal(data, &parsed) != nil || parsed.Object != "search" {
		return failure("invalid_response", 0)
	}
	result := webSearchResult{Results: []webSearchSource{}}
	seen := map[string]bool{}
	for _, r := range parsed.Results {
		// Check decoded strings, not raw JSON, so escaped credentials cannot pass.
		if s.key != "" && (strings.Contains(r.Title, s.key) || strings.Contains(r.URL, s.key) || strings.Contains(r.Snippet, s.key)) {
			return failure("credential_redacted", 0)
		}
		if len(result.Results) >= maxResults {
			continue
		}
		u, err := url.Parse(r.URL)
		if err != nil || u.Host == "" || u.User != nil || (u.Scheme != "https" && u.Scheme != "http") || len(r.URL) > 4096 || seen[r.URL] {
			continue
		}
		seen[r.URL] = true
		title := strings.TrimSpace(r.Title)
		if title == "" {
			title = r.URL
		}
		result.Results = append(result.Results, webSearchSource{Title: searchText(title, 512), URL: r.URL, Snippet: searchText(strings.TrimSpace(r.Snippet), 500)})
	}
	return result, false
}

func webSearchHandler(s *webSearchClient, tailnetClient func(*http.Request) bool) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		request, ok := readMCPRequest(w, r, tailnetClient)
		if !ok {
			return
		}
		var result any
		switch request.Method {
		case "initialize":
			var params struct {
				ProtocolVersion string `json:"protocolVersion"`
			}
			if json.Unmarshal(request.Params, &params) != nil {
				rpcError(w, request.ID, -32602, "invalid initialize parameters")
				return
			}
			version := params.ProtocolVersion
			if version != "2025-03-26" && version != "2025-11-25" {
				version = "2025-03-26"
			}
			result = map[string]any{"protocolVersion": version, "serverInfo": map[string]string{"name": "claw-websearch", "version": "2"}, "capabilities": map[string]any{"tools": map[string]any{}}}
		case "tools/list":
			result = map[string]any{"tools": []any{map[string]any{
				"name": "web_search", "description": "Search the current web. Returns a list of results, each with title, url and snippet, most relevant first; there is no written answer. Use web_fetch on a result URL for detail. An empty list means nothing usable was found. On kind rate_limited, retry after retry_after seconds.",
				"inputSchema": json.RawMessage(`{"type":"object","properties":{"query":{"type":"string","minLength":1,"maxLength":2000},"max_results":{"type":"integer","minimum":1,"maximum":10,"default":5}},"required":["query"],"additionalProperties":false}`),
				"annotations": map[string]bool{"readOnlyHint": true, "openWorldHint": true},
			}}}
		case "tools/call":
			var params struct {
				Name      string          `json:"name"`
				Arguments json.RawMessage `json:"arguments"`
			}
			if json.Unmarshal(request.Params, &params) != nil {
				rpcError(w, request.ID, -32602, "invalid tool parameters")
				return
			}
			if params.Name != "web_search" {
				rpcError(w, request.ID, -32601, "tool not allowed")
				return
			}
			var args struct {
				Query      string `json:"query"`
				MaxResults *int   `json:"max_results"`
			}
			decoder := json.NewDecoder(bytes.NewReader(params.Arguments))
			decoder.DisallowUnknownFields()
			var fields map[string]json.RawMessage
			if decoder.Decode(&args) != nil || strings.TrimSpace(args.Query) == "" || utf8.RuneCountInString(args.Query) > 2000 || json.Unmarshal(params.Arguments, &fields) != nil || (fields["max_results"] != nil && args.MaxResults == nil) || (args.MaxResults != nil && (*args.MaxResults < 1 || *args.MaxResults > 10)) {
				rpcError(w, request.ID, -32602, "query must be 1-2000 characters; max_results must be an integer from 1 to 10")
				return
			}
			limit := 5
			if args.MaxResults != nil {
				limit = *args.MaxResults
			}
			ctx, cancel := context.WithTimeout(r.Context(), webSearchTimeout)
			defer cancel()
			reply, failed := s.search(ctx, args.Query, limit)
			text, _ := json.Marshal(reply)
			result = map[string]any{"content": []any{map[string]string{"type": "text", "text": string(text)}}, "structuredContent": reply, "isError": failed}
		default:
			rpcError(w, request.ID, -32601, "method not allowed")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"jsonrpc": "2.0", "id": request.ID, "result": result})
	})
}
