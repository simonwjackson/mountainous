"""Forward Beszel alerts into the notify topic, one live item per alert.

Beszel's generic webhook (`generic://127.0.0.1:PORT/beszel?template=json&disabletls=yes`)
POSTs {"title": ..., "message": ...}. The title names what changed, for example
"Connection to tate is down" or "unzen CPU above threshold". Each title maps to
a key such as `status:tate`. A new message for a key clears that key's previous
item, so "is up" replaces "is down" and a repeated alert replaces itself.

A failed publish answers 502 and leaves the state unchanged. A failed clear is
kept and retried on the next request. Tokens reach the notify CLI through its
environment (NOTIFY_TOKEN_FILE), never argv.
"""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading

MAX_BODY = 64 * 1024
SEQUENCE = re.compile(r"[A-Za-z0-9._-]{1,64}")

# Title shapes from beszel 0.20.0, internal/alerts/*.go. Host names have no spaces.
PATTERNS = [
    (re.compile(r"^Connection to (?P<s>\S+) is \S+"), "status:{s}"),
    (re.compile(r"^(?P<s>\S+) (?P<a>.+) (?:above|below) threshold$"), "threshold:{s}:{a}"),
    (re.compile(r"^Failed services on (?P<s>\S+)"), "systemd:{s}"),
    (re.compile(r"^Services recovered on (?P<s>\S+)"), "systemd:{s}"),
    (re.compile(r"^Unhealthy container .+ on (?P<s>\S+)"), "containers:{s}"),
    (re.compile(r"^\d+ unhealthy containers on (?P<s>\S+)"), "containers:{s}"),
    (re.compile(r"^(?P<s>\S+) containers are healthy"), "containers:{s}"),
    (re.compile(r"^SMART \S+ on (?P<s>\S+): (?P<d>\S+)"), "smart:{s}:{d}"),
    (re.compile(r"^Storage pool \S+ on (?P<s>\S+): (?P<p>.+)$"), "pool:{s}:{p}"),
    (re.compile(r"^Network monitor \S+ on (?P<s>\S+): (?P<l>.+)$"), "network:{s}:{l}"),
]


def alert_key(title: str) -> str:
    for pattern, template in PATTERNS:
        match = pattern.match(title)
        if match:
            return template.format(**match.groupdict())
    return "title:" + title


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


class Notifier:
    def __init__(self, binary: str, timeout: int = 30):
        self.binary, self.timeout = binary, timeout

    def send(self, summary: str, body: str):
        try:
            result = subprocess.run(
                [self.binary, "send", "--name", "beszel", "--summary", summary, "--body", body],
                capture_output=True, text=True, timeout=self.timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            log(f"publish failed: {type(error).__name__}")
            return None
        seq = result.stdout.strip()
        if result.returncode != 0 or not SEQUENCE.fullmatch(seq):
            log(f"publish failed: exit {result.returncode}: {result.stderr.strip()[:200]}")
            return None
        return seq

    def clear(self, seq: str) -> bool:
        if not SEQUENCE.fullmatch(seq):
            return True
        try:
            result = subprocess.run(
                [self.binary, "clear", seq], capture_output=True, text=True, timeout=self.timeout
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            log(f"clear failed: {type(error).__name__}")
            return False
        if result.returncode != 0:
            log(f"clear failed: exit {result.returncode}: {result.stderr.strip()[:200]}")
        return result.returncode == 0


class Store:
    """{"live": {key: seq}, "stale": [seq, ...]} in one JSON file, replaced atomically."""

    def __init__(self, path: Path):
        self.path = path

    def load(self) -> dict:
        try:
            state = json.loads(self.path.read_text())
        except FileNotFoundError:
            return {"live": {}, "stale": []}
        except (OSError, ValueError) as error:
            log(f"state unreadable, starting empty: {type(error).__name__}")
            return {"live": {}, "stale": []}
        live = state.get("live") if isinstance(state, dict) else None
        stale = state.get("stale") if isinstance(state, dict) else None
        return {
            "live": {k: v for k, v in (live or {}).items() if isinstance(v, str)},
            "stale": [s for s in (stale or []) if isinstance(s, str)],
        }

    def save(self, state: dict) -> None:
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(state, sort_keys=True))
        os.replace(temporary, self.path)


def deliver(store: Store, notifier: Notifier, title: str, message: str) -> bool:
    state = store.load()
    state["stale"] = [seq for seq in state["stale"] if not notifier.clear(seq)]
    key = alert_key(title)
    seq = notifier.send(title, message)
    if seq is None:
        store.save(state)
        return False
    previous = state["live"].get(key)
    state["live"][key] = seq
    if previous and previous != seq and not notifier.clear(previous):
        state["stale"].append(previous)
    store.save(state)
    log(f"forwarded {key}")
    return True


def handler(store: Store, notifier: Notifier, path: str):
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def answer(self, code: int) -> None:
            self.send_response(code)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_POST(self):
            if self.path.split("?", 1)[0] != path:
                return self.answer(404)
            try:
                length = int(self.headers.get("Content-Length", ""))
            except ValueError:
                return self.answer(411)
            if length <= 0 or length > MAX_BODY:
                return self.answer(413)
            try:
                payload = json.loads(self.rfile.read(length))
            except ValueError:
                return self.answer(400)
            if not isinstance(payload, dict):
                return self.answer(400)
            title, message = payload.get("title"), payload.get("message")
            if not isinstance(title, str) or not title.strip() or not isinstance(message, str):
                return self.answer(400)
            with lock:
                ok = deliver(store, notifier, title.strip(), message.strip())
            return self.answer(204 if ok else 502)

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", default="127.0.0.1:8091")
    parser.add_argument("--path", default="/beszel")
    parser.add_argument("--state-dir", required=True, type=Path)
    parser.add_argument("--notify", required=True, help="notify CLI")
    args = parser.parse_args()
    host, port = args.listen.rsplit(":", 1)
    store = Store(args.state_dir / "alerts.json")
    server = ThreadingHTTPServer((host, int(port)), handler(store, Notifier(args.notify), args.path))
    log(f"listening on {host}:{port}{args.path}")
    server.serve_forever()


if __name__ == "__main__":
    main()
