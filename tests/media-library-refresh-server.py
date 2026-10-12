#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Disposable HTTP library-refresh endpoint with its real authentication contract."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import sys

received = Path(sys.argv[1])
response_status = Path(sys.argv[2]) if len(sys.argv) > 2 else None


class LibraryRefresh(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/Library/Refresh' or self.headers.get('X-Emby-Token') != 'fixture-only-token':
            self.send_response(403)
        elif response_status and response_status.exists() and int(response_status.read_text()) != 204:
            self.send_response(int(response_status.read_text()))
        else:
            received.write_text(str(int(received.read_text()) + 1) if received.exists() else '1')
            self.send_response(204)
        self.end_headers()

    def log_message(self, *args):
        pass


HTTPServer(('0.0.0.0', 8097), LibraryRefresh).serve_forever()
