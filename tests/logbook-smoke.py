#!/usr/bin/env python3
"""Exercise the built server and CLI with an empty, temporary data directory."""

import json
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

app = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="logbook-smoke-") as directory:
    root = Path(directory)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    url = f"http://127.0.0.1:{port}"
    process = subprocess.Popen(
        [
            str(app / "bin/logbook-server"),
            "--port",
            str(port),
            "--data-dir",
            str(root / "data"),
            "--state-dir",
            str(root / "state"),
            "--inbox-dir",
            str(root / "inbox"),
            "--gadgetbridge-export",
            str(root / "inbox/gadgetbridge/Gadgetbridge.db"),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    try:
        for _ in range(100):
            if process.poll() is not None:
                raise AssertionError("server exited: " + process.stderr.read().decode())
            try:
                with urllib.request.urlopen(url + "/healthz", timeout=1) as response:
                    assert json.load(response) == {"status": "ok"}
                break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError("server did not become healthy")
        request = urllib.request.Request(
            url + "/rpc",
            json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "metrics.list",
                    "params": {},
                }
            ).encode(),
            {"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            assert json.load(response)["result"]
        result = subprocess.check_output(
            [str(app / "bin/logbook"), "--url", url, "status"]
        )
        assert isinstance(json.loads(result), list)
        assert (app / "bin/logbook-tsnet").is_file()
        print(
            "PASS: built loopback server health, metrics RPC, and CLI status; no tailnet join"
        )
    finally:
        process.send_signal(signal.SIGINT)
        try:
            assert process.wait(timeout=5) == 0
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stderr.close()
