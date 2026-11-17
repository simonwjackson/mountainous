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

func searchPayload(results ...map[string]any) string {
	if results == nil {
		results = []map[string]any{}
	}
	data, _ := json.Marshal(map[string]any{"object": "search", "results": results})
	return string(data)
}

func result(title, url, snippet string) map[string]any {
	return map[string]any{"title": title, "url": url, "snippet": snippet, "date": nil}
}

func TestWebSearchResponses(t *testing.T) {
	news := result("News", "https://example.com/news", "New release today")
	for _, tc := range []struct {
		name, body, kind, retryAfter  string
		status, wantStatus, wantRetry int
		delay                         time.Duration
		want                          []string
	}{
		{name: "results", body: searchPayload(news, result("Duplicate", "https://example.com/news", ""), result("Unsafe", "file:///etc/passwd", ""), result("", "https://example.org/b", "second")), want: []string{"https://example.com/news", "https://example.org/b"}},
		{name: "empty", body: searchPayload(), want: []string{}},
		{name: "rate limited", body: `{"error":{"code":"search_sources_exhausted"}}`, status: 429, retryAfter: "334219", kind: "rate_limited", wantStatus: 429, wantRetry: 334219},
		{name: "rate limited no reset", body: searchTestKey, status: 429, kind: "rate_limited", wantStatus: 429},
		{name: "unavailable", body: searchTestKey, status: 503, kind: "upstream_http_error", wantStatus: 503},
		{name: "forbidden", body: searchTestKey, status: 403, kind: "upstream_http_error", wantStatus: 403},
		{name: "timeout", delay: 100 * time.Millisecond, kind: "upstream_timeout"},
		{name: "invalid JSON", body: "not JSON", kind: "invalid_response"},
		{name: "not a search answer", body: `{"object":"response","results":[]}`, kind: "invalid_response"},
		{name: "too large", body: strings.Repeat("x", mcpMaxBody+1), kind: "invalid_response"},
		{name: "reflected credential", body: searchPayload(result("x", "https://example.com/?k="+searchTestKey, "")), kind: "credential_redacted"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.Method != "POST" || r.URL.Path != "/v1/search" || r.Header.Get("Authorization") != "Bearer "+searchTestKey || r.Header.Get("Content-Type") != "application/json" {
					t.Error("wrong upstream contract")
				}
				var body map[string]json.RawMessage
				if json.NewDecoder(r.Body).Decode(&body) != nil {
					t.Error("invalid request")
				}
				// The front door picks the source: no model, tools or source names.
				if len(body) != 2 || string(body["query"]) != `"latest release"` || string(body["max_results"]) != "2" {
					t.Errorf("wrong request: %v", body)
				}
				if tc.delay > 0 {
					select {
					case <-time.After(tc.delay):
					case <-r.Context().Done():
						return
					}
				}
				if tc.retryAfter != "" {
					w.Header().Set("Retry-After", tc.retryAfter)
				}
				if tc.status > 0 {
					w.WriteHeader(tc.status)
				}
				fmt.Fprint(w, tc.body)
			}))
			defer upstream.Close()
			client := newWebSearchClient(upstream.URL+"/v1/search", searchTestKey)
			if tc.delay > 0 {
				client.client.Timeout = 20 * time.Millisecond
			}
			handler := webSearchHandler(client, func(*http.Request) bool { return true })
			r := httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_search","arguments":{"query":"latest release","max_results":2}}}`))
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, r)
			if strings.Contains(w.Body.String(), searchTestKey) || strings.Contains(w.Body.String(), "search_sources_exhausted") {
				t.Fatal("credential or upstream body leaked")
			}
			var response struct {
				Result struct {
					IsError bool `json:"isError"`
					Content []struct {
						Type, Text string
					} `json:"content"`
					StructuredContent struct {
						Kind       string
						Status     int
						RetryAfter *int `json:"retry_after"`
						Results    []struct{ Title, URL, Snippet string }
					} `json:"structuredContent"`
				}
			}
			if json.Unmarshal(w.Body.Bytes(), &response) != nil {
				t.Fatal("invalid JSON")
			}
			got := response.Result
			if tc.kind != "" {
				if !got.IsError || got.StructuredContent.Kind != tc.kind || got.StructuredContent.Status != tc.wantStatus {
					t.Fatalf("wrong error: %s", w.Body)
				}
				if tc.kind == "rate_limited" && (got.StructuredContent.RetryAfter == nil || *got.StructuredContent.RetryAfter != tc.wantRetry) {
					t.Fatalf("wrong retry_after: %s", w.Body)
				}
				return
			}
			if got.IsError || got.StructuredContent.Results == nil || len(got.Content) != 1 || got.Content[0].Type != "text" {
				t.Fatalf("wrong result: %s", w.Body)
			}
			// The text block carries the same list as structuredContent.
			var text struct {
				Results []struct{ Title, URL, Snippet string }
			}
			if json.Unmarshal([]byte(got.Content[0].Text), &text) != nil || len(text.Results) != len(got.StructuredContent.Results) {
				t.Fatalf("text and structuredContent differ: %s", w.Body)
			}
			urls := []string{}
			for _, r := range got.StructuredContent.Results {
				urls = append(urls, r.URL)
				if r.Title == "" {
					t.Fatal("empty title")
				}
			}
			if strings.Join(urls, " ") != strings.Join(tc.want, " ") {
				t.Fatalf("wrong results %v: %s", urls, w.Body)
			}
			if len(tc.want) > 0 && got.StructuredContent.Results[0].Snippet != "New release today" {
				t.Fatalf("wrong snippet: %s", w.Body)
			}
		})
	}
}

func TestRetryAfterSeconds(t *testing.T) {
	now := time.Date(2026, 11, 17, 0, 0, 0, 0, time.UTC)
	for value, want := range map[string]int{"30": 30, " 7 ": 7, "0": 0, "-3": 0, "": 0, "soon": 0, now.Add(90 * time.Second).Format(http.TimeFormat): 90, now.Add(-time.Minute).Format(http.TimeFormat): 0} {
		if got := retryAfterSeconds(value, now); got != want {
			t.Errorf("%q: got %d, want %d", value, got, want)
		}
	}
}

func TestWebSearchBoundary(t *testing.T) {
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		fmt.Fprint(w, searchPayload(result("ok", "https://example.com/", "")))
	}))
	defer upstream.Close()
	client := newWebSearchClient(upstream.URL, searchTestKey)
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
	if strings.Count(w.Body.String(), `"name":"web_search"`) != 1 || strings.Contains(w.Body.String(), "cited answer") {
		t.Fatal(w.Body.String())
	}
}
