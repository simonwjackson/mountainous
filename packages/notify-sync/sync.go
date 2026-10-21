package notifysync

import (
	"context"
	"errors"
	"log/slog"
	"time"
)

func (d *Daemon) SyncOnce(ctx context.Context) error { _, err := d.reconcile(ctx, false); return err }
func (d *Daemon) reconcile(ctx context.Context, full bool) ([]Message, error) {
	deliveryErr := d.Flush(ctx)
	var receiveErr error
	all := []Message{}
	notifications := []Message{}
	for _, topic := range []string{Topic, ControlTopic} {
		cursor, err := d.cursor(topic)
		if full {
			cursor = "all"
		}
		if err == nil {
			var messages []Message
			messages, err = d.Client.Poll(ctx, topic, cursor)
			if err == nil {
				err = d.HandleBatch(messages)
				all = append(all, messages...)
				if topic == Topic {
					notifications = messages
				}
			}
		}
		receiveErr = errors.Join(receiveErr, err)
	}
	if receiveErr == nil {
		d.mu.Lock()
		d.caughtUp = true
		d.mu.Unlock()
		if full {
			receiveErr = d.ReconcileExpiry(notifications, d.Clock.Now().Unix())
			if receiveErr == nil {
				receiveErr = d.Prune(all, d.Clock.Now().Unix())
			}
		}
	}
	err := errors.Join(deliveryErr, receiveErr)
	if err != nil {
		d.setStatus("unreachable", err)
	} else {
		d.setStatus("connected", nil)
	}
	return all, err
}

func (d *Daemon) watchLoop(ctx context.Context, wakes chan<- Message) {
	delay := 250 * time.Millisecond
	for {
		start := d.Clock.Now()
		err := d.Client.Watch(ctx, func(m Message) {
			select {
			case wakes <- m:
			case <-ctx.Done():
			}
		})
		if ctx.Err() != nil {
			return
		}
		slog.Warn("notification wake-up stream disconnected; ordered polling remains active", "error", err)
		select {
		case wakes <- Message{Event: "reconnect"}:
		case <-ctx.Done():
			return
		}
		timer := d.Clock.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C():
		}
		if d.Clock.Now().Sub(start) >= 30*time.Second {
			delay = 250 * time.Millisecond
		} else {
			delay = min(delay*2, 5*time.Second)
		}
	}
}

// Run uses the unordered stream only for wake-ups. Fallback deadlines stay
// anchored to Run's start, even when HTTP work delays servicing a deadline.
// Missed intervals coalesce into one reconciliation, not a burst of requests.
func (d *Daemon) Run(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	wakes := make(chan Message, 256)
	done := make(chan struct{})
	go func() { defer close(done); d.watchLoop(ctx, wakes) }()
	defer func() { cancel(); <-done }()
	const fallbackInterval = 30 * time.Second
	nextFallback := d.Clock.Now().Add(fallbackInterval)
	pending := map[string]time.Time{}
	observed := map[string]time.Time{}
	retryDelay := 25 * time.Millisecond
	var retryAt time.Time
	lastFull := d.Clock.Now()
	apply := func(full bool) {
		messages, _ := d.reconcile(ctx, full)
		now := d.Clock.Now()
		if full {
			lastFull = now
		}
		for _, m := range messages {
			observed[m.ID] = now
			delete(pending, m.ID)
		}
		for id, when := range observed {
			if now.Sub(when) > 2*time.Minute {
				delete(observed, id)
			}
		}
		for id, deadline := range pending {
			if !now.Before(deadline) {
				delete(pending, id)
			}
		}
		if len(pending) > 0 {
			retryAt = now.Add(retryDelay)
			retryDelay = min(retryDelay*2, 400*time.Millisecond)
		} else {
			retryAt = time.Time{}
			retryDelay = 25 * time.Millisecond
		}
	}
	apply(true)
	for {
		deadline := nextFallback
		if !retryAt.IsZero() && retryAt.Before(deadline) {
			deadline = retryAt
		}
		timer := d.Clock.NewTimer(max(0, deadline.Sub(d.Clock.Now())))
		sync := false
		full := false
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil
		case <-d.outboxWake:
			sync = true
		case <-timer.C():
			now := d.Clock.Now()
			sync = true
			if !now.Before(nextFallback) {
				full = now.Sub(lastFull) >= 55*time.Second
				nextFallback = nextFallback.Add((now.Sub(nextFallback)/fallbackInterval + 1) * fallbackInterval)
			}
		case m := <-wakes:
			accept := func(m Message) {
				if m.Event == "open" || m.Event == "reconnect" {
					sync = true
					return
				}
				if m.ID != "" {
					if _, seen := observed[m.ID]; !seen {
						pending[m.ID] = d.Clock.Now().Add(2 * time.Second)
						sync = true
					}
				}
			}
			accept(m)
		drain:
			for {
				select {
				case m := <-wakes:
					accept(m)
				default:
					break drain
				}
			}
		}
		timer.Stop()
		if ctx.Err() != nil {
			return nil
		}
		if sync {
			apply(full)
		}
	}
}
