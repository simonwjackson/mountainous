#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Readiness must describe the actual local listener, not a stale GitHub row."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

source = Path(os.environ.get("GITHUB_ACTIONS_READY_SOURCE", Path(__file__).resolve().parents[1] / "modules/github-actions-ready.py"))
spec = importlib.util.spec_from_file_location("ready", source)
ready = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ready)


class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.service = {"ActiveState": "active", "MainPID": "123"}
        self.registration = {"agentName": "unzen-forgerie", "agentId": 14}
        self.remote = {"total_count": 1, "runners": [{"id": 14, "name": "unzen-forgerie", "status": "online", "busy": False}]}

    def test_actual_registration_file_with_or_without_utf8_bom(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command = root / "listener-properties.py"
            command.write_text('#!/usr/bin/env nix-shell\n#! nix-shell -i python3 -p python3\nprint("ActiveState=active\\nMainPID=123\\nNRestarts=0")\n')
            registration = root / ".runner"
            content = b'{"agentName":"unzen-forgerie","agentId":14}'
            for prefix in [b"", b"\xef\xbb\xbf"]:
                with self.subTest(prefix=prefix):
                    registration.write_bytes(prefix + content)
                    service, value = ready.listener_state(registration, (sys.executable, str(command)))
                    self.assertEqual(service["MainPID"], "123")
                    self.assertEqual(ready.validate_registration(service, value, self.remote)["id"], 14)

    def invoke_cli(self, active):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            properties = root / "listener-properties.py"
            state = "active" if active else "inactive"
            properties.write_text(f'#!/usr/bin/env nix-shell\n#! nix-shell -i python3 -p python3\nprint("ActiveState={state}\\nMainPID=123\\nNRestarts=1")\n')
            registration = root / ".runner"
            registration.write_bytes(b'\xef\xbb\xbf{"agentName":"unzen-forgerie","agentId":14}')
            policy = root / "policy.py"
            policy.write_text('import json\nORG = "forgerie"\ndef installation_token(*args): return "fixture-access"\ndef verify_group(access): return {"id": 3}\ndef request_json(*args): return json.loads(' + repr(json.dumps(self.remote)) + ')\n')
            harness = root / "ready-cli.py"
            harness.write_text(
                '#!/usr/bin/env nix-shell\n#! nix-shell -i python3 -p python3\n'
                'import functools, importlib.util, sys\nfrom pathlib import Path\n'
                f'spec = importlib.util.spec_from_file_location("ready", {str(source)!r})\n'
                'ready = importlib.util.module_from_spec(spec)\nspec.loader.exec_module(ready)\n'
                f'ready.listener_state = functools.partial(ready.listener_state, Path({str(registration)!r}), (sys.executable, {str(properties)!r}))\n'
                'sys.exit(ready.main())\n'
            )
            return subprocess.run([sys.executable, str(harness), "--policy-script", str(policy), "--app-id", "1", "--private-key", "unused", "--timeout", "1"], capture_output=True, text=True, timeout=10)

    def test_cli_accepts_actual_bom_registration(self):
        result = self.invoke_cli(True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["runner_id"], 14)

    def test_cli_deadline_preserves_last_readiness_failure(self):
        result = self.invoke_cli(False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("no active listener", json.loads(result.stderr)["reason"])

    def test_online_exact_registration_is_ready(self):
        self.assertEqual(ready.validate_registration(self.service, self.registration, self.remote)["id"], 14)

    def test_busy_listener_is_ready(self):
        self.remote["runners"][0]["busy"] = True
        self.assertTrue(ready.validate_registration(self.service, self.registration, self.remote)["busy"])

    def test_stopped_listener_is_not_ready_despite_online_row(self):
        self.service.update(ActiveState="inactive", MainPID="0")
        with self.assertRaisesRegex(ValueError, "no active listener"):
            ready.validate_registration(self.service, self.registration, self.remote)

    def test_startup_retry_is_not_readiness(self):
        self.service.update(ActiveState="activating", MainPID="0")
        with self.assertRaises(ValueError):
            ready.validate_registration(self.service, self.registration, self.remote)

    def test_old_online_registration_is_not_current_listener(self):
        self.remote["runners"][0]["id"] = 13
        with self.assertRaisesRegex(ValueError, "does not match"):
            ready.validate_registration(self.service, self.registration, self.remote)

    def test_offline_registration_is_not_ready(self):
        self.remote["runners"][0]["status"] = "offline"
        with self.assertRaisesRegex(ValueError, "not online"):
            ready.validate_registration(self.service, self.registration, self.remote)

    def test_group_cannot_have_extra_or_missing_runners(self):
        for remote in [{"total_count": 0, "runners": []}, {"total_count": 2, "runners": self.remote["runners"] * 2}]:
            with self.subTest(remote=remote), self.assertRaises(ValueError):
                ready.validate_registration(self.service, self.registration, remote)

    def test_local_name_and_identity_are_required(self):
        for registration in [{}, {"agentName": "other", "agentId": 14}, {"agentName": "unzen-forgerie", "agentId": 0}]:
            with self.subTest(registration=registration), self.assertRaises(ValueError):
                ready.validate_registration(self.service, registration, self.remote)


if __name__ == "__main__":
    unittest.main()
