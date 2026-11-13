package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

func tableFile(t *testing.T, table map[string]mcpRoute) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "table.json")
	writeTable(t, path, table)
	return path
}

func writeTable(t *testing.T, path string, table map[string]mcpRoute) {
	t.Helper()
	data, err := json.Marshal(table)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
}

func routeRequest(router http.Handler, path, body string) *httptest.ResponseRecorder {
	r := httptest.NewRequest("POST", path, strings.NewReader(body))
	r.Header.Set("Authorization", "Bearer caller-secret")
	r.Header.Set("Cookie", "session=caller-secret")
	r.Header.Set("Proxy-Authorization", "Basic caller-secret")
	r.Header.Set("X-Api-Key", "caller-secret")
	r.Header.Set("X-Forwarded-For", "claw-simon")
	r.Header.Set("MCP-Protocol-Version", "2025-03-26")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, r)
	return w
}

const listRequest = `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`

func TestMCPRoutesIdentityCredentialsAndFiltering(t *testing.T) {
	requests := 0
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if r.URL.String() != "/fixed-mcp" || r.Header.Get("Authorization") != "Bearer server-secret" {
			t.Errorf("wrong fixed upstream or credential: %s", r.URL)
		}
		for _, header := range []string{"Cookie", "Proxy-Authorization", "X-Api-Key", "X-Forwarded-For"} {
			if r.Header.Get(header) != "" {
				t.Errorf("caller header leaked: %s", header)
			}
		}
		if r.Header.Get("MCP-Protocol-Version") != "2025-03-26" {
			t.Error("protocol version missing")
		}
		io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"echo"},{"name":"other"},{"name":"secret"}]}}`)
	}))
	defer backend.Close()
	credentials := t.TempDir()
	if err := os.WriteFile(filepath.Join(credentials, "echo-key"), []byte("server-secret\n"), 0600); err != nil {
		t.Fatal(err)
	}
	node, identityErr := "claw-simon.hummingbird-lake.ts.net.", error(nil)
	router := newMCPRouter(http.NotFoundHandler(), func(r *http.Request) (string, error) {
		if r.RemoteAddr != "192.0.2.1:1234" {
			t.Error("WhoIs must receive original remote address")
		}
		return node, identityErr
	})
	path := tableFile(t, map[string]mcpRoute{
		"echo":  {Backend: backend.URL + "/fixed-mcp", Callers: []string{"claw-simon"}, Tools: []string{"echo"}, BearerCredential: "echo-key"},
		"other": {Backend: backend.URL + "/fixed-mcp", Callers: []string{"claw-simon"}, Tools: []string{"other"}, BearerCredential: "echo-key"},
	})
	if err := router.reload(path, credentials); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"echo", "other"} {
		w := routeRequest(router, "/mcp/"+name, listRequest)
		var response struct {
			Result struct{ Tools []struct{ Name string } }
		}
		if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil || len(response.Result.Tools) != 1 || response.Result.Tools[0].Name != name {
			t.Fatalf("per-row list filter: %s", w.Body)
		}
	}
	before := requests
	w := routeRequest(router, "/mcp/echo", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"other"}}`)
	if !strings.Contains(w.Body.String(), "tool not allowed") || requests != before {
		t.Fatal("disallowed tool reached upstream")
	}
	for _, denied := range []string{"zao.hummingbird-lake.ts.net.", "", "claw-simon-2.hummingbird-lake.ts.net."} {
		node = denied
		if w := routeRequest(router, "/mcp/echo", listRequest); w.Code != 403 {
			t.Fatalf("node %q got %d", denied, w.Code)
		}
	}
	node, identityErr = "claw-simon.hummingbird-lake.ts.net.", errors.New("WhoIs unavailable")
	if w := routeRequest(router, "/mcp/echo", listRequest); w.Code != 403 {
		t.Fatal("WhoIs failure must deny")
	}
	for _, unknown := range []string{"/mcp/missing", "/mcp/", "/mcp/echo/", "/mcp/echo/nested"} {
		if w := routeRequest(router, unknown, listRequest); w.Code != 404 {
			t.Fatalf("unknown path %s got %d", unknown, w.Code)
		}
	}
	if requests != before {
		t.Fatal("denied traffic reached upstream")
	}
}

