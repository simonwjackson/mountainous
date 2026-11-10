package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// These endpoints expose stateless MCP requests, not a general HTTP proxy.
// No current calendar/maps tool has a UI resource. Resource and all other MCP
// methods fail closed; adding a view requires a separate exact URI allowlist.
const mcpMaxBody = 4 << 20

type mcpRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

func rpcError(w http.ResponseWriter, id json.RawMessage, code int, message string) {
	if len(id) == 0 {
		id = json.RawMessage("null")
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(struct {
		JSONRPC string          `json:"jsonrpc"`
		ID      json.RawMessage `json:"id"`
		Error   any             `json:"error"`
	}{"2.0", id, struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}{code, message}})
}

// The SDK may return JSON or one SSE message for a stateless POST. Buffer it
// within a fixed bound and re-encode JSON, so an unfiltered SSE event cannot leak.
func mcpResponse(response *http.Response) (map[string]json.RawMessage, error) {
	data, err := io.ReadAll(io.LimitReader(response.Body, mcpMaxBody+1))
	if err != nil || len(data) > mcpMaxBody || response.StatusCode != http.StatusOK {
		return nil, errors.New("invalid upstream response")
	}
	if strings.HasPrefix(response.Header.Get("Content-Type"), "text/event-stream") {
		var lines []string
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "data:") {
				lines = append(lines, strings.TrimPrefix(strings.TrimPrefix(line, "data:"), " "))
			}
		}
		data = []byte(strings.Join(lines, "\n"))
	}
	var envelope map[string]json.RawMessage
	if json.Unmarshal(data, &envelope) != nil || envelope == nil {
		return nil, errors.New("invalid upstream JSON")
	}
	return envelope, nil
}

func mcpHandler(backend *url.URL, tools []string, tailnetClient func(*http.Request) bool) http.Handler {
	allowed := make(map[string]bool, len(tools))
	for _, name := range tools {
		allowed[name] = true
	}
	// A fixed loopback destination, no environment proxy and no redirects.
	client := &http.Client{Timeout: 60 * time.Second, Transport: &http.Transport{}, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	target := *backend
	target.Path, target.RawPath, target.RawQuery, target.Fragment = "/mcp", "", "", ""
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !tailnetClient(r) {
			http.Error(w, "tailnet client required", http.StatusForbidden)
			return
		}
		if r.URL.Path != "/mcp" || r.URL.RawQuery != "" || r.Method != http.MethodPost {
			rpcError(w, nil, -32601, "MCP POST /mcp required")
			return
		}
		var request mcpRequest
		data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, mcpMaxBody))
		if err != nil || json.Unmarshal(data, &request) != nil || request.JSONRPC != "2.0" {
			rpcError(w, nil, -32600, "invalid MCP request")
			return
		}
		if request.Method == "notifications/initialized" && len(request.ID) == 0 {
			w.WriteHeader(http.StatusAccepted)
			return
		}
		var id any
		if json.Unmarshal(request.ID, &id) != nil || id == nil {
			rpcError(w, nil, -32600, "request ID required")
			return
		}
		switch id.(type) {
		case string, float64:
		default:
			rpcError(w, nil, -32600, "invalid request ID")
			return
		}
		switch request.Method {
		case "initialize":
			var params struct {
				ProtocolVersion string          `json:"protocolVersion"`
				ClientInfo      json.RawMessage `json:"clientInfo"`
				Capabilities    map[string]any  `json:"capabilities"`
			}
			if json.Unmarshal(request.Params, &params) != nil {
				rpcError(w, request.ID, -32602, "invalid initialize parameters")
				return
			}
			params.Capabilities = map[string]any{}
			request.Params, _ = json.Marshal(params)
		case "tools/list":
			// Our apps are unpaginated. Never forward arbitrary cursors or metadata.
			request.Params = json.RawMessage(`{}`)
		case "tools/call":
			var params struct {
				Name      string                     `json:"name"`
				Arguments map[string]json.RawMessage `json:"arguments,omitempty"`
			}
			if json.Unmarshal(request.Params, &params) != nil {
				rpcError(w, request.ID, -32602, "invalid tool parameters")
				return
			}
			if !allowed[params.Name] {
				rpcError(w, request.ID, -32601, "tool not allowed")
				return
			}
			request.Params, _ = json.Marshal(params)
		default:
			rpcError(w, request.ID, -32601, "method not allowed")
			return
		}
		// Re-encode validated fields. Never forward the original body or headers.
		body, _ := json.Marshal(request)
		upstream, err := http.NewRequestWithContext(r.Context(), http.MethodPost, target.String(), bytes.NewReader(body))
		if err != nil {
			rpcError(w, request.ID, -32603, "upstream request failed")
			return
		}
		upstream.Header.Set("Content-Type", "application/json")
		upstream.Header.Set("Accept", "application/json, text/event-stream")
		if version := r.Header.Get("MCP-Protocol-Version"); version != "" {
			upstream.Header.Set("MCP-Protocol-Version", version)
		}
		response, err := client.Do(upstream)
		if err != nil {
			rpcError(w, request.ID, -32603, "upstream unavailable")
			return
		}
		defer response.Body.Close()
		envelope, err := mcpResponse(response)
		if err != nil {
			rpcError(w, request.ID, -32603, "invalid upstream response")
			return
		}
		// Rebuild the envelope, keeping no unrecognized upstream extensions.
		output := map[string]any{"jsonrpc": "2.0", "id": request.ID}
		if remoteError, ok := envelope["error"]; ok {
			output["error"] = remoteError
		} else {
			var result map[string]json.RawMessage
			if json.Unmarshal(envelope["result"], &result) != nil || result == nil {
				rpcError(w, request.ID, -32603, "invalid upstream result")
				return
			}
			switch request.Method {
			case "tools/list":
				var listed []struct {
					Name string `json:"name"`
				}
				var raw []json.RawMessage
				if json.Unmarshal(result["tools"], &listed) != nil || json.Unmarshal(result["tools"], &raw) != nil {
					rpcError(w, request.ID, -32603, "invalid upstream tools")
					return
				}
				selected := []json.RawMessage{}
				for i, tool := range listed {
					if allowed[tool.Name] {
						selected = append(selected, raw[i])
					}
				}
				output["result"] = map[string]any{"tools": selected}
			case "initialize":
				output["result"] = map[string]any{"protocolVersion": result["protocolVersion"], "serverInfo": result["serverInfo"], "capabilities": map[string]any{"tools": map[string]any{}}}
			default:
				output["result"] = result
			}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(output)
	})
}
