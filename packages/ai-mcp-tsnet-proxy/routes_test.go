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
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"tailscale.com/client/tailscale/apitype"
	"tailscale.com/tailcfg"
)

// Real stable IDs from the tailnet: claw-simon (flakey), Laure's claw, and Zao.
const (
	simonNode = "nbQJZMcewG11CNTRL"
	laureNode = "nkT3Yhzyy121CNTRL"
	zaoNode   = "nto5J2nGb311CNTRL"
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
	node, identityErr := simonNode, error(nil)
	router := newMCPRouter(http.NotFoundHandler(), func(r *http.Request) (string, error) {
		if r.RemoteAddr != "192.0.2.1:1234" {
			t.Error("WhoIs must receive original remote address")
		}
		return node, identityErr
	})
	path := tableFile(t, map[string]mcpRoute{
		"echo":  {Backend: backend.URL + "/fixed-mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}, BearerCredential: "echo-key"},
		"other": {Backend: backend.URL + "/fixed-mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"other"}, BearerCredential: "echo-key"},
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
	for _, denied := range []string{laureNode, zaoNode, "", "claw-simon", "claw-simon.hummingbird-lake.ts.net."} {
		node = denied
		if w := routeRequest(router, "/mcp/echo", listRequest); w.Code != 403 {
			t.Fatalf("node %q got %d", denied, w.Code)
		}
	}
	node, identityErr = simonNode, errors.New("WhoIs unavailable")
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
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return simonNode, nil })
	path := tableFile(t, map[string]mcpRoute{"echo": {Backend: old.URL, CallerNodeIDs: []string{simonNode}, Tools: []string{"old"}}})
	if err := router.reload(path, ""); err != nil {
		t.Fatal(err)
	}
	done := make(chan *httptest.ResponseRecorder, 1)
	go func() { done <- routeRequest(router, "/mcp/echo", listRequest) }()
	<-started
	writeTable(t, path, map[string]mcpRoute{"new": {Backend: newBackend.URL, CallerNodeIDs: []string{simonNode}, Tools: []string{"new"}}})
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
		"empty-callers":      {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{}, Tools: []string{"echo"}},
		"no-tools":           {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode}},
		"non-loopback":       {Backend: "https://example.com/mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}},
		"query":              {Backend: "http://127.0.0.1:8422/mcp?secret=x", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}},
		"caller-wildcard":    {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{"*"}, Tools: []string{"echo"}},
		"caller-empty-id":    {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{""}, Tools: []string{"echo"}},
		"caller-node-name":   {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{"claw-simon"}, Tools: []string{"echo"}},
		"caller-short-name":  {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{"zao"}, Tools: []string{"echo"}},
		"caller-new-name":    {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{"flakey"}, Tools: []string{"echo"}},
		"caller-not-an-id":   {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{"nbQJZMcewG11"}, Tools: []string{"echo"}},
		"caller-dns-name":    {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{"claw-simon.hummingbird-lake.ts.net."}, Tools: []string{"echo"}},
		"caller-joined-ids":  {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode + "," + zaoNode}, Tools: []string{"echo"}},
		"caller-spaced-id":   {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{" " + simonNode}, Tools: []string{"echo"}},
		"credential-path":    {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}, BearerCredential: "/tmp/key"},
		"missing-credential": {Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}, BearerCredential: "missing"},
	} {
		t.Run(name, func(t *testing.T) {
			router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return simonNode, nil })
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
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return simonNode, nil })
	path := tableFile(t, map[string]mcpRoute{"echo": {Backend: backend.URL, CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}}})
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
		"unknown-field": `{"echo":{"backend":"http://127.0.0.1:8422","callerNodeIds":["nbQJZMcewG11CNTRL"],"mcpTools":["echo"],"bearer":"inline-secret"}}`,
		// A stage-one table matched node names. The new binary must refuse it.
		"name-callers":   `{"echo":{"backend":"http://127.0.0.1:8422","callers":["claw-simon"],"mcpTools":["echo"]}}`,
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

