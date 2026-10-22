package notifysync_test

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"testing"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

// ntfy counts replayed cache bytes against each user's daily bandwidth limit.
// When the limit runs out part way through a replay, ntfy has already sent
// 200 OK, so it ends the stream with an error line. On 2026-10-22 notifyd took
// that cut replay for the whole cache, closed newer items as evicted and
// revived dismissed ones. Poll must refuse it.
func TestPollRejectsAReplayThatNtfyCutsShort(t *testing.T) {
	base := ntfyServerWith(t, "visitor-attachment-daily-bandwidth-limit: 16k\n")
	const published = 24
	body := strings.Repeat("x", 1500)
	for i := 0; i < published; i++ {
		res, err := http.Post(base+"/"+ns.Topic, "text/plain", strings.NewReader(body))
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != 200 {
			t.Fatalf("publish %d: %s", i, res.Status)
		}
	}
	c, err := ns.NewClient(base, base, "", "")
	if err != nil {
		t.Fatal(err)
	}
	for attempt := 0; attempt < 5; attempt++ {
		messages, err := c.Poll(context.Background(), ns.Topic, "all")
		if err == nil {
			if len(messages) != published {
				t.Fatalf("accepted a replay of %d of %d messages", len(messages), published)
			}
			continue
		}
		var replay *ns.ReplayError
		if !errors.As(err, &replay) || replay.Code != 42905 || replay.Status != 429 {
			t.Fatalf("want ntfy's bandwidth error, got %v", err)
		}
		return
	}
	t.Fatal("the bandwidth limit never cut a replay; the test does not reach the failure")
}
