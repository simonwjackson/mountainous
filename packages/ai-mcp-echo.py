"""A staging-only no-op MCP backend. Never read files, environment or user data."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class EchoMCP(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        if self.path != "/mcp":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 65536:
                raise ValueError("invalid size")
            request = json.loads(self.rfile.read(length))
            if not isinstance(request, dict) or request.get("jsonrpc") != "2.0":
                raise ValueError("invalid request")
            method = request.get("method")
            error = None
            if method == "initialize":
                result = {
                    "protocolVersion": "2025-03-26",
                    "serverInfo": {"name": "ai-staging-echo", "version": "1"},
                    "capabilities": {"tools": {}},
                }
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {
                    "tools": [
                        {
                            "name": "echo",
                            "description": "No-op staging test. Always returns ok.",
                            "inputSchema": {
                                "type": "object",
                                "properties": {},
                                "additionalProperties": False,
                            },
                        }
                    ]
                }
            elif (
                method == "tools/call"
                and request.get("params", {}).get("name") == "echo"
            ):
                result = {"content": [{"type": "text", "text": "ok"}]}
            else:
                result = None
                error = {"code": -32601, "message": "method not allowed"}
            response = {"jsonrpc": "2.0", "id": request.get("id")}
            response["error" if error else "result"] = error if error else result
            data = json.dumps(response).encode()
        except (ValueError, TypeError, AttributeError):
            self.send_error(400)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8422), EchoMCP).serve_forever()
