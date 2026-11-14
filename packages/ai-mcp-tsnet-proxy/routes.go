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
	"os/signal"
	"path/filepath"
	"regexp"
	"strings"
	"sync/atomic"
	"syscall"

	"tailscale.com/client/tailscale/apitype"
)

// Credential names refer only to files in systemd's CREDENTIALS_DIRECTORY.
// No caller input or secret values belong in this table.
// A row has a loopback Backend or a native Scryer account, never both.
type mcpRoute struct {
	Backend          string   `json:"backend,omitempty"`
	CallerNodeIDs    []string `json:"callerNodeIds"`
	Tools            []string `json:"mcpTools"`
	Resources        []string `json:"mcpResources,omitempty"`
	BearerCredential string   `json:"bearerCredential,omitempty"`
	// The proxy serves this account's Scryer MCP itself (scryer.go), the same
	// code a claw-scryer-<user> endpoint runs. No loopback MCP server exists.
	Scryer *scryerRoute `json:"scryer,omitempty"`
}

type scryerRoute struct {
	URL                string `json:"url"` // the fixed HTTPS GraphQL URL
	Username           string `json:"username"`
	PasswordCredential string `json:"passwordCredential"`
}

// systemd's SetCredential default (modules/tailnet-names.nix) when the sops
// file is missing. It is never a key or a password.
const unavailableCredential = "unavailable credential"

// Tests replace this to reach a local fixture instead of the HTTPS URL.
var newScryerRouteClient = newScryerClient

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
		caller := func(r *http.Request) bool {
			// WhoIs's stable node ID, not a node name, Host, forwarded headers
			// or user profile, owns identity. Exact, case-sensitive match only.
			id, err := router.stableNodeID(r)
			return err == nil && id != "" && callers[id]
		}
		var handler http.Handler
		var err error
		if row.Scryer != nil {
			handler, err = scryerRouteHandler(row, credentialsDirectory, caller)
		} else {
			handler, err = loopbackRouteHandler(row, credentialsDirectory, caller)
		}
		if err != nil {
			return err
		}
		routes["/mcp/"+name] = handler
	}
	// Invalid reloads never partially publish. In-flight requests own old handlers.
	router.routes.Store(routes)
	return nil
}

// The filtered proxy to a loopback MCP server, with an optional server-held
// Bearer key and an exact MCP App resource allowlist.
func loopbackRouteHandler(row mcpRoute, credentialsDirectory string, caller func(*http.Request) bool) (http.Handler, error) {
	backend, err := url.Parse(row.Backend)
	// Credentials and harmless test traffic stay on loopback.
	if err != nil || backend.Scheme != "http" || backend.Hostname() != "127.0.0.1" || backend.User != nil || backend.RawQuery != "" || backend.ForceQuery || backend.Fragment != "" || backend.Opaque != "" {
		return nil, errors.New("MCP backend must be fixed IPv4 loopback HTTP")
	}
	for _, uri := range row.Resources {
		// MCP App views only; never a file, HTTP or other resource.
		if !strings.HasPrefix(uri, "ui://") || len(uri) == len("ui://") || strings.ContainsAny(uri, " \t\r\n,") {
			return nil, errors.New("MCP resources must be exact ui:// URIs")
		}
	}
	var bearer string
	if row.BearerCredential != "" {
		data, err := readRouteCredential(credentialsDirectory, row.BearerCredential)
		bearer = strings.TrimSpace(data)
		if err != nil || bearer == "" || strings.ContainsAny(bearer, " \t\r\n") {
			return nil, errors.New("MCP credential unavailable or invalid")
		}
	}
	return mcpAuthenticatedResourceHandler(backend, row.Tools, row.Resources, bearer, caller), nil
}

// Scryer's own tools: scryer_graphql and the MCP App tools (scryer_app.go).
func scryerToolNames() map[string]bool {
	names := map[string]bool{"scryer_graphql": true}
	for _, tool := range scryerAppTools("") {
		names[tool.(map[string]any)["name"].(string)] = true
	}
	return names
}

// The account-scoped Scryer MCP, as a claw-scryer-<user> endpoint serves it,
// limited to the row's tools. The password is the server-held credential.
func scryerRouteHandler(row mcpRoute, credentialsDirectory string, caller func(*http.Request) bool) (http.Handler, error) {
	if row.Backend != "" || row.BearerCredential != "" || len(row.Resources) != 0 {
		return nil, errors.New("a Scryer row has no backend, bearer key or resource list")
	}
	graphql, err := url.Parse(row.Scryer.URL)
	if err != nil || graphql.Scheme != "https" || graphql.Host == "" || graphql.User != nil || graphql.RawQuery != "" || graphql.ForceQuery || graphql.Fragment != "" || graphql.Opaque != "" {
		return nil, errors.New("Scryer requires a fixed HTTPS GraphQL URL")
	}
	if !routeName.MatchString(row.Scryer.Username) {
		return nil, errors.New("invalid Scryer username")
	}
	native := scryerToolNames()
	allowed := make(map[string]bool, len(row.Tools))
	for _, tool := range row.Tools {
		if !native[tool] {
			return nil, errors.New("unknown Scryer tool")
		}
		allowed[tool] = true
	}
	data, err := readRouteCredential(credentialsDirectory, row.Scryer.PasswordCredential)
	// The endpoint mode strips only the final newline; a password may hold spaces.
	password := strings.TrimSuffix(data, "\n")
	if err != nil || password == "" || password == unavailableCredential || strings.ContainsAny(password, "\r\n\x00") {
		return nil, errors.New("Scryer credential unavailable or invalid")
	}
	return scryerToolsHandler(newScryerRouteClient(row.Scryer.URL, row.Scryer.Username, password), allowed, caller), nil
}

func readRouteCredential(credentialsDirectory, name string) (string, error) {
	if credentialsDirectory == "" || !routeName.MatchString(name) {
		return "", errors.New("MCP credential must name a LoadCredential file")
	}
	data, err := os.ReadFile(filepath.Join(credentialsDirectory, name))
	if err != nil {
		return "", errors.New("MCP credential unavailable")
	}
	return string(data), nil
}

// Call before the slow tailnet start (up to 90 s). SIGHUP's default action
// kills the process, so a reload during startup must already be caught; it
// waits in the channel until watch runs.
func notifyReloads() chan os.Signal {
	reloads := make(chan os.Signal, 1)
	signal.Notify(reloads, syscall.SIGHUP)
	return reloads
}

// A bad table, or a missing, empty or invalid credential (systemd's
// SetCredential default "unavailable credential") must not stop the front
// door: log it, serve no MCP rows, and let a later valid reload publish the
// table. Every other path keeps working.
func (router *mcpRouter) loadInitial(path, credentialsDirectory string) {
	if router.reload(path, credentialsDirectory) != nil {
		log.Print("initial MCP table rejected; serving no MCP rows until a valid reload")
	} else {
		log.Print("MCP table loaded")
	}
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
