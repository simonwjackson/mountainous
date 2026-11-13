"""Exercise the real harmless MCP backend over a loopback HTTP socket."""

import importlib.util
import json
import sys
import threading
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

spec = importlib.util.spec_from_file_location("echo", sys.argv[1])
echo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(echo)
server = ThreadingHTTPServer(("127.0.0.1", 0), echo.EchoMCP)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
base = f"http://127.0.0.1:{server.server_port}"


def request(method, params=None):
    data = json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}}
    ).encode()
    req = urllib.request.Request(
        base + "/mcp", data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=3) as response:
        assert response.status == 200
        return json.load(response)


try:
    assert request("initialize")["result"]["serverInfo"]["name"] == "ai-staging-echo"
    assert request("ping")["result"] == {}
    tools = request("tools/list")["result"]["tools"]
    assert [tool["name"] for tool in tools] == ["echo"]
    assert request(
        "tools/call", {"name": "echo", "arguments": {"secret": "never-echo"}}
    )["result"] == {"content": [{"type": "text", "text": "ok"}]}
    assert request("tools/call", {"name": "unknown"})["error"]["code"] == -32601
    try:
        urllib.request.urlopen(base + "/mcp", data=b"invalid", timeout=3)
    except urllib.error.HTTPError as error:
        assert error.code == 400
    else:
        raise AssertionError("invalid JSON accepted")
finally:
    server.shutdown()
    thread.join(timeout=3)
    server.server_close()

print("MCP echo: initialize, ping, list, no-op, deny, invalid JSON PASS")
