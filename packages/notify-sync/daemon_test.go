package notifysync_test

import (
	"context"
	"encoding/json"
	"fmt"
	ns "github.com/simonwjackson/mountainous/notify-sync"
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
	return ntfyServerWith(t, "")
}

// ntfyServerWith starts ntfy with extra lines appended to its config.
func ntfyServerWith(t *testing.T, extra string) string {
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
	text := fmt.Sprintf("listen-http: %s\ncache-file: %s/cache.db\ncache-duration: 720h\ncache-batch-size: 0\ncache-batch-timeout: 0s\nvisitor-request-limit-exempt-hosts: 127.0.0.1\n%s", address, dir, extra)
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
	exited := make(chan struct{})
	var processErr error
	go func() { processErr = cmd.Wait(); close(exited) }()
	t.Cleanup(func() { cmd.Process.Kill(); <-exited; log.Close() })
	base := "http://" + address
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	if err := waitForHealth(ctx, base, exited); err != nil {
		data, _ := os.ReadFile(log.Name())
		select {
		case <-exited:
			t.Fatalf("ntfy startup: %v (process: %v): %s", err, processErr, data)
		default:
			t.Fatalf("ntfy startup: %v: %s", err, data)
		}
	}
	return base
}

type rig struct {
	t       *testing.T
	ctx     context.Context
	d       *ns.Daemon
	c       *ns.Client
	signals []ns.Signal
	path    string
	items   map[uint32]ns.Item
}

func newRig(t *testing.T, base string) *rig {
	t.Helper()
	c, err := ns.NewClient(base, base, "", "")
	if err != nil {
		t.Fatal(err)
	}
	c.HTTP.Timeout = 60 * time.Second
	path := filepath.Join(t.TempDir(), "store.db")
	s, err := ns.OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	r := &rig{t: t, ctx: context.Background(), c: c, path: path, items: map[uint32]ns.Item{}}
	r.d = ns.NewDaemon(s, c, "test-host")
	r.d.LocalOnlyApps = []string{"volume-osd"}
	r.d.Emit = func(s ns.Signal) error { r.signals = append(r.signals, s); return nil }
	t.Cleanup(func() { r.d.Store.Close() })
	return r
}
func (r *rig) check(err error) {
	r.t.Helper()
	if err != nil {
		r.t.Fatal(err)
	}
}
func (r *rig) notify(in ns.NotifyInput) uint32 {
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
	r.item(id)
	return id
}
func (r *rig) item(id uint32) ns.Item {
	r.t.Helper()
	for _, item := range socketSnapshot(r.t, r.d).Items {
		r.items[item.ID] = item
	}
	item, ok := r.items[id]
	if !ok {
		r.t.Fatalf("notification %d never appeared in a snapshot", id)
	}
	return item
}
func (r *rig) isOpen(id uint32) bool {
	r.t.Helper()
	for _, item := range socketSnapshot(r.t, r.d).Items {
		if item.ID == id {
			return true
		}
	}
	return false
}
func (r *rig) outbox() int { return socketSnapshot(r.t, r.d).Status.Outbox }
func (r *rig) remoteItem(seq string) ns.Item {
	r.t.Helper()
	for _, item := range socketSnapshot(r.t, r.d).Items {
		if item.Seq == seq {
			return item
		}
	}
	r.t.Fatalf("missing remote sequence %s", seq)
	return ns.Item{}
}
func (r *rig) delete(id uint32) {
	r.t.Helper()
	req, err := http.NewRequestWithContext(r.ctx, "DELETE", r.c.Base+"/notify/"+r.item(id).Seq, nil)
	r.check(err)
	res, err := r.c.HTTP.Do(req)
	r.check(err)
	res.Body.Close()
	if res.StatusCode != 200 {
		r.t.Fatal(res.Status)
	}
}

