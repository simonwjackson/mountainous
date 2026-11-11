package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

// The skill's socat fixture has the same login/401 flow. This HTTP fixture adds
// expiry, MFA, malformed replies and reflected credentials without subprocesses.
type scryerFixture struct {
	mu                                            sync.Mutex
	logins, calls                                 int
	lifetime                                      time.Duration
	revoke, rejectLogin, invalid, reflectPassword bool
	status                                        int
	password                                      string
}

func (f *scryerFixture) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var body struct {
		Query     string
		Variables struct {
			I struct {
				Username, Password string
				PersistSession     bool
			}
		}
	}
	if json.NewDecoder(r.Body).Decode(&body) != nil {
		w.WriteHeader(400)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if strings.Contains(body.Query, "login(input:") {
		f.logins++
		if body.Variables.I.Password != f.password || body.Variables.I.Username != "admin" || body.Variables.I.PersistSession {
			w.WriteHeader(403)
			return
		}
		if f.rejectLogin {
			fmt.Fprintf(w, `{"errors":[{"message":%q}]}`, f.password)
			return
		}
		fmt.Fprintf(w, `{"data":{"login":{"token":"tok-%d","expiresAt":%q}}}`, f.logins, time.Now().Add(f.lifetime).Format(time.RFC3339Nano))
		f.revoke = false
		return
	}
	f.calls++
	if f.revoke || r.Header.Get("Authorization") != fmt.Sprintf("Bearer tok-%d", f.logins) {
		w.WriteHeader(401)
		fmt.Fprint(w, `{"errors":[{"message":"expired"}]}`)
		return
	}
	if f.status != 0 {
		w.WriteHeader(f.status)
	}
	switch {
	case f.invalid:
		fmt.Fprint(w, `not json`)
	case f.reflectPassword:
		fmt.Fprintf(w, `{"errors":[{"message":%q}]}`, f.password)
	default:
		fmt.Fprint(w, `{"data":{"echo":1},"errors":[{"message":"step up","extensions":{"code":"MFA_STEP_UP_REQUIRED"}}]}`)
	}
}

func callScryer(handler http.Handler, body string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	r := httptest.NewRequest("POST", "/mcp", strings.NewReader(body))
	handler.ServeHTTP(w, r)
	return w
}

const scryerCall = `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":"query{echo}","variables":{"q":"Dune"}}}}`

func fixtureHandler(t *testing.T) (*scryerFixture, http.Handler) {
	t.Helper()
	f := &scryerFixture{password: "test-secret-\"\\-credential", lifetime: 24 * time.Hour}
	server := httptest.NewServer(f)
	t.Cleanup(server.Close)
	return f, scryerHandler(newScryerClient(server.URL, f.password), func(*http.Request) bool { return true })
}

