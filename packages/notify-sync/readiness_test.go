package notifysync_test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

// Readiness is a protocol condition, not a sleep or a performance assertion.
// Each attempt is bounded; the caller owns the generous overall deadline.
func waitForHealth(ctx context.Context, base string, exited <-chan struct{}) error {
	client := &http.Client{Timeout: time.Second}
	retry := time.NewTicker(20 * time.Millisecond)
	defer retry.Stop()
	for {
		select {
		case <-exited:
			return fmt.Errorf("ntfy exited before becoming healthy")
		default:
		}
		req, err := http.NewRequestWithContext(ctx, "GET", base+"/v1/health", nil)
		if err != nil {
			return err
		}
		response, err := client.Do(req)
		if err == nil {
			var health struct {
				Healthy bool `json:"healthy"`
			}
			decodeErr := json.NewDecoder(response.Body).Decode(&health)
			response.Body.Close()
			if response.StatusCode == 200 && decodeErr == nil && health.Healthy {
				return nil
			}
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-exited:
			return fmt.Errorf("ntfy exited before becoming healthy")
		case <-retry.C:
		}
	}
}
func TestReadinessWaitsForTheHealthProtocol(t *testing.T) {
	var healthy atomic.Bool
	attempts := make(chan struct{}, 8)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/health" {
			t.Error(r.URL.Path)
		}
		select {
		case attempts <- struct{}{}:
		default:
		}
		if !healthy.Load() {
			w.WriteHeader(503)
			w.Write([]byte(`{"healthy":false}`))
			return
		}
		w.Write([]byte(`{"healthy":true}`))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	ready := make(chan error, 1)
	go func() { ready <- waitForHealth(ctx, server.URL, nil) }()
	// Two requests prove that an HTTP response alone does not count as ready.
	for i := 0; i < 2; i++ {
		select {
		case <-attempts:
		case err := <-ready:
			t.Fatalf("returned before healthy: %v", err)
		case <-ctx.Done():
			t.Fatal(ctx.Err())
		}
	}
	healthy.Store(true)
	select {
	case err := <-ready:
		if err != nil {
			t.Fatal(err)
		}
	case <-ctx.Done():
		t.Fatal(ctx.Err())
	}
}
func TestReadinessReportsAnExitedProcess(t *testing.T) {
	exited := make(chan struct{})
	close(exited)
	if err := waitForHealth(context.Background(), "http://127.0.0.1:1", exited); err == nil {
		t.Fatal("accepted an exited ntfy process")
	}
}
