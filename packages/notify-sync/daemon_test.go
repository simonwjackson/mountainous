package notifysync

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func ntfyServer(t *testing.T) string {
	t.Helper()
	bin := os.Getenv("NTFY_BIN")
	if bin == "" {
		var err error
		bin, err = exec.LookPath("ntfy")
		if err != nil {
			t.Skip("integration test requires NTFY_BIN or ntfy on PATH")
		}
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := l.Addr().String()
	l.Close()
	dir := t.TempDir()
	config := filepath.Join(dir, "server.yml")
	text := fmt.Sprintf("listen-http: %s\ncache-file: %s/cache.db\ncache-duration: 720h\ncache-batch-size: 0\ncache-batch-timeout: 0s\nvisitor-request-limit-exempt-hosts: 127.0.0.1\n", address, dir)
	if err = os.WriteFile(config, []byte(text), 0600); err != nil {
		t.Fatal(err)
	}
	log, err := os.Create(filepath.Join(dir, "ntfy.log"))
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(bin, "serve", "--config", config)
	cmd.Stdout = log
	cmd.Stderr = log
	if err = cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait(); log.Close() })
	base := "http://" + address
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		r, err := http.Get(base + "/v1/health")
		if err == nil {
			r.Body.Close()
			if r.StatusCode == 200 {
				return base
			}
		}
		time.Sleep(20 * time.Millisecond)
	}
	data, _ := os.ReadFile(log.Name())
	t.Fatalf("ntfy startup: %s", data)
	return ""
}

type rig struct {
	t       *testing.T
	ctx     context.Context
	d       *Daemon
	c       *Client
	signals []Signal
	path    string
}

func newRig(t *testing.T, base string) *rig {
	t.Helper()
	c, err := NewClient(base, base, "", "")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "store.db")
	s, err := OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	r := &rig{t: t, ctx: context.Background(), c: c, path: path}
	r.d = NewDaemon(s, c, "test-host")
	r.d.LocalOnlyApps = []string{"volume-osd"}
	r.d.Emit = func(s Signal) error { r.signals = append(r.signals, s); return nil }
	t.Cleanup(func() { r.d.Store.Close() })
	return r
}
func (r *rig) check(err error) {
	r.t.Helper()
	if err != nil {
		r.t.Fatal(err)
	}
}
func (r *rig) notify(in NotifyInput) uint32 {
	r.t.Helper()
	if in.AppName == "" {
		in.AppName = "test-app"
	}
	if in.Sender == "" {
		in.Sender = ":1.900"
	}
	if in.Summary == "" {
		in.Summary = r.t.Name()
	}
	id, err := r.d.Notify(in)
	r.check(err)
	return id
}
func (r *rig) row(id uint32) *record {
	r.t.Helper()
	s, err := r.d.Store.load()
	r.check(err)
	return s.Records[id]
}
func (r *rig) sync() { r.t.Helper(); r.check(r.d.SyncOnce(r.ctx)) }
func (r *rig) events(id uint32) []Message {
	r.t.Helper()
	ms, err := r.c.Poll(r.ctx, Topic, "all")
	r.check(err)
	seq := r.row(id).Item.Seq
	out := []Message{}
	for _, m := range ms {
		if m.Seq() == seq {
			out = append(out, m)
		}
	}
	return out
}
func (r *rig) control(id uint32, kind, key string) Message {
	r.t.Helper()
	b, _ := json.Marshal(Control{Version: 1, Type: kind, Seq: r.row(id).Item.Seq, Key: key})
	m, err := r.c.Publish(r.ctx, Message{Topic: ControlTopic, Message: string(b)})
	r.check(err)
	return m
}
func (r *rig) closed(id, reason uint32) {
	r.t.Helper()
	n := 0
	for _, s := range r.signals {
		if s.ID == id && s.Member == "NotificationClosed" {
			n++
			if s.Reason != reason {
				r.t.Fatalf("reason %d, want %d", s.Reason, reason)
			}
		}
	}
	if n != 1 {
		r.t.Fatalf("got %d close signals for %d", n, id)
	}
}
func (r *rig) restart() {
	r.t.Helper()
	r.check(r.d.Store.Close())
	s, err := OpenStore(r.path)
	r.check(err)
	r.d = NewDaemon(s, r.c, "test-host")
	r.d.Emit = func(s Signal) error { r.signals = append(r.signals, s); return nil }
}