func TestScryerSession(t *testing.T) {
	f, h := fixtureHandler(t)
	for range 2 {
		w := callScryer(h, scryerCall)
		var reply struct {
			Result struct{ StructuredContent json.RawMessage }
		}
		if json.Unmarshal(w.Body.Bytes(), &reply) != nil || string(reply.Result.StructuredContent) != `{"data":{"echo":1},"errors":[{"message":"step up","extensions":{"code":"MFA_STEP_UP_REQUIRED"}}]}` {
			t.Fatal("GraphQL data/errors were not preserved")
		}
	}
	if f.logins != 1 || f.calls != 2 {
		t.Fatalf("session not reused: logins=%d calls=%d", f.logins, f.calls)
	}
	f.revoke = true
	callScryer(h, scryerCall)
	if f.logins != 2 || f.calls != 4 {
		t.Fatalf("401 retry counts: logins=%d calls=%d", f.logins, f.calls)
	}
}
func TestScryerExpiry(t *testing.T) {
	f, h := fixtureHandler(t)
	f.lifetime = 4 * time.Minute
	callScryer(h, scryerCall)
	callScryer(h, scryerCall)
	if f.logins != 2 || f.calls != 2 {
		t.Fatal("session inside five-minute renewal window was reused")
	}
}
func TestScryerErrorsAndSecrets(t *testing.T) {
	for _, tc := range []struct {
		name                    string
		status                  int
		login, invalid, reflect bool
		want                    string
	}{
		{name: "MFA", status: 460, want: `"status":460`},
		{name: "server", status: 503, want: `"status":503`},
		{name: "login", login: true, want: "scryer_login_error"},
		{name: "invalid JSON", invalid: true, want: "scryer_transport_error"},
		{name: "reflected password", reflect: true, want: "scryer_credential_redacted"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f, h := fixtureHandler(t)
			f.status, f.rejectLogin, f.invalid, f.reflectPassword = tc.status, tc.login, tc.invalid, tc.reflect
			var logs bytes.Buffer
			original := log.Writer()
			log.SetOutput(&logs)
			defer log.SetOutput(original)
			w := callScryer(h, scryerCall)
			var output any
			json.Unmarshal(w.Body.Bytes(), &output)
			if !strings.Contains(w.Body.String(), tc.want) || !strings.Contains(w.Body.String(), `"isError":true`) {
				t.Fatalf("expected structured error %s", tc.want)
			}
			if containsCredential(output, f.password) || strings.Contains(logs.String(), f.password) || strings.Contains(w.Body.String(), "tok-") {
				t.Fatal("credential leaked")
			}
			if !tc.login && f.calls != 1 {
				t.Fatal("non-401 error retried")
			}
		})
	}
}
func TestScryerBoundary(t *testing.T) {
	f, h := fixtureHandler(t)
	w := callScryer(h, `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)
	var listed struct {
		Result struct{ Tools []struct{ Name string } }
	}
	json.Unmarshal(w.Body.Bytes(), &listed)
	if len(listed.Result.Tools) != 5 || listed.Result.Tools[0].Name != "scryer_graphql" {
		t.Fatal("wrong exposed tools")
	}
	w = callScryer(h, `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}`)
	if !strings.Contains(w.Body.String(), `"resources":{}`) || strings.Contains(w.Body.String(), "prompts") {
		t.Fatal("unexpected capabilities")
	}
	for _, body := range []string{
		`{"jsonrpc":"2.0","id":1,"method":"prompts/list"}`,
		`{"jsonrpc":"2.0","id":1,"method":"resources/read"}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"other"}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":"x","variables":[]}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":"x","variables":null}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":" "}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scryer_graphql","arguments":{"query":"x","url":"https://evil"}}}`,
		`{"jsonrpc":"2.0","method":"tools/call"}`,
		`[{"jsonrpc":"2.0","id":1,"method":"tools/list"}]`,
		scryerCall + `{}`,
		strings.Repeat("x", mcpMaxBody+1),
	} {
		w = callScryer(h, body)
		if !strings.Contains(w.Body.String(), `"error"`) {
			t.Fatal("invalid request accepted")
		}
	}
	if f.calls != 0 || f.logins != 0 {
		t.Fatal("denied request reached Scryer")
	}
	outsider := scryerHandler(newScryerClient("http://127.0.0.1:1", f.password), func(*http.Request) bool { return false })
	r := httptest.NewRequest("POST", "/mcp", strings.NewReader(scryerCall))
	r.Header.Set("X-Forwarded-For", "100.100.100.100")
	w = httptest.NewRecorder()
	outsider.ServeHTTP(w, r)
	if w.Code != 403 {
		t.Fatal("unverified peer accepted")
	}
}
func TestScryerFullAdminAndConcurrentReuse(t *testing.T) {
	f, h := fixtureHandler(t)
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			w := callScryer(h, strings.Replace(scryerCall, "query{echo}", "mutation{echo}", 1))
			if strings.Contains(w.Body.String(), `"error":`) {
				t.Error("mutation rejected")
			}
		}()
	}
	wg.Wait()
	if f.logins != 1 || f.calls != 8 {
		t.Fatal("concurrent calls did not reuse one session")
	}
}