func TestMCPRoutesNormalPathsAreUnchanged(t *testing.T) {
	for _, path := range []string{"/v1/responses?model=test", "/v1/models", "/health", "/", "/mcp", "/mcpx/echo"} {
		request := httptest.NewRequest("PATCH", path, strings.NewReader("exact body"))
		request.Header.Set("Authorization", "Bearer per-client-key")
		request.Header.Set("Cookie", "normal=unchanged")
		called := false
		router := newMCPRouter(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			called = true
			if r != request || r.Header.Get("Authorization") != "Bearer per-client-key" || r.Header.Get("Cookie") != "normal=unchanged" {
				t.Error("normal request was modified")
			}
			body, _ := io.ReadAll(r.Body)
			if string(body) != "exact body" {
				t.Error("body changed")
			}
			w.WriteHeader(201)
		}), func(*http.Request) (string, error) { t.Fatal("normal path must not call WhoIs"); return "", nil })
		w := httptest.NewRecorder()
		router.ServeHTTP(w, request)
		if !called || w.Code != 201 {
			t.Fatalf("fallback missed %s", path)
		}
	}
}

func TestMCPRoutesFrontDoorStreamingAndHeaders(t *testing.T) {
	release := make(chan struct{})
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.String() != "/v1/responses?stream=true" || r.Header.Get("Authorization") != "Bearer client-key" || r.Header.Get("Cookie") != "client=cookie" || r.Header.Get("X-Forwarded-Proto") != "https" {
			t.Error("front-door request contract changed")
		}
		// Like a real model backend, read the whole request before streaming.
		if body, err := io.ReadAll(r.Body); err != nil || string(body) != "{}" {
			t.Error("front-door request body changed")
		}
		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("X-Backend", "unchanged")
		io.WriteString(w, "data: first\n\n")
		w.(http.Flusher).Flush()
		<-release
		io.WriteString(w, "data: last\n\n")
	}))
	defer backend.Close()
	u, _ := url.Parse(backend.URL)
	router := newMCPRouter(proxyHandler(u), func(*http.Request) (string, error) { t.Error("WhoIs called for model stream"); return "", nil })
	server := httptest.NewServer(router)
	defer server.Close()
	request, _ := http.NewRequest("POST", server.URL+"/v1/responses?stream=true", strings.NewReader("{}"))
	// A chunked body makes the shared proxy see EOF before the backend can answer.
	// With a fixed length, an instant answer races the HTTP/1.x server's
	// request-body close (Go issue 15527) in the shared proxyHandler, not here.
	request.ContentLength = -1
	request.Header.Set("Authorization", "Bearer client-key")
	request.Header.Set("Cookie", "client=cookie")
	client := &http.Client{Timeout: 3 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		close(release)
		t.Fatal(err)
	}
	defer response.Body.Close()
	first := make([]byte, len("data: first\n\n"))
	_, err = io.ReadFull(response.Body, first)
	if err != nil || string(first) != "data: first\n\n" || response.Header.Get("X-Backend") != "unchanged" {
		close(release)
		t.Fatalf("stream was buffered/changed: %v", err)
	}
	// Reload while the front-door stream is open too.
	if err := router.reload(tableFile(t, map[string]mcpRoute{}), ""); err != nil {
		t.Fatal(err)
	}
	close(release)
	last, err := io.ReadAll(response.Body)
	if err != nil || string(last) != "data: last\n\n" {
		t.Fatalf("stream dropped on reload: %s %v", last, err)
	}
}

func TestMCPRoutesReloadRetainsInflightAndRejectsInvalidTable(t *testing.T) {
	started, release := make(chan struct{}), make(chan struct{})
	old := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(started)
		<-release
		io.WriteString(w, `{"result":{"tools":[{"name":"old"}]}}`)
	}))
	defer old.Close()
	newBackend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, `{"result":{"tools":[{"name":"new"}]}}`)
	}))
	defer newBackend.Close()
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return "claw-simon.tailnet.ts.net.", nil })
	path := tableFile(t, map[string]mcpRoute{"echo": {Backend: old.URL, Callers: []string{"claw-simon"}, Tools: []string{"old"}}})
	if err := router.reload(path, ""); err != nil {
		t.Fatal(err)
	}
	done := make(chan *httptest.ResponseRecorder, 1)
	go func() { done <- routeRequest(router, "/mcp/echo", listRequest) }()
	<-started
	writeTable(t, path, map[string]mcpRoute{"new": {Backend: newBackend.URL, Callers: []string{"claw-simon"}, Tools: []string{"new"}}})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reloads := make(chan os.Signal, 1)
	go router.watch(ctx, reloads, path, "")
	reloads <- syscall.SIGHUP
	deadline := time.Now().Add(3 * time.Second)
	for {
		w := routeRequest(router, "/mcp/new", listRequest)
		if w.Code == 200 && strings.Contains(w.Body.String(), `"name":"new"`) {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("SIGHUP table reload did not publish")
		}
		time.Sleep(time.Millisecond)
	}
	if w := routeRequest(router, "/mcp/new", listRequest); !strings.Contains(w.Body.String(), `"name":"new"`) {
		t.Fatalf("new request used old table: %s", w.Body)
	}
	writeTable(t, path, map[string]mcpRoute{"echo": {Backend: newBackend.URL, Tools: []string{"new"}}})
	if router.reload(path, "") == nil {
		t.Fatal("accepted row without callers")
	}
	if w := routeRequest(router, "/mcp/new", listRequest); !strings.Contains(w.Body.String(), `"name":"new"`) {
		t.Fatal("invalid reload replaced working table")
	}
	close(release)
	select {
	case w := <-done:
		if !strings.Contains(w.Body.String(), `"name":"old"`) {
			t.Fatalf("inflight request changed: %s", w.Body)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("inflight request dropped")
	}
}

