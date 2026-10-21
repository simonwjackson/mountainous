package notifysync_test

import (
	"context"
	"encoding/json"
	ns "github.com/simonwjackson/mountainous/notify-sync"
	"net"
	"path/filepath"
	"testing"
	"time"
)

// socketSnapshot reads the same Unix socket snapshot as the desktop view.
func socketSnapshot(t *testing.T, d *ns.Daemon) ns.UIEvent {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	path := filepath.Join(t.TempDir(), "ui.sock")
	done := make(chan error, 1)
	go func() { done <- d.ServeSocket(ctx, path) }()
	defer func() {
		cancel()
		if err := <-done; err != nil {
			t.Error(err)
		}
	}()
	var conn net.Conn
	deadline := time.Now().Add(60 * time.Second)
	for time.Now().Before(deadline) {
		var err error
		conn, err = net.Dial("unix", path)
		if err == nil {
			break
		}
		time.Sleep(time.Millisecond)
	}
	if conn == nil {
		t.Fatal("UI socket did not start")
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(60 * time.Second))
	if _, err := conn.Write([]byte("{\"op\":\"subscribe\"}\n")); err != nil {
		t.Fatal(err)
	}
	return decodeSocketEvent(t, json.NewDecoder(conn))
}
func decodeSocketEvent(t *testing.T, decoder *json.Decoder) ns.UIEvent {
	t.Helper()
	var data json.RawMessage
	if err := decoder.Decode(&data); err != nil {
		t.Fatal(err)
	}
	if err := ns.ValidateSocketMessage(data); err != nil {
		t.Fatalf("invalid socket event %s: %v", data, err)
	}
	var e ns.UIEvent
	if err := json.Unmarshal(data, &e); err != nil {
		t.Fatal(err)
	}
	return e
}
func TestSocketSchemaRejectsFieldsOutsideContract(t *testing.T) {
	for _, raw := range []string{`{"op":"dismiss"}`, `{"op":"subscribe","id":1}`, `{"type":"status","status":{"server":"connected","outbox":0,"last_error":null},"fresh":false}`, `{"op":"action","id":1,"key":"go","extra":1}`} {
		if ns.ValidateSocketMessage([]byte(raw)) == nil {
			t.Fatalf("accepted %s", raw)
		}
	}
}
func TestSocketEventsAndOperationsMatchSharedSchema(t *testing.T) {
	r := newRig(t, ntfyServer(t))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	path := filepath.Join(t.TempDir(), "ui.sock")
	done := make(chan error, 1)
	go func() { done <- r.d.ServeSocket(ctx, path) }()
	defer func() { cancel(); r.check(<-done) }()
	var conn net.Conn
	eventually(t, func() bool { var err error; conn, err = net.Dial("unix", path); return err == nil })
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(60 * time.Second))
	decoder := json.NewDecoder(conn)
	send := func(op ns.UIOperation) {
		t.Helper()
		data, err := json.Marshal(op)
		r.check(err)
		r.check(ns.ValidateSocketMessage(data))
		_, err = ns.DecodeUIOperation(data)
		r.check(err)
		_, err = conn.Write(append(data, '\n'))
		r.check(err)
	}
	send(ns.UIOperation{Op: "subscribe"})
	if e := decodeSocketEvent(t, decoder); e.Type != "snapshot" {
		t.Fatal(e.Type)
	}
	id := r.notify(ns.NotifyInput{Actions: []ns.Action{{"go", "Go"}}, Resident: true})
	seen := map[string]bool{}
	readUntil := func(kind string) {
		t.Helper()
		for {
			e := decodeSocketEvent(t, decoder)
			seen[e.Type] = true
			if e.Type == kind {
				return
			}
		}
	}
	readUntil("upsert")
	readUntil("status")
	send(ns.UIOperation{Op: "action", ID: id, Key: "go"})
	readUntil("status")
	send(ns.UIOperation{Op: "dismiss", ID: id})
	readUntil("remove")
	r.notify(ns.NotifyInput{})
	readUntil("upsert")
	send(ns.UIOperation{Op: "dismiss_all"})
	readUntil("remove")
}
