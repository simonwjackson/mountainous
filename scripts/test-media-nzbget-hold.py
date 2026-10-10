#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise native startup holds against the pinned NZBGet binary on loopback."""
import base64
import importlib.util
from importlib.machinery import SourceFileLoader
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.request

SOURCE = Path(__file__).parents[1] / "modules/media-nzbget-launch.py"
spec = importlib.util.spec_from_file_location("media_nzbget_launch", SOURCE)
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)
inventory_path = Path(__file__).with_name("media-inventory-target")
inventory_spec = importlib.util.spec_from_loader("media_inventory", SourceFileLoader("media_inventory", str(inventory_path)))
inventory = importlib.util.module_from_spec(inventory_spec)
inventory_spec.loader.exec_module(inventory)
BINARY = sys.argv.pop(1) if len(sys.argv) > 1 else None


class NativeStartupHold(unittest.TestCase):
    def test_flags_disable_old_tasks_and_feeds_without_exposing_credentials(self):
        settings = {"Task4.Time": "*", "Task4.Command": "UnpauseDownload", "Feed1.URL": "private-url",
                    "ControlPassword": "fixture-private-credential"}
        original = dict(settings)
        flags = launch.hold_flags(settings)
        self.assertIn("Task4.Time=", flags)
        self.assertIn("Feed1.Interval=0", flags)
        self.assertIn("Task1.Command=PauseDownload", flags)
        self.assertIn("Task2.Command=PausePostProcess", flags)
        self.assertIn("Task3.Command=PauseScan", flags)
        self.assertNotIn("fixture-private-credential", " ".join(flags))
        self.assertNotIn("private-url", " ".join(flags))
        self.assertEqual(settings, original)

    def test_force_priority_inventory_uses_native_fields_and_rejects_unknowns(self):
        self.assertEqual(inventory.queue_safety([{"MaxPriority": 899}, {"MaxPriority": 900}]),
                         {"groups": 2, "force_priority_groups": 1})
        with self.assertRaises(KeyError):
            inventory.queue_safety([{"Priority": 0}])
        with self.assertRaises(ValueError):
            inventory.queue_safety([{"MaxPriority": None}])

    @unittest.skipUnless(BINARY, "pass the pinned binary to run its integration contract")
    def test_native_binary_starts_all_activities_paused_without_rewriting_config(self):
        with tempfile.TemporaryDirectory(prefix="media-nzbget-hold-") as temporary:
            root = Path(temporary)
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            directories = {key: root / key for key in ("DestDir", "InterDir", "NzbDir", "QueueDir", "TempDir", "ScriptDir")}
            for directory in directories.values():
                directory.mkdir()
            protected = directories["InterDir"] / "preserved.partial"
            protected.write_bytes(b"fixture-work-must-not-change")
            config = root / "nzbget.conf"
            template = Path(BINARY).resolve().parents[1] / "share/nzbget/nzbget.conf"
            settings = {"MainDir": str(root), "ControlIP": "127.0.0.1", "ControlPort": str(port),
                        "ControlUsername": "fixture-user", "ControlPassword": "fixture-password",
                        "RequiredDir": str(directories["DestDir"]), "OutputMode": "log", "Server1.Active": "yes",
                        "UnrarCmd": sys.executable, "SevenZipCmd": sys.executable,
                        "Server1.Host": "127.0.0.1", "Server1.Port": "119", "Server1.Connections": "1",
                        "Task4.Time": "*", "Task4.Command": "UnpauseDownload"}
            settings.update({key: str(value) for key, value in directories.items()})
            lines, seen = [], set()
            for line in template.read_text().splitlines():
                key = line.split("=", 1)[0].strip()
                if key in settings:
                    line = key + "=" + settings[key]
                    seen.add(key)
                lines.append(line)
            lines += [key + "=" + value for key, value in settings.items() if key not in seen]
            config.write_text("\n".join(lines) + "\n")
            config.chmod(0o600)
            original = config.read_bytes()
            (root / "nzbget.log").touch()
            log = (root / "private-log").open("wb")
            process = subprocess.Popen([BINARY, "--server", "--configfile", str(config)] + launch.hold_flags(settings),
                                       stdout=log, stderr=log)
            try:
                status = None
                for _ in range(100):
                    if process.poll() is not None:
                        text = (root / "private-log").read_text(errors="replace")
                        text = text.replace("fixture-password", "<REDACTED>").replace("fixture-user", "<REDACTED>")
                        self.fail("pinned NZBGet exited before readiness: " + text[-2000:])
                    try:
                        status = self.rpc(port, "status", [])
                        if all(status.get(field) is True for field in ("DownloadPaused", "PostPaused", "ScanPaused")):
                            break
                    except (OSError, ValueError):
                        pass
                    time.sleep(0.1)
                self.assertIsNotNone(status, "loopback RPC did not become ready")
                for field in ("DownloadPaused", "PostPaused", "ScanPaused"):
                    self.assertIs(status.get(field), True, field)
                # Seed a real, individually unpaused group. Global startup holds
                # must survive loading its persisted queue, not only an empty server.
                nzb = (b'<?xml version="1.0"?><nzb xmlns="http://www.newzbin.com/DTD/2003/nzb">'
                       b'<file poster="fixture" date="0" subject="fixture.bin (1/1)">'
                       b'<groups><group>fixture.group</group></groups><segments>'
                       b'<segment bytes="1048576" number="1">fixture-message-id</segment>'
                       b'</segments></file></nzb>')
                identifier = self.rpc(port, "append", ["fixture.nzb", base64.b64encode(nzb).decode(),
                                      "", 0, False, False, "", 0, "score"])
                self.assertGreater(identifier, 0)
                queued = self.rpc(port, "listgroups", [])
                self.assertEqual(len(queued), 1)
                self.assertEqual(queued[0]["NZBID"], identifier)
                self.assertEqual(inventory.queue_safety(queued), {"groups": 1, "force_priority_groups": 0})
                self.assertEqual(queued[0]["PausedSizeLo"], 0)
                process.terminate()
                process.wait(timeout=10)
                self.assertTrue(any(directories["QueueDir"].iterdir()), "queue was not saved")
                process = subprocess.Popen([BINARY, "--server", "--configfile", str(config)] + launch.hold_flags(settings),
                                           stdout=log, stderr=log)
                restarted = None
                for _ in range(100):
                    self.assertIsNone(process.poll(), "pinned NZBGet exited while loading saved state")
                    try:
                        restarted = self.rpc(port, "status", [])
                        if all(restarted.get(field) is True for field in ("DownloadPaused", "PostPaused", "ScanPaused")):
                            break
                    except (OSError, ValueError):
                        pass
                    time.sleep(0.1)
                self.assertIsNotNone(restarted)
                for field in ("DownloadPaused", "PostPaused", "ScanPaused"):
                    self.assertIs(restarted.get(field), True, field)
                self.assertEqual(restarted["PostJobCount"], 0)
                self.assertEqual(restarted["DownloadedSizeLo"], 0)
                restored = self.rpc(port, "listgroups", [])
                self.assertEqual(len(restored), 1)
                for field in ("NZBID", "NZBName", "FileSizeLo", "RemainingSizeLo", "PausedSizeLo", "MinPriority", "MaxPriority"):
                    self.assertEqual(restored[0][field], queued[0][field], field)
                self.assertEqual(restored[0]["ActiveDownloads"], 0)
                entries = self.rpc(port, "log", [0, 1000])
                self.assertFalse(any(entry.get("Kind") == "ERROR" for entry in entries),
                                 "native hold must not rely on configuration errors: " + " | ".join(
                                     entry.get("Text", "").replace("fixture-password", "<REDACTED>")
                                     for entry in entries if entry.get("Kind") == "ERROR"))
                self.assertEqual(config.read_bytes(), original)
                self.assertEqual(protected.read_bytes(), b"fixture-work-must-not-change")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                log.close()

    def rpc(self, port, method, params):
        request = urllib.request.Request("http://127.0.0.1:" + str(port) + "/jsonrpc",
            data=json.dumps({"id": 1, "method": method, "params": params}).encode(),
            headers={"Content-Type": "application/json", "Authorization": "Basic " +
                     base64.b64encode(b"fixture-user:fixture-password").decode()})
        with urllib.request.urlopen(request, timeout=1) as response:
            reply = json.load(response)
            if "error" in reply:
                raise RuntimeError("fixture RPC rejected " + method + ": " + str(reply["error"]))
            return reply["result"]


if __name__ == "__main__":
    unittest.main()
