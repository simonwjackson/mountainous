#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise real archive restoration and connection-baseline comparison."""

import copy
from contextlib import closing
import hashlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import sqlite3
import sys
import tarfile
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / "scripts" / name))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


verify = load("rakku-verify-backup")
inventory = load("rakku-inventory")
switch = load("rakku-switch-target")


class ArchiveRestoreTests(unittest.TestCase):
    def archive(self, *, corrupt=False, omit=None, traversal=False, unsupported=False):
        output = io.BytesIO()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "permafrost/var/lib/hass"
            (home / ".storage").mkdir(parents=True)
            for name in ("home-assistant_v2.db", "zigbee.db"):
                with closing(sqlite3.connect(home / name)) as db, db:
                    db.execute("CREATE TABLE preserved (value TEXT)")
                    db.execute("INSERT INTO preserved VALUES ('paired-device')")
            for name in (
                "core.uuid",
                "core.config_entries",
                "core.device_registry",
                "core.entity_registry",
                "auth",
            ):
                (home / ".storage" / name).write_text(
                    json.dumps({"data": {"preserved": True}})
                )
            (root / "extra/secrets").mkdir(parents=True)
            (root / "extra/secrets/zwave-js-secrets").write_text('{"securityKeys": {}}')
            nvm = root / "extra/zwave-controller.nvm"
            nvm.write_bytes(b"controller-backup-fixture" * 128)
            files = {}
            for path in sorted(root.rglob("*")):
                if path.is_file():
                    metadata = path.stat()
                    files[str(path.relative_to(root))] = {
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                        "size": metadata.st_size,
                        "uid": metadata.st_uid,
                        "gid": metadata.st_gid,
                        "mode": metadata.st_mode & 0o7777,
                    }
            manifest = {
                "id": "test-backup",
                "system": "/nix/store/old-system",
                "files": files,
                "zwave_nvm": {"sha256": hashlib.sha256(nvm.read_bytes()).hexdigest()},
            }
            if unsupported:
                del manifest["files"]["extra/zwave-controller.nvm"]
                nvm.unlink()
                manifest["zwave_nvm"] = {
                    "status": "unsupported",
                    "reason": "ZW0209: Unknown NVM size - cannot backup",
                }
            (root / "manifest.json").write_text(json.dumps(manifest))
            if corrupt:
                (home / ".storage/core.uuid").write_text("{}")
            with tarfile.open(fileobj=output, mode="w:gz") as archive:
                for path in sorted(root.rglob("*")):
                    relative = str(path.relative_to(root))
                    if path.is_file() and relative != omit:
                        archive.add(path, arcname=relative)
                if traversal:
                    info = tarfile.TarInfo("../escape")
                    info.size = 1
                    archive.addfile(info, io.BytesIO(b"x"))
        output.seek(0)
        return output

    def test_restores_every_file_and_checks_both_databases(self):
        with tempfile.TemporaryDirectory() as directory:
            result = verify.verify_stream(self.archive(), Path(directory))
            self.assertEqual(result["files_verified"], 9)
            self.assertEqual(result["databases"], "integrity_check OK")
            db_path = Path(directory) / "permafrost/var/lib/hass/zigbee.db"
            with closing(sqlite3.connect(db_path)) as db:
                self.assertEqual(
                    db.execute("SELECT value FROM preserved").fetchone()[0],
                    "paired-device",
                )

    def test_records_only_the_known_unsupported_nvm_case(self):
        with tempfile.TemporaryDirectory() as directory:
            result = verify.verify_stream(
                self.archive(unsupported=True), Path(directory)
            )
            self.assertEqual(result["controller_backup_status"], "unsupported ZW0209")
            self.assertEqual(result["files_verified"], 8)

    def test_refuses_changed_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "differ"):
                verify.verify_stream(self.archive(corrupt=True), Path(directory))

    def test_refuses_missing_security_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "differ"):
                verify.verify_stream(
                    self.archive(omit="extra/secrets/zwave-js-secrets"), Path(directory)
                )

    def test_rejects_archive_path_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "Unsafe archive path"):
                verify.verify_stream(self.archive(traversal=True), Path(directory))


class BootSelectionTests(unittest.TestCase):
    def test_selects_only_the_exact_system_init(self):
        with tempfile.TemporaryDirectory() as directory:
            entries = Path(directory)
            (entries / "nixos-generation-40.conf").write_text(
                "options init=/nix/store/old/init loglevel=4\n"
            )
            (entries / "nixos-generation-41.conf").write_text(
                "options init=/nix/store/new/init loglevel=4\n"
            )
            self.assertEqual(
                switch.boot_entry("/nix/store/old", entries), "nixos-generation-40.conf"
            )
            self.assertEqual(
                switch.boot_entry("/nix/store/new", entries), "nixos-generation-41.conf"
            )
            with self.assertRaisesRegex(RuntimeError, "No boot entry"):
                switch.boot_entry("/nix/store/ne", entries)


