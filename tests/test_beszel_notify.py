"""modules/beszel-notify.py over real HTTP, with a recording notify CLI.

Run: python3 tests/test_beszel_notify.py path/to/beszel-notify.py
"""

import http.client
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = None


def load_module():
    spec = importlib.util.spec_from_file_location("beszel_notify", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Keys(unittest.TestCase):
    """Every title shape in beszel 0.20.0 maps to a key shared by alert and recovery."""

    def test_pairs(self):
        key = load_module().alert_key
        pairs = [
            ("Connection to tate is down 🔴", "Connection to tate is up ✅", "status:tate"),
            ("unzen CPU above threshold", "unzen CPU below threshold", "threshold:unzen:CPU"),
            ("unzen Disk usage of towada above threshold", "unzen Disk usage of towada below threshold",
             "threshold:unzen:Disk usage of towada"),
            ("Failed services on ibuki 🔴", "Services recovered on ibuki ✅", "systemd:ibuki"),
            ("Unhealthy container web on yari 🔴", "yari containers are healthy ✅", "containers:yari"),
            ("3 unhealthy containers on yari 🔴", "yari containers are healthy ✅", "containers:yari"),
            ("SMART Failed on unzen: sda 🔴", "SMART Passed on unzen: sda ✅", "smart:unzen:sda"),
            ("Storage pool DEGRADED on unzen: towada", "Storage pool ONLINE on unzen: towada", "pool:unzen:towada"),
            ("Network monitor down on fuji: gateway", "Network monitor up on fuji: gateway", "network:fuji:gateway"),
        ]
        for alert, recovery, expected in pairs:
            self.assertEqual(key(alert), expected, alert)
            self.assertEqual(key(recovery), expected, recovery)

    def test_unknown_title_is_its_own_key(self):
        self.assertEqual(load_module().alert_key("Test"), "title:Test")


class Bridge(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.calls = root / "calls.jsonl"
        self.fail_send = root / "fail-send"
        self.fail_clear = root / "fail-clear"
        self.state = root / "state"
        self.state.mkdir()
        notify = root / "notify"
        notify.write_text(
            f"#!{shutil.which('bash')}\n"
            f'printf \'%s\\n\' "$(printf \'%s\\0\' "$@" | {shutil.which("python3")} -c '
            f'"import sys,json; print(json.dumps(sys.stdin.read().split(chr(0))[:-1]))")" >> {self.calls}\n'
            f'case "$1" in\n'
            f'  send) [ -e {self.fail_send} ] && exit 1; echo "beszel-$(wc -l < {self.calls} | tr -d \' \')";;\n'
            f'  clear) [ -e {self.fail_clear} ] && exit 1; exit 0;;\n'
            f"esac\n"
        )
        notify.chmod(0o755)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            self.port = probe.getsockname()[1]
        self.server = subprocess.Popen(
            [sys.executable, SCRIPT, "--listen", f"127.0.0.1:{self.port}",
             "--state-dir", str(self.state), "--notify", str(notify)],
            stderr=subprocess.PIPE, text=True,
        )
        for _ in range(100):
            try:
                socket.create_connection(("127.0.0.1", self.port), timeout=0.1).close()
                break
            except OSError:
                time.sleep(0.05)

    def tearDown(self):
        self.server.terminate()
        self.server.wait(5)
        self.server.stderr.close()
        self.tmp.cleanup()

    def post(self, body, path="/beszel?template=json"):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        connection.request("POST", path, data, {"Content-Type": "application/json"})
        status = connection.getresponse().status
        connection.close()
        return status

    def log(self):
        if not self.calls.exists():
            return []
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def live(self):
        return json.loads((self.state / "alerts.json").read_text())

    def test_recovery_replaces_alert(self):
        self.assertEqual(self.post({"title": "Connection to tate is down 🔴", "message": "m1"}), 204)
        self.assertEqual(self.post({"title": "Connection to tate is up ✅", "message": "m2"}), 204)
        calls = self.log()
        self.assertEqual(calls[0][:6], ["send", "--name", "beszel", "--summary", "Connection to tate is down 🔴", "--body"])
        self.assertEqual(calls[1][0], "send")
        self.assertEqual(calls[2], ["clear", "beszel-1"])
        self.assertEqual(self.live(), {"live": {"status:tate": "beszel-2"}, "stale": []})

    def test_different_keys_stay_live(self):
        self.post({"title": "Connection to tate is down", "message": ""})
        self.post({"title": "unzen CPU above threshold", "message": ""})
        self.assertEqual(sorted(self.live()["live"]), ["status:tate", "threshold:unzen:CPU"])
        self.assertFalse(any(c[0] == "clear" for c in self.log()))

    def test_failed_publish_is_502_and_keeps_state(self):
        self.post({"title": "Connection to tate is down", "message": ""})
        self.fail_send.touch()
        self.assertEqual(self.post({"title": "Connection to tate is up", "message": ""}), 502)
        self.assertEqual(self.live()["live"], {"status:tate": "beszel-1"})

    def test_failed_clear_is_retried(self):
        self.post({"title": "Connection to tate is down", "message": ""})
        self.fail_clear.touch()
        self.post({"title": "Connection to tate is up", "message": ""})
        self.assertEqual(self.live()["stale"], ["beszel-1"])
        self.fail_clear.unlink()
        self.post({"title": "unzen CPU above threshold", "message": ""})
        self.assertEqual(self.live()["stale"], [])
        self.assertEqual([c for c in self.log() if c[0] == "clear"][-1], ["clear", "beszel-1"])

    def test_rejects_bad_requests(self):
        self.assertEqual(self.post({"title": "x", "message": ""}, path="/other"), 404)
        self.assertEqual(self.post(b"not json"), 400)
        self.assertEqual(self.post({"message": "no title"}), 400)
        self.assertEqual(self.post(b"x" * (64 * 1024 + 1)), 413)
        self.assertEqual(self.log(), [])


if __name__ == "__main__":
    SCRIPT = sys.argv.pop(1)
    unittest.main()
