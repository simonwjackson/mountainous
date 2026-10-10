package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"tailscale.com/tsnet"
)

// Enrollment never deletes a device. Saved machine state owns the identity.
// Errors deliberately omit server bodies, credentials and authentication URLs.
func enrollmentKey(ctx context.Context, client *http.Client, api, id, secret string, tags []string) (string, error) {
	if id == "" || secret == "" || len(tags) == 0 {
		return "", errors.New("incomplete OAuth enrollment configuration")
	}
	for _, tag := range tags {
		if !strings.HasPrefix(tag, "tag:") || strings.TrimPrefix(tag, "tag:") == "" {
			return "", errors.New("invalid enrollment tag")
		}
	}
	form := url.Values{"client_id": {id}, "client_secret": {secret}, "grant_type": {"client_credentials"}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, api+"/oauth/token", strings.NewReader(form.Encode()))
	if err != nil {
		return "", errors.New("cannot construct OAuth request")
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	response, err := client.Do(req)
	if err != nil {
		return "", errors.New("OAuth transport failed")
	}
	var token struct {
		AccessToken string `json:"access_token"`
	}
	decodeErr := json.NewDecoder(io.LimitReader(response.Body, 65536)).Decode(&token)
	response.Body.Close()
	if response.StatusCode != http.StatusOK || decodeErr != nil || token.AccessToken == "" {
		return "", errors.New("OAuth authorization failed")
	}
	body, err := json.Marshal(map[string]any{
		"capabilities": map[string]any{"devices": map[string]any{"create": map[string]any{
			"reusable": false, "ephemeral": false, "preauthorized": true, "tags": tags,
		}}},
		"expirySeconds": 3600,
	})
	if err != nil {
		return "", errors.New("cannot construct enrollment request")
	}
	req, err = http.NewRequestWithContext(ctx, http.MethodPost, api+"/tailnet/-/keys", strings.NewReader(string(body)))
	if err != nil {
		return "", errors.New("cannot construct enrollment request")
	}
	req.Header.Set("Authorization", "Bearer "+token.AccessToken)
	req.Header.Set("Content-Type", "application/json")
	response, err = client.Do(req)
	if err != nil {
		return "", errors.New("enrollment transport failed")
	}
	defer response.Body.Close()
	var key struct {
		Key string `json:"key"`
	}
	decodeErr = json.NewDecoder(io.LimitReader(response.Body, 65536)).Decode(&key)
	if response.StatusCode < 200 || response.StatusCode >= 300 || decodeErr != nil || key.Key == "" {
		return "", errors.New("enrollment authorization failed")
	}
	return key.Key, nil
}

func credential(path string) (string, error) {
	value, err := os.ReadFile(path)
	if err != nil {
		return "", errors.New("credential file unavailable")
	}
	return strings.TrimSpace(string(value)), nil
}

func proxyHandler(backend *url.URL) http.Handler {
	proxy := httputil.NewSingleHostReverseProxy(backend)
	director := proxy.Director
	proxy.Director = func(req *http.Request) {
		incomingHost := req.Host
		director(req)
		req.Host = backend.Host
		clientIP, _, err := net.SplitHostPort(req.RemoteAddr)
		if err != nil {
			clientIP = req.RemoteAddr
		}
		// Replace caller-supplied forwarding headers instead of trusting them.
		req.Header.Del("X-Forwarded-For")
		req.Header.Set("X-Forwarded-Proto", "https")
		req.Header.Set("X-Forwarded-Host", incomingHost)
		req.Header.Set("X-Real-IP", clientIP)
	}
	proxy.ErrorHandler = func(w http.ResponseWriter, _ *http.Request, _ error) {
		http.Error(w, "backend unavailable", http.StatusBadGateway)
	}
	// Request paths can contain secrets. Do not log requests or backend URLs.
	return proxy
}

func main() {
	hostname := flag.String("hostname", "tsnet-proxy", "Service name")
	backend := flag.String("backend", "http://localhost:8080", "Backend URL")
	authKey := flag.String("authkey", "", "Legacy auth key; prefer credential files")
	port := flag.String("port", "443", "Listening port")
	state := flag.String("state", "", "Explicit protected tsnet state directory")
	oauthID := flag.String("oauth-id-file", "", "OAuth client ID file")
	oauthSecret := flag.String("oauth-secret-file", "", "OAuth secret file")
	tags := flag.String("tags", "tag:mountainous", "Comma-separated enrollment tags")
	flag.Parse()
	backendURL, err := url.Parse(*backend)
	if err != nil || backendURL.Host == "" || backendURL.User != nil ||
		(backendURL.Scheme != "http" && backendURL.Scheme != "https") {
		log.Fatal("invalid backend configuration")
	}
	if (*oauthID == "") != (*oauthSecret == "") || (*oauthID != "" && *state == "") {
		log.Fatal("OAuth requires both credential files and explicit state")
	}
	if *authKey == "" {
		*authKey = os.Getenv("TS_AUTHKEY")
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if *oauthID != "" {
		id, err := credential(*oauthID)
		if err != nil {
			log.Fatal("OAuth ID unavailable")
		}
		secret, err := credential(*oauthSecret)
		if err != nil {
			log.Fatal("OAuth secret unavailable")
		}
		*authKey, err = enrollmentKey(ctx, &http.Client{Timeout: 30 * time.Second},
			"https://api.tailscale.com/api/v2", id, secret, strings.Split(*tags, ","))
		if err != nil {
			log.Fatal(err)
		}
	}
	srv := &tsnet.Server{
		Hostname: *hostname, Dir: *state, AuthKey: *authKey,
		Logf: func(string, ...any) {}, UserLogf: func(string, ...any) {},
	}
	defer srv.Close()
	upContext, cancel := context.WithTimeout(ctx, 90*time.Second)
	status, err := srv.Up(upContext)
	cancel()
	if err != nil || status == nil || status.Self == nil {
		log.Fatal("tailnet connection failed; identity state retained")
	}
	if strings.Split(strings.TrimSuffix(status.Self.DNSName, "."), ".")[0] != *hostname {
		log.Fatal("service name mismatch; refusing to serve or delete another identity")
	}
	var listener net.Listener
	if *port == "443" {
		listener, err = srv.ListenTLS("tcp", ":443")
	} else {
		listener, err = srv.Listen("tcp", ":"+*port)
	}
	if err != nil {
		log.Fatal("service listener failed; identity state retained")
	}
	server := &http.Server{Handler: proxyHandler(backendURL), ReadHeaderTimeout: 15 * time.Second}
	go func() {
		<-ctx.Done()
		shutdownContext, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		server.Shutdown(shutdownContext)
	}()
	log.Print("service identity verified; proxy ready")
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		log.Fatal("proxy server failed")
	}
}
