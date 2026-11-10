"""Verify the official packaged stdio server and its ui:// resource, offline."""

import json
import select
import subprocess
import sys

with subprocess.Popen(
    [sys.argv[1], "--stdio"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
) as server:

    def send(message):
        server.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
        server.stdin.flush()

    def request(ident, method, params):
        send({"id": ident, "method": method, "params": params})
        while True:
            assert select.select([server.stdout], [], [], 20)[0], method + " timed out"
            message = json.loads(server.stdout.readline())
            if message.get("id") == ident:
                assert "error" not in message, message
                return message["result"]

    try:
        request(
            1,
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "nix-check", "version": "1"},
            },
        )
        send({"method": "notifications/initialized"})
        tools = request(2, "tools/list", {})["tools"]
        clock = next(tool for tool in tools if tool["name"] == "get-time")
        uri = clock["_meta"]["ui"]["resourceUri"]
        assert uri.startswith("ui://")
        content = request(3, "resources/read", {"uri": uri})["contents"][0]
        assert content["mimeType"] == "text/html;profile=mcp-app"
        assert "<html" in content["text"]
        assert not request(4, "tools/call", {"name": "get-time", "arguments": {}}).get(
            "isError"
        )
        print("Packaged MCP clock tool and React ui:// resource passed")
    finally:
        server.terminate()
        server.wait(timeout=5)
