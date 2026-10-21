// Package notifysync implements the fleet notification store and ntfy protocol.
package notifysync

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

const Topic = "notify"
const ControlTopic = "notify-ctl"

var sequencePattern = regexp.MustCompile(`^[-_A-Za-z0-9]{1,64}$`)
var cleanPattern = regexp.MustCompile(`[^-_A-Za-z0-9]`)

func SafeName(s string) string {
	s = cleanPattern.ReplaceAllString(s, "_")
	if len(s) > 20 {
		s = s[:20]
	}
	if s == "" {
		return "host"
	}
	return s
}
func ValidSequence(s string) bool { return sequencePattern.MatchString(s) }

type Action struct {
	Key   string `json:"key"`
	Label string `json:"label"`
}
type Item struct {
	ID          uint32   `json:"id"`
	Seq         string   `json:"seq"`
	Origin      string   `json:"origin"`
	Host        string   `json:"host"`
	AppName     string   `json:"app_name"`
	AppIcon     string   `json:"app_icon"`
	Image       *string  `json:"image"`
	Summary     string   `json:"summary"`
	Body        string   `json:"body"`
	Actions     []Action `json:"actions"`
	Urgency     uint8    `json:"urgency"`
	Resident    bool     `json:"resident"`
	LocalOnly   bool     `json:"local_only"`
	Created     int64    `json:"created"`
	Updated     int64    `json:"updated"`
	SenderAlive bool     `json:"sender_alive"`
}
type Status struct {
	Server    string  `json:"server"`
	Outbox    int     `json:"outbox"`
	LastError *string `json:"last_error"`
}
type UIEvent struct {
	Type   string  `json:"type"`
	Items  []Item  `json:"items,omitempty"`
	Item   *Item   `json:"item,omitempty"`
	Status *Status `json:"status,omitempty"`
	Fresh  bool    `json:"fresh"`
	ID     uint32  `json:"id,omitempty"`
	Reason uint32  `json:"reason,omitempty"`
}

// MarshalJSON emits exactly the fields for each event in ui-socket.v1.json.
func (e UIEvent) MarshalJSON() ([]byte, error) {
	switch e.Type {
	case "snapshot":
		return json.Marshal(struct {
			Type   string  `json:"type"`
			Items  []Item  `json:"items"`
			Status *Status `json:"status"`
		}{e.Type, e.Items, e.Status})
	case "upsert":
		return json.Marshal(struct {
			Type  string `json:"type"`
			Item  *Item  `json:"item"`
			Fresh bool   `json:"fresh"`
		}{e.Type, e.Item, e.Fresh})
	case "remove":
		return json.Marshal(struct {
			Type   string `json:"type"`
			ID     uint32 `json:"id"`
			Reason uint32 `json:"reason"`
		}{e.Type, e.ID, e.Reason})
	case "status":
		return json.Marshal(struct {
			Type   string  `json:"type"`
			Status *Status `json:"status"`
		}{e.Type, e.Status})
	default:
		return nil, errors.New("unknown UI event")
	}
}

type UIOperation struct {
	Op  string `json:"op"`
	ID  uint32 `json:"id"`
	Key string `json:"key"`
}

func (op UIOperation) MarshalJSON() ([]byte, error) {
	switch op.Op {
	case "subscribe", "dismiss_all":
		return json.Marshal(struct {
			Op string `json:"op"`
		}{op.Op})
	case "dismiss":
		return json.Marshal(struct {
			Op string `json:"op"`
			ID uint32 `json:"id"`
		}{op.Op, op.ID})
	case "action":
		return json.Marshal(struct {
			Op  string `json:"op"`
			ID  uint32 `json:"id"`
			Key string `json:"key"`
		}{op.Op, op.ID, op.Key})
	default:
		return nil, errors.New("unknown UI operation")
	}
}

type Control struct {
	Version int    `json:"v"`
	Type    string `json:"type"`
	Seq     string `json:"seq"`
	Key     string `json:"key,omitempty"`
}

func (c Control) Validate() error {
	if c.Version != 1 || !ValidSequence(c.Seq) || (c.Type != "action" && c.Type != "clear") || (c.Type == "action" && (c.Key == "" || len(c.Key) > 256)) {
		return errors.New("invalid control message")
	}
	return nil
}

