package notifysync

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"sync"
)

type Signal struct {
	Member string
	ID     uint32
	Reason uint32
	Key    string
	Sender string
}
type Daemon struct {
	mu            sync.Mutex
	flushMu       sync.Mutex
	Store         *Store
	Client        *Client
	Host          string
	LocalOnlyApps []string
	Emit          func(Signal) error
	clients       map[chan UIEvent]struct{}
	status        Status
	caughtUp      bool
	outboxWake    chan struct{}
}

func NewDaemon(s *Store, c *Client, host string) *Daemon {
	return &Daemon{Store: s, Client: c, Host: SafeName(host), clients: map[chan UIEvent]struct{}{}, status: Status{Server: "connecting"}, outboxWake: make(chan struct{}, 1)}
}
func outbox(s *state) int {
	n := len(s.Controls)
	for _, r := range s.Records {
		if r.Pending != "" {
			n++
		}
	}
	return n
}
func openItems(s *state) []Item {
	items := []Item{}
	for _, r := range s.Records {
		if r.Open {
			items = append(items, r.Item)
		}
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ID < items[j].ID })
	return items
}
func (d *Daemon) broadcast(e UIEvent) {
	for c := range d.clients {
		select {
		case c <- e:
		default:
			delete(d.clients, c)
			close(c)
		}
	}
}
func (d *Daemon) Subscribe() (<-chan UIEvent, func(), error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return nil, nil, err
	}
	ch := make(chan UIEvent, 128)
	d.clients[ch] = struct{}{}
	status := d.status
	status.Outbox = outbox(s)
	ch <- UIEvent{Type: "snapshot", Items: openItems(s), Status: &status}
	return ch, func() {
		d.mu.Lock()
		defer d.mu.Unlock()
		if _, ok := d.clients[ch]; ok {
			delete(d.clients, ch)
			close(ch)
		}
	}, nil
}
func (d *Daemon) commit(s *state, events []UIEvent, signals []Signal) error {
	if err := d.Store.save(s); err != nil {
		return err
	}
	// Checkpoint before delivering side effects. A replay cannot fire an action
	// twice; a crash between checkpoint and signal can lose that one signal.
	for _, sig := range signals {
		if d.Emit != nil {
			if err := d.Emit(sig); err != nil {
				return err
			}
		}
	}
	for _, e := range events {
		d.broadcast(e)
	}
	status := d.status
	status.Outbox = outbox(s)
	d.broadcast(UIEvent{Type: "status", Status: &status})
	return nil
}

func (d *Daemon) commitDelivery(s *state, events []UIEvent, signals []Signal) error {
	if err := d.commit(s, events, signals); err != nil {
		return err
	}
	if outbox(s) > 0 {
		d.wakeOutbox()
	}
	return nil
}
func (d *Daemon) wakeOutbox() {
	select {
	case d.outboxWake <- struct{}{}:
	default:
	}
}

type NotifyInput struct {
	Sender, AppName, AppIcon, Summary, Body string
	Replaces                                uint32
	Actions                                 []Action
	Urgency                                 uint8
	Resident, Transient                     bool
	Image                                   *string
}

