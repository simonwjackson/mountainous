package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync/atomic"
)

// Credential names refer only to files in systemd's CREDENTIALS_DIRECTORY.
// No caller input or secret values belong in this table.
type mcpRoute struct {
	Backend          string   `json:"backend"`
	Callers          []string `json:"callers"`
	Tools            []string `json:"mcpTools"`
	BearerCredential string   `json:"bearerCredential,omitempty"`
}

type mcpRouter struct {
	fallback http.Handler
	whoIs    func(*http.Request) (string, error)
	routes   atomic.Value // immutable map[string]http.Handler; one snapshot per request
}

func newMCPRouter(fallback http.Handler, whoIs func(*http.Request) (string, error)) *mcpRouter {
	router := &mcpRouter{fallback: fallback, whoIs: whoIs}
	router.routes.Store(map[string]http.Handler{})
	return router
}

var routeName = regexp.MustCompile(`^[a-zA-Z0-9_-]+$`)
var callerName = regexp.MustCompile(`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`)

func (router *mcpRouter) reload(path, credentialsDirectory string) error {
	file, err := os.Open(path)
	if err != nil {
		return errors.New("MCP table unavailable")
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, (1<<20)+1))
	if err != nil || len(data) > 1<<20 {
		return errors.New("MCP table too large or unreadable")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var table map[string]mcpRoute
	if decoder.Decode(&table) != nil || table == nil {
		return errors.New("invalid MCP table")
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF {
		return errors.New("invalid MCP table suffix")
	}
	routes := make(map[string]http.Handler, len(table))
	for name, row := range table {
		if !routeName.MatchString(name) || len(row.Callers) == 0 || len(row.Tools) == 0 {
			return errors.New("MCP row requires a name, callers and tools")
		}
		backend, err := url.Parse(row.Backend)
		// Step one keeps credentials and harmless test traffic on loopback.
		if err != nil || backend.Scheme != "http" || backend.Hostname() != "127.0.0.1" || backend.User != nil || backend.RawQuery != "" || backend.Fragment != "" || backend.Opaque != "" {
			return errors.New("MCP backend must be fixed IPv4 loopback HTTP")
		}
		callers := make(map[string]bool, len(row.Callers))
		for _, caller := range row.Callers {
			if !callerName.MatchString(caller) {
				return errors.New("MCP caller must be an exact short node name")
			}
			callers[caller] = true
		}
		for _, tool := range row.Tools {
			if !routeName.MatchString(tool) {
				return errors.New("invalid MCP tool name")
			}
		}
		var bearer string
		if row.BearerCredential != "" {
			if credentialsDirectory == "" || !routeName.MatchString(row.BearerCredential) {
				return errors.New("MCP credential must name a LoadCredential file")
			}
			data, err := os.ReadFile(filepath.Join(credentialsDirectory, row.BearerCredential))
			bearer = strings.TrimSpace(string(data))
			if err != nil || bearer == "" || strings.ContainsAny(bearer, " \t\r\n") {
				return errors.New("MCP credential unavailable or invalid")
			}
		}
		routes["/mcp/"+name] = mcpAuthenticatedResourceHandler(backend, row.Tools, nil, bearer, func(r *http.Request) bool {
			node, err := router.whoIs(r)
			// WhoIs, not Host, forwarded headers or user profile, owns identity.
			shortName := strings.Split(strings.TrimSuffix(node, "."), ".")[0]
			return err == nil && callers[shortName]
		})
	}
	// Invalid reloads never partially publish. In-flight requests own old handlers.
	router.routes.Store(routes)
	return nil
}

func (router *mcpRouter) watch(ctx context.Context, reloads <-chan os.Signal, path, credentialsDirectory string) {
	for {
		select {
		case <-ctx.Done():
			return
		case _, ok := <-reloads:
			if !ok {
				return
			}
			if router.reload(path, credentialsDirectory) != nil {
				log.Print("MCP table reload rejected; previous table retained")
			} else {
				log.Print("MCP table reloaded")
			}
		}
	}
}

func (router *mcpRouter) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !strings.HasPrefix(r.URL.Path, "/mcp/") {
		// Do not clone, rewrite, authenticate or wrap normal front-door traffic.
		router.fallback.ServeHTTP(w, r)
		return
	}
	handler, ok := router.routes.Load().(map[string]http.Handler)[r.URL.Path]
	if !ok {
		http.NotFound(w, r)
		return
	}
	request := r.Clone(r.Context())
	request.URL.Path, request.URL.RawPath = "/mcp", ""
	handler.ServeHTTP(w, request)
}