func TestMCPRoutesMatchCallersByStableNodeID(t *testing.T) {
	calls := 0
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"echo"}]}}`)
	}))
	defer backend.Close()
	caller := ""
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return caller, nil })
	if err := router.reload(tableFile(t, map[string]mcpRoute{
		"sparkyfitness": {Backend: backend.URL + "/mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}},
		"echo":          {Backend: backend.URL + "/mcp", CallerNodeIDs: []string{simonNode, zaoNode}, Tools: []string{"echo"}},
	}), ""); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		path, caller string
		want         int
	}{
		{"/mcp/sparkyfitness", simonNode, 200},
		{"/mcp/sparkyfitness", laureNode, 403},
		{"/mcp/sparkyfitness", zaoNode, 403},
		{"/mcp/echo", simonNode, 200},
		{"/mcp/echo", zaoNode, 200},
		{"/mcp/echo", laureNode, 403},
		// A node that takes over a removed node's name gets a new stable ID.
		{"/mcp/sparkyfitness", "nNewNodeSameName1CNTRL", 403},
		// The node name and DNS name no longer grant anything.
		{"/mcp/sparkyfitness", "claw-simon", 403},
		{"/mcp/sparkyfitness", "flakey", 403},
		{"/mcp/sparkyfitness", "claw-simon.hummingbird-lake.ts.net.", 403},
		// Exact and case-sensitive: no prefix, suffix, case or list match.
		{"/mcp/sparkyfitness", "nbqjzmcewg11cntrl", 403},
		{"/mcp/sparkyfitness", simonNode + "x", 403},
		{"/mcp/sparkyfitness", simonNode[:len(simonNode)-1], 403},
		{"/mcp/sparkyfitness", simonNode + "," + laureNode, 403},
		{"/mcp/sparkyfitness", "", 403},
	} {
		caller = c.caller
		before := calls
		w := routeRequest(router, c.path, listRequest)
		if w.Code != c.want {
			t.Fatalf("%s from %q: got %d, want %d", c.path, c.caller, w.Code, c.want)
		}
		if forwarded := calls - before; (c.want == 200) != (forwarded == 1) {
			t.Fatalf("%s from %q reached upstream %d times", c.path, c.caller, forwarded)
		}
	}
}

func TestWhoIsStableNodeIDUsesOnlyTheStableID(t *testing.T) {
	named := func(name string, id tailcfg.StableNodeID) *apitype.WhoIsResponse {
		return &apitype.WhoIsResponse{
			Node:        &tailcfg.Node{Name: name, StableID: id},
			UserProfile: &tailcfg.UserProfile{LoginName: "simon.jackson@gmail.com"},
		}
	}
	if id, err := whoIsStableNodeID(named("claw-simon.hummingbird-lake.ts.net.", simonNode), nil); err != nil || id != simonNode {
		t.Fatalf("got %q %v", id, err)
	}
	// After a rename the same node keeps its ID.
	if id, err := whoIsStableNodeID(named("flakey.hummingbird-lake.ts.net.", simonNode), nil); err != nil || id != simonNode {
		t.Fatalf("renamed node got %q %v", id, err)
	}
	for name, c := range map[string]struct {
		peer *apitype.WhoIsResponse
		err  error
	}{
		"lookup-error":    {named("claw-simon.hummingbird-lake.ts.net.", simonNode), errors.New("WhoIs unavailable")},
		"no-peer":         {nil, nil},
		"no-node":         {&apitype.WhoIsResponse{UserProfile: &tailcfg.UserProfile{LoginName: "simon.jackson@gmail.com"}}, nil},
		"name-without-id": {named("claw-simon.hummingbird-lake.ts.net.", ""), nil},
	} {
		if id, err := whoIsStableNodeID(c.peer, c.err); err == nil || id != "" {
			t.Errorf("%s: got %q %v, want an error", name, id, err)
		}
	}
}

func TestMCPRoutesBadInitialTableKeepsFrontDoor(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer server-secret" {
			t.Error("wrong upstream credential")
		}
		io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"sparky_get_food_diary"}]}}`)
	}))
	defer backend.Close()
	row := mcpRoute{Backend: backend.URL + "/mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"sparky_get_food_diary"}, BearerCredential: "mcp-sparkyfitness"}
	for name, c := range map[string]struct {
		table      string // empty: no table file
		credential *string
	}{
		"missing-table":      {"", nil},
		"malformed-table":    {`{"sparkyfitness":`, nil},
		"stage-one-table":    {`{"sparkyfitness":{"backend":"http://127.0.0.1:3010/mcp","callers":["claw-simon"],"mcpTools":["x"]}}`, nil},
		"missing-credential": {"row", nil},
		"empty-credential":   {"row", new(string)},
		// systemd's SetCredential default (modules/tailnet-names.nix) when the sops file is absent.
		"systemd-default-credential": {"row", func() *string { v := "unavailable credential"; return &v }()},
		"whitespace-credential":      {"row", func() *string { v := "server secret\n"; return &v }()},
	} {
		t.Run(name, func(t *testing.T) {
			dir, credentials := t.TempDir(), t.TempDir()
			path := filepath.Join(dir, "table.json")
			switch c.table {
			case "":
			case "row":
				writeTable(t, path, map[string]mcpRoute{"sparkyfitness": row})
			default:
				if err := os.WriteFile(path, []byte(c.table), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if c.credential != nil {
				if err := os.WriteFile(filepath.Join(credentials, "mcp-sparkyfitness"), []byte(*c.credential), 0600); err != nil {
					t.Fatal(err)
				}
			}
			frontDoor := 0
			router := newMCPRouter(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				frontDoor++
				w.WriteHeader(201)
			}), func(*http.Request) (string, error) { return simonNode, nil })
			router.loadInitial(path, credentials) // must not exit or panic
			for _, p := range []string{"/v1/models", "/v1/responses", "/mcp"} {
				if w := routeRequest(router, p, "{}"); w.Code != 201 {
					t.Fatalf("front door %s got %d", p, w.Code)
				}
			}
			if frontDoor != 3 {
				t.Fatalf("front door served %d of 3", frontDoor)
			}
			if w := routeRequest(router, "/mcp/sparkyfitness", listRequest); w.Code != 404 {
				t.Fatalf("rejected row is served: %d", w.Code)
			}
			// Fixing the table and credential, then a reload, publishes the row.
			writeTable(t, path, map[string]mcpRoute{"sparkyfitness": row})
			if err := os.WriteFile(filepath.Join(credentials, "mcp-sparkyfitness"), []byte("server-secret\n"), 0600); err != nil {
				t.Fatal(err)
			}
			if err := router.reload(path, credentials); err != nil {
				t.Fatal(err)
			}
			if w := routeRequest(router, "/mcp/sparkyfitness", listRequest); w.Code != 200 || !strings.Contains(w.Body.String(), "sparky_get_food_diary") {
				t.Fatalf("fixed row not served: %d %s", w.Code, w.Body)
			}
		})
	}
}

