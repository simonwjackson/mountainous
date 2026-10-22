package notifysync_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

// Manual time is a system-boundary implementation. Advancing it never sleeps.
// A newly armed timer is the barrier that says the event loop finished its I/O.
type manualClock struct {
	mu     sync.Mutex
	now    time.Time
	timers []*manualTimer
	armed  chan *manualTimer
}
type manualTimer struct {
	clock  *manualClock
	at     time.Time
	ch     chan time.Time
	active bool
}

func newManualClock() *manualClock {
	return &manualClock{now: time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC), armed: make(chan *manualTimer, 1024)}
}
func (c *manualClock) Now() time.Time { c.mu.Lock(); defer c.mu.Unlock(); return c.now }
func (c *manualClock) NewTimer(d time.Duration) ns.Timer {
	c.mu.Lock()
	timer := &manualTimer{clock: c, at: c.now.Add(d), ch: make(chan time.Time, 1), active: true}
	c.timers = append(c.timers, timer)
	if d <= 0 {
		timer.active = false
		timer.ch <- c.now
	}
	c.mu.Unlock()
	c.armed <- timer
	return timer
}
func (t *manualTimer) C() <-chan time.Time { return t.ch }
func (t *manualTimer) Stop() bool {
	t.clock.mu.Lock()
	defer t.clock.mu.Unlock()
	was := t.active
	t.active = false
	return was
}
func (c *manualClock) Advance(d time.Duration) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = c.now.Add(d)
	fired := 0
	for _, timer := range c.timers {
		if timer.active && !timer.at.After(c.now) {
			timer.active = false
			timer.ch <- c.now
			fired++
		}
	}
	return fired
}
func (c *manualClock) awaitTimer(t *testing.T, d time.Duration) *manualTimer {
	t.Helper()
	guard := time.NewTimer(60 * time.Second)
	defer guard.Stop()
	for {
		select {
		case timer := <-c.armed:
			c.mu.Lock()
			matches := timer.active && timer.at.Sub(c.now) == d
			c.mu.Unlock()
			if matches {
				return timer
			}
		case <-guard.C:
			t.Fatalf("event loop did not arm a %s timer", d)
		}
	}
}

// schedulingHub serves the real HTTP subscription/poll boundary in memory.
// It can stage a live event before making that event visible in the cache.
type schedulingHub struct {
	mu     sync.Mutex
	polls  []string
	sinces []string
	cache  map[string][]ns.Message
	// cut > 0 makes notification replays behave as ntfy does when a user's
	// daily bandwidth runs out: 200 OK, cut messages, then an error line.
	cut     int
	streams map[chan ns.Message]struct{}
	blockAt int
	blocked chan struct{}
	release chan struct{}
}

