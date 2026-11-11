package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
	"unicode/utf16"
	"unicode/utf8"
)

// The fixed destination and model are deployment policy, never caller input.
// Requests follow pi-web-access/openai-search.ts's Responses provider shape.
type webSearchClient struct {
	url, key, model string
	client          *http.Client
}

func newWebSearchClient(url, key, model string) *webSearchClient {
	return &webSearchClient{url: url, key: key, model: model, client: &http.Client{
		Timeout: 60 * time.Second, Transport: &http.Transport{},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}
}

type webSearchSource struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
}
type webSearchResult struct {
	Answer  string            `json:"answer"`
	Results []webSearchSource `json:"results"`
}
type responsesOutput struct {
	Status string          `json:"status"`
	Error  json.RawMessage `json:"error"`
	Output []struct {
		Type    string `json:"type"`
		Content []struct {
			Type        string `json:"type"`
			Text        string `json:"text"`
			Annotations []struct {
				Type  string `json:"type"`
				Title string `json:"title"`
				URL   string `json:"url"`
				Start int    `json:"start_index"`
				End   int    `json:"end_index"`
			} `json:"annotations"`
		} `json:"content"`
	} `json:"output"`
}

func searchText(text string, limit int) string {
	runes := []rune(text)
	if len(runes) > limit {
		return string(runes[:limit])
	}
	return text
}

func parseSearchResponse(data []byte) (responsesOutput, error) {
	var response responsesOutput
	if bytes.HasPrefix(bytes.TrimSpace(data), []byte("{")) {
		if json.Unmarshal(data, &response) != nil {
			return response, errors.New("invalid response")
		}
	} else {
		completed := false
		for _, line := range strings.Split(string(data), "\n") {
			if !strings.HasPrefix(line, "data:") {
				continue
			}
			value := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
			if value == "[DONE]" {
				continue
			}
			var event struct {
				Type     string          `json:"type"`
				Response json.RawMessage `json:"response"`
			}
			if json.Unmarshal([]byte(value), &event) != nil {
				return response, errors.New("invalid response")
			}
			switch event.Type {
			case "error", "response.failed", "response.incomplete":
				return response, errors.New("failed response")
			case "response.completed":
				if json.Unmarshal(event.Response, &response) != nil {
					return response, errors.New("invalid response")
				}
				completed = true
			}
		}
		if !completed {
			return response, errors.New("incomplete stream")
		}
	}
	if response.Status != "completed" || (len(response.Error) > 0 && string(response.Error) != "null") {
		return response, errors.New("failed response")
	}
	return response, nil
}

func (s *webSearchClient) search(ctx context.Context, query string, maxResults int) (any, bool) {
	failure := func(kind string, status int) (any, bool) {
		return map[string]any{"kind": kind, "status": status, "message": "Front-door web search failed; no upstream body is disclosed"}, true
	}
	body, _ := json.Marshal(map[string]any{
		"model":        s.model,
		"instructions": fmt.Sprintf("Search the web and return a concise answer grounded only in the web results. Include clickable source citations in the response text when possible. Prefer around %d distinct sources. Keep the answer to three short paragraphs.", maxResults),
		"input":        []any{map[string]any{"role": "user", "content": []any{map[string]string{"type": "input_text", "text": query}}}},
		"tools":        []any{map[string]string{"type": "web_search"}}, "include": []string{"web_search_call.action.sources"},
		"store": false, "stream": true, "tool_choice": "required", "parallel_tool_calls": true,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.url, bytes.NewReader(body))
	if err != nil {
		return failure("upstream_unavailable", 0)
	}
	req.Header.Set("Authorization", "Bearer "+s.key)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("OpenAI-Beta", "responses=experimental")
	response, err := s.client.Do(req)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil {
			return failure("upstream_timeout", 0)
		}
		return failure("upstream_unavailable", 0)
	}
	defer response.Body.Close()
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
	parsed, err := parseSearchResponse(data)
	if err != nil {
		return failure("invalid_response", 0)
	}
	result := webSearchResult{Results: []webSearchSource{}}
	seen := map[string]bool{}
	searched := false
	for _, item := range parsed.Output {
		if item.Type == "web_search_call" {
			searched = true
		}
		if item.Type != "message" {
			continue
		}
		for _, part := range item.Content {
			if part.Type != "output_text" {
				continue
			}
			// Check decoded strings, not raw JSON, so escaped credentials cannot pass.
			if s.key != "" && strings.Contains(part.Text, s.key) {
				return failure("credential_redacted", 0)
			}
			if part.Text != "" {
				result.Answer = searchText(strings.TrimSpace(result.Answer+"\n"+part.Text), 16000)
			}
			for _, a := range part.Annotations {
				if s.key != "" && (strings.Contains(a.Title, s.key) || strings.Contains(a.URL, s.key)) {
					return failure("credential_redacted", 0)
				}
				if a.Type != "url_citation" || len(result.Results) >= maxResults {
					continue
				}
				u, err := url.Parse(a.URL)
				if err != nil || u.Host == "" || u.User != nil || (u.Scheme != "https" && u.Scheme != "http") || len(a.URL) > 4096 {
					continue
				}
				q := u.Query()
				if q.Get("utm_source") == "openai" {
					q.Del("utm_source")
					u.RawQuery = q.Encode()
				}
				clean := u.String()
				if seen[clean] {
					continue
				}
				seen[clean] = true
				// Responses annotation offsets use UTF-16 code units, like Pi/JavaScript.
				text := utf16.Encode([]rune(part.Text))
				start, end := max(0, a.Start-100), min(len(text), a.End+100)
				snippet := ""
				if start < end {
					snippet = strings.TrimSpace(string(utf16.Decode(text[start:end])))
				}
				title := a.Title
				if strings.TrimSpace(title) == "" {
					title = clean
				}
				result.Results = append(result.Results, webSearchSource{Title: searchText(title, 512), URL: clean, Snippet: searchText(snippet, 300)})
			}
		}
	}
	if !searched || (result.Answer == "" && len(result.Results) == 0) {
		return failure("invalid_response", 0)
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
			result = map[string]any{"protocolVersion": version, "serverInfo": map[string]string{"name": "claw-websearch", "version": "1"}, "capabilities": map[string]any{"tools": map[string]any{}}}
		case "tools/list":
			result = map[string]any{"tools": []any{map[string]any{
				"name": "web_search", "description": "Search the current web through the front door's model-native search. Returns a cited answer and citation sources with title, url and snippet. Use web_fetch on a source URL for detail. No sources are invented when citations are absent.",
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
			ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
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