func TestMCPRoutesReloadSignalDuringStartupIsKept(t *testing.T) {
	reloads := notifyReloads()
	defer signal.Stop(reloads)
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"echo"}]}}`)
	}))
	defer backend.Close()
	path := tableFile(t, map[string]mcpRoute{})
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return simonNode, nil })
	router.loadInitial(path, "")
	writeTable(t, path, map[string]mcpRoute{"echo": {Backend: backend.URL, CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}}})
	// SIGHUP before the watcher runs, as during the tailnet start. Without
	// notifyReloads its default action would kill this test process.
	if err := syscall.Kill(syscall.Getpid(), syscall.SIGHUP); err != nil {
		t.Fatal(err)
	}
	time.Sleep(50 * time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go router.watch(ctx, reloads, path, "")
	deadline := time.Now().Add(3 * time.Second)
	for routeRequest(router, "/mcp/echo", listRequest).Code != 200 {
		if time.Now().After(deadline) {
			t.Fatal("startup SIGHUP was not applied after watch started")
		}
		time.Sleep(time.Millisecond)
	}
}

// An eBay-like loopback row: tools and MCP App views each have an exact list.
func TestMCPRoutesServeExactResources(t *testing.T) {
	var methods []string
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request mcpRequest
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Error(err)
		}
		methods = append(methods, request.Method+" "+string(request.Params))
		switch request.Method {
		case "resources/list":
			io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"resources":[{"uri":"ui://ebay/search.html"},{"uri":"ui://ebay/admin.html"}]}}`)
		case "resources/read":
			io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"contents":[{"uri":"ui://ebay/search.html","text":"<!DOCTYPE html>"}]}}`)
		default:
			io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-03-26","serverInfo":{"name":"ebay"},"tools":[]}}`)
		}
	}))
	defer backend.Close()
	caller := simonNode
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return caller, nil })
	if err := router.reload(tableFile(t, map[string]mcpRoute{
		"ebay":     {Backend: backend.URL + "/mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"ebay_listings"}, Resources: []string{"ui://ebay/search.html"}},
		"calendar": {Backend: backend.URL + "/mcp", CallerNodeIDs: []string{simonNode}, Tools: []string{"calendar_busy"}},
	}), ""); err != nil {
		t.Fatal(err)
	}
	w := routeRequest(router, "/mcp/ebay", `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{}}}`)
	if !strings.Contains(w.Body.String(), `"resources":{}`) {
		t.Fatalf("a row with views must announce resources: %s", w.Body)
	}
	w = routeRequest(router, "/mcp/ebay", `{"jsonrpc":"2.0","id":1,"method":"resources/list"}`)
	if !strings.Contains(w.Body.String(), "ui://ebay/search.html") || strings.Contains(w.Body.String(), "admin") {
		t.Fatalf("resource list not filtered: %s", w.Body)
	}
	w = routeRequest(router, "/mcp/ebay", `{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"ui://ebay/search.html"}}`)
	if !strings.Contains(w.Body.String(), "DOCTYPE") {
		t.Fatalf("allowed view not read: %s", w.Body)
	}
	before := len(methods)
	for path, body := range map[string]string{
		"/mcp/ebay":     `{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"ui://ebay/admin.html"}}`,
		"/mcp/calendar": `{"jsonrpc":"2.0","id":1,"method":"resources/list"}`,
	} {
		w := routeRequest(router, path, body)
		if !strings.Contains(w.Body.String(), "-32601") {
			t.Fatalf("%s: refused resource method answered: %s", path, w.Body)
		}
	}
	caller = laureNode
	if w := routeRequest(router, "/mcp/ebay", `{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"ui://ebay/search.html"}}`); w.Code != 403 {
		t.Fatalf("another caller read a view: %d", w.Code)
	}
	if len(methods) != before {
		t.Fatalf("refused resource traffic reached upstream: %v", methods[before:])
	}
}