class IdentityStagingTests(unittest.TestCase):
    def test_replaces_equal_staged_file_with_idempotent_persistent_link(self):
        with tempfile.TemporaryDirectory() as directory:
            live, persistent = Path(directory) / "live", Path(directory) / "persistent"
            live.write_text("test-key-material")
            persistent.write_text("test-key-material")
            persistent.chmod(0o600)
            switch.link_identity(live, persistent)
            switch.link_identity(live, persistent)
            self.assertTrue(live.is_symlink())
            self.assertEqual(live.resolve(), persistent)
            self.assertEqual(live.stat().st_mode & 0o777, 0o600)

    def test_refuses_to_replace_another_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            live, persistent = Path(directory) / "live", Path(directory) / "persistent"
            live.write_text("existing-identity")
            persistent.write_text("different-identity")
            with self.assertRaisesRegex(RuntimeError, "different SSH identity"):
                switch.link_identity(live, persistent)
            self.assertEqual(live.read_text(), "existing-identity")


class RollbackRestoreTests(unittest.TestCase):
    def test_restores_original_files_and_keeps_failed_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, live, failed = root / "original", root / "live", root / "failed"
            source.mkdir()
            live.mkdir()
            (source / "registration").write_text("original-pairing")
            (source / "registration").chmod(0o600)
            (live / "registration").write_text("changed-pairing")
            (live / "extra").write_text("failed-state")
            switch.restore_directory(source, live, failed)
            self.assertEqual((live / "registration").read_text(), "original-pairing")
            self.assertEqual((live / "registration").stat().st_mode & 0o777, 0o600)
            self.assertFalse((live / "extra").exists())
            self.assertEqual((failed / "registration").read_text(), "changed-pairing")
            self.assertEqual((failed / "extra").read_text(), "failed-state")


class ConnectionAcceptanceTests(unittest.TestCase):
    def baseline(self):
        return {
            "ha_version": "2025.12.3",
            "device_ids": ["device-a"],
            "entities": [{"entity_id": "light.a", "unique_id": "same-radio"}],
            "integration_ids": ["zha-id"],
            "zigbee_identity": {
                "coordinator_ieee": "same-coordinator",
                "network_key_digest": "same-key",
            },
            "availability": {"light.a": True, "sensor.sleeping": False},
            "websocket": {
                "zwave/controller": {"home_id": 1234, "node_ids": [1, 3]},
                "config_entries/get": [
                    {"entry_id": "zha-id", "state": "loaded"},
                    {"entry_id": "old-offline", "state": "setup_retry"},
                ],
            },
        }

    def test_accepts_same_identity_and_preexisting_failures(self):
        baseline = self.baseline()
        self.assertEqual(inventory.compare(baseline, copy.deepcopy(baseline)), [])

    def test_rejects_recreated_device_identity(self):
        before = self.baseline()
        after = copy.deepcopy(before)
        after["device_ids"] = ["new-onboarding-device"]
        self.assertIn("device_ids changed", inventory.compare(before, after))

    def test_rejects_newly_unavailable_entity(self):
        before = self.baseline()
        after = copy.deepcopy(before)
        after["availability"]["light.a"] = False
        self.assertTrue(
            any("light.a" in failure for failure in inventory.compare(before, after))
        )

    def test_rejects_previously_loaded_integration_failure(self):
        before = self.baseline()
        after = copy.deepcopy(before)
        after["websocket"]["config_entries/get"][0]["state"] = "setup_retry"
        self.assertTrue(
            any(
                "integrations lost" in failure
                for failure in inventory.compare(before, after)
            )
        )

    def test_rejects_changed_zigbee_network(self):
        before = self.baseline()
        after = copy.deepcopy(before)
        after["zigbee_identity"]["network_key_digest"] = "different-key"
        self.assertIn(
            "Zigbee coordinator/network identity changed",
            inventory.compare(before, after),
        )

    def test_rejects_lost_zwave_node(self):
        before = self.baseline()
        after = copy.deepcopy(before)
        after["websocket"]["zwave/controller"]["node_ids"] = [1]
        self.assertIn(
            "Z-Wave controller identity, nodes or runtime changed",
            inventory.compare(before, after),
        )

    def test_rejects_application_upgrade(self):
        before = self.baseline()
        after = copy.deepcopy(before)
        after["ha_version"] = "2026.10.0"
        self.assertIn("ha_version changed", inventory.compare(before, after))


if __name__ == "__main__":
    unittest.main()