func TestSpikeScenarios(t *testing.T) {
	base := ntfyServer(t)
	t.Run("publish stable sequence and two non-default app buttons", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{Actions: []Action{{"default", "Open"}, {"a", "A"}, {"b", "B"}, {"c", "C"}}, Urgency: 2})
		r.sync()
		m := r.events(id)[0]
		if len(m.Actions) != 3 || m.Actions[0].Label != "A" || m.Actions[2].Label != "Done" || m.Priority != 5 || !ValidSequence(m.Seq()) {
			t.Fatalf("payload %+v", m)
		}
		if !strings.HasPrefix(m.Seq(), "test-host-") {
			t.Fatal(m.Seq())
		}
	})
	for _, op := range []string{"dismiss", "app-close", "remote-clear", "remote-delete"} {
		t.Run(op, func(t *testing.T) {
			r := newRig(t, base)
			id := r.notify(NotifyInput{})
			r.sync()
			reason := uint32(2)
			switch op {
			case "dismiss":
				r.check(r.d.Operation(UIOperation{Op: "dismiss", ID: id}))
			case "app-close":
				reason = 3
				r.check(r.d.Close(id, reason, true, ":1.900"))
			case "remote-clear":
				r.check(r.c.Clear(r.ctx, r.row(id).Item.Seq))
			case "remote-delete":
				resp, err := r.c.request(r.ctx, "DELETE", "/notify/"+r.row(id).Item.Seq, nil)
				r.check(err)
				resp.Body.Close()
			}
			r.sync()
			r.closed(id, reason)
			if r.row(id).Open {
				t.Fatal("still open")
			}
			if n := len(r.events(id)); n != 2 {
				t.Fatalf("echo loop: %d events", n)
			}
			r.sync()
			r.closed(id, reason)
		})
	}
	t.Run("close closed ID is no-op", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		r.check(r.d.Close(id, 3, true, ":1.900"))
		r.check(r.d.Close(id, 3, true, ":1.900"))
		r.sync()
		r.closed(id, 3)
	})
	t.Run("cache expiry reason 1 sends no clear", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		s, err := r.d.Store.load()
		r.check(err)
		s.Records[id].Expires = 1
		r.check(r.d.Store.save(s))
		r.check(r.d.ReconcileExpiry(nil, time.Now().Unix()))
		r.closed(id, 1)
		r.sync()
		if len(r.events(id)) != 1 {
			t.Fatal("expiry sent clear")
		}
	})
	t.Run("popup timeout does not close store", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		time.Sleep(350 * time.Millisecond)
		if !r.row(id).Open || len(r.signals) != 0 {
			t.Fatal("popup timeout closed item")
		}
	})
	t.Run("replace keeps ID and sequence", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{Body: "10%"})
		r.sync()
		seq := r.row(id).Item.Seq
		for _, body := range []string{"60%", "100%"} {
			got := r.notify(NotifyInput{Replaces: id, Body: body})
			if got != id {
				t.Fatal("ID changed")
			}
			r.sync()
		}
		if r.row(id).Item.Seq != seq || len(r.events(id)) != 3 {
			t.Fatal("duplicate sequence")
		}
	})
	t.Run("replace after clear revives same sequence", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		r.check(r.c.Clear(r.ctx, r.row(id).Item.Seq))
		r.sync()
		if r.notify(NotifyInput{Replaces: id, Body: "revived"}) != id {
			t.Fatal("ID changed")
		}
		r.sync()
		if !r.row(id).Open || len(r.events(id)) != 3 {
			t.Fatal("not revived")
		}
	})
	for _, filter := range []string{"transient", "app-filter"} {
		t.Run(filter+" stays local", func(t *testing.T) {
			r := newRig(t, base)
			in := NotifyInput{Transient: filter == "transient"}
			if filter == "app-filter" {
				in.AppName = "volume-osd"
			}
			id := r.notify(in)
			r.sync()
			if len(r.events(id)) != 0 {
				t.Fatal("local item published")
			}
			r.check(r.d.Operation(UIOperation{Op: "dismiss", ID: id}))
			r.sync()
			r.closed(id, 2)
			if len(r.events(id)) != 0 {
				t.Fatal("local dismiss published")
			}
		})
	}
	for _, resident := range []bool{false, true} {
		t.Run(fmt.Sprintf("phone action resident=%v", resident), func(t *testing.T) {
			r := newRig(t, base)
			id := r.notify(NotifyInput{Actions: []Action{{"go", "Go"}}, Resident: resident})
			r.sync()
			ctl := r.control(id, "action", "go")
			r.sync()
			if len(r.signals) == 0 || r.signals[0].Member != "ActionInvoked" || r.signals[0].Key != "go" {
				t.Fatal(r.signals)
			}
			r.check(r.d.Handle(ctl))
			if resident {
				if !r.row(id).Open || len(r.signals) != 1 || len(r.events(id)) != 1 {
					t.Fatal("resident action closed or replayed")
				}
			} else {
				r.closed(id, 2)
				if len(r.signals) != 2 || r.signals[1].Member != "NotificationClosed" {
					t.Fatal("wrong signal order")
				}
			}
		})
	}
	t.Run("Done via stateless hub with no daemon awake", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		ctl := r.control(id, "clear", "")
		h := Hub{r.c}
		r.check(h.ApplyControl(r.ctx, ctl))
		r.check(h.ApplyControl(r.ctx, ctl))
		r.sync()
		r.closed(id, 2)
		if len(r.events(id)) != 2 {
			t.Fatal("hub duplicate clear")
		}
	})
	t.Run("hub ignores old Done after replacement", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		ctl := r.control(id, "clear", "")
		r.notify(NotifyInput{Replaces: id, Body: "new revision"})
		r.sync()
		h := Hub{r.c}
		r.check(h.ApplyControl(r.ctx, ctl))
		r.sync()
		if !r.row(id).Open || len(r.events(id)) != 2 {
			t.Fatal("old control closed latest revision")
		}
	})
	t.Run("stale clear ordered before latest publish is ignored", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{})
		r.sync()
		r.check(r.c.Clear(r.ctx, r.row(id).Item.Seq))
		r.notify(NotifyInput{Replaces: id, Body: "revision 2"})
		r.check(r.d.Flush(r.ctx))
		r.sync()
		if !r.row(id).Open || len(r.signals) != 0 {
			t.Fatal("stale clear closed current revision")
		}
	})
	t.Run("restart catches clear action delete and preserves IDs", func(t *testing.T) {
		r := newRig(t, base)
		a := r.notify(NotifyInput{})
		b := r.notify(NotifyInput{Actions: []Action{{"go", "Go"}}})
		c := r.notify(NotifyInput{})
		r.sync()
		r.check(r.c.Clear(r.ctx, r.row(a).Item.Seq))
		r.control(b, "action", "go")
		resp, err := r.c.request(r.ctx, "DELETE", "/notify/"+r.row(c).Item.Seq, nil)
		r.check(err)
		resp.Body.Close()
		r.restart()
		r.sync()
		r.closed(a, 2)
		r.closed(b, 2)
		r.closed(c, 2)
		next := r.notify(NotifyInput{})
		if next <= c {
			t.Fatal("ID reused")
		}
	})
	t.Run("clean restart produces no spurious signals", func(t *testing.T) {
		r := newRig(t, base)
		r.notify(NotifyInput{})
		r.sync()
		r.restart()
		r.sync()
		if len(r.signals) != 0 {
			t.Fatal(r.signals)
		}
	})
	t.Run("cursor loss is idempotent", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(NotifyInput{Actions: []Action{{"go", "Go"}}, Resident: true})
		r.sync()
		r.control(id, "action", "go")
		r.sync()
		s, err := r.d.Store.load()
		r.check(err)
		s.Cursors[Topic] = "XXXXXXXXXXXX"
		s.Cursors[ControlTopic] = "XXXXXXXXXXXX"
		r.check(r.d.Store.save(s))
		r.restart()
		r.sync()
		if len(r.signals) != 1 || !r.row(id).Open {
			t.Fatal("replay invoked action again")
		}
	})
	t.Run("latency twenty real publish and clear round trips", func(t *testing.T) {
		r := newRig(t, base)
		start := time.Now()
		for i := 0; i < 20; i++ {
			id := r.notify(NotifyInput{})
			r.sync()
			r.check(r.c.Clear(r.ctx, r.row(id).Item.Seq))
			r.sync()
			r.closed(id, 2)
		}
		t.Logf("20 synchronous round trips: %s", time.Since(start))
	})
	t.Run("all sequences have no consecutive clear events", func(t *testing.T) {
		c, _ := NewClient(base, base, "", "")
		ms, err := c.Poll(context.Background(), Topic, "all")
		if err != nil {
			t.Fatal(err)
		}
		prev := map[string]string{}
		for _, m := range ms {
			if m.Event != "message" && prev[m.Seq()] != "message" {
				t.Fatalf("consecutive clear for %s", m.Seq())
			}
			prev[m.Seq()] = m.Event
		}
	})
}

