#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Readiness must describe the actual local listener, not a stale GitHub row."""
import importlib.util
import os
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
