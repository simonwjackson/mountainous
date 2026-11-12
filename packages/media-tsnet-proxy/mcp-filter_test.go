package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestMCPBoundary(t *testing.T) {
	calls := 0
	var expectedHost string
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.Host != expectedHost || r.URL.Path != "/mcp" {
			t.Error("incorrect upstream request")
		}
		var request struct {
			Method string `json:"method"`
		}
		json.NewDecoder(r.Body).Decode(&request)
		w.Header().Set("Content-Type", "text/event-stream")
		switch request.Method {
		case "tools/list":
			w.Write([]byte("event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"tools\":[{\"name\":\"calendar_busy\"},{\"name\":\"mail_list\"},{\"name\":\"mail_send\"}],\"nextCursor\":\"secret\"}}\n\n"))
		case "initialize":
			w.Write([]byte("data: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-03-26\",\"serverInfo\":{\"name\":\"google\",\"version\":\"1\"},\"capabilities\":{\"tools\":{},\"resources\":{},\"prompts\":{}}}}\n\n"))
		default:
			w.Write([]byte("data: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"content\":[]}}\n\n"))
		}
	}))
	defer backend.Close()
	target, _ := url.Parse(backend.URL)
	expectedHost = target.Host
	handler := mcpHandler(target, []string{"calendar_busy"}, func(*http.Request) bool { return true })
	send := func(body string) *httptest.ResponseRecorder {
		t.Helper()
		r := httptest.NewRequest("POST", "https://claw-calendar.example/mcp", strings.NewReader(body))
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	for _, method := range []string{"mail_list", "mail_read", "mail_proposals", "mail_send", "calendar_create", "not_listed", "Calendar_busy", "calendar_busy/../mail_list"} {
		before := calls
		w := send(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"` + method + `","arguments":{}}}`)
		if !strings.Contains(w.Body.String(), `"code":-32601`) || calls != before {
			t.Fatalf("denied tool reached backend: %s %s", method, w.Body.String())
		}
	}
	for _, body := range []string{
		`{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"ui://mail"}}`,
		`{"jsonrpc":"2.0","id":1,"method":"prompts/get"}`,
		`[{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"mail_list"}}]`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/list"} {"method":"tools/call"}`,
		`{"jsonrpc":"2.0","method":"tools/call","params":{"name":"calendar_busy"}}`,
	} {
		before := calls
		w := send(body)
		if !strings.Contains(w.Body.String(), `"error"`) || calls != before {
			t.Fatalf("unsafe request forwarded: %s", body)
		}
	}
	w := send(`{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)
	if !strings.Contains(w.Body.String(), "calendar_busy") || strings.Contains(w.Body.String(), "mail_") || strings.Contains(w.Body.String(), "nextCursor") {
		t.Fatal(w.Body.String())
	}
	w = send(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}`)
	if strings.Contains(w.Body.String(), "resources") || strings.Contains(w.Body.String(), "prompts") {
		t.Fatal(w.Body.String())
	}
	before := calls
	w = send(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"calendar_busy","arguments":{}}}`)
	if calls != before+1 || strings.Contains(w.Body.String(), "error") {
		t.Fatal(w.Body.String())
	}
	before = calls
	w = send(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)
	if w.Code != 202 || calls != before {
		t.Fatal("initialization notification must be handled locally")
	}
	outsider := mcpHandler(target, []string{"calendar_busy"}, func(*http.Request) bool { return false })
	r := httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"tools/list"}`))
	r.Header.Set("X-Forwarded-For", "100.100.100.100")
	w = httptest.NewRecorder()
	outsider.ServeHTTP(w, r)
	if w.Code != 403 || calls != before {
		t.Fatal("non-tailnet client accepted")
	}
}