func newSchedulingHub(t *testing.T) *schedulingHub {
	return &schedulingHub{cache: map[string][]ns.Message{}, streams: map[chan ns.Message]struct{}{}, blocked: make(chan struct{}), release: make(chan struct{})}
}
func (h *schedulingHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/x-ndjson")
	if r.URL.Query().Get("since") == "none" {
		ch := make(chan ns.Message, 16)
		h.mu.Lock()
		h.streams[ch] = struct{}{}
		h.mu.Unlock()
		defer func() { h.mu.Lock(); delete(h.streams, ch); h.mu.Unlock() }()
		json.NewEncoder(w).Encode(ns.Message{ID: "open", Event: "open"})
		w.(http.Flusher).Flush()
		for {
			select {
			case <-r.Context().Done():
				return
			case m := <-ch:
				if json.NewEncoder(w).Encode(m) != nil {
					return
				}
				w.(http.Flusher).Flush()
			}
		}
	}
	topic := strings.Split(strings.Trim(r.URL.Path, "/"), "/")[0]
	h.mu.Lock()
	h.polls = append(h.polls, topic)
	h.sinces = append(h.sinces, topic+" "+r.URL.Query().Get("since"))
	cut := h.cut
	block := h.blockAt == len(h.polls)
	h.mu.Unlock()
	if block {
		close(h.blocked)
		select {
		case <-h.release:
		case <-r.Context().Done():
			return
		}
	}
	h.mu.Lock()
	messages := append([]ns.Message(nil), h.cache[topic]...)
	h.mu.Unlock()
	cursor := r.URL.Query().Get("since")
	for i, m := range messages {
		if m.ID == cursor {
			messages = messages[i+1:]
			break
		}
	}
	cutShort := cut > 0 && topic == ns.Topic
	if cutShort && len(messages) > cut {
		messages = messages[:cut]
	}
	for _, m := range messages {
		if json.NewEncoder(w).Encode(m) != nil {
			return
		}
	}
	if cutShort {
		w.Write([]byte(`{"code":42905,"http":429,"error":"limit reached: daily bandwidth reached","link":"https://ntfy.sh/docs/publish/#limitations"}` + "\n"))
	}
}
func (h *schedulingHub) fullReplays() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	n := 0
	for _, s := range h.sinces {
		if s == ns.Topic+" all" {
			n++
		}
	}
	return n
}
func (h *schedulingHub) setCut(n int) { h.mu.Lock(); defer h.mu.Unlock(); h.cut = n }
func (h *schedulingHub) count() int   { h.mu.Lock(); defer h.mu.Unlock(); return len(h.polls) }
func (h *schedulingHub) stage(m ns.Message) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for ch := range h.streams {
		ch <- m
	}
}
func (h *schedulingHub) commit(m ns.Message) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.cache[m.Topic] = append(h.cache[m.Topic], m)
}
func schedulingDaemon(t *testing.T, h *schedulingHub) (*rig, *manualClock) {
	t.Helper()
	server := httptest.NewServer(h)
	t.Cleanup(server.Close)
	r := newRig(t, server.URL)
	clock := newManualClock()
	r.d.Clock = clock
	runDaemon(t, r)
	return r, clock
}
func awaitStartup(t *testing.T, h *schedulingHub, c *manualClock) {
	t.Helper()
	for {
		timer := c.awaitTimer(t, 30*time.Second)
		c.mu.Lock()
		h.mu.Lock()
		ready := timer.active && len(h.polls) >= 4
		h.mu.Unlock()
		c.mu.Unlock()
		if ready {
			return
		}
	}
}
func TestFallbackPollsExactlyTwoTopicsPerVirtualInterval(t *testing.T) {
	h := newSchedulingHub(t)
	_, clock := schedulingDaemon(t, h)
	awaitStartup(t, h, clock)
	if h.count() != 4 {
		t.Fatal(h.count())
	}
	for interval := 1; interval <= 4; interval++ {
		if fired := clock.Advance(29 * time.Second); fired != 0 {
			t.Fatalf("fallback fired early: %d", fired)
		}
		if got := h.count(); got != 4+2*(interval-1) {
			t.Fatalf("early polling: %d", got)
		}
		if fired := clock.Advance(time.Second); fired != 1 {
			t.Fatalf("fallback timer count %d", fired)
		}
		clock.awaitTimer(t, 30*time.Second)
		if got := h.count(); got != 4+2*interval {
			t.Fatalf("interval %d: %d polls", interval, got)
		}
	}
}
func TestFallbackKeepsItsPhaseWhenStartupReconciliationIsBlocked(t *testing.T) {
	h := newSchedulingHub(t)
	h.blockAt = 4
	r, clock := schedulingDaemon(t, h)
	select {
	case <-h.blocked:
	case <-time.After(60 * time.Second):
		t.Fatal("fourth HTTP request never started")
	}
	// This satisfies the OLD idle predicate, although the fourth response is
	// still blocked. It reproduces zero new polls without a late-started timer.
	if h.count() != 4 || socketSnapshot(t, r.d).Status.Server != "connected" {
		t.Fatal("did not reproduce old readiness predicate")
	}
	clock.Advance(95 * time.Second)
	if h.count() != 4 {
		t.Fatal("a blocked reconciliation unexpectedly polled")
	}
	close(h.release)
	// One overdue fallback catches up, then the next deadline is 120s, not 125s.
	clock.awaitTimer(t, 25*time.Second)
	if h.count() != 6 {
		t.Fatalf("coalesced catch-up: %d polls", h.count())
	}
	clock.Advance(24 * time.Second)
	if h.count() != 6 {
		t.Fatal("fallback drifted early")
	}
	clock.Advance(time.Second)
	clock.awaitTimer(t, 30*time.Second)
	if h.count() != 8 {
		t.Fatalf("fallback lost its original phase: %d", h.count())
	}
}
func TestWakeRetryBackoffUsesVirtualTime(t *testing.T) {
	h := newSchedulingHub(t)
	r, clock := schedulingDaemon(t, h)
	awaitStartup(t, h, clock)
	m := ns.Message{ID: "event-one", Sequence: "remote-one", Topic: ns.Topic, Event: "message", Title: "delayed cache insert", Message: "body"}
	h.stage(m)
	clock.awaitTimer(t, 25*time.Millisecond)
	if h.count() != 6 {
		t.Fatalf("initial wake: %d", h.count())
	}
	for i, delay := range []time.Duration{25 * time.Millisecond, 50 * time.Millisecond, 100 * time.Millisecond} {
		if clock.Advance(delay-time.Nanosecond) != 0 {
			t.Fatal("retry fired early")
		}
		if h.count() != 6+2*i {
			t.Fatal("unexpected early request")
		}
		clock.Advance(time.Nanosecond)
		clock.awaitTimer(t, delay*2)
		if h.count() != 8+2*i {
			t.Fatalf("retry %d: %d polls", i, h.count())
		}
	}
	h.commit(m)
	clock.Advance(200 * time.Millisecond)
	clock.awaitTimer(t, 30*time.Second-375*time.Millisecond)
	if !hasSummary(t, r.d, m.Title) {
		t.Fatal("visible event did not reach the UI")
	}
	if clock.Advance(time.Second) != 0 {
		t.Fatal("retry continued after the event became visible")
	}
	if h.count() != 14 {
		t.Fatalf("retry did not stop: %d polls", h.count())
	}
}

