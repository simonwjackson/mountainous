#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Admission and idempotent service policy with private temporary state."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys


def load(name):
    path = Path(__file__).parent.parent / "modules" / (name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


settings = load("media-nzbfast-settings")
ready = load("media-state-ready")


class SettingsTests(unittest.TestCase):
    def test_fresh_held_settings_are_private_keyed_and_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            settings.prepare(directory, True)
            first = path.read_bytes()
            data = json.loads(first)
            self.assertTrue(data["paused"] and data["offline"])
            self.assertEqual(len(data["apikey"]), 64)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(data["cat_meta"], {"Series": {"dir": "Series"}, "Movies": {"dir": "Movies"}})
            for key in ("auto_rename", "spot_enabled", "index_enabled", "identity_lookup", "update_checks", "delete_to_trash"):
                self.assertIs(data[key], False)
            self.assertEqual(data["out_umask"], "002")
            settings.prepare(directory, True)
            self.assertEqual(first, path.read_bytes())
            settings.prepare(directory, False)
            enabled = json.loads(path.read_text())
            self.assertNotIn("paused", enabled)
            self.assertNotIn("offline", enabled)
            self.assertEqual(enabled["apikey"], data["apikey"])

    def test_schedules_and_timed_pauses_refuse_held_start_without_writes(self):
        resume = [{"days": "all", "time": "00:00", "action": "resume"}]
        policies = [{"schedule": resume}, {"schedule": json.dumps(resume)},
                    {"schedule": "malformed"}, {"schedule": False},
                    {"pause_until_unix": 1}, {"pause_until_unix": 4102444800}]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            for policy in policies:
                before = json.dumps({"apikey": "fixture-key", "port": 1234, **policy})
                path.write_text(before)
                result = subprocess.run([sys.executable, settings.__file__, directory, "held"], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, policy)
                self.assertEqual(path.read_text(), before)
                self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ["settings.json"])
            settings.prepare(directory, False)
            data = json.loads(path.read_text())
            self.assertNotIn("pause_until_unix", data)
            self.assertEqual(data["port"], 1234)

    def test_empty_schedules_are_preserved_while_held_and_enabled_keeps_schedule(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            for empty in (None, "", [], "[]", "  []  "):
                path.write_text(json.dumps({"apikey": "fixture-key", "schedule": empty}))
                settings.prepare(directory, True)
                data = json.loads(path.read_text())
                self.assertEqual(data["schedule"], empty)
                self.assertTrue(data["paused"] and data["offline"])
            schedule = json.dumps([{"days": "all", "time": "00:00", "action": "resume"}])
            path.write_text(json.dumps({"apikey": "fixture-key", "schedule": schedule}))
            settings.prepare(directory, False)
            self.assertEqual(json.loads(path.read_text())["schedule"], schedule)

    def test_invalid_or_established_keyless_state_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            for invalid in ("[]", '{"apikey": 42}'):
                path.write_text(invalid)
                with self.assertRaises(ValueError):
                    settings.prepare(directory, True)
            path.write_text("{}")
            (Path(directory) / ".spool").mkdir()
            with self.assertRaises(ValueError):
                settings.prepare(directory, True)
            self.assertEqual(path.read_text(), "{}")

    def test_enabled_nonempty_server_is_required(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            for invalid in ({}, {"servers": []}, {"servers": [{"host": " "}]}, {"servers": [{"host": "fixture.invalid", "enabled": False}]}):
                path.write_text(json.dumps(invalid))
                with self.assertRaises(ValueError):
                    ready.validate_nzbfast(path)
            path.write_text(json.dumps({"servers": [{"host": "fixture.invalid", "enabled": True}]}))
            ready.validate_nzbfast(path)


if __name__ == "__main__":
    unittest.main()