// Change only the server response boundary: ntfy treats an expired cursor as
// unknown and returns its cache. Never edit the daemon's private persistence.
func forceCacheReplay(t *testing.T, c *ns.Client) {
	t.Helper()
	backend, err := url.Parse(c.Base)
	if err != nil {
		t.Fatal(err)
	}
	proxy := httputil.NewSingleHostReverseProxy(backend)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("poll") == "1" {
			q := r.URL.Query()
			q.Set("since", "XXXXXXXXXXXX")
			r.URL.RawQuery = q.Encode()
		}
		proxy.ServeHTTP(w, r)
	}))
	t.Cleanup(server.Close)
	c.Base = server.URL
}
func (r *rig) sync() { r.t.Helper(); r.check(r.d.SyncOnce(r.ctx)) }
func (r *rig) events(id uint32) []ns.Message {
	r.t.Helper()
	ms, err := r.c.Poll(r.ctx, ns.Topic, "all")
	r.check(err)
	seq := r.item(id).Seq
	out := []ns.Message{}
	for _, m := range ms {
		if m.Seq() == seq {
			out = append(out, m)
		}
	}
	return out
}
func (r *rig) control(id uint32, kind, key string) ns.Message {
	r.t.Helper()
	b, _ := json.Marshal(ns.Control{Version: 1, Type: kind, Seq: r.item(id).Seq, Key: key})
	m, err := r.c.Publish(r.ctx, ns.Message{Topic: ns.ControlTopic, Message: string(b)})
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
	s, err := ns.OpenStore(r.path)
	r.check(err)
	r.d = ns.NewDaemon(s, r.c, "test-host")
	r.d.Emit = func(s ns.Signal) error { r.signals = append(r.signals, s); return nil }
}