func TestWakeRetriesExpireWithoutARealTimeSleep(t *testing.T) {
	h := newSchedulingHub(t)
	_, clock := schedulingDaemon(t, h)
	awaitStartup(t, h, clock)
	h.stage(ns.Message{ID: "not-cached", Topic: ns.Topic, Event: "message"})
	for _, delay := range []time.Duration{25 * time.Millisecond, 50 * time.Millisecond, 100 * time.Millisecond, 200 * time.Millisecond, 400 * time.Millisecond, 400 * time.Millisecond, 400 * time.Millisecond, 400 * time.Millisecond, 400 * time.Millisecond} {
		clock.awaitTimer(t, delay)
		clock.Advance(delay)
	}
	// The final retry reaches virtual 2.375s. The next deadline must be the
	// original 30s fallback, not another retry or a new 30s interval.
	clock.awaitTimer(t, 30*time.Second-2375*time.Millisecond)
	if h.count() != 24 {
		t.Fatalf("bounded retries made %d polls, want 24", h.count())
	}
	if clock.Advance(time.Second) != 0 {
		t.Fatal("retry timer remained active")
	}
}

// advanceFallbacks moves virtual time across n fallback intervals and waits
// for each reconciliation to finish.
func advanceFallbacks(t *testing.T, c *manualClock, n int) {
	t.Helper()
	for i := 0; i < n; i++ {
		c.Advance(ns.FallbackInterval)
		c.awaitTimer(t, ns.FallbackInterval)
	}
}

func TestFullReplayRunsHourlyNotEveryMinute(t *testing.T) {
	h := newSchedulingHub(t)
	h.commit(ns.Message{ID: "seed", Sequence: "seed", Topic: ns.Topic, Event: "message", Title: "seed", Message: "body"})
	_, clock := schedulingDaemon(t, h)
	awaitStartup(t, h, clock)
	if got := h.fullReplays(); got != 1 {
		t.Fatalf("startup made %d full replays, want 1", got)
	}
	intervals := int(ns.FullReplayInterval / ns.FallbackInterval)
	advanceFallbacks(t, clock, intervals-1)
	if got := h.fullReplays(); got != 1 {
		t.Fatalf("%d full replays before an hour passed", got)
	}
	advanceFallbacks(t, clock, 1)
	if got := h.fullReplays(); got != 2 {
		t.Fatalf("no full replay after an hour: %d", got)
	}
}

// The 2026-10-22 failure: ntfy cut every replay short after Myoko used up its
// daily bandwidth. The full replay closed open items as evicted and pruned the
// seen marks after the cut; the next incremental replay then revived a
// dismissed item with a fresh popup.
func TestCutReplayNeitherClosesNorRevivesItems(t *testing.T) {
	h := newSchedulingHub(t)
	for _, m := range []ns.Message{
		{ID: "m-filler", Sequence: "filler", Topic: ns.Topic, Event: "message", Title: "filler", Message: "body"},
		{ID: "m-dismissed", Sequence: "dismissed", Topic: ns.Topic, Event: "message", Title: "dismissed item", Message: "body"},
		{ID: "m-clear", Sequence: "dismissed", Topic: ns.Topic, Event: "message_clear"},
		{ID: "m-open", Sequence: "open", Topic: ns.Topic, Event: "message", Title: "open item", Message: "body"},
	} {
		h.commit(m)
	}
	r, clock := schedulingDaemon(t, h)
	awaitStartup(t, h, clock)
	if hasSummary(t, r.d, "dismissed item") || !hasSummary(t, r.d, "open item") {
		t.Fatal("startup did not fold the cache")
	}
	h.setCut(1)
	// Across a full replay and the incremental replay after it.
	advanceFallbacks(t, clock, int(ns.FullReplayInterval/ns.FallbackInterval)+1)
	if hasSummary(t, r.d, "dismissed item") {
		t.Fatal("a cut replay revived a dismissed item")
	}
	if !hasSummary(t, r.d, "open item") {
		t.Fatal("a cut replay closed an open item as evicted")
	}
	status := socketSnapshot(t, r.d).Status
	if status.Server != "unreachable" || status.LastError == nil || !strings.Contains(*status.LastError, "daily bandwidth") {
		t.Fatalf("the cut replay is not reported: %+v", status)
	}
	h.setCut(0)
	advanceFallbacks(t, clock, 1)
	if hasSummary(t, r.d, "dismissed item") || !hasSummary(t, r.d, "open item") {
		t.Fatal("recovery changed the items")
	}
	if status := socketSnapshot(t, r.d).Status; status.Server != "connected" {
		t.Fatalf("did not recover: %+v", status)
	}
}
