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

	"tailscale.com/client/tailscale/apitype"
)

// Credential names refer only to files in systemd's CREDENTIALS_DIRECTORY.
// No caller input or secret values belong in this table.
type mcpRoute struct {
	Backend          string   `json:"backend"`
	CallerNodeIDs    []string `json:"callerNodeIds"`
	Tools            []string `json:"mcpTools"`
	BearerCredential string   `json:"bearerCredential,omitempty"`
}

type mcpRouter struct {
	fallback http.Handler
	// Returns the caller's stable Tailscale node ID from WhoIs.
	stableNodeID func(*http.Request) (string, error)
	routes       atomic.Value // immutable map[string]http.Handler; one snapshot per request
}

func newMCPRouter(fallback http.Handler, stableNodeID func(*http.Request) (string, error)) *mcpRouter {
	router := &mcpRouter{fallback: fallback, stableNodeID: stableNodeID}
	router.routes.Store(map[string]http.Handler{})
	return router
}

// A node name can be registered again by another node after the original is
// removed, and a rename changes it. The stable node ID does neither.
func whoIsStableNodeID(peer *apitype.WhoIsResponse, err error) (string, error) {
	if err != nil || peer == nil || peer.Node == nil || peer.Node.StableID == "" {
		return "", errors.New("tailnet identity unavailable")
	}
	return string(peer.Node.StableID), nil
}

var routeName = regexp.MustCompile(`^[a-zA-Z0-9_-]+$`)

// The shape of Tailscale's stable node IDs, e.g. nbQJZMcewG11CNTRL. A node
// name such as "zao" or "flakey" never passes as an ID.
var stableNodeIDPattern = regexp.MustCompile(`^n[a-zA-Z0-9]+CNTRL$`)

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
		if !routeName.MatchString(name) || len(row.CallerNodeIDs) == 0 || len(row.Tools) == 0 {
			return errors.New("MCP row requires a name, caller node IDs and tools")
		}
		backend, err := url.Parse(row.Backend)
		// Step one keeps credentials and harmless test traffic on loopback.
		if err != nil || backend.Scheme != "http" || backend.Hostname() != "127.0.0.1" || backend.User != nil || backend.RawQuery != "" || backend.Fragment != "" || backend.Opaque != "" {
			return errors.New("MCP backend must be fixed IPv4 loopback HTTP")
		}
		callers := make(map[string]bool, len(row.CallerNodeIDs))
		for _, id := range row.CallerNodeIDs {
			if !stableNodeIDPattern.MatchString(id) {
				return errors.New("MCP caller must be a stable Tailscale node ID")
			}
			callers[id] = true
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
			// WhoIs's stable node ID, not a node name, Host, forwarded headers
			// or user profile, owns identity. Exact, case-sensitive match only.
			id, err := router.stableNodeID(r)
			return err == nil && id != "" && callers[id]
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
