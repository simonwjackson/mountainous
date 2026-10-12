#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Real filesystem coverage for NZBFAST provisioning; all credentials are fixtures."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("provision", Path(__file__).with_name("media-nzbfast-provision.py"))
provision = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provision)


class ProvisionTests(unittest.TestCase):
    def test_saved_credentials_and_effective_fallbacks(self):
        config = provision.convert("# fixture only\nServer1.Username=fixture-user\nServer1.Password=fixture=password\n")
        self.assertEqual(config["servers"], [{"host": "news.newsdemon.com", "port": 563,
            "tls": True, "connections": 50, "username": "fixture-user", "password": "fixture=password", "enabled": True}])

    def test_explicit_server_values_and_invalid_boundaries(self):
        base = "Server1.Username=test\nServer1.Password=test\n"
        server = provision.convert(base + "Server1.Host=news.example.invalid\nServer1.Port=119\nServer1.Encryption=no\nServer1.Connections=3\n")["servers"][0]
        self.assertEqual((server["port"], server["tls"], server["connections"]), (119, False, 3))
        for invalid in ("Server1.Port=0", "Server1.Port=65536", "Server1.Connections=0", "Server1.Encryption=maybe", "Server1.Host=", "Server1.Port=oops"):
            with self.assertRaises(ValueError):
                provision.convert(base + invalid)
        with self.assertRaises(ValueError):
            provision.convert("Server1.Username=test")

    def test_atomic_private_write_and_overwrite_admission(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "config.json"
            config = provision.convert("Server1.Username=test\nServer1.Password=secret-fixture\n")
            provision.write_config(target, config, os.getuid(), os.getgid(), False)
            self.assertEqual(json.loads(target.read_text()), config)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertEqual(target.stat().st_uid, os.getuid())
            before = target.read_bytes()
            with self.assertRaises(FileExistsError):
                provision.write_config(target, {}, os.getuid(), os.getgid(), False)
            self.assertEqual(target.read_bytes(), before)
            provision.write_config(target, config, os.getuid(), os.getgid(), True)
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ["config.json"])


if __name__ == "__main__":
    unittest.main()
