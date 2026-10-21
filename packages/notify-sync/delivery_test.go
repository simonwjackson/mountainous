package notifysync_test

import (
	"encoding/json"
	ns "github.com/simonwjackson/mountainous/notify-sync"
	"io"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"unicode/utf8"
)

func TestBodyBoundaryPublishesThroughNtfy(t *testing.T) {
	base := ntfyServer(t)
	for _, body := range []string{strings.Repeat("x", 4095), strings.Repeat("x", 4096), strings.Repeat("x", 4097), strings.Repeat("界", 1366), strings.Repeat("x", 4094) + "界"} {
		t.Run(strconv.Itoa(len(body)), func(t *testing.T) {
			r := newRig(t, base)
			id := r.notify(ns.NotifyInput{Body: body})
			r.sync()
			found := false
			for _, e := range socketSnapshot(t, r.d).Items {
				if e.ID == id {
					found = true
					if e.Body != body {
						t.Fatal("local body was truncated")
					}
				}
			}
			if !found {
				t.Fatal("local item missing")
			}
			events := r.events(id)
			if len(events) != 1 || len(events[0].Message) >= 4096 || !utf8.ValidString(events[0].Message) {
				t.Fatalf("wire body bytes=%d", len(events[0].Message))
			}
		})
	}
}
func TestPermanentPublishFailureDoesNotBlockOtherDeliveryOrReception(t *testing.T) {
	base := ntfyServer(t)
	backend, _ := url.Parse(base)
	proxy := httputil.NewSingleHostReverseProxy(backend)
	var rejected atomic.Int32
	gateway := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if req.Method == "POST" && (req.URL.Path == "/" || req.URL.Path == "") {
			var m ns.Message
			if err := json.NewDecoder(req.Body).Decode(&m); err != nil {
				t.Error(err)
				w.WriteHeader(400)
				return
			}
			req.Body.Close()
			if m.Title == "reject this item" {
				rejected.Add(1)
				http.Error(w, "permanent rejection", 400)
				return
			}
			data, _ := json.Marshal(m)
			req.Body = io.NopCloser(strings.NewReader(string(data)))
			req.ContentLength = int64(len(data))
		}
		proxy.ServeHTTP(w, req)
	}))
	defer gateway.Close()
	r := newRig(t, gateway.URL)
	old := r.notify(ns.NotifyInput{Summary: "clear remotely"})
	r.sync()
	oldSeq := ""
	for _, i := range socketSnapshot(t, r.d).Items {
		if i.ID == old {
			oldSeq = i.Seq
		}
	}
	r.notify(ns.NotifyInput{Summary: "reject this item"})
	healthy := r.notify(ns.NotifyInput{Summary: "deliver this item"})
	r.check(r.c.Clear(r.ctx, oldSeq))
	r.sync()
	r.closed(old, 2)
	if len(r.events(healthy)) != 1 {
		t.Fatal("permanent error blocked later outbox item")
	}
	status := socketSnapshot(t, r.d).Status
	if status.LastError == nil || !strings.Contains(*status.LastError, "400") {
		t.Fatalf("missing status error: %+v", status)
	}
	r.restart()
	r.sync()
	if rejected.Load() != 1 {
		t.Fatal("parked item retried after restart")
	}
	if socketSnapshot(t, r.d).Status.LastError == nil {
		t.Fatal("restart lost delivery error")
	}
}