func scryerRouteFixture(t *testing.T, fixture *scryerFixture, row mcpRoute) (*mcpRouter, *string) {
	t.Helper()
	server := httptest.NewServer(fixture)
	t.Cleanup(server.Close)
	original := newScryerRouteClient
	t.Cleanup(func() { newScryerRouteClient = original })
	newScryerRouteClient = func(graphql, username, password string) *scryerClient {
		if graphql != row.Scryer.URL {
			t.Errorf("Scryer client for %q, want the row's URL", graphql)
		}
		return newScryerClient(server.URL, username, password)
	}
	credentials := t.TempDir()
	if err := os.WriteFile(filepath.Join(credentials, "mcp-scryer"), []byte(fixture.password+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	caller := simonNode
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return caller, nil })
	if err := router.reload(tableFile(t, map[string]mcpRoute{"scryer": row}), credentials); err != nil {
		t.Fatal(err)
	}
	return router, &caller
}

func scryerRow(tools ...string) mcpRoute {
	return mcpRoute{CallerNodeIDs: []string{simonNode}, Tools: tools, Scryer: &scryerRoute{
		URL: "https://scryer.hummingbird-lake.ts.net/graphql", Username: "simon", PasswordCredential: "mcp-scryer"}}
}

func TestMCPRoutesScryerRowServesOnlyItsTools(t *testing.T) {
	fixture := &scryerFixture{password: "pass word", username: "simon", lifetime: time.Hour}
	router, caller := scryerRouteFixture(t, fixture, scryerRow("scryer_graphql", "scryer_search"))
	w := routeRequest(router, "/mcp/scryer", `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}`)
	if !strings.Contains(w.Body.String(), `"claw-scryer"`) {
		t.Fatalf("initialize: %s", w.Body)
	}
	w = routeRequest(router, "/mcp/scryer", listRequest)
	var listed struct {
		Result struct{ Tools []struct{ Name string } }
	}
	if err := json.Unmarshal(w.Body.Bytes(), &listed); err != nil {
		t.Fatal(err)
	}
	names := []string{}
	for _, tool := range listed.Result.Tools {
		names = append(names, tool.Name)
	}
	if strings.Join(names, ",") != "scryer_graphql,scryer_search" {
		t.Fatalf("listed %v, want exactly the row's tools", names)
	}
	fixture.mu.Lock()
	calls := fixture.calls
	fixture.mu.Unlock()
	for _, tool := range []string{"scryer_add", "scryer_monitor", "scryer_title", "scryer_delete"} {
		w := routeRequest(router, "/mcp/scryer", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"`+tool+`","arguments":{"titleId":"1"}}}`)
		if !strings.Contains(w.Body.String(), "-32601") {
			t.Fatalf("%s outside the row answered: %s", tool, w.Body)
		}
	}
	fixture.mu.Lock()
	if fixture.calls != calls {
		t.Fatal("a refused tool reached Scryer")
	}
	fixture.mu.Unlock()
	w = routeRequest(router, "/mcp/scryer", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":"{echo}"}}}`)
	if !strings.Contains(w.Body.String(), `\"echo\":1`) || strings.Contains(w.Body.String(), "pass word") {
		t.Fatalf("allowed read failed or leaked: %s", w.Body)
	}
	w = routeRequest(router, "/mcp/scryer", `{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"ui://scryer/media.html"}}`)
	if !strings.Contains(w.Body.String(), scryerViewMIME) {
		t.Fatalf("view not served: %s", w.Body)
	}
	fixture.mu.Lock()
	calls, logins := fixture.calls, fixture.logins
	fixture.mu.Unlock()
	for _, denied := range []string{laureNode, zaoNode, "", "claw-scryer-simon"} {
		*caller = denied
		if w := routeRequest(router, "/mcp/scryer", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":"{echo}"}}}`); w.Code != 403 {
			t.Fatalf("caller %q got %d", denied, w.Code)
		}
	}
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	if fixture.calls != calls || fixture.logins != logins {
		t.Fatal("a denied caller reached Scryer")
	}
}