func (d *Daemon) Notify(in NotifyInput) (uint32, error) {
	if len(in.Actions) > 128 || len(in.Summary) > 8192 || len(in.Body) > 1<<20 || in.Urgency > 2 {
		return 0, errors.New("notification exceeds limits")
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return 0, err
	}
	r := s.Records[in.Replaces]
	if r != nil && (r.Item.Origin != "local" || r.Sender != in.Sender) {
		r = nil
	}
	if r == nil {
		id, err := s.alloc()
		if err != nil {
			return 0, err
		}
		r = &record{Item: Item{ID: id, Seq: fmt.Sprintf("%s-%s-%d", d.Host, s.Nonce, id), Created: nowMillis()}}
		s.Records[id] = r
	}
	local := in.Transient
	for _, a := range d.LocalOnlyApps {
		if a == in.AppName {
			local = true
		}
	}
	r.Item = Item{ID: r.Item.ID, Seq: r.Item.Seq, Created: r.Item.Created, Updated: nowMillis(), Origin: "local", Host: d.Host, AppName: in.AppName, AppIcon: in.AppIcon, Image: in.Image, Summary: in.Summary, Body: in.Body, Actions: in.Actions, Urgency: in.Urgency, Resident: in.Resident, LocalOnly: local, SenderAlive: true}
	if r.Item.Actions == nil {
		r.Item.Actions = []Action{}
	}
	r.Revision++
	r.Failure = ""
	r.Sender = in.Sender
	r.Open = true
	if !local {
		r.Pending = "publish"
		r.PubSeen = false
	} else if r.Published {
		r.Pending = "clear"
	} else {
		r.Pending = ""
	}
	item := r.Item
	err = d.commitDelivery(s, []UIEvent{{Type: "upsert", Item: &item, Fresh: true}}, nil)
	return item.ID, err
}
func closeRecord(r *record, reason uint32, propagate bool) ([]UIEvent, []Signal) {
	if !r.Open {
		return nil, nil
	}
	r.Open = false
	r.Failure = ""
	r.Revision++
	r.Item.Updated = nowMillis()
	r.Pending = ""
	if propagate && r.Published {
		r.Pending = "clear"
	}
	signals := []Signal{}
	if r.Item.Origin == "local" && r.Item.SenderAlive {
		signals = append(signals, Signal{Member: "NotificationClosed", ID: r.Item.ID, Reason: reason, Sender: r.Sender})
	}
	return []UIEvent{{Type: "remove", ID: r.Item.ID, Reason: reason}}, signals
}
func (d *Daemon) Close(id, reason uint32, propagate bool, sender string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	r := s.Records[id]
	if r == nil || (sender != "" && r.Sender != sender) {
		return nil
	}
	es, ss := closeRecord(r, reason, propagate)
	return d.commitDelivery(s, es, ss)
}
func invoke(s *state, r *record, key string, remoteControl bool) ([]UIEvent, []Signal) {
	if r == nil || !r.Open || !r.Item.SenderAlive {
		return nil, nil
	}
	valid := false
	for _, a := range r.Item.Actions {
		if a.Key == key {
			valid = true
		}
	}
	if !valid {
		return nil, nil
	}
	signals := []Signal{}
	if r.Item.Origin == "local" {
		signals = append(signals, Signal{Member: "ActionInvoked", ID: r.Item.ID, Key: key, Sender: r.Sender})
	} else {
		if remoteControl {
			return nil, nil
		}
		s.Controls = append(s.Controls, Control{Version: 1, Type: "action", Seq: r.Item.Seq, Key: key})
		// Only the owner may close after acting. Clearing here would reach the
		// owner's notification poll before its control poll and suppress the action.
		return nil, nil
	}
	if !r.Item.Resident {
		es, ss := closeRecord(r, 2, true)
		return es, append(signals, ss...)
	}
	return nil, signals
}
func (d *Daemon) Operation(op UIOperation) error {
	if op.Op != "dismiss" && op.Op != "action" && op.Op != "dismiss_all" {
		return errors.New("unknown UI operation")
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	es := []UIEvent{}
	ss := []Signal{}
	if op.Op == "dismiss_all" {
		for _, r := range s.Records {
			e, sigs := closeRecord(r, 2, true)
			es = append(es, e...)
			ss = append(ss, sigs...)
		}
	} else if r := s.Records[op.ID]; r != nil {
		if op.Op == "dismiss" {
			es, ss = closeRecord(r, 2, true)
		} else {
			es, ss = invoke(s, r, op.Key, false)
		}
	}
	return d.commitDelivery(s, es, ss)
}

// senderLost applies the same projection for unique-name loss and bus restart.
func senderLost(r *record) *UIEvent {
	if !r.Item.SenderAlive {
		return nil
	}
	r.Item.SenderAlive = false
	r.Revision++
	r.Item.Updated = nowMillis()
	if !r.Open {
		return nil
	}
	if !r.Item.LocalOnly {
		r.Pending = "publish"
		r.PubSeen = false
	}
	item := r.Item
	return &UIEvent{Type: "upsert", Item: &item, Fresh: false}
}

func (d *Daemon) SenderGone(sender string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	es := []UIEvent{}
	for _, r := range s.Records {
		if r.Sender == sender {
			if event := senderLost(r); event != nil {
				es = append(es, *event)
			}
		}
	}
	return d.commitDelivery(s, es, nil)
}

// Session IDs prevent unique-name reuse after a bus restart from reviving a
// different application's buttons.
func (d *Daemon) Session(id string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	es := []UIEvent{}
	if s.Session != "" && s.Session != id {
		for _, r := range s.Records {
			if r.Item.Origin == "local" {
				if event := senderLost(r); event != nil {
					es = append(es, *event)
				}
			}
		}
	}
	s.Session = id
	return d.commitDelivery(s, es, nil)
}
func (d *Daemon) Senders() ([]string, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return nil, err
	}
	unique := map[string]bool{}
	for _, r := range s.Records {
		if r.Open && r.Item.Origin == "local" && r.Item.SenderAlive {
			unique[r.Sender] = true
		}
	}
	out := []string{}
	for name := range unique {
		out = append(out, name)
	}
	return out, nil
}
func (d *Daemon) Handle(m Message) error { return d.HandleBatch([]Message{m}) }
func (d *Daemon) HandleBatch(messages []Message) error {
	if len(messages) == 0 {
		return nil
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	es := []UIEvent{}
	ss := []Signal{}
	for _, m := range messages {
		if m.Event != "message" && m.Event != "message_clear" && m.Event != "message_delete" {
			continue
		}
		if m.Topic == ControlTopic {
			if !s.Seen[m.ID] {
				s.Seen[m.ID] = true
				var ctl Control
				if json.Unmarshal([]byte(m.Message), &ctl) == nil && ctl.Validate() == nil && ctl.Type == "action" {
					r := s.bySeq(ctl.Seq)
					if r != nil && r.Item.Origin == "local" {
						newEvents, newSignals := invoke(s, r, ctl.Key, true)
						if r.Pending != "" && len(newSignals) > 0 {
							d.wakeOutbox()
						}
						es = append(es, newEvents...)
						ss = append(ss, newSignals...)
					}
				}
			}
		} else if m.Topic == Topic {
			r := s.bySeq(m.Seq())
			if r != nil && r.Item.Origin == "local" {
				if m.Event == "message" {
					r.PubSeen = m.ID == r.PubID && r.Pending != "publish"
				} else if r.Open && r.PubSeen && !r.Item.LocalOnly {
					newEvents, newSignals := closeRecord(r, 2, false)
					es = append(es, newEvents...)
					ss = append(ss, newSignals...)
				}
			} else if !s.Seen[m.ID] {
				s.Seen[m.ID] = true
				if m.Event == "message" {
					fresh := d.caughtUp && (r == nil || !r.Open)
					if r == nil {
						id, err := s.alloc()
						if err != nil {
							return err
						}
						r = &record{}
						r.Item.ID = id
						s.Records[id] = r
					}
					r.Item = m.Remote(r.Item.ID)
					r.Open = true
					r.Published = true
					r.PubID = m.ID
					r.PubSeen = true
					r.Expires = m.Expires
					item := r.Item
					es = append(es, UIEvent{Type: "upsert", Item: &item, Fresh: fresh})
				} else if r != nil {
					newEvents, newSignals := closeRecord(r, 2, false)
					es = append(es, newEvents...)
					ss = append(ss, newSignals...)
				}
			}
		}
		s.Cursors[m.Topic] = m.ID

	}
	return d.commit(s, es, ss)
}
func (d *Daemon) setStatus(server string, err error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	status := Status{Server: server}
	if err == nil {
		err = d.Store.deliveryError()
	}
	if err != nil {
		s := err.Error()
		status.LastError = &s
	}
	if count, err := d.Store.pendingCount(); err == nil {
		status.Outbox = count
	}
	d.status = status
	d.broadcast(UIEvent{Type: "status", Status: &status})
}

// Flush never holds the aggregate lock during network I/O. A revision check
// prevents a completed request from erasing a newer local update or dismiss.
func (d *Daemon) Flush(ctx context.Context) error {
	d.flushMu.Lock()
	defer d.flushMu.Unlock()
	for {
		d.mu.Lock()
		s, err := d.Store.loadMeta()
		if err != nil {
			d.mu.Unlock()
			return err
		}
		if len(s.Controls) == 0 {
			d.mu.Unlock()
			break
		}
		ctl := s.Controls[0]
		d.mu.Unlock()
		if err = d.Client.Control(ctx, ctl); err != nil {
			if !permanentDeliveryError(err) {
				return err
			}
			slog.Error("dropping rejected control request", "seq", ctl.Seq, "error", err)
		}
		d.mu.Lock()
		s, err = d.Store.loadMeta()
		if err == nil && len(s.Controls) > 0 && s.Controls[0] == ctl {
			s.Controls = s.Controls[1:]
			err = d.Store.saveMeta(s)
		}
		d.mu.Unlock()
		if err != nil {
			return err
		}
	}
	d.mu.Lock()
	ids, err := d.Store.pendingIDs()
	d.mu.Unlock()
	if err != nil {
		return err
	}
	for _, id := range ids {
		d.mu.Lock()
		r, err := d.Store.get(id)
		if err != nil {
			d.mu.Unlock()
			return err
		}
		if r == nil || r.Pending == "" {
			d.mu.Unlock()
			continue
		}
		snapshot := *r
		d.mu.Unlock()
		var result Message
		switch snapshot.Pending {
		case "publish":
			result, err = d.Client.Publish(ctx, Payload(snapshot.Item, d.Client.Public, d.Client.Button))
		case "clear":
			err = d.Client.Clear(ctx, snapshot.Item.Seq)
		default:
			return errors.New("invalid outbox operation")
		}
		if err != nil {
			if !permanentDeliveryError(err) {
				return err
			}
			slog.Error("parking rejected notification delivery", "seq", snapshot.Item.Seq, "operation", snapshot.Pending, "error", err)
			d.mu.Lock()
			current, loadErr := d.Store.get(id)
			if loadErr == nil && current != nil && current.Revision == snapshot.Revision {
				current.Pending = ""
				current.Failure = fmt.Sprintf("%s: %s", snapshot.Item.Seq, err)
				loadErr = d.Store.put(current)
			}
			d.mu.Unlock()
			if loadErr != nil {
				return loadErr
			}
			continue
		}
		d.mu.Lock()
		r, err = d.Store.get(id)
		if err == nil && r != nil {
			if snapshot.Pending == "publish" {
				r.Published = true
				if r.Revision == snapshot.Revision {
					r.Pending = ""
					r.PubID = result.ID
					r.PubSeen = false
					r.Expires = result.Expires
				} else if !r.Open || r.Item.LocalOnly {
					r.Pending = "clear"
				}
			} else if r.Revision == snapshot.Revision && r.Pending == "clear" {
				r.Pending = ""
			}
			err = d.Store.put(r)
		}
		d.mu.Unlock()
		if err != nil {
			return err
		}
	}
	return nil
}
func (d *Daemon) cursor(topic string) (string, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.loadMeta()
	if err != nil {
		return "", err
	}
	return s.Cursors[topic], nil
}

// ReconcileExpiry runs only after a successful full server fold. A popup's
// expire_timeout never closes the store. A cache eviction is reason 1.
func (d *Daemon) ReconcileExpiry(messages []Message, now int64) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	open := Fold(messages)
	last := map[string]Message{}
	for _, m := range messages {
		last[m.Seq()] = m
	}
	es := []UIEvent{}
	ss := []Signal{}
	for _, r := range s.Records {
		if r.Open && r.Published && !r.Item.LocalOnly && r.Pending == "" {
			if _, exists := open[r.Item.Seq]; !exists {
				reason := uint32(1)
				if m, exists := last[r.Item.Seq]; exists && (m.Event == "message_clear" || m.Event == "message_delete") {
					if r.Item.Origin == "local" && !r.PubSeen {
						continue
					}
					reason = 2
				}
				e, sigs := closeRecord(r, reason, false)
				es = append(es, e...)
				ss = append(ss, sigs...)
			}
		}
	}
	return d.commit(s, es, ss)
}

// Prune retains closed tombstones slightly longer than the server cache. The
// monotonic counter is independent, so pruning cannot reuse a D-Bus ID.
func (d *Daemon) Prune(cached []Message, now int64) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	s, err := d.Store.load()
	if err != nil {
		return err
	}
	ids := map[string]bool{}
	for _, m := range cached {
		ids[m.ID] = true
	}
	for id := range s.Seen {
		if !ids[id] {
			delete(s.Seen, id)
		}
	}
	cutoff := (now - 31*24*60*60) * 1000
	for id, r := range s.Records {
		if !r.Open && r.Pending == "" && r.Item.Updated < cutoff {
			delete(s.Records, id)
		}
	}
	return d.Store.save(s)
}
