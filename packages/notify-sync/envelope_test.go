package notifysync_test

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"testing"
	"unicode/utf8"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

func encodedRequestForAssertion(t *testing.T, m ns.Message) []byte {
	t.Helper()
	var buffer bytes.Buffer
	encoder := json.NewEncoder(&buffer)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(m); err != nil {
		t.Fatal(err)
	}
	return bytes.TrimSuffix(buffer.Bytes(), []byte{'\n'})
}
func TestEscapedNotificationEnvelopesRoundTripThroughNtfy(t *testing.T) {
	base := ntfyServer(t)
	backend, _ := url.Parse(base)
	proxy := httputil.NewSingleHostReverseProxy(backend)
	var mu sync.Mutex
	var requests [][]byte
	recorder := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			data, err := io.ReadAll(r.Body)
			if err != nil {
				t.Error(err)
				return
			}
			r.Body.Close()
			mu.Lock()
			requests = append(requests, append([]byte(nil), data...))
			mu.Unlock()
			r.Body = io.NopCloser(bytes.NewReader(data))
			r.ContentLength = int64(len(data))
		}
		proxy.ServeHTTP(w, r)
	}))
	defer recorder.Close()
	cases := []struct{ name, body string }{
		{"quotes", strings.Repeat(`"`, 4095)},
		{"html", strings.Repeat("<>&", 1000)},
		{"backslashes", strings.Repeat(`\`, 4095)},
		{"emoji", strings.Repeat("😀", 2000)},
		{"controls", strings.Repeat("\x01\x07\x1b", 1365)},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := newRig(t, recorder.URL)
			r.c.Button = "tk_button_only_token_not_notify_writer"
			id := r.notify(ns.NotifyInput{Summary: "escaping regression", AppName: "test-app", Body: tc.body, Actions: []ns.Action{{Key: "go", Label: "Open"}, {Key: "retry", Label: "Retry"}}})
			r.sync()
			mu.Lock()
			data := append([]byte(nil), requests[len(requests)-1]...)
			mu.Unlock()
			var sent ns.Message
			if err := json.Unmarshal(data, &sent); err != nil {
				t.Fatalf("invalid encoded request: %v", err)
			}
			messages := r.events(id)
			if len(messages) != 1 {
				t.Fatalf("notification did not publish: envelope=%d bytes status=%+v", len(data), socketSnapshot(t, r.d).Status)
			}
			if len(data) >= 8192 || len(sent.Message) >= 4096 || !utf8.ValidString(sent.Message) {
				t.Fatalf("limits: envelope=%d text=%d", len(data), len(sent.Message))
			}
			if messages[0].Message != sent.Message || !strings.HasPrefix(tc.body, sent.Message) {
				t.Fatal("text did not round-trip as a complete prefix")
			}
			if r.item(id).Body != tc.body {
				t.Fatal("local text changed")
			}
			if len(sent.Message) < len(tc.body) {
				_, size := utf8.DecodeRuneInString(tc.body[len(sent.Message):])
				next := sent
				next.Message = tc.body[:len(sent.Message)+size]
				if len(next.Message) < 4096 && len(encodedRequestForAssertion(t, next)) < 8192 {
					t.Fatal("client cut more text than either server limit required")
				}
			}
			if tc.name == "html" && sent.Message != tc.body {
				t.Fatal("unneeded HTML escaping truncated a body that fits")
			}
			t.Logf("%s: input=%d text=%d runes=%d encoded_request=%d", tc.name, len(tc.body), len(sent.Message), utf8.RuneCountInString(sent.Message), len(data))
		})
	}
}

func TestNtfyJSONRequestLimitIsExclusive8192Bytes(t *testing.T) {
	base := ntfyServer(t)
	for _, size := range []int{8191, 8192} {
		t.Run(strconv.Itoa(size), func(t *testing.T) {
			data := []byte(`{"topic":"notify","message":"limit probe"}`)
			data = append(data, bytes.Repeat([]byte{' '}, size-len(data))...)
			response, err := http.Post(base, "application/json", bytes.NewReader(data))
			if err != nil {
				t.Fatal(err)
			}
			response.Body.Close()
			want := 200
			if size == 8192 {
				want = 413
			}
			if response.StatusCode != want {
				t.Fatalf("%d bytes: HTTP %d, want %d", size, response.StatusCode, want)
			}
		})
	}
}
func TestMetadataWithoutATextBudgetParksOnlyThatItem(t *testing.T) {
	r := newRig(t, ntfyServer(t))
	id := r.notify(ns.NotifyInput{Summary: "metadata too large", Body: "keep locally", Actions: []ns.Action{{Key: "go", Label: strings.Repeat("x", 9000)}}})
	healthy := r.notify(ns.NotifyInput{Summary: "still delivered"})
	r.sync()
	if len(r.events(id)) != 0 || len(r.events(healthy)) != 1 {
		t.Fatal("an unencodable envelope blocked other delivery")
	}
	if r.item(id).Body != "keep locally" || socketSnapshot(t, r.d).Status.LastError == nil {
		t.Fatal("failed item lost its local text or status error")
	}
}