func TestMCPRoutesRejectInvalidScryerAndResourceRows(t *testing.T) {
	scryer := func(edit func(*mcpRoute)) mcpRoute {
		row := scryerRow("scryer_graphql")
		row.Scryer = &scryerRoute{URL: row.Scryer.URL, Username: row.Scryer.Username, PasswordCredential: row.Scryer.PasswordCredential}
		edit(&row)
		return row
	}
	for name, c := range map[string]struct {
		row      mcpRoute
		password string
	}{
		"scryer-unknown-tool":       {scryer(func(r *mcpRoute) { r.Tools = []string{"scryer_graphql", "scryer_delete"} }), "secret"},
		"scryer-with-backend":       {scryer(func(r *mcpRoute) { r.Backend = "http://127.0.0.1:8422" }), "secret"},
		"scryer-with-bearer":        {scryer(func(r *mcpRoute) { r.BearerCredential = "mcp-scryer" }), "secret"},
		"scryer-with-resources":     {scryer(func(r *mcpRoute) { r.Resources = []string{"ui://scryer/media.html"} }), "secret"},
		"scryer-http":               {scryer(func(r *mcpRoute) { r.Scryer.URL = "http://scryer.hummingbird-lake.ts.net/graphql" }), "secret"},
		"scryer-userinfo":           {scryer(func(r *mcpRoute) { r.Scryer.URL = "https://simon:x@scryer.hummingbird-lake.ts.net/graphql" }), "secret"},
		"scryer-query":              {scryer(func(r *mcpRoute) { r.Scryer.URL = "https://scryer.hummingbird-lake.ts.net/graphql?x=1" }), "secret"},
		"scryer-empty-query":        {scryer(func(r *mcpRoute) { r.Scryer.URL = "https://scryer.hummingbird-lake.ts.net/graphql?" }), "secret"},
		"scryer-bad-username":       {scryer(func(r *mcpRoute) { r.Scryer.Username = "simon jackson" }), "secret"},
		"scryer-credential-path":    {scryer(func(r *mcpRoute) { r.Scryer.PasswordCredential = "/run/secrets/x" }), "secret"},
		"scryer-missing-credential": {scryer(func(r *mcpRoute) { r.Scryer.PasswordCredential = "missing" }), "secret"},
		"scryer-empty-password":     {scryer(func(*mcpRoute) {}), ""},
		"scryer-newline-password":   {scryer(func(*mcpRoute) {}), "\n"},
		"scryer-two-lines":          {scryer(func(*mcpRoute) {}), "one\ntwo"},
		// systemd's SetCredential default when the sops file is missing.
		"scryer-systemd-default": {scryer(func(*mcpRoute) {}), "unavailable credential"},
		"resource-http":          {mcpRoute{Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}, Resources: []string{"https://example.com/view"}}, "secret"},
		"resource-empty-ui":      {mcpRoute{Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}, Resources: []string{"ui://"}}, "secret"},
		"resource-joined":        {mcpRoute{Backend: "http://127.0.0.1:8422", CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}, Resources: []string{"ui://a.html,ui://b.html"}}, "secret"},
		"no-backend":             {mcpRoute{CallerNodeIDs: []string{simonNode}, Tools: []string{"echo"}}, "secret"},
	} {
		t.Run(name, func(t *testing.T) {
			credentials := t.TempDir()
			if err := os.WriteFile(filepath.Join(credentials, "mcp-scryer"), []byte(c.password), 0600); err != nil {
				t.Fatal(err)
			}
			router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return simonNode, nil })
			if router.reload(tableFile(t, map[string]mcpRoute{"echo": c.row}), credentials) == nil {
				t.Fatal("invalid row accepted")
			}
		})
	}
}