func TestSpikeScenarios(t *testing.T) {
	base := ntfyServer(t)
	t.Run("publish stable sequence and two non-default app buttons", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{Actions: []ns.Action{{"default", "Open"}, {"a", "A"}, {"b", "B"}, {"c", "C"}}, Urgency: 2})
		r.sync()
		m := r.events(id)[0]
		if len(m.Actions) != 3 || m.Actions[0].Label != "A" || m.Actions[2].Label != "Done" || m.Priority != 5 || !ns.ValidSequence(m.Seq()) {
			t.Fatalf("payload %+v", m)
		}
		if !strings.HasPrefix(m.Seq(), "test-host-") {
			t.Fatal(m.Seq())
		}
	})
	for _, op := range []string{"dismiss", "app-close", "remote-clear", "remote-delete"} {
		t.Run(op, func(t *testing.T) {
			r := newRig(t, base)
			id := r.notify(ns.NotifyInput{})
			r.sync()
			reason := uint32(2)
			switch op {
			case "dismiss":
				r.check(r.d.Operation(ns.UIOperation{Op: "dismiss", ID: id}))
			case "app-close":
				reason = 3
				r.check(r.d.Close(id, reason, true, ":1.900"))
			case "remote-clear":
				r.check(r.c.Clear(r.ctx, r.item(id).Seq))
			case "remote-delete":
				r.delete(id)
			}
			r.sync()
			r.closed(id, reason)
			if r.isOpen(id) {
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
		id := r.notify(ns.NotifyInput{})
		r.sync()
		r.check(r.d.Close(id, 3, true, ":1.900"))
		r.check(r.d.Close(id, 3, true, ":1.900"))
		r.sync()
		r.closed(id, 3)
	})
	t.Run("cache expiry reason 1 sends no clear", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{})
		r.sync()
		r.check(r.d.ReconcileExpiry(nil, time.Now().Unix()))
		r.closed(id, 1)
		r.sync()
		if len(r.events(id)) != 1 {
			t.Fatal("expiry sent clear")
		}
	})
	t.Run("popup timeout does not close store", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{})
		r.sync()
		time.Sleep(350 * time.Millisecond)
		if !r.isOpen(id) || len(r.signals) != 0 {
			t.Fatal("popup timeout closed item")
		}
	})
	t.Run("replace keeps ID and sequence", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{Body: "10%"})
		r.sync()
		seq := r.item(id).Seq
		for _, body := range []string{"60%", "100%"} {
			got := r.notify(ns.NotifyInput{Replaces: id, Body: body})
			if got != id {
				t.Fatal("ID changed")
			}
			r.sync()
		}
		if r.item(id).Seq != seq || len(r.events(id)) != 3 {
			t.Fatal("duplicate sequence")
		}
	})
	t.Run("replace after clear revives same sequence", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{})
		r.sync()
		r.check(r.c.Clear(r.ctx, r.item(id).Seq))
		r.sync()
		if r.notify(ns.NotifyInput{Replaces: id, Body: "revived"}) != id {
			t.Fatal("ID changed")
		}
		r.sync()
		if !r.isOpen(id) || len(r.events(id)) != 3 {
			t.Fatal("not revived")
		}
	})
	for _, filter := range []string{"transient", "app-filter"} {
		t.Run(filter+" stays local", func(t *testing.T) {
			r := newRig(t, base)
			in := ns.NotifyInput{Transient: filter == "transient"}
			if filter == "app-filter" {
				in.AppName = "volume-osd"
			}
			id := r.notify(in)
			r.sync()
			if len(r.events(id)) != 0 {
				t.Fatal("local item published")
			}
			r.check(r.d.Operation(ns.UIOperation{Op: "dismiss", ID: id}))
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
			id := r.notify(ns.NotifyInput{Actions: []ns.Action{{"go", "Go"}}, Resident: resident})
			r.sync()
			ctl := r.control(id, "action", "go")
			r.sync()
			if len(r.signals) == 0 || r.signals[0].Member != "ActionInvoked" || r.signals[0].Key != "go" {
				t.Fatal(r.signals)
			}
			r.check(r.d.Handle(ctl))
			if resident {
				if !r.isOpen(id) || len(r.signals) != 1 || len(r.events(id)) != 1 {
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
		id := r.notify(ns.NotifyInput{})
		r.sync()
		ctl := r.control(id, "clear", "")
		h := ns.Hub{r.c}
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
		id := r.notify(ns.NotifyInput{})
		r.sync()
		ctl := r.control(id, "clear", "")
		r.notify(ns.NotifyInput{Replaces: id, Body: "new revision"})
		r.sync()
		h := ns.Hub{r.c}
		r.check(h.ApplyControl(r.ctx, ctl))
		r.sync()
		if !r.isOpen(id) || len(r.events(id)) != 2 {
			t.Fatal("old control closed latest revision")
		}
	})
	t.Run("stale clear ordered before latest publish is ignored", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{})
		r.sync()
		r.check(r.c.Clear(r.ctx, r.item(id).Seq))
		r.notify(ns.NotifyInput{Replaces: id, Body: "revision 2"})
		r.check(r.d.Flush(r.ctx))
		r.sync()
		if !r.isOpen(id) || len(r.signals) != 0 {
			t.Fatal("stale clear closed current revision")
		}
	})
	t.Run("restart catches clear action delete and preserves IDs", func(t *testing.T) {
		r := newRig(t, base)
		a := r.notify(ns.NotifyInput{})
		b := r.notify(ns.NotifyInput{Actions: []ns.Action{{"go", "Go"}}})
		c := r.notify(ns.NotifyInput{})
		r.sync()
		r.check(r.c.Clear(r.ctx, r.item(a).Seq))
		r.control(b, "action", "go")
		r.delete(c)
		r.restart()
		r.sync()
		r.closed(a, 2)
		r.closed(b, 2)
		r.closed(c, 2)
		next := r.notify(ns.NotifyInput{})
		if next <= c {
			t.Fatal("ID reused")
		}
	})
	t.Run("clean restart produces no spurious signals", func(t *testing.T) {
		r := newRig(t, base)
		r.notify(ns.NotifyInput{})
		r.sync()
		r.restart()
		r.sync()
		if len(r.signals) != 0 {
			t.Fatal(r.signals)
		}
	})
	t.Run("cursor loss is idempotent", func(t *testing.T) {
		r := newRig(t, base)
		id := r.notify(ns.NotifyInput{Actions: []ns.Action{{"go", "Go"}}, Resident: true})
		r.sync()
		r.control(id, "action", "go")
		r.sync()
		forceCacheReplay(t, r.c)
		r.restart()
		r.sync()
		if len(r.signals) != 1 || !r.isOpen(id) {
			t.Fatal("replay invoked action again")
		}
	})
	t.Run("latency twenty real publish and clear round trips", func(t *testing.T) {
		r := newRig(t, base)
		start := time.Now()
		for i := 0; i < 20; i++ {
			id := r.notify(ns.NotifyInput{})
			r.sync()
			r.check(r.c.Clear(r.ctx, r.item(id).Seq))
			r.sync()
			r.closed(id, 2)
		}
		t.Logf("20 synchronous round trips: %s", time.Since(start))
	})
	t.Run("all sequences have no consecutive clear events", func(t *testing.T) {
		c, _ := ns.NewClient(base, base, "", "")
		ms, err := c.Poll(context.Background(), ns.Topic, "all")
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
	seq, err := r.c.Send(r.ctx, ns.SendInput{Name: "builder", Summary: "remote build", Actions: []ns.Action{{"go", "Go"}}})
	r.check(err)
	r.sync()
	item := r.remoteItem(seq)
	if item.Origin != "remote" || item.Host != "builder" {
		t.Fatal("remote notification missing")
	}
	r.check(r.d.Operation(ns.UIOperation{Op: "action", ID: item.ID, Key: "go"}))
	r.sync()
	ctls, err := r.c.Poll(r.ctx, ns.ControlTopic, "all")
	r.check(err)
	if len(ctls) != 1 {
		t.Fatal("remote action not forwarded")
	}
	if len(r.signals) != 0 {
		t.Fatal("remote item signaled local application")
	}
	id := r.notify(ns.NotifyInput{Actions: []ns.Action{{"go", "Go"}}})
	r.sync()
	r.check(r.d.SenderGone(":1.900"))
	r.sync()
	events := r.events(id)
	if len(events[len(events)-1].Actions) != 1 || events[len(events)-1].Actions[0].Label != "Done" || r.item(id).SenderAlive {
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

// A browser that shows the ntfy web app raises a desktop notification for each
// ntfy message, with the page origin as the first body line. Publishing that
// copy feeds it back to the browser and loops without end.
func TestBrowserEcho(t *testing.T) {
	base := ntfyServer(t)
	origin := strings.TrimPrefix(base, "http://")
	for name, body := range map[string]string{
		"text":   origin + "\n\nCopied to clipboard.",
		"bare":   origin,
		"nested": origin + "\n\n" + origin + "\n\nFile saved",
		"spaced": "  " + origin + " \r\n\nCopied",
	} {
		t.Run(name, func(t *testing.T) {
			r := newRig(t, base)
			id := r.notify(ns.NotifyInput{AppName: "Chromium", Body: body})
			r.sync()
			if !r.item(id).LocalOnly || len(r.events(id)) != 0 {
				t.Fatal("browser echo published")
			}
		})
	}
	for name, body := range map[string]string{
		"later":  "See " + origin + "\n\nfor details",
		"other":  "example.com\n\nhello",
		"prefix": origin + "0\n\nhello",
	} {
		t.Run(name+"-ok", func(t *testing.T) {
			r := newRig(t, base)
			id := r.notify(ns.NotifyInput{AppName: "Chromium", Body: body})
			r.sync()
			if r.item(id).LocalOnly || len(r.events(id)) != 1 {
				t.Fatal("ordinary notification not published")
			}
		})
	}
}

func TestOutboxRetryAndButtonScope(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	r.c.Button = "tk_button_only"
	good := r.c.Base
	r.c.Base = "http://127.0.0.1:1"
	id := r.notify(ns.NotifyInput{})
	if err := r.d.SyncOnce(r.ctx); err == nil {
		t.Fatal("offline publish succeeded")
	}
	if r.outbox() != 1 {
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
	id := r.notify(ns.NotifyInput{Actions: []ns.Action{{"go", "Go"}}})
	r.sync()
	r.check(r.d.Session("new-session"))
	r.sync()
	if r.item(id).SenderAlive {
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
	seq, err := r.c.Send(r.ctx, ns.SendInput{Name: "builder", Summary: "remote"})
	r.check(err)
	r.sync()
	r.check(r.d.Operation(ns.UIOperation{Op: "dismiss", ID: r.remoteItem(seq).ID}))
	r.sync()
	items, err := r.c.List(r.ctx)
	r.check(err)
	if len(items) != 0 {
		t.Fatal("remote dismiss not cleared")
	}
	seq, err = r.c.Send(r.ctx, ns.SendInput{Name: "builder", Summary: "action", Actions: []ns.Action{{"go", "Go"}}})
	r.check(err)
	ctl, _ := json.Marshal(ns.Control{Version: 1, Type: "action", Seq: seq, Key: "go"})
	m, err := r.c.Publish(r.ctx, ns.Message{Topic: ns.ControlTopic, Message: string(ctl)})
	r.check(err)
	h := ns.Hub{r.c}
	r.check(h.ApplyControl(r.ctx, m))
	ctx, cancel := context.WithTimeout(r.ctx, 60*time.Second)
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
			r.c.HTTP.Timeout = 0
			id := r.notify(ns.NotifyInput{})
			done := make(chan error, 1)
			go func() { done <- r.d.Flush(r.ctx) }()
			select {
			case <-started:
			case <-time.After(60 * time.Second):
				t.Fatal("publish did not start")
			}
			updated := make(chan error, 1)
			go func() {
				if dismiss {
					updated <- r.d.Operation(ns.UIOperation{Op: "dismiss", ID: id})
				} else {
					_, err := r.d.Notify(ns.NotifyInput{Sender: ":1.900", AppName: "test-app", Summary: "new revision", Body: "new revision", Replaces: id})
					updated <- err
				}
			}()
			select {
			case err := <-updated:
				r.check(err)
			case <-time.After(60 * time.Second):
				close(release)
				t.Fatal("D-Bus operation blocked on network")
			}
			close(release)
			r.check(<-done)
			r.sync()
			if dismiss {
				if r.isOpen(id) || len(r.events(id)) != 2 {
					t.Fatal("dismiss during publish lost its clear")
				}
			} else {
				if !r.isOpen(id) || r.outbox() != 0 || len(r.events(id)) != 2 {
					t.Fatal("update during publish lost its revision")
				}
			}
		})
	}
}

func TestPruneKeepsMonotonicIDsAndCachedActionDedup(t *testing.T) {
	r := newRig(t, ntfyServer(t))
	closed := r.notify(ns.NotifyInput{})
	r.check(r.d.Close(closed, 3, false, ":1.900"))
	active := r.notify(ns.NotifyInput{Resident: true, Actions: []ns.Action{{"go", "Go"}}})
	r.sync()
	r.control(active, "action", "go")
	r.sync()
	cached, err := r.c.Poll(r.ctx, ns.ControlTopic, "all")
	r.check(err)
	r.check(r.d.Prune(cached, time.Now().Add(32*24*time.Hour).Unix()))
	r.restart()
	r.check(r.d.HandleBatch(cached))
	r.check(r.d.HandleBatch(cached))
	if len(r.signals) != 2 || r.signals[1].Member != "ActionInvoked" {
		t.Fatalf("cached action replayed: %+v", r.signals)
	}
	if !r.isOpen(active) {
		t.Fatal("prune removed open item")
	}
	next := r.notify(ns.NotifyInput{})
	if next <= active {
		t.Fatal("pruning reused an ID")
	}
}

func TestRestartOldIDsAndReplayOfRevivedSequence(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	id := r.notify(ns.NotifyInput{})
	r.sync()
	r.restart()
	r.check(r.d.Close(id, 3, true, ":1.900"))
	r.sync()
	r.closed(id, 3)
	revived := r.notify(ns.NotifyInput{Replaces: id, Body: "revived"})
	if revived != id {
		t.Fatal("replace changed ID")
	}
	r.sync()
	forceCacheReplay(t, r.c)
	r.restart()
	r.sync()
	if !r.isOpen(id) || len(r.signals) != 1 {
		t.Fatal("full replay closed revived notification")
	}
	next := r.notify(ns.NotifyInput{})
	if next <= id {
		t.Fatal("restart reused ID")
	}
}
func TestClearOutboxSurvivesOfflineRestart(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	id := r.notify(ns.NotifyInput{})
	r.sync()
	r.c.Base = "http://127.0.0.1:1"
	r.check(r.d.Operation(ns.UIOperation{Op: "dismiss", ID: id}))
	if err := r.d.SyncOnce(r.ctx); err == nil {
		t.Fatal("offline clear succeeded")
	}
	if r.outbox() != 1 {
		t.Fatal("clear lost")
	}
	r.restart()
	r.c.Base = base
	r.sync()
	if r.outbox() != 0 || len(r.events(id)) != 2 {
		t.Fatal("restart did not deliver clear")
	}
	r.closed(id, 2)
}

func TestRemoteActionWaitsForTheOwningDaemon(t *testing.T) {
	base := ntfyServer(t)
	owner := newRig(t, base)
	view := newRig(t, base)
	id := owner.notify(ns.NotifyInput{Summary: "owned app", Actions: []ns.Action{{"go", "Go"}}})
	owner.sync()
	view.sync()
	snapshot := socketSnapshot(t, view.d)
	if len(snapshot.Items) != 1 || snapshot.Items[0].Origin != "remote" {
		t.Fatal(snapshot.Items)
	}
	ownerSeq := snapshot.Items[0].Seq
	view.check(view.d.Operation(ns.UIOperation{Op: "action", ID: snapshot.Items[0].ID, Key: "go"}))
	view.sync()
	owner.sync()
	if len(owner.signals) != 2 || owner.signals[0].Member != "ActionInvoked" || owner.signals[0].ID != id || owner.signals[0].Key != "go" || owner.signals[1].Member != "NotificationClosed" || owner.signals[1].Reason != 2 {
		t.Fatalf("owner signals: %+v", owner.signals)
	}
	owner.sync()
	view.sync()
	for _, item := range socketSnapshot(t, view.d).Items {
		if item.Seq == ownerSeq {
			t.Fatal("owner's close did not remove remote view")
		}
	}
}
