package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

// Only the login session is cached, in process memory. Restarting drops it.
// A rejected session (HTTP 401) is the only safe reason to resend an operation.
type scryerClient struct {
	url, password string
	client        *http.Client
	mu            sync.Mutex
	token         string
	expires       time.Time
}

func newScryerClient(url, password string) *scryerClient {
	return &scryerClient{url: url, password: password, client: &http.Client{
		Timeout: 30 * time.Second, Transport: &http.Transport{},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}
}

func (s *scryerClient) post(ctx context.Context, body []byte, token string) (json.RawMessage, int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.url, bytes.NewReader(body))
	if err != nil {
		return nil, 0, errors.New("invalid Scryer request")
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	response, err := s.client.Do(req)
	if err != nil {
		return nil, 0, errors.New("Scryer unavailable; do not retry a mutation without reading its state")
	}
	defer response.Body.Close()
	data, err := io.ReadAll(io.LimitReader(response.Body, mcpMaxBody+1))
	if err != nil || len(data) > mcpMaxBody {
		return nil, response.StatusCode, errors.New("Scryer response unreadable or too large")
	}
	if !json.Valid(data) {
		return nil, response.StatusCode, errors.New("Scryer returned invalid JSON")
	}
	return data, response.StatusCode, nil
}

func (s *scryerClient) session(ctx context.Context, rejected string) (string, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token != "" && s.token != rejected && time.Until(s.expires) > 5*time.Minute {
		return s.token, 0, nil
	}
	s.token = ""
	body, _ := json.Marshal(map[string]any{
		"query":     "mutation($i:LoginInput!){login(input:$i){token expiresAt}}",
		"variables": map[string]any{"i": map[string]any{"username": "admin", "password": s.password, "persistSession": false}},
	})
	data, status, err := s.post(ctx, body, "")
	// Never expose login response bodies: they may contain passwords or tokens.
	if err != nil || status != http.StatusOK {
		return "", status, errors.New("Scryer admin login failed")
	}
	var result struct {
		Data struct {
			Login struct {
				Token     string
				ExpiresAt time.Time
			}
		}
		Errors []json.RawMessage
	}
	if json.Unmarshal(data, &result) != nil || len(result.Errors) != 0 || result.Data.Login.Token == "" || !result.Data.Login.ExpiresAt.After(time.Now()) {
		return "", status, errors.New("Scryer admin login failed")
	}
	s.token, s.expires = result.Data.Login.Token, result.Data.Login.ExpiresAt
	return s.token, 0, nil
}

// Fail closed if an upstream error or selected secret field reflects our own
// credential. Otherwise preserve the complete GraphQL JSON, including errors.
func containsCredential(value any, password string) bool {
	switch v := value.(type) {
	case string:
		return password != "" && strings.Contains(v, password)
	case []any:
		for _, item := range v {
			if containsCredential(item, password) {
				return true
			}
		}
	case map[string]any:
		for k, item := range v {
			if containsCredential(k, password) || containsCredential(item, password) {
				return true
			}
		}
	}
	return false
}

func (s *scryerClient) execute(ctx context.Context, body []byte) (any, bool) {
	token, status, err := s.session(ctx, "")
	if err != nil {
		return map[string]any{"kind": "scryer_login_error", "status": status, "message": err.Error()}, true
	}
	data, status, err := s.post(ctx, body, token)
	if status == http.StatusUnauthorized {
		token, status, err = s.session(ctx, token)
		if err != nil {
			return map[string]any{"kind": "scryer_login_error", "status": status, "message": err.Error()}, true
		}
		data, status, err = s.post(ctx, body, token)
	}
	if err != nil {
		return map[string]any{"kind": "scryer_transport_error", "status": status, "message": err.Error()}, true
	}
	var decoded any
	json.Unmarshal(data, &decoded)
	if containsCredential(decoded, s.password) {
		return map[string]any{"kind": "scryer_credential_redacted", "message": "Scryer reply contained the admin credential and was withheld"}, true
	}
	if status < 200 || status >= 300 {
		return map[string]any{"kind": "scryer_http_error", "status": status, "body": data}, true
	}
	return data, false
}

func scryerHandler(s *scryerClient, tailnetClient func(*http.Request) bool) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		request, ok := readMCPRequest(w, r, tailnetClient)
		if !ok {
			return
		}
		var result any
		switch request.Method {
		case "initialize":
			var params struct {
				ProtocolVersion string `json:"protocolVersion"`
			}
			if json.Unmarshal(request.Params, &params) != nil {
				rpcError(w, request.ID, -32602, "invalid initialize parameters")
				return
			}
			version := params.ProtocolVersion
			if version != "2025-03-26" && version != "2025-11-25" {
				version = "2025-03-26"
			}
			result = map[string]any{"protocolVersion": version, "serverInfo": map[string]string{"name": "claw-scryer", "version": "1"}, "capabilities": map[string]any{"tools": map[string]any{}}}
		case "tools/list":
			result = map[string]any{"tools": []any{map[string]any{
				"name": "scryer_graphql", "description": "Full-admin Scryer GraphQL. Read the live schema. Mutations are allowed; confirm destructive actions. No uploads or downloads. Do not retry mutations after timeouts.",
				"inputSchema": json.RawMessage(`{"type":"object","properties":{"query":{"type":"string","minLength":1},"variables":{"type":"object"}},"required":["query"],"additionalProperties":false}`),
			}}}
		case "tools/call":
			var params struct {
				Name      string          `json:"name"`
				Arguments json.RawMessage `json:"arguments"`
			}
			if json.Unmarshal(request.Params, &params) != nil {
				rpcError(w, request.ID, -32602, "invalid tool parameters")
				return
			}
			if params.Name != "scryer_graphql" {
				rpcError(w, request.ID, -32601, "tool not allowed")
				return
			}
			var args struct {
				Query     string                     `json:"query"`
				Variables map[string]json.RawMessage `json:"variables,omitempty"`
			}
			decoder := json.NewDecoder(bytes.NewReader(params.Arguments))
			decoder.DisallowUnknownFields()
			var fields map[string]json.RawMessage
			if decoder.Decode(&args) != nil || strings.TrimSpace(args.Query) == "" || json.Unmarshal(params.Arguments, &fields) != nil || (fields["variables"] != nil && bytes.Equal(bytes.TrimSpace(fields["variables"]), []byte("null"))) {
				rpcError(w, request.ID, -32602, "query must be a nonempty string; variables must be an object")
				return
			}
			body, _ := json.Marshal(args)
			ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
			defer cancel()
			reply, failed := s.execute(ctx, body)
			text, _ := json.Marshal(reply)
			result = map[string]any{"content": []any{map[string]string{"type": "text", "text": string(text)}}, "structuredContent": reply, "isError": failed}
		default:
			rpcError(w, request.ID, -32601, "method not allowed")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"jsonrpc": "2.0", "id": request.ID, "result": result})
	})
}