// One bad Scryer password must not stop the front door, as for a bad key.
func TestMCPRoutesScryerSystemdDefaultKeepsFrontDoor(t *testing.T) {
	dir, credentials := t.TempDir(), t.TempDir()
	path := filepath.Join(dir, "table.json")
	writeTable(t, path, map[string]mcpRoute{"scryer": scryerRow("scryer_graphql")})
	if err := os.WriteFile(filepath.Join(credentials, "mcp-scryer"), []byte("unavailable credential"), 0600); err != nil {
		t.Fatal(err)
	}
	router := newMCPRouter(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(201) }),
		func(*http.Request) (string, error) { return simonNode, nil })
	router.loadInitial(path, credentials)
	if w := routeRequest(router, "/v1/models", "{}"); w.Code != 201 {
		t.Fatalf("front door got %d", w.Code)
	}
	if w := routeRequest(router, "/mcp/scryer", listRequest); w.Code != 404 {
		t.Fatalf("row with the systemd default served: %d", w.Code)
	}
}

const webSearchRowKey = "row-held-search-key"

func webSearchRow(callers ...string) mcpRoute {
	return mcpRoute{CallerNodeIDs: callers, Tools: []string{"web_search"}, WebSearch: &webSearchRoute{
		URL: webSearchResponsesURL, Model: "gpt-6.1-sol", KeyCredential: "mcp-websearch"}}
}

