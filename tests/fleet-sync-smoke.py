#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 syncthing nodejs
"""Two real Syncthing peers, including a phone-side export. No fleet changes."""

import argparse
import http.client
import json
import socket
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path


class UnixHTTP(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=2)
        self.path = str(path)

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.path)


def wait(check, label):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        try:
            if check():
                return
        except (OSError, ValueError, http.client.HTTPException):
            pass
        time.sleep(0.1)
    raise AssertionError("Timed out: " + label)


def api(peer, method, path, value=None):
    conn = UnixHTTP(peer["socket"])
    try:
        conn.request(
            method,
            "/rest/" + path,
            None if value is None else json.dumps(value),
            {"X-API-Key": peer["key"], "Content-Type": "application/json"},
        )
        response = conn.getresponse()
        data = response.read()
        assert response.status < 300, (response.status, data)
        return json.loads(data) if data else None
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agent", required=True)
    parser.add_argument("--syncthing", default="syncthing")
    parser.add_argument("--runtime", default="node")
    parser.add_argument(
        "--settings", required=True, help="JSON from Tate services.syncthing.settings"
    )
    parser.add_argument(
        "--external-settings",
        required=True,
        help="JSON settings from tests/fleet-sync-external.nix",
    )
    args = parser.parse_args()
    settings = json.loads(Path(args.settings).read_text())
    external = json.loads(Path(args.external_settings).read_text())
    phone = external["devices"]["phone"]
    assert phone["addresses"] == ["tcp://phone.hummingbird-lake.ts.net:22000"]
    assert not phone["introducer"] and not phone["autoAcceptFolders"]
    assert external["options"] == settings["options"]
    processes, logs = [], []
    with tempfile.TemporaryDirectory(prefix="fleet-sync-smoke-") as tmp:
        root = Path(tmp)
        peers = []
        try:
            for name in ("a", "b"):
                base = root / name
                base.mkdir()
                bootstrap_settings = base / "bootstrap.json"
                bootstrap_settings.write_text(json.dumps(settings))
                subprocess.run(
                    [
                        sys.executable,
                        str(
                            Path(__file__).parents[1]
                            / "modules/fleet-sync-bootstrap.py"
                        ),
                        args.syncthing,
                        str(base),
                        str(bootstrap_settings),
                    ],
                    check=True,
                )
                tree = ET.parse(base / "config.xml")
                for folder in list(tree.getroot().findall("folder")):
                    tree.getroot().remove(folder)
                tree.write(base / "config.xml")
                peer = {
                    "base": base,
                    "socket": base / "gui.sock",
                    "key": tree.getroot().findtext("gui/apikey"),
                    "id": subprocess.check_output(
                        [args.syncthing, "device-id", "--home", str(base)], text=True
                    ).strip(),
                }
                with socket.socket() as listener:
                    listener.bind(("127.0.0.1", 0))
                    peer["port"] = listener.getsockname()[1]
                bootstrap_settings = base / "bootstrap.json"
                bootstrap_settings.write_text(
                    json.dumps(
                        {
                            "options": settings["options"]
                            | {"listenAddresses": [f"tcp://127.0.0.1:{peer['port']}"]}
                        }
                    )
                )
                subprocess.run(
                    [
                        sys.executable,
                        str(
                            Path(__file__).parents[1]
                            / "modules/fleet-sync-bootstrap.py"
                        ),
                        args.syncthing,
                        str(base),
                        str(bootstrap_settings),
                    ],
                    check=True,
                )
                folder = base / "pi"
                folder.mkdir()
                agent_dir = base / "agent"
                agent_dir.mkdir()
                (agent_dir / "settings.json").symlink_to(folder / "settings.json")
                peer["folder"], peer["agent"] = folder, agent_dir
                peer["export"] = base / "gadgetbridge"
                peer["export"].mkdir()
                peers.append(peer)
                log = (base / "log").open("w")
                logs.append(log)
                processes.append(
                    subprocess.Popen(
                        [
                            args.syncthing,
                            "serve",
                            "--home",
                            str(base),
                            "--no-browser",
                            "--no-upgrade",
                            "--no-restart",
                            "--gui-address",
                            "unix://" + str(peer["socket"]),
                        ],
                        stdout=log,
                        stderr=subprocess.STDOUT,
                    )
                )
                wait(
                    lambda peer=peer: api(peer, "GET", "system/ping"), "Unix GUI socket"
                )
            for i, peer in enumerate(peers):
                other = peers[1 - i]
                options = settings["options"] | {
                    "listenAddresses": [f"tcp://127.0.0.1:{peer['port']}"]
                }
                api(peer, "PATCH", "config/options", options)
                api(
                    peer,
                    "PUT",
                    "config/devices",
                    [
                        {
                            "deviceID": other["id"],
                            "name": "phone" if i == 0 else "rakku",
                            "addresses": [f"tcp://127.0.0.1:{other['port']}"],
                            "introducer": False,
                            "autoAcceptFolders": False,
                        }
                    ],
                )
                folder = settings["folders"]["pi"].copy()
                patterns = folder.pop("ignorePatterns")
                for nix_field in ("enable", "label"):
                    folder.pop(nix_field, None)
                folder.update(
                    path=str(peer["folder"]), devices=[{"deviceID": other["id"]}]
                )
                export = external["folders"]["gadgetbridge"].copy()
                export_patterns = export.pop("ignorePatterns")
                for nix_field in ("enable", "label"):
                    export.pop(nix_field, None)
                export.update(
                    path=str(peer["export"]), devices=[{"deviceID": other["id"]}]
                )
                api(peer, "PUT", "config/folders", [folder, export])
                api(
                    peer,
                    "POST",
                    "db/ignores?folder=gadgetbridge",
                    {"ignore": export_patterns},
                )
                api(peer, "POST", "db/ignores?folder=pi", {"ignore": patterns})
            a, b = peers

            def write(peer, model):
                subprocess.run(
                    [
                        args.runtime,
                        str(Path(__file__).parent / "pi/settings-write.mjs"),
                        args.agent,
                        str(peer["agent"]),
                        model,
                    ],
                    check=True,
                )
                assert (peer["agent"] / "settings.json").is_symlink()

            def arrived(peer, model):
                data = json.loads((peer["folder"] / "settings.json").read_text())
                return (
                    data["defaultProvider"] == "cliproxyapi"
                    and data["defaultModel"] == model
                    and data["enabledModels"] == ["cliproxyapi/" + model, "decide/*"]
                )

            write(a, "sync-forward")
            (a["folder"] / "auth.json").write_text('{"not":"shared"}')
            wait(lambda: arrived(b, "sync-forward"), "A to B settings sync")
            write(b, "sync-back")
            wait(lambda: arrived(a, "sync-back"), "B to A settings sync")
            assert not (b["folder"] / "auth.json").exists()
            # B models the external phone: only its export may reach Rakku/A.
            # Atomic replacement is how export tools publish a fresh snapshot.
            payload = b"synthetic Gadgetbridge export version 1"
            (b["export"] / "Gadgetbridge.db").write_bytes(payload)
            (b["export"] / "private.db").write_bytes(b"must stay on phone")
            wait(
                lambda: (a["export"] / "Gadgetbridge.db").read_bytes() == payload,
                "phone export to Rakku",
            )
            payload = b"synthetic Gadgetbridge export version 2"
            temporary = b["export"] / "export.tmp"
            temporary.write_bytes(payload)
            temporary.replace(b["export"] / "Gadgetbridge.db")
            wait(
                lambda: (a["export"] / "Gadgetbridge.db").read_bytes() == payload,
                "replaced phone export to Rakku",
            )
            assert not (a["export"] / "private.db").exists()
            assert not (a["export"] / "export.tmp").exists()
            assert not list(root.rglob("*.sync-conflict-*"))
            for peer in peers:
                log = (peer["base"] / "log").read_text()
                assert "Using discovery mechanism" not in log
                assert "Relay listener starting" not in log
                assert "QUIC listener starting" not in log
            print(
                "PASS: pi writes through symlink; defaults and scope sync both ways; auth.json stays local; phone export syncs, other files stay local"
            )
        finally:
            for process in processes:
                process.terminate()
            for process in processes:
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            for log in logs:
                log.close()


if __name__ == "__main__":
    main()
