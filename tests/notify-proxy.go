// This test is injected only into the proxy check build. Production proxy
// sources stay unchanged. It exercises the actual proxyHandler on TCP sockets.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestNtfyJSONStreamAndWebSocket(t *testing.T) {
	bin := os.Getenv("NTFY_BIN")
	if bin == "" {
		t.Fatal("NTFY_BIN is required")
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := l.Addr().String()
	l.Close()
	dir := t.TempDir()
	config := filepath.Join(dir, "server.yml")
	if err = os.WriteFile(config, []byte(fmt.Sprintf("listen-http: %s\ncache-file: %s/cache.db\nvisitor-request-limit-exempt-hosts: 127.0.0.1\n", address, dir)), 0600); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(bin, "serve", "--config", config)
	if err = cmd.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { cmd.Process.Kill(); cmd.Wait() }()
	base := "http://" + address
	deadline := time.Now().Add(60 * time.Second)
	healthClient := &http.Client{Timeout: time.Second}
	ready := false
	for time.Now().Before(deadline) {
		r, err := healthClient.Get(base + "/v1/health")
		if err == nil {
			var health struct {
				Healthy bool `json:"healthy"`
			}
			decodeErr := json.NewDecoder(r.Body).Decode(&health)
			r.Body.Close()
			if r.StatusCode == 200 && decodeErr == nil && health.Healthy {
				ready = true
				break
			}
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !ready {
		t.Fatal("ntfy did not start")
	}
	backend, _ := url.Parse(base)
	proxy := httptest.NewServer(proxyHandler(backend))
	defer proxy.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	publish := func(text string) {
		t.Helper()
		r, err := http.Post(proxy.URL+"/notify", "text/plain", strings.NewReader(text))
		if err != nil {
			t.Fatal(err)
		}
		r.Body.Close()
		if r.StatusCode != 200 {
			t.Fatal(r.Status)
		}
	}
	t.Run("JSON_stream_flushes_before_EOF", func(t *testing.T) {
		req, _ := http.NewRequestWithContext(ctx, "GET", proxy.URL+"/notify/json?since=none", nil)
		r, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer r.Body.Close()
		reader := bufio.NewReader(r.Body)
		line, err := reader.ReadBytes('\n')
		if err != nil || !strings.Contains(string(line), `"event":"open"`) {
			t.Fatalf("open: %s %v", line, err)
		}
		publish("stream proof")
		line, err = reader.ReadBytes('\n')
		if err != nil || !strings.Contains(string(line), "stream proof") {
			t.Fatalf("message: %s %v", line, err)
		}
	})
	t.Run("WebSocket_upgrade_and_message", func(t *testing.T) {
		ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(proxy.URL, "http")+"/notify/ws?since=none", nil)
		if err != nil {
			t.Fatal(err)
		}
		defer ws.CloseNow()
		_, b, err := ws.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		var m struct {
			Event   string `json:"event"`
			Message string `json:"message"`
		}
		if err = json.Unmarshal(b, &m); err != nil || m.Event != "open" {
			t.Fatalf("open: %s", b)
		}
		publish("WebSocket proof")
		_, b, err = ws.Read(ctx)
		if err != nil || !strings.Contains(string(b), "WebSocket proof") {
			t.Fatalf("message: %s %v", b, err)
		}
	})
}
