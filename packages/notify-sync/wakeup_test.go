package notifysync_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"sync/atomic"
	"testing"
	"time"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

// streamGateway forwards the real ntfy stream. Tests can delay cache visibility
// or disconnect that transport without touching notification persistence.
type streamGateway struct {
	url             string
	opens           atomic.Int32
	polls           atomic.Int32
	hiddenPolls     atomic.Int32
	hideUntil       atomic.Int64
	visibilityDelay time.Duration
	firstCancel     chan context.CancelFunc
	allowReconnect  chan struct{}
}

func newStreamGateway(t *testing.T, base string, delay time.Duration, holdReconnect bool) *streamGateway {
	t.Helper()
	backend, _ := url.Parse(base)
	proxy := httputil.NewSingleHostReverseProxy(backend)
	g := &streamGateway{visibilityDelay: delay, firstCancel: make(chan context.CancelFunc, 1), allowReconnect: make(chan struct{})}
	if !holdReconnect {
		close(g.allowReconnect)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("poll") == "1" {
			g.polls.Add(1)
			if time.Now().UnixNano() < g.hideUntil.Load() {
				g.hiddenPolls.Add(1)
				w.Header().Set("Content-Type", "application/x-ndjson")
				return
			}
		}
		if r.URL.Query().Get("since") != "none" || r.URL.Path != "/notify,notify-ctl/json" {
			proxy.ServeHTTP(w, r)
			return
		}
		n := g.opens.Add(1)
		if n > 1 {
			select {
			case <-g.allowReconnect:
			case <-r.Context().Done():
				return
			}
		}
		ctx, cancel := context.WithCancel(r.Context())
		defer cancel()
		if n == 1 {
			g.firstCancel <- cancel
		}
		req, err := http.NewRequestWithContext(ctx, "GET", base+r.URL.RequestURI(), nil)
		if err != nil {
			t.Error(err)
			return
		}
		response, err := http.DefaultClient.Do(req)
		if err != nil {
			return
		}
		defer response.Body.Close()
		w.Header().Set("Content-Type", "application/x-ndjson")
		w.WriteHeader(response.StatusCode)
		w.(http.Flusher).Flush()
		decoder := json.NewDecoder(response.Body)
		for {
			var raw json.RawMessage
			if err = decoder.Decode(&raw); err != nil {
				return
			}
			var message ns.Message
			if json.Unmarshal(raw, &message) != nil {
				return
			}
			if message.Event == "message" && g.visibilityDelay > 0 {
				g.hideUntil.Store(time.Now().Add(g.visibilityDelay).UnixNano())
			}
			if _, err = w.Write(append(raw, '\n')); err != nil {
				return
			}
			w.(http.Flusher).Flush()
		}
	}))
	g.url = server.URL
	t.Cleanup(server.Close)
	return g
}
func runDaemon(t *testing.T, r *rig) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- r.d.Run(ctx) }()
	t.Cleanup(func() { cancel(); r.check(<-done) })
}
func hasSummary(t *testing.T, d *ns.Daemon, summary string) bool {
	for _, i := range socketSnapshot(t, d).Items {
		if i.Summary == summary {
			return true
		}
	}
	return false
}
func TestStreamWakeRetriesUntilTheCacheShowsTheEvent(t *testing.T) {
	base := ntfyServer(t)
	gate := newStreamGateway(t, base, 200*time.Millisecond, false)
	r := newRig(t, gate.url)
	runDaemon(t, r)
	eventually(t, func() bool { return gate.opens.Load() > 0 && gate.polls.Load() >= 4 })
	sender, err := ns.NewClient(base, base, "", "")
	r.check(err)
	_, err = sender.Send(r.ctx, ns.SendInput{Name: "external", Summary: "cache visibility race"})
	r.check(err)
	eventually(t, func() bool { return hasSummary(t, r.d, "cache visibility race") })
	if gate.hiddenPolls.Load() == 0 {
		t.Fatal("test did not stage dispatch before cache visibility")
	}
}
func TestStreamReconnectReconcilesEventsMissedWhileDisconnected(t *testing.T) {
	base := ntfyServer(t)
	gate := newStreamGateway(t, base, 0, true)
	r := newRig(t, gate.url)
	runDaemon(t, r)
	var cancel context.CancelFunc
	select {
	case cancel = <-gate.firstCancel:
	case <-time.After(5 * time.Second):
		t.Fatal("stream never connected")
	}
	eventually(t, func() bool { return gate.polls.Load() >= 4 })
	cancel()
	eventually(t, func() bool { return gate.opens.Load() >= 2 })
	sender, err := ns.NewClient(base, base, "", "")
	r.check(err)
	_, err = sender.Send(r.ctx, ns.SendInput{Name: "external", Summary: "missed while disconnected"})
	r.check(err)
	close(gate.allowReconnect)
	eventually(t, func() bool { return hasSummary(t, r.d, "missed while disconnected") })
}

func TestIdleDaemonUsesTwoOrderedPollsPerThirtySeconds(t *testing.T) {
	base := ntfyServer(t)
	gate := newStreamGateway(t, base, 0, false)
	r := newRig(t, gate.url)
	runDaemon(t, r)
	eventually(t, func() bool {
		return gate.opens.Load() == 1 && gate.polls.Load() >= 4 && socketSnapshot(t, r.d).Status.Server == "connected"
	})
	polls, opens := gate.polls.Load(), gate.opens.Load()
	start := time.Now()
	time.Sleep(31 * time.Second)
	count := gate.polls.Load() - polls
	connections := gate.opens.Load() - opens
	elapsed := time.Since(start)
	t.Logf("idle: %d ordered GETs and %d stream reconnects in %.3fs (%.4f requests/s)", count, connections, elapsed.Seconds(), float64(count+connections)/elapsed.Seconds())
	if count != 2 || connections != 0 {
		t.Fatalf("idle daemon made %d polls and %d stream reconnects", count, connections)
	}
}
func TestOutboxChangeWakesAnIdleDaemon(t *testing.T) {
	base := ntfyServer(t)
	gate := newStreamGateway(t, base, 0, false)
	r := newRig(t, gate.url)
	runDaemon(t, r)
	eventually(t, func() bool { return gate.polls.Load() >= 4 })
	id := r.notify(ns.NotifyInput{Summary: "publish without waiting for fallback"})
	eventually(t, func() bool { return len(r.events(id)) == 1 })
}
