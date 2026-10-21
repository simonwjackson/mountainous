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
			receiveErr = d.ReconcileExpiry(notifications, time.Now().Unix())
			if receiveErr == nil {
				receiveErr = d.Prune(all, time.Now().Unix())
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
		start := time.Now()
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
		timer := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
		if time.Since(start) >= 30*time.Second {
			delay = 250 * time.Millisecond
		} else {
			delay = min(delay*2, 5*time.Second)
		}
	}
}

// Run uses the unordered stream only for wake-ups. Per-topic cache cursors
// define replay order. A bounded retry covers ntfy dispatch-before-cache races;
// a 30-second fallback also handles missing or uncached wake-ups.
func (d *Daemon) Run(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	wakes := make(chan Message, 256)
	done := make(chan struct{})
	go func() { defer close(done); d.watchLoop(ctx, wakes) }()
	defer func() { cancel(); <-done }()
	fallback := time.NewTicker(30 * time.Second)
	defer fallback.Stop()
	retry := time.NewTimer(time.Hour)
	retry.Stop()
	defer retry.Stop()
	pending := map[string]time.Time{}
	observed := map[string]time.Time{}
	retryDelay := 25 * time.Millisecond
	lastFull := time.Now()
	apply := func(full bool) {
		messages, _ := d.reconcile(ctx, full)
		now := time.Now()
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
		retry.Stop()
		if len(pending) > 0 {
			retry.Reset(retryDelay)
			retryDelay = min(retryDelay*2, 400*time.Millisecond)
		} else {
			retryDelay = 25 * time.Millisecond
		}
	}
	apply(true)
	for {
		sync := false
		full := false
		select {
		case <-ctx.Done():
			return nil
		case <-d.outboxWake:
			sync = true
		case <-fallback.C:
			sync = true
			full = time.Since(lastFull) >= 55*time.Second
		case <-retry.C:
			sync = true
		case m := <-wakes:
			// Drain a burst before polling. Message bodies never mutate the store.
			accept := func(m Message) {
				if m.Event == "open" || m.Event == "reconnect" {
					sync = true
					return
				}
				if m.ID != "" {
					if _, seen := observed[m.ID]; !seen {
						pending[m.ID] = time.Now().Add(2 * time.Second)
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
		if ctx.Err() != nil {
			return nil
		}
		if sync {
			apply(full)
		}
	}
}