func TestMCPRoutesRejectInvalidCredentialsAndRows(t *testing.T) {
	for name, row := range map[string]mcpRoute{
		"no-callers":         {Backend: "http://127.0.0.1:8422", Tools: []string{"echo"}},
		"no-tools":           {Backend: "http://127.0.0.1:8422", Callers: []string{"claw-simon"}},
		"non-loopback":       {Backend: "https://example.com/mcp", Callers: []string{"claw-simon"}, Tools: []string{"echo"}},
		"query":              {Backend: "http://127.0.0.1:8422/mcp?secret=x", Callers: []string{"claw-simon"}, Tools: []string{"echo"}},
		"caller":             {Backend: "http://127.0.0.1:8422", Callers: []string{"*"}, Tools: []string{"echo"}},
		"credential-path":    {Backend: "http://127.0.0.1:8422", Callers: []string{"claw-simon"}, Tools: []string{"echo"}, BearerCredential: "/tmp/key"},
		"missing-credential": {Backend: "http://127.0.0.1:8422", Callers: []string{"claw-simon"}, Tools: []string{"echo"}, BearerCredential: "missing"},
	} {
		t.Run(name, func(t *testing.T) {
			router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return "claw-simon", nil })
			if router.reload(tableFile(t, map[string]mcpRoute{"echo": row}), t.TempDir()) == nil {
				t.Fatal("invalid row accepted")
			}
		})
	}
}

func TestMCPRoutesWithoutCredentialNeverUseCallerAuth(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		for _, header := range []string{"Authorization", "Proxy-Authorization", "Cookie", "X-Api-Key", "X-Forwarded-For"} {
			if r.Header.Get(header) != "" {
				t.Errorf("caller header forwarded without server credential: %s", header)
			}
		}
		var request mcpRequest
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Error(err)
		}
		io.WriteString(w, `{"result":{"content":[{"type":"text","text":"ok"}]}}`)
	}))
	defer backend.Close()
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return "claw-simon.tailnet.ts.net", nil })
	path := tableFile(t, map[string]mcpRoute{"echo": {Backend: backend.URL, Callers: []string{"claw-simon"}, Tools: []string{"echo"}}})
	if err := router.reload(path, ""); err != nil {
		t.Fatal(err)
	}
	w := routeRequest(router, "/mcp/echo", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"echo"}}`)
	if !strings.Contains(w.Body.String(), `"text":"ok"`) {
		t.Fatalf("allowed call failed: %s", w.Body)
	}
	// Removing the last row keeps the router alive and revokes the path.
	writeTable(t, path, map[string]mcpRoute{})
	if err := router.reload(path, ""); err != nil {
		t.Fatal(err)
	}
	if w := routeRequest(router, "/mcp/echo", listRequest); w.Code != 404 {
		t.Fatal("deleted route is still available")
	}
}

func TestMCPRoutesRejectMalformedTables(t *testing.T) {
	for name, data := range map[string]string{
		"unknown-field":  `{"echo":{"backend":"http://127.0.0.1:8422","callers":["claw-simon"],"mcpTools":["echo"],"bearer":"inline-secret"}}`,
		"trailing-value": `{} {}`,
		"null":           `null`,
		"large":          `{}` + strings.Repeat(" ", 1<<20),
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "table.json")
			if err := os.WriteFile(path, []byte(data), 0600); err != nil {
				t.Fatal(err)
			}
			router := newMCPRouter(http.NotFoundHandler(), nil)
			if router.reload(path, t.TempDir()) == nil {
				t.Fatal("malformed table accepted")
			}
		})
	}
}
