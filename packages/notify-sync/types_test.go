package notifysync_test

import (
	"encoding/json"
	ns "github.com/simonwjackson/mountainous/notify-sync"
	"strings"
	"testing"
	"unicode/utf8"
)

func TestButtonMappingAndWireLimits(t *testing.T) {
	for _, urgency := range []uint8{0, 1, 2} {
		i := ns.Item{Seq: "host-epoch-1", AppName: strings.Repeat("\x00", 1024), Host: "host", Body: strings.Repeat("界", 3000), Summary: strings.Repeat("界", 1000), AppIcon: "private-icon", Urgency: urgency, SenderAlive: true, Actions: []ns.Action{{"default", "Open"}, {"a", "A"}, {"b", "B"}, {"c", "C"}}}
		m := ns.Payload(i, "https://ntfy.example", "tk_button")
		if len(m.Tags) != 1 || len(m.Tags[0]) > 512 || len(m.Message) > 4096 || len(m.Title) > 1024 || !utf8.ValidString(m.Message) || len(m.Actions) != 3 {
			t.Fatal("ntfy limits exceeded")
		}
		if m.Priority != []int{2, 3, 5}[urgency] {
			t.Fatal("priority mapping")
		}
		b, err := json.Marshal(m)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(b), "private-icon") || strings.Contains(string(b), "default") {
			t.Fatal("private icon or default action leaked")
		}
	}
}
func TestControlValidation(t *testing.T) {
	for _, c := range []ns.Control{{Version: 2, Type: "clear", Seq: "seq"}, {Version: 1, Type: "clear", Seq: "../seq"}, {Version: 1, Type: "unknown", Seq: "seq"}, {Version: 1, Type: "action", Seq: "seq"}} {
		if c.Validate() == nil {
			t.Fatalf("accepted %+v", c)
		}
	}
	if (ns.Control{Version: 1, Type: "clear", Seq: "host-epoch-1"}).Validate() != nil {
		t.Fatal("valid control rejected")
	}
}

func TestAgentProvenanceDoesNotComeFromHostnameOrSequence(t *testing.T) {
	base := ntfyServer(t)
	r := newRig(t, base)
	r.d.Host = "agent-desktop"
	id := r.notify(ns.NotifyInput{Summary: "untrusted app text"})
	r.sync()
	seq, err := r.c.Send(r.ctx, ns.SendInput{Name: "builder", Summary: "agent text"})
	r.check(err)
	// Messages without notify-sync metadata remain untrusted even with an
	// agent-looking sequence. Only Send supplies explicit agent provenance.
	_, err = r.c.Publish(r.ctx, ns.Message{Topic: ns.Topic, Sequence: "agent-looks-trusted", Message: "external text"})
	r.check(err)
	listed, err := r.c.List(r.ctx)
	r.check(err)
	trust := map[string]string{}
	for _, entry := range listed {
		trust[entry.Item.Seq] = entry.Trust
	}
	if trust[r.item(id).Seq] != "untrusted" || trust["agent-looks-trusted"] != "untrusted" || trust[seq] != "agent" {
		t.Fatal(trust)
	}
}
