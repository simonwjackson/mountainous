"""Data-free loopback test process. Does not join a tailnet or call providers."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json

parser = argparse.ArgumentParser()
parser.add_argument("--host", default="127.0.0.1", choices=["127.0.0.1"])
parser.add_argument("--port", type=int, required=True)
parser.add_argument("--data-dir")
args = parser.parse_args()


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/healthz":
            self.send_error(404)
            return
        body = json.dumps({"status": "ok", "phase": "ready", "buildId": "canary-v1"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


ThreadingHTTPServer((args.host, args.port), HealthHandler).serve_forever()
