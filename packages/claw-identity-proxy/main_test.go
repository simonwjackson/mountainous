package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"net/url"
	"strings"
	"testing"
)

var cfg = Config{Tag: "tag:mountainous", Login: "simon@example.com"}

func fakeWhoIs(peers map[string]Peer) WhoIs {
	return func(_ context.Context, addr netip.Addr) (Peer, error) {
		p, ok := peers[addr.String()]
		if !ok {
			return Peer{}, errors.New("unknown peer")
		}
		return p, nil
	}
}

var peers = map[string]Peer{
	"100.64.0.1": {Tags: []string{"tag:mountainous"}},
	"100.64.0.2": {Tags: []string{"tag:claw-tools"}},
	"100.64.0.3": {},
}

// upstream echoes the identity and forwarding headers it received.
func upstream(t *testing.T) *url.URL {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "login=%q xff=%q xfh=%q xfp=%q host=%q",
			r.Header.Get(loginHeader), r.Header.Get("X-Forwarded-For"),
			r.Header.Get("X-Forwarded-Host"), r.Header.Get("X-Forwarded-Proto"), r.Host)
	}))
	t.Cleanup(srv.Close)
	u, _ := url.Parse(srv.URL)
	return u
}

func get(t *testing.T, h http.Handler, headers map[string]string) string {
	t.Helper()
	r := httptest.NewRequest("GET", "https://claw.example.ts.net/", nil)
	for k, v := range headers {
		r.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	body, _ := io.ReadAll(w.Result().Body)
	return string(body)
}

func TestIdentity(t *testing.T) {
	h := newHandler(upstream(t), cfg, fakeWhoIs(peers))
	serve := func(xff string) map[string]string {
		return map[string]string{"X-Forwarded-For": xff, "X-Forwarded-Host": "claw.example.ts.net", "X-Forwarded-Proto": "https"}
	}
	cases := []struct {
		name    string
		headers map[string]string
		want    string
	}{
		{"tagged device gets the configured login", serve("100.64.0.1"), `login="simon@example.com"`},
		{"other tag gets nothing", serve("100.64.0.2"), `login=""`},
		{"untagged device without a Serve login gets nothing", serve("100.64.0.3"), `login=""`},
		{"unknown peer gets nothing", serve("100.64.0.9"), `login=""`},
		{"no X-Forwarded-For gets nothing", map[string]string{}, `login=""`},
		{"a chain is refused", serve("100.64.0.1, 100.64.0.2"), `login=""`},
		{"loopback is refused", serve("127.0.0.1"), `login=""`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := get(t, h, c.headers); !strings.Contains(got, c.want) {
				t.Fatalf("got %s, want %s", got, c.want)
			}
		})
	}
}

func TestServeLoginPassesThroughUnchanged(t *testing.T) {
	h := newHandler(upstream(t), cfg, fakeWhoIs(peers))
	got := get(t, h, map[string]string{"X-Forwarded-For": "100.64.0.1", loginHeader: "laure@example.com"})
	if !strings.Contains(got, `login="laure@example.com"`) {
		t.Fatal(got)
	}
}

func TestForwardingHeadersAndHostSurvive(t *testing.T) {
	h := newHandler(upstream(t), cfg, fakeWhoIs(peers))
	got := get(t, h, map[string]string{"X-Forwarded-For": "100.64.0.3", "X-Forwarded-Host": "claw.example.ts.net", "X-Forwarded-Proto": "https"})
	for _, want := range []string{`xff="100.64.0.3"`, `xfh="claw.example.ts.net"`, `xfp="https"`, `host="claw.example.ts.net"`} {
		if !strings.Contains(got, want) {
			t.Fatalf("got %s, want %s", got, want)
		}
	}
}

// A WebSocket-style upgrade must reach the gateway with the login and stay open.
func TestUpgradeCarriesLogin(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	seen := make(chan string, 1)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		req, err := http.ReadRequest(bufio.NewReader(c))
		if err != nil {
			return
		}
		seen <- req.Header.Get(loginHeader)
		io.WriteString(c, "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\nhello")
	}()
	target, _ := url.Parse("http://" + ln.Addr().String())
	proxy := httptest.NewServer(newHandler(target, cfg, fakeWhoIs(peers)))
	defer proxy.Close()
	c, err := net.Dial("tcp", strings.TrimPrefix(proxy.URL, "http://"))
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	io.WriteString(c, "GET /ws HTTP/1.1\r\nHost: claw\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nX-Forwarded-For: 100.64.0.1\r\n\r\n")
	resp, err := http.ReadResponse(bufio.NewReader(c), nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 101 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	if got := <-seen; got != "simon@example.com" {
		t.Fatalf("upstream saw login %q", got)
	}
}
