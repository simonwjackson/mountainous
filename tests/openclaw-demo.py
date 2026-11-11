"""Verify the official packaged stdio server and its ui:// resource, offline."""

import json
import select
import subprocess
import sys

tool_name = sys.argv[2]

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
        app_tool = next(tool for tool in tools if tool["name"] == tool_name)
        uri = app_tool["_meta"]["ui"]["resourceUri"]
        assert uri.startswith("ui://")
        content = request(3, "resources/read", {"uri": uri})["contents"][0]
        assert content["mimeType"] == "text/html;profile=mcp-app"
        assert "<html" in content["text"]
        result = request(4, "tools/call", {"name": tool_name, "arguments": {}})
        assert not result.get("isError"), result
        if tool_name == "get-budget-data":
            data = result["structuredContent"]
            assert sum(c["defaultPercent"] for c in data["config"]["categories"]) == 100
            assert len(data["analytics"]["history"]) == 24
        if tool_name == "get-system-info":
            assert result["structuredContent"]["cpu"]["count"] > 0
            poll = next(tool for tool in tools if tool["name"] == "poll-system-stats")
            assert poll["_meta"]["ui"]["visibility"] == ["app"]
            timestamps = []
            for ident in (5, 6):
                stats = request(
                    ident, "tools/call", {"name": "poll-system-stats", "arguments": {}}
                )
                assert not stats.get("isError"), stats
                data = stats["structuredContent"]
                assert data["cpu"]["cores"]
                assert 0 <= data["memory"]["usedPercent"] <= 100
                timestamps.append(data["timestamp"])
            assert timestamps[0] < timestamps[1]
        print(f"Packaged MCP {tool_name} tool and ui:// resource passed")
    finally:
        server.terminate()
        server.wait(timeout=5)
