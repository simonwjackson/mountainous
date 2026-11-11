package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

const searchTestKey = "private-search-credential"

func searchPayload(answer string, citations bool) string {
	annotations := []any{}
	if citations {
		annotations = append(annotations, map[string]any{"type": "url_citation", "url": "https://example.com/news?utm_source=openai", "title": "News", "start_index": 0, "end_index": 8}, map[string]any{"type": "url_citation", "url": "https://example.com/news", "title": "Duplicate"}, map[string]any{"type": "url_citation", "url": "file:///etc/passwd", "title": "Unsafe"})
	}
	data, _ := json.Marshal(map[string]any{"status": "completed", "output": []any{map[string]any{"type": "web_search_call"}, map[string]any{"type": "message", "content": []any{map[string]any{"type": "output_text", "text": answer, "annotations": annotations}}}}})
	return string(data)
}

func TestWebSearchResponses(t *testing.T) {
	for _, tc := range []struct {
		name, body, kind string
		status           int
		delay            time.Duration
		sse              bool
	}{
		{name: "citations", body: searchPayload("New release today", true)},
		{name: "no citations", body: searchPayload("No sources found", false)},
		{name: "SSE citations", body: searchPayload("New release today", true), sse: true},
		{name: "HTTP error", body: searchTestKey, status: 503, kind: "upstream_http_error"},
		{name: "timeout", delay: 100 * time.Millisecond, kind: "upstream_timeout"},
		{name: "invalid JSON", body: "not JSON", kind: "invalid_response"},
		{name: "too large", body: strings.Repeat("x", mcpMaxBody+1), kind: "invalid_response"},
		{name: "reflected credential", body: searchPayload(searchTestKey, true), kind: "credential_redacted"},
		{name: "no search", body: `{"status":"completed","output":[]}`, kind: "invalid_response"},
		{name: "failed SSE", body: `{"status":"failed","error":{"message":"` + searchTestKey + `"}}`, sse: true, kind: "invalid_response"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/v1/responses" || r.Header.Get("Authorization") != "Bearer "+searchTestKey || r.Header.Get("OpenAI-Beta") != "responses=experimental" {
					t.Error("wrong upstream contract")
				}
				var body map[string]json.RawMessage
				if json.NewDecoder(r.Body).Decode(&body) != nil {
					t.Error("invalid request")
				}
				for key, want := range map[string]string{"model": `"gpt-6.1-sol"`, "store": "false", "stream": "true", "tool_choice": `"required"`, "parallel_tool_calls": "true", "tools": `[{"type":"web_search"}]`, "include": `["web_search_call.action.sources"]`} {
					if string(body[key]) != want {
						t.Errorf("wrong %s: %s", key, body[key])
					}
				}
				if tc.delay > 0 {
					select {
					case <-time.After(tc.delay):
					case <-r.Context().Done():
						return
					}
				}
				if tc.status > 0 {
					w.WriteHeader(tc.status)
				}
				if tc.sse {
					w.Header().Set("Content-Type", "text/event-stream")
					fmt.Fprintf(w, "data: {\"type\":\"response.completed\",\"response\":%s}\n\ndata: [DONE]\n\n", tc.body)
				} else {
					fmt.Fprint(w, tc.body)
				}
			}))
			defer upstream.Close()
			client := newWebSearchClient(upstream.URL+"/v1/responses", searchTestKey, "gpt-6.1-sol")
			if tc.delay > 0 {
				client.client.Timeout = 20 * time.Millisecond
			}
			handler := webSearchHandler(client, func(*http.Request) bool { return true })
			r := httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_search","arguments":{"query":"latest release","max_results":1}}}`))
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, r)
			if strings.Contains(w.Body.String(), searchTestKey) {
				t.Fatal("credential leaked")
			}
			var response struct {
				Result struct {
					IsError           bool `json:"isError"`
					StructuredContent struct {
						Kind    string
						Answer  string
						Results []struct{ Title, URL, Snippet string }
					} `json:"structuredContent"`
				}
			}
			if json.Unmarshal(w.Body.Bytes(), &response) != nil {
				t.Fatal("invalid JSON")
			}
			got := response.Result
			if tc.kind != "" {
				if !got.IsError || got.StructuredContent.Kind != tc.kind {
					t.Fatalf("wrong error: %s", w.Body)
				}
				return
			}
			if got.IsError || got.StructuredContent.Answer == "" || got.StructuredContent.Results == nil {
				t.Fatalf("wrong result: %s", w.Body)
			}
			if strings.Contains(tc.name, "citations") && tc.name != "no citations" {
				if len(got.StructuredContent.Results) != 1 || got.StructuredContent.Results[0].URL != "https://example.com/news" || got.StructuredContent.Results[0].Snippet == "" {
					t.Fatalf("wrong citations: %s", w.Body)
				}
			} else if len(got.StructuredContent.Results) != 0 {
				t.Fatal("invented citation")
			}
		})
	}
}

func TestWebSearchBoundary(t *testing.T) {
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls.Add(1); fmt.Fprint(w, searchPayload("ok", true)) }))
	defer upstream.Close()
	client := newWebSearchClient(upstream.URL, searchTestKey, "gpt-6.1-sol")
	for _, args := range []string{`{}`, `{"query":" "}`, `{"query":1}`, `{"query":"q","max_results":null}`, `{"query":"q","max_results":0}`, `{"query":"q","max_results":11}`, `{"query":"q","max_results":1.5}`, `{"query":"q","model":"other"}`, `{"query":"` + strings.Repeat("a", 2001) + `"}`} {
		w := httptest.NewRecorder()
		webSearchHandler(client, func(*http.Request) bool { return true }).ServeHTTP(w, httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_search","arguments":`+args+`}}`)))
		if !strings.Contains(w.Body.String(), `"code":-32602`) {
			t.Fatalf("accepted invalid args: %s", w.Body)
		}
	}
	for _, method := range []string{"resources/read", "resources/list", "prompts/list", "unknown"} {
		w := httptest.NewRecorder()
		webSearchHandler(client, func(*http.Request) bool { return true }).ServeHTTP(w, httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"`+method+`"}`)))
		if !strings.Contains(w.Body.String(), `"code":-32601`) {
			t.Fatal(w.Body.String())
		}
	}
	w := httptest.NewRecorder()
	webSearchHandler(client, func(*http.Request) bool { return false }).ServeHTTP(w, httptest.NewRequest("POST", "/mcp", strings.NewReader(`{}`)))
	if w.Code != 403 || calls.Load() != 0 {
		t.Fatal("denied request reached upstream")
	}
	w = httptest.NewRecorder()
	webSearchHandler(client, func(*http.Request) bool { return true }).ServeHTTP(w, httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)))
	if strings.Count(w.Body.String(), `"name":"web_search"`) != 1 {
		t.Fatal(w.Body.String())
	}
}