func TestRemoteItemsAndLiveness(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	seq, err := r.c.Send(r.ctx, SendInput{Name: "builder", Summary: "remote build", Actions: []Action{{"go", "Go"}}})
	r.check(err)
	r.sync()
	s, err := r.d.Store.load()
	r.check(err)
	item := s.bySeq(seq)
	if item == nil || item.Item.Origin != "remote" || item.Item.Host != "builder" {
		t.Fatal("remote notification missing")
	}
	r.check(r.d.Operation(UIOperation{Op: "action", ID: item.Item.ID, Key: "go"}))
	r.sync()
	ctls, err := r.c.Poll(r.ctx, ControlTopic, "all")
	r.check(err)
	if len(ctls) != 1 {
		t.Fatal("remote action not forwarded")
	}
	if len(r.signals) != 0 {
		t.Fatal("remote item signaled local application")
	}
	id := r.notify(NotifyInput{Actions: []Action{{"go", "Go"}}})
	r.sync()
	r.check(r.d.SenderGone(":1.900"))
	r.sync()
	events := r.events(id)
	if len(events[len(events)-1].Actions) != 1 || events[len(events)-1].Actions[0].Label != "Done" || r.row(id).Item.SenderAlive {
		t.Fatal("dead sender buttons remain")
	}
	r.control(id, "action", "go")
	r.sync()
	if len(r.signals) != 0 {
		t.Fatal("dead sender action emitted")
	}
	r.control(id, "action", "invalid")
	r.sync()
}

