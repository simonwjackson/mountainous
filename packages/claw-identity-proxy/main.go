// claw-identity-proxy sits between the Claw node's own `tailscale serve` and
// the OpenClaw gateway, both on loopback in the openclaw container.
//
// Tailscale Serve already deletes client-supplied Tailscale-User-* headers and
// sets Tailscale-User-Login for devices logged in as a person. It sets no
// login for tagged devices. This proxy gives a configured person to tagged
// devices that carry one configured tag, by asking the local tailscaled (WhoIs)
// about the X-Forwarded-For address that Serve set. Everything else passes
// through unchanged; a request without a login is then refused by the gateway.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/netip"
	"net/url"
	"os/exec"
	"slices"
	"strings"
	"sync"
	"time"
)

const loginHeader = "Tailscale-User-Login"

// Peer is the part of `tailscale whois --json` this proxy uses.
type Peer struct {
	Tags []string
}

// WhoIs resolves a tailnet address to its node.
type WhoIs func(ctx context.Context, addr netip.Addr) (Peer, error)

// Config says which tagged devices act as which person.
type Config struct {
	Tag   string
	Login string
}

// identify returns the login to add for a request that Serve left without one,
// or "" to add nothing.
func identify(ctx context.Context, r *http.Request, cfg Config, whois WhoIs) string {
	if r.Header.Get(loginHeader) != "" {
		return ""
	}
	forwarded := r.Header.Values("X-Forwarded-For")
	if len(forwarded) != 1 || strings.Contains(forwarded[0], ",") {
		return ""
	}
	addr, err := netip.ParseAddr(strings.TrimSpace(forwarded[0]))
	if err != nil || addr.IsLoopback() {
		return ""
	}
	peer, err := whois(ctx, addr)
	if err != nil || !slices.Contains(peer.Tags, cfg.Tag) {
		return ""
	}
	return cfg.Login
}

// newHandler proxies to upstream, adding the login when identify finds one.
func newHandler(upstream *url.URL, cfg Config, whois WhoIs) http.Handler {
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(upstream)
			pr.Out.Host = pr.In.Host
			// Rewrite drops the X-Forwarded-* headers. Keep Serve's values:
			// the gateway needs them to attribute the proxied client.
			for _, h := range []string{"X-Forwarded-For", "X-Forwarded-Host", "X-Forwarded-Proto"} {
				if v := pr.In.Header.Values(h); len(v) > 0 {
					pr.Out.Header[h] = slices.Clone(v)
				}
			}
			if login := identify(pr.In.Context(), pr.In, cfg, whois); login != "" {
				pr.Out.Header.Set(loginHeader, login)
			}
		},
	}
	return proxy
}

// cliWhoIs asks tailscaled through the tailscale CLI and caches answers briefly,
// because one page load makes many requests from the same device.
func cliWhoIs(bin string, ttl time.Duration) WhoIs {
	type entry struct {
		peer    Peer
		expires time.Time
	}
	var mu sync.Mutex
	cache := map[netip.Addr]entry{}
	return func(ctx context.Context, addr netip.Addr) (Peer, error) {
		now := time.Now()
		mu.Lock()
		if e, ok := cache[addr]; ok && now.Before(e.expires) {
			mu.Unlock()
			return e.peer, nil
		}
		mu.Unlock()
		ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		out, err := exec.CommandContext(ctx, bin, "whois", "--json", addr.String()).Output()
		if err != nil {
			return Peer{}, err
		}
		var reply struct {
			Node *struct {
				Tags []string
			}
		}
		if err := json.Unmarshal(out, &reply); err != nil {
			return Peer{}, err
		}
		if reply.Node == nil {
			return Peer{}, errors.New("whois: no node")
		}
		peer := Peer{Tags: reply.Node.Tags}
		mu.Lock()
		cache[addr] = entry{peer: peer, expires: now.Add(ttl)}
		mu.Unlock()
		return peer, nil
	}
}

func main() {
	listen := flag.String("listen", "127.0.0.1:18788", "loopback address that Tailscale Serve targets")
	upstream := flag.String("upstream", "http://127.0.0.1:18789", "OpenClaw gateway")
	bin := flag.String("tailscale", "tailscale", "tailscale CLI")
	tag := flag.String("tag", "", "tag whose devices act as -login")
	login := flag.String("login", "", "login given to devices with -tag")
	flag.Parse()
	target, err := url.Parse(*upstream)
	if err != nil || *tag == "" || *login == "" {
		log.Fatal("need -upstream, -tag and -login")
	}
	if addr, err := netip.ParseAddrPort(*listen); err != nil || !addr.Addr().IsLoopback() {
		log.Fatal("-listen must be a loopback address")
	}
	cfg := Config{Tag: *tag, Login: *login}
	server := &http.Server{
		Addr:              *listen,
		Handler:           newHandler(target, cfg, cliWhoIs(*bin, 30*time.Second)),
		ReadHeaderTimeout: 30 * time.Second,
	}
	log.Fatal(server.ListenAndServe())
}
