package notifysync_test

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"log/slog"
	"net"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

func TestInvalidRemoteItemCannotPoisonLaterSnapshots(t *testing.T) {
	h := newSchedulingHub(t)
	server := httptest.NewServer(h)
	defer server.Close()
	r := newRig(t, server.URL)
	invalid := ns.Message{ID: "invalid12345", Sequence: "../bad-sequence", Topic: ns.Topic, Event: "message", Title: "reject this remote item", Message: "untrusted"}
	good := ns.Message{ID: "valid1234567", Sequence: "valid-sequence", Topic: ns.Topic, Event: "message", Title: "keep this remote item", Message: "normal"}
	var logs bytes.Buffer
	previous := slog.Default()
	output, flags := log.Writer(), log.Flags()
	slog.SetDefault(slog.New(slog.NewJSONHandler(&logs, nil)))
	defer func() { slog.SetDefault(previous); log.SetOutput(output); log.SetFlags(flags) }()
	h.commit(invalid)
	h.commit(good)
	r.sync()
	if !strings.Contains(logs.String(), "invalid12345") {
		t.Fatal("rejection was not logged")
	}
	snapshot := socketSnapshot(t, r.d)
	if len(snapshot.Items) != 1 || snapshot.Items[0].Seq != "valid-sequence" || snapshot.Items[0].ID != 1 {
		t.Fatalf("invalid source item escaped: %+v", snapshot.Items)
	}
	if snapshot.Status.LastError == nil || !strings.Contains(*snapshot.Status.LastError, "rejected") {
		t.Fatalf("rejection missing from status: %+v", snapshot.Status)
	}
	// Successful polls and restarts retain the warning, without the bad row.
	r.sync()
	r.restart()
	snapshot = socketSnapshot(t, r.d)
	if len(snapshot.Items) != 1 || snapshot.Status.LastError == nil {
		t.Fatal("rejection or healthy item lost on restart")
	}
	// Replaying a rejected event does not poison a new view or re-add a row.
	r.check(r.d.Handle(invalid))
	snapshot = socketSnapshot(t, r.d)
	if len(snapshot.Items) != 1 {
		t.Fatal(snapshot.Items)
	}
}
func TestSocketWriterRefusesAnInvalidInternalSnapshot(t *testing.T) {
	h := newSchedulingHub(t)
	server := httptest.NewServer(h)
	defer server.Close()
	r := newRig(t, server.URL)
	// Deliberately misconfigure the trusted producer through its public config.
	// This exercises the outgoing guard independently of remote ingress checks.
	r.d.Host = "invalid/host"
	_, err := r.d.Notify(ns.NotifyInput{Sender: ":1.9", AppName: "test", Summary: "must not reach wire"})
	r.check(err)
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
	_, err = conn.Write([]byte("{\"op\":\"subscribe\"}\n"))
	r.check(err)
	data, err := bufio.NewReader(conn).ReadBytes('\n')
	if len(data) > 0 || !errors.Is(err, io.EOF) {
		t.Fatalf("writer leaked an invalid snapshot: %s (%v)", data, err)
	}
}

func snapshot500() ns.UIEvent {
	items := make([]ns.Item, 500)
	for i := range items {
		items[i] = ns.Item{ID: uint32(i + 1), Seq: fmt.Sprintf("other-host-notification-%d", i+1), Origin: "remote", Host: "other-host", AppName: "build", AppIcon: "", Summary: "Build completed", Body: strings.Repeat("x", 256), Actions: []ns.Action{{Key: "open", Label: "Open"}, {Key: "retry", Label: "Retry"}}, Urgency: 1, Created: 1761000000000, Updated: 1761000000000, SenderAlive: true}
	}
	return ns.UIEvent{Type: "snapshot", Items: items, Status: &ns.Status{Server: "connected"}}
}
func BenchmarkSnapshot500Validation(b *testing.B) {
	snapshot := snapshot500()
	data, err := json.Marshal(snapshot)
	if err != nil {
		b.Fatal(err)
	}
	if err = ns.ValidateSocketMessage(data); err != nil {
		b.Fatal(err)
	}
	b.Logf("snapshot: %d items, %d bytes", len(snapshot.Items), len(data))
	b.Run("marshal-only", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			if _, err := json.Marshal(snapshot); err != nil {
				b.Fatal(err)
			}
		}
	})
	b.Run("schema-only", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			if err := ns.ValidateSocketMessage(data); err != nil {
				b.Fatal(err)
			}
		}
	})
}

func BenchmarkEncodeValidatedSnapshot500(b *testing.B) {
	snapshot := snapshot500()
	data, err := ns.EncodeUIEvent(snapshot)
	if err != nil {
		b.Fatal(err)
	}
	b.Logf("snapshot: %d items, %d bytes", len(snapshot.Items), len(data))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := ns.EncodeUIEvent(snapshot); err != nil {
			b.Fatal(err)
		}
	}
}

func TestEncodeUIEventValidatesEveryEventVariant(t *testing.T) {
	item := snapshot500().Items[0]
	status := ns.Status{Server: "connected"}
	for _, event := range []ns.UIEvent{{Type: "snapshot", Items: []ns.Item{item}, Status: &status}, {Type: "upsert", Item: &item}, {Type: "remove", ID: 1, Reason: 2}, {Type: "status", Status: &status}} {
		t.Run(event.Type, func(t *testing.T) {
			if _, err := ns.EncodeUIEvent(event); err != nil {
				t.Fatal(err)
			}
		})
	}
	item.Seq = "../invalid"
	status.Outbox = -1
	for _, event := range []ns.UIEvent{{Type: "snapshot", Items: []ns.Item{item}, Status: &ns.Status{Server: "connected"}}, {Type: "upsert", Item: &item}, {Type: "remove", ID: 0, Reason: 2}, {Type: "status", Status: &status}} {
		t.Run(event.Type+"-invalid", func(t *testing.T) {
			if data, err := ns.EncodeUIEvent(event); err == nil {
				t.Fatalf("accepted invalid event: %s", data)
			}
		})
	}
}