func TestOutboxRetryAndButtonScope(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	r.c.Button = "tk_button_only"
	good := r.c.Base
	r.c.Base = "http://127.0.0.1:1"
	id := r.notify(NotifyInput{})
	if err := r.d.SyncOnce(r.ctx); err == nil {
		t.Fatal("offline publish succeeded")
	}
	if r.row(id).Pending != "publish" {
		t.Fatal("outbox lost")
	}
	r.c.Base = good
	r.sync()
	m := r.events(id)[0]
	for _, a := range m.Actions {
		if a.Headers["Authorization"] != "Bearer tk_button_only" || !strings.HasSuffix(a.URL, "/notify-ctl") || a.Method != "POST" {
			t.Fatal("button has broad authority")
		}
	}
}

func TestBusSessionChangeDropsReusedSender(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	r.check(r.d.Session("old-session"))
	id := r.notify(NotifyInput{Actions: []Action{{"go", "Go"}}})
	r.sync()
	r.check(r.d.Session("new-session"))
	r.sync()
	if r.row(id).Item.SenderAlive {
		t.Fatal("sender unique name from another bus was trusted")
	}
	m := r.events(id)
	if len(m[len(m)-1].Actions) != 1 {
		t.Fatal("app buttons survived bus restart")
	}
}
func TestRemoteDismissAndHubAgentAction(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	seq, err := r.c.Send(r.ctx, SendInput{Name: "builder", Summary: "remote"})
	r.check(err)
	r.sync()
	s, err := r.d.Store.load()
	r.check(err)
	r.check(r.d.Operation(UIOperation{Op: "dismiss", ID: s.bySeq(seq).Item.ID}))
	r.sync()
	items, err := r.c.List(r.ctx)
	r.check(err)
	if len(items) != 0 {
		t.Fatal("remote dismiss not cleared")
	}
	seq, err = r.c.Send(r.ctx, SendInput{Name: "builder", Summary: "action", Actions: []Action{{"go", "Go"}}})
	r.check(err)
	ctl, _ := json.Marshal(Control{Version: 1, Type: "action", Seq: seq, Key: "go"})
	m, err := r.c.Publish(r.ctx, Message{Topic: ControlTopic, Message: string(ctl)})
	r.check(err)
	h := Hub{r.c}
	r.check(h.ApplyControl(r.ctx, m))
	ctx, cancel := context.WithTimeout(r.ctx, time.Second)
	defer cancel()
	got, err := r.c.Wait(ctx, seq)
	r.check(err)
	if got.Type != "action" || got.Key != "go" {
		t.Fatal(got)
	}
	items, err = r.c.List(r.ctx)
	r.check(err)
	if len(items) != 0 {
		t.Fatal("agent action did not clear everywhere")
	}
}

