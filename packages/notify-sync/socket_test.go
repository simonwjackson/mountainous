package notifysync

import (
	"context"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
	"time"
)

// socketSnapshot exercises the public UI connection, not the database.
func socketSnapshot(t *testing.T, d *Daemon) UIEvent {
	t.Helper()
	events, stop, err := d.Subscribe()
	if err != nil {
		t.Fatal(err)
	}
	defer stop()
	e := <-events
	b, err := json.Marshal(e)
	if err != nil {
		t.Fatal(err)
	}
	if err = ValidateSocketMessage(b); err != nil {
		t.Fatalf("invalid snapshot %s: %v", b, err)
	}
	return e
}
func decodeSocketEvent(t *testing.T, decoder *json.Decoder) UIEvent {
	t.Helper()
	var data json.RawMessage
	if err := decoder.Decode(&data); err != nil {
		t.Fatal(err)
	}
	if err := ValidateSocketMessage(data); err != nil {
		t.Fatalf("invalid socket event %s: %v", data, err)
	}
	var e UIEvent
	if err := json.Unmarshal(data, &e); err != nil {
		t.Fatal(err)
	}
	return e
}
func TestSocketSchemaRejectsFieldsOutsideContract(t *testing.T) {
	for _, raw := range []string{`{"op":"dismiss"}`, `{"op":"subscribe","id":1}`, `{"type":"status","status":{"server":"connected","outbox":0,"last_error":null},"fresh":false}`, `{"op":"action","id":1,"key":"go","extra":1}`} {
		if ValidateSocketMessage([]byte(raw)) == nil {
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
	conn.SetDeadline(time.Now().Add(8 * time.Second))
	decoder := json.NewDecoder(conn)
	send := func(op UIOperation) {
		t.Helper()
		data, err := json.Marshal(op)
		r.check(err)
		r.check(ValidateSocketMessage(data))
		_, err = DecodeUIOperation(data)
		r.check(err)
		_, err = conn.Write(append(data, '\n'))
		r.check(err)
	}
	send(UIOperation{Op: "subscribe"})
	if e := decodeSocketEvent(t, decoder); e.Type != "snapshot" {
		t.Fatal(e.Type)
	}
	id := r.notify(NotifyInput{Actions: []Action{{"go", "Go"}}, Resident: true})
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
	send(UIOperation{Op: "action", ID: id, Key: "go"})
	readUntil("status")
	send(UIOperation{Op: "dismiss", ID: id})
	readUntil("remove")
	r.notify(NotifyInput{})
	readUntil("upsert")
	send(UIOperation{Op: "dismiss_all"})
	readUntil("remove")
}