func TestMCPMapsBoundary(t *testing.T) {
	target, _ := url.Parse("http://127.0.0.1:1")
	handler := mcpHandler(target, []string{"travel_time"}, func(*http.Request) bool { return true })
	for _, tool := range []string{"calendar_busy", "mail_list", "not_listed"} {
		r := httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"`+tool+`"}}`))
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if !strings.Contains(w.Body.String(), `"code":-32601`) {
			t.Fatal(w.Body.String())
		}
	}
}

// An upstream that grows write tools or resources cannot widen this endpoint.
func TestMCPEbayViewsBoundary(t *testing.T) {
	calls := 0
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		var request mcpRequest
		json.NewDecoder(r.Body).Decode(&request)
		w.Header().Set("Content-Type", "application/json")
		result := map[string]any{}
		switch request.Method {
		case "initialize":
			result = map[string]any{"protocolVersion": "2025-11-25", "serverInfo": map[string]any{"name": "ebay"}, "capabilities": map[string]any{"prompts": map[string]any{}}}
		case "tools/list":
			result["tools"] = []any{map[string]any{"name": "ebay_search"}, map[string]any{"name": "ebay_listings"}, map[string]any{"name": "ebay_buy"}}
		case "resources/list":
			result["resources"] = []any{map[string]any{"uri": "ui://ebay/search.html"}, map[string]any{"uri": "ui://ebay/listings.html"}, map[string]any{"uri": "ui://other/secrets"}}
			result["nextCursor"] = "secret"
		case "resources/read":
			result["contents"] = []any{map[string]any{"uri": "ui://ebay/search.html", "mimeType": "text/html;profile=mcp-app", "text": "<!-- ebay-view source-sha256: test -->", "_meta": map[string]any{"ui": map[string]any{"csp": map[string]any{"resourceDomains": []string{"https://i.ebayimg.com"}}}}}}
		}
		json.NewEncoder(w).Encode(map[string]any{"jsonrpc": "2.0", "id": 1, "result": result})
	}))
	defer backend.Close()
	target, _ := url.Parse(backend.URL)
	handler := mcpResourceHandler(target, []string{"ebay_search", "ebay_listings"}, []string{"ui://ebay/search.html", "ui://ebay/listings.html"}, func(*http.Request) bool { return true })
	send := func(method, params string) string {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"`+method+`","params":`+params+`}`)))
		return w.Body.String()
	}
	for _, uri := range []string{"ui://ebay/../secrets", "ui://other/secrets", "ui://ebay/write.html", "ui://ebay/search.html?secret=1"} {
		before := calls
		if !strings.Contains(send("resources/read", `{"uri":"`+uri+`"}`), `"code":-32601`) || calls != before {
			t.Fatal("unlisted resource forwarded")
		}
	}
	for _, method := range []string{"resources/subscribe", "prompts/list", "ebay/write"} {
		before := calls
		if !strings.Contains(send(method, `{}`), `"code":-32601`) || calls != before {
			t.Fatal("unlisted method forwarded")
		}
	}
	before := calls
	if !strings.Contains(send("tools/call", `{"name":"ebay_buy"}`), `"code":-32601`) || calls != before {
		t.Fatal("write forwarded")
	}
	if got := send("initialize", `{}`); !strings.Contains(got, "resources") || strings.Contains(got, "prompts") {
		t.Fatal(got)
	}
	if got := send("tools/list", `{}`); strings.Contains(got, "ebay_buy") || !strings.Contains(got, "ebay_listings") {
		t.Fatal(got)
	}
	if got := send("resources/list", `{}`); strings.Contains(got, "secrets") || strings.Contains(got, "nextCursor") || !strings.Contains(got, "listings.html") {
		t.Fatal(got)
	}
	if got := send("resources/read", `{"uri":"ui://ebay/search.html"}`); !strings.Contains(got, "source-sha256") || !strings.Contains(got, "https://i.ebayimg.com") {
		t.Fatal(got)
	}
	for _, name := range []string{"ebay_search", "ebay_listings"} {
		if got := send("tools/call", `{"name":"`+name+`","arguments":{}}`); strings.Contains(got, `"error"`) {
			t.Fatal(got)
		}
	}
}