func TestNotifyAndDismissDoNotWaitForOutboxNetwork(t *testing.T) {
	base := ntfyServer(t)
	for _, dismiss := range []bool{false, true} {
		t.Run(fmt.Sprintf("dismiss=%v", dismiss), func(t *testing.T) {
			backend, _ := url.Parse(base)
			proxy := httputil.NewSingleHostReverseProxy(backend)
			started := make(chan struct{}, 1)
			release := make(chan struct{})
			var once sync.Once
			gate := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
				if req.Method == "POST" && req.URL.Path == "" || req.Method == "POST" && req.URL.Path == "/" {
					once.Do(func() { started <- struct{}{}; <-release })
				}
				proxy.ServeHTTP(w, req)
			}))
			defer gate.Close()
			r := newRig(t, gate.URL)
			id := r.notify(NotifyInput{})
			done := make(chan error, 1)
			go func() { done <- r.d.Flush(r.ctx) }()
			select {
			case <-started:
			case <-time.After(5 * time.Second):
				t.Fatal("publish did not start")
			}
			updated := make(chan error, 1)
			go func() {
				if dismiss {
					updated <- r.d.Operation(UIOperation{Op: "dismiss", ID: id})
				} else {
					_, err := r.d.Notify(NotifyInput{Sender: ":1.900", AppName: "test-app", Summary: "new revision", Body: "new revision", Replaces: id})
					updated <- err
				}
			}()
			select {
			case err := <-updated:
				r.check(err)
			case <-time.After(time.Second):
				close(release)
				t.Fatal("D-Bus operation blocked on network")
			}
			close(release)
			r.check(<-done)
			r.sync()
			if dismiss {
				if r.row(id).Open || len(r.events(id)) != 2 {
					t.Fatal("dismiss during publish lost its clear")
				}
			} else {
				if !r.row(id).Open || r.row(id).Pending != "" || len(r.events(id)) != 2 {
					t.Fatal("update during publish lost its revision")
				}
			}
		})
	}
}

func TestPruneKeepsMonotonicIDsAndCachedActionDedup(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	id := r.notify(NotifyInput{})
	r.check(r.d.Close(id, 3, false, ":1.900"))
	s, err := r.d.Store.load()
	r.check(err)
	s.Records[id].Item.Updated = 1
	s.Seen["cached-control"] = true
	s.Seen["expired-control"] = true
	r.check(r.d.Store.save(s))
	r.check(r.d.Prune([]Message{{ID: "cached-control"}}, time.Now().Unix()))
	s, err = r.d.Store.load()
	r.check(err)
	if s.Records[id] != nil || !s.Seen["cached-control"] || s.Seen["expired-control"] {
		t.Fatal("pruning violated cache lifetime")
	}
	next := r.notify(NotifyInput{})
	if next <= id {
		t.Fatal("pruning reused ID")
	}
}

func TestRestartOldIDsAndReplayOfRevivedSequence(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	id := r.notify(NotifyInput{})
	r.sync()
	r.restart()
	r.check(r.d.Close(id, 3, true, ":1.900"))
	r.sync()
	r.closed(id, 3)
	revived := r.notify(NotifyInput{Replaces: id, Body: "revived"})
	if revived != id {
		t.Fatal("replace changed ID")
	}
	r.sync()
	s, err := r.d.Store.load()
	r.check(err)
	s.Cursors[Topic] = "XXXXXXXXXXXX"
	s.Cursors[ControlTopic] = "XXXXXXXXXXXX"
	r.check(r.d.Store.save(s))
	r.restart()
	r.sync()
	if !r.row(id).Open || len(r.signals) != 1 {
		t.Fatal("full replay closed revived notification")
	}
	next := r.notify(NotifyInput{})
	if next <= id {
		t.Fatal("restart reused ID")
	}
}
func TestClearOutboxSurvivesOfflineRestart(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	id := r.notify(NotifyInput{})
	r.sync()
	r.c.Base = "http://127.0.0.1:1"
	r.check(r.d.Operation(UIOperation{Op: "dismiss", ID: id}))
	if err := r.d.SyncOnce(r.ctx); err == nil {
		t.Fatal("offline clear succeeded")
	}
	if r.row(id).Pending != "clear" {
		t.Fatal("clear lost")
	}
	r.restart()
	r.c.Base = base
	r.sync()
	if r.row(id).Pending != "" || len(r.events(id)) != 2 {
		t.Fatal("restart did not deliver clear")
	}
	r.closed(id, 2)
}
