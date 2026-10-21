package notifysync_test

import (
	"bytes"
	"context"
	"encoding/json"
	ns "github.com/simonwjackson/mountainous/notify-sync"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestStatelessMCPAndBearer(t *testing.T) {
	base := ntfyServer(t)
	client, _ := ns.NewClient(base, base, "", "")
	hub := ns.Hub{client}
	token := strings.Repeat("m", 48)
	handler, err := hub.Handler(token)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	defer server.Close()
	request := func(auth, body string) (int, []byte) {
		t.Helper()
		req, err := http.NewRequest("POST", server.URL+"/mcp", strings.NewReader(body))
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json, text/event-stream")
		req.Header.Set("Authorization", auth)
		req.Header.Set("MCP-Protocol-Version", "2025-06-18")
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		data, _ := io.ReadAll(res.Body)
		if res.Header.Get("Mcp-Session-Id") != "" {
			t.Fatal("stateful session created")
		}
		return res.StatusCode, data
	}
	if code, _ := request("", `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`); code != 401 {
		t.Fatal(code)
	}
	code, data := request("Bearer "+token, `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)
	if code != 200 {
		t.Fatalf("%d: %s", code, data)
	}
	for _, name := range []string{"send", "list", "clear", "wait"} {
		if !bytes.Contains(data, []byte(`"name":"`+name+`"`)) {
			t.Fatalf("missing %s: %s", name, data)
		}
	}
	code, data = request("Bearer "+token, `{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"send","arguments":{"name":"mcp-test","summary":"MCP send"}}}`)
	if code != 200 || bytes.Contains(data, []byte(`"isError":true`)) {
		t.Fatalf("%d %s", code, data)
	}
	items, err := client.List(context.Background())
	if err != nil || len(items) != 1 {
		t.Fatalf("%v %v", items, err)
	}
	seq := items[0].Item.Seq
	code, data = request("Bearer "+token, `{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list","arguments":{}}}`)
	if code != 200 || !bytes.Contains(data, []byte(seq)) {
		t.Fatalf("list: %d %s", code, data)
	}
	call, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": map[string]any{"name": "clear", "arguments": map[string]string{"seq": seq}}})
	code, data = request("Bearer "+token, string(call))
	if code != 200 || !bytes.Contains(data, []byte(`"cleared":true`)) {
		t.Fatalf("%d %s", code, data)
	}
	waitCall, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": map[string]any{"name": "wait", "arguments": map[string]any{"seq": seq, "timeout": 1}}})
	code, data = request("Bearer "+token, string(waitCall))
	if code != 200 || !bytes.Contains(data, []byte(`"type":"clear"`)) {
		t.Fatalf("wait: %d %s", code, data)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	ctl, err := client.Wait(ctx, seq)
	if err != nil || ctl.Type != "clear" {
		t.Fatalf("%+v %v", ctl, err)
	}
}
