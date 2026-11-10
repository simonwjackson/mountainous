"""Start the shipped daemon with the production merge; require Basic auth."""

import base64
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

script, daemon = sys.argv[1:]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    config = root / "config"
    config.mkdir()
    (root / "transmission-rpc-password").write_text("fixture-password\n")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    settings = config / "settings.json"
    settings.write_text(
        json.dumps(
            {
                "rpc-enabled": True,
                "rpc-bind-address": "127.0.0.1",
                "rpc-port": port,
                "rpc-whitelist-enabled": False,
                "rpc-host-whitelist-enabled": False,
                "rpc-authentication-required": False,
                "rpc-url": "/transmission/",
                "download-dir": directory,
                "ratio-limit": 3.5,
                "dht-enabled": False,
                "pex-enabled": False,
                "lpd-enabled": False,
                "port-forwarding-enabled": False,
                "peer-bind-address-ipv4": "127.0.0.1",
                "peer-bind-address-ipv6": "::1",
                "peer-port": 0,
            }
        )
    )
    # Repeat after Transmission has hashed the password and saved snake_case.
    for password in ("fixture-password", "rotated-password"):
        (root / "transmission-rpc-password").write_text(password + "\n")
        subprocess.run(
            [sys.executable, script, str(settings)],
            check=True,
            env=dict(os.environ, CREDENTIALS_DIRECTORY=directory),
        )
        with (root / "daemon.log").open("w+") as log:
            process = subprocess.Popen(
                [
                    daemon,
                    "--foreground",
                    "--config-dir",
                    str(config),
                    "--paused",
                    "--no-watch-dir",
                ],
                stdout=log,
                stderr=log,
            )
            try:
                url = f"http://127.0.0.1:{port}/transmission/rpc"
                deadline = time.monotonic() + 20
                while True:
                    try:
                        urllib.request.urlopen(url, timeout=1)
                        raise AssertionError("unauthenticated RPC was admitted")
                    except urllib.error.HTTPError as error:
                        assert error.code == 401, error.code
                        break
                    except urllib.error.URLError:
                        if process.poll() is not None or time.monotonic() > deadline:
                            log.seek(0)
                            raise AssertionError(log.read())
                        time.sleep(0.1)
                headers = {
                    "Content-Type": "application/json",
                    "Authorization": "Basic "
                    + base64.b64encode(f"torrents:{password}".encode()).decode(),
                }
                body = json.dumps(
                    {"jsonrpc": "2.0", "id": 1, "method": "session_get", "params": {}}
                ).encode()
                try:
                    urllib.request.urlopen(
                        urllib.request.Request(url, data=body, headers=headers),
                        timeout=3,
                    )
                    raise AssertionError("expected session challenge")
                except urllib.error.HTTPError as error:
                    assert error.code == 409, error.code
                    headers["X-Transmission-Session-Id"] = error.headers[
                        "X-Transmission-Session-Id"
                    ]
                with urllib.request.urlopen(
                    urllib.request.Request(url, data=body, headers=headers), timeout=3
                ) as response:
                    result = json.load(response)
                assert result["result"]["version"].startswith("4.1.4"), result
                assert result["result"]["rpc_version_semver"].startswith("6."), result
                assert result["result"]["download_dir"] == directory, result
                assert result["result"]["seed_ratio_limit"] == 3.5, result
            finally:
                process.terminate()
                process.wait(timeout=15)
                assert process.returncode == 0
print(
    "Transmission 4.1.4: Basic auth, 409 retry, JSON-RPC 6.x, state preservation and password rotation passed"
)