// A real Responses server on loopback stands in for the front door; the row's
// fixed URL is checked, then the client is pointed at this server.
func webSearchRouteFixture(t *testing.T, row mcpRoute, key string) (*mcpRouter, *string, *[]string) {
	t.Helper()
	seen := &[]string{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*seen = append(*seen, r.Header.Get("Authorization"))
		if r.URL.Path != "/v1/responses" || r.Header.Get("Cookie") != "" || r.Header.Get("X-Api-Key") != "" {
			t.Error("caller headers or another path reached the front door")
		}
		w.Header().Set("Content-Type", "application/json")
		io.WriteString(w, searchPayload("Fresh answer", true))
	}))
	t.Cleanup(server.Close)
	original := newWebSearchRouteClient
	t.Cleanup(func() { newWebSearchRouteClient = original })
	newWebSearchRouteClient = func(responses, key, model string) *webSearchClient {
		if responses != webSearchResponsesURL || model != "gpt-6.1-sol" {
			t.Errorf("web search client for %q %q, want the row's URL and model", responses, model)
		}
		return newWebSearchClient(server.URL+"/v1/responses", key, model)
	}
	credentials := t.TempDir()
	if err := os.WriteFile(filepath.Join(credentials, "mcp-websearch"), []byte(key), 0600); err != nil {
		t.Fatal(err)
	}
	caller := simonNode
	router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return caller, nil })
	if err := router.reload(tableFile(t, map[string]mcpRoute{"websearch": row}), credentials); err != nil {
		t.Fatal(err)
	}
	return router, &caller, seen
}