type HTTPAction struct {
	Action  string            `json:"action"`
	Label   string            `json:"label"`
	URL     string            `json:"url"`
	Method  string            `json:"method"`
	Headers map[string]string `json:"headers,omitempty"`
	Body    string            `json:"body"`
	Clear   bool              `json:"clear"`
}
type Message struct {
	ID       string       `json:"id,omitempty"`
	Time     int64        `json:"time,omitempty"`
	Expires  int64        `json:"expires,omitempty"`
	Event    string       `json:"event,omitempty"`
	Topic    string       `json:"topic"`
	Sequence string       `json:"sequence_id,omitempty"`
	Title    string       `json:"title,omitempty"`
	Message  string       `json:"message"`
	Priority int          `json:"priority,omitempty"`
	Tags     []string     `json:"tags,omitempty"`
	Actions  []HTTPAction `json:"actions,omitempty"`
}

func (m Message) Seq() string {
	if m.Sequence != "" {
		return m.Sequence
	}
	return m.ID
}

type metadata struct {
	Host     string `json:"h"`
	App      string `json:"a"`
	Resident bool   `json:"r"`
	Alive    bool   `json:"l"`
	Agent    bool   `json:"g"`
}

func (m Message) metadata() metadata {
	for _, tag := range m.Tags {
		if strings.HasPrefix(tag, "ns1_") {
			b, err := base64.RawURLEncoding.DecodeString(strings.TrimPrefix(tag, "ns1_"))
			if err == nil {
				var meta metadata
				if json.Unmarshal(b, &meta) == nil {
					return meta
				}
			}
		}
	}
	return metadata{Host: "agent", App: "ntfy", Alive: true, Agent: strings.HasPrefix(m.Seq(), "agent-")}
}
func (m Message) Remote(id uint32) Item {
	meta := m.metadata()
	urgency := uint8(1)
	if m.Priority <= 2 && m.Priority > 0 {
		urgency = 0
	}
	if m.Priority >= 4 {
		urgency = 2
	}
	acts := []Action{}
	for _, a := range m.Actions {
		var ctl Control
		if json.Unmarshal([]byte(a.Body), &ctl) == nil && ctl.Validate() == nil && ctl.Type == "action" && ctl.Seq == m.Seq() {
			acts = append(acts, Action{ctl.Key, a.Label})
		}
	}
	return Item{ID: id, Seq: m.Seq(), Origin: "remote", Host: meta.Host, AppName: meta.App, Summary: m.Title, Body: m.Message, Actions: acts, Urgency: urgency, Resident: meta.Resident, SenderAlive: meta.Alive, Created: m.Time * 1000, Updated: m.Time * 1000}
}
func Payload(i Item, public, button string) Message {
	metaInfo := metadata{Host: i.Host, App: i.AppName, Resident: i.Resident, Alive: i.SenderAlive, Agent: strings.HasPrefix(i.Seq, "agent-")}
	meta, _ := json.Marshal(metaInfo)
	// ntfy caps all tags at 512 bytes. Preserve the complete app name locally.
	for len(base64.RawURLEncoding.EncodeToString(meta))+4 > 512 {
		metaInfo.App = clip(metaInfo.App, len(metaInfo.App)/2)
		meta, _ = json.Marshal(metaInfo)
	}
	acts := []HTTPAction{}
	add := func(c Control, label string, clear bool) {
		body, _ := json.Marshal(c)
		headers := map[string]string{}
		if button != "" {
			headers["Authorization"] = "Bearer " + button
		}
		acts = append(acts, HTTPAction{Action: "http", Label: label, URL: strings.TrimRight(public, "/") + "/" + ControlTopic, Method: "POST", Headers: headers, Body: string(body), Clear: clear})
	}
	if i.SenderAlive {
		for _, a := range i.Actions {
			if a.Key == "default" {
				continue
			}
			if len(acts) == 2 {
				break
			}
			add(Control{Version: 1, Type: "action", Seq: i.Seq, Key: a.Key}, a.Label, !i.Resident)
		}
	}
	add(Control{Version: 1, Type: "clear", Seq: i.Seq}, "Done", true)
	body := i.Body
	if body == "" {
		body = i.Summary
	}
	if body == "" {
		body = "(empty)"
	}
	priority := 3
	if i.Urgency == 0 {
		priority = 2
	}
	if i.Urgency == 2 {
		priority = 5
	}
	return Message{Topic: Topic, Sequence: i.Seq, Title: clip(i.Summary, 1024), Message: clip(body, 4095), Priority: priority, Tags: []string{"ns1_" + base64.RawURLEncoding.EncodeToString(meta)}, Actions: acts}
}
func nowMillis() int64 { return time.Now().UnixMilli() }

// clip bounds ntfy text fields at valid UTF-8 boundaries. Local text is intact.
func clip(s string, n int) string {
	if len(s) <= n {
		return s
	}
	for n > 0 && !utf8.RuneStart(s[n]) {
		n--
	}
	return s[:n]
}