func TestMCPRoutesWebSearchRowServesBothGatewaysOnly(t *testing.T) {
	router, caller, seen := webSearchRouteFixture(t, webSearchRow(simonNode, laureNode), webSearchRowKey+"\n")
	call := `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_search","arguments":{"query":"news","max_results":1}}}`
	for _, allowed := range []string{simonNode, laureNode} {
		*caller = allowed
		w := routeRequest(router, "/mcp/websearch", `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}`)
		if w.Code != 200 || !strings.Contains(w.Body.String(), `"claw-websearch"`) {
			t.Fatalf("initialize for %s: %d %s", allowed, w.Code, w.Body)
		}
		w = routeRequest(router, "/mcp/websearch", listRequest)
		var listed struct {
			Result struct{ Tools []struct{ Name string } }
		}
		if err := json.Unmarshal(w.Body.Bytes(), &listed); err != nil || len(listed.Result.Tools) != 1 || listed.Result.Tools[0].Name != "web_search" {
			t.Fatalf("tools/list for %s: %s", allowed, w.Body)
		}
		w = routeRequest(router, "/mcp/websearch", call)
		if w.Code != 200 || !strings.Contains(w.Body.String(), "Fresh answer") || strings.Contains(w.Body.String(), `"isError":true`) {
			t.Fatalf("web_search for %s: %d %s", allowed, w.Code, w.Body)
		}
		if strings.Contains(w.Body.String(), webSearchRowKey) {
			t.Fatal("the row's key reached a caller")
		}
	}
	if len(*seen) != 2 || (*seen)[0] != "Bearer "+webSearchRowKey || (*seen)[1] != "Bearer "+webSearchRowKey {
		t.Fatalf("front door saw %v, want only the row's key twice", *seen)
	}
	w := routeRequest(router, "/mcp/websearch", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_fetch","arguments":{}}}`)
	if !strings.Contains(w.Body.String(), "-32601") {
		t.Fatalf("another tool answered: %s", w.Body)
	}
	for _, denied := range []string{zaoNode, "", "claw", "nOtherNode11CNTRL"} {
		*caller = denied
		if w := routeRequest(router, "/mcp/websearch", call); w.Code != 403 {
			t.Fatalf("caller %q got %d", denied, w.Code)
		}
	}
	if len(*seen) != 2 {
		t.Fatal("a refused call reached the front door")
	}
}

func TestMCPRoutesRejectInvalidWebSearchRows(t *testing.T) {
	search := func(edit func(*mcpRoute)) mcpRoute {
		row := webSearchRow(simonNode)
		row.WebSearch = &webSearchRoute{URL: row.WebSearch.URL, Model: row.WebSearch.Model, KeyCredential: row.WebSearch.KeyCredential}
		edit(&row)
		return row
	}
	for name, c := range map[string]struct {
		row mcpRoute
		key string
	}{
		"with-backend":       {search(func(r *mcpRoute) { r.Backend = "http://127.0.0.1:8422" }), "secret"},
		"with-bearer":        {search(func(r *mcpRoute) { r.BearerCredential = "mcp-websearch" }), "secret"},
		"with-resources":     {search(func(r *mcpRoute) { r.Resources = []string{"ui://search.html"} }), "secret"},
		"with-scryer":        {search(func(r *mcpRoute) { r.Scryer = scryerRow("scryer_graphql").Scryer }), "secret"},
		"another-tool":       {search(func(r *mcpRoute) { r.Tools = []string{"web_fetch"} }), "secret"},
		"two-tools":          {search(func(r *mcpRoute) { r.Tools = []string{"web_search", "web_fetch"} }), "secret"},
		"another-port":       {search(func(r *mcpRoute) { r.WebSearch.URL = "http://127.0.0.1:8431/v1/responses" }), "secret"},
		"https":              {search(func(r *mcpRoute) { r.WebSearch.URL = "https://127.0.0.1:8430/v1/responses" }), "secret"},
		"remote":             {search(func(r *mcpRoute) { r.WebSearch.URL = "http://ai.hummingbird-lake.ts.net/v1/responses" }), "secret"},
		"another-path":       {search(func(r *mcpRoute) { r.WebSearch.URL = "http://127.0.0.1:8430/v1/chat/completions" }), "secret"},
		"query":              {search(func(r *mcpRoute) { r.WebSearch.URL = webSearchResponsesURL + "?x=1" }), "secret"},
		"empty-model":        {search(func(r *mcpRoute) { r.WebSearch.Model = "" }), "secret"},
		"bad-model":          {search(func(r *mcpRoute) { r.WebSearch.Model = "gpt 6" }), "secret"},
		"credential-path":    {search(func(r *mcpRoute) { r.WebSearch.KeyCredential = "/run/secrets/x" }), "secret"},
		"missing-credential": {search(func(r *mcpRoute) { r.WebSearch.KeyCredential = "missing" }), "secret"},
		"empty-key":          {search(func(*mcpRoute) {}), ""},
		"newline-key":        {search(func(*mcpRoute) {}), "\n"},
		"two-lines":          {search(func(*mcpRoute) {}), "one\ntwo"},
		// systemd's SetCredential default when the sops file is missing.
		"systemd-default": {search(func(*mcpRoute) {}), "unavailable credential"},
	} {
		t.Run(name, func(t *testing.T) {
			credentials := t.TempDir()
			if err := os.WriteFile(filepath.Join(credentials, "mcp-websearch"), []byte(c.key), 0600); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(credentials, "mcp-scryer"), []byte("secret"), 0600); err != nil {
				t.Fatal(err)
			}
			router := newMCPRouter(http.NotFoundHandler(), func(*http.Request) (string, error) { return simonNode, nil })
			if router.reload(tableFile(t, map[string]mcpRoute{"websearch": c.row}), credentials) == nil {
				t.Fatal("invalid row accepted")
			}
		})
	}
}

// A missing web search key, like a bad SparkyFitness key, must not stop the front door.
func TestMCPRoutesWebSearchSystemdDefaultKeepsFrontDoor(t *testing.T) {
	dir, credentials := t.TempDir(), t.TempDir()
	path := filepath.Join(dir, "table.json")
	writeTable(t, path, map[string]mcpRoute{"websearch": webSearchRow(simonNode, laureNode)})
	if err := os.WriteFile(filepath.Join(credentials, "mcp-websearch"), []byte("unavailable credential"), 0600); err != nil {
		t.Fatal(err)
	}
	router := newMCPRouter(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(201) }),
		func(*http.Request) (string, error) { return simonNode, nil })
	router.loadInitial(path, credentials)
	if w := routeRequest(router, "/v1/models", "{}"); w.Code != 201 {
		t.Fatalf("front door got %d", w.Code)
	}
	if w := routeRequest(router, "/mcp/websearch", listRequest); w.Code != 404 {
		t.Fatalf("row with the systemd default served: %d", w.Code)
	}
}
