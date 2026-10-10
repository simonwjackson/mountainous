#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 python3Packages.pyyaml
"""Real filesystem tests for private state transfer. No live API calls."""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import pwd
import tarfile
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("cliproxyapi-state")
loader = importlib.machinery.SourceFileLoader("state_transfer", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
state = importlib.util.module_from_spec(spec)
loader.exec_module(state)


class StateTransferTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.home = self.root / "source"
        self.home.mkdir()
        self.packet = self.root / "packet"
        for relative in state.DIRS:
            directory = self.home / relative
            directory.mkdir(parents=True)
            (directory / "saved.json").write_text(
                json.dumps({"value": "fixture-preserved-value"})
            )
        (self.home / ".config/cliproxyapi/config.yaml").write_text(
            "auth-dir: "
            + str(self.home)
            + "/.cli-proxy-api\napi-keys: [fixture-client-key]\n"
        )

    def tearDown(self):
        self.temporary.cleanup()

    def seal(self):
        with contextlib.redirect_stdout(io.StringIO()):
            state.export_state(self.home, self.packet)

    def test_archive_round_trip_keeps_every_state_byte(self):
        self.seal()
        restored = self.root / "restored"
        restored.mkdir()
        state.extract(self.packet / "state.tar.gz", restored)
        self.assertEqual(state.manifest(self.home), state.manifest(restored))

    def test_import_rebases_paths_without_changing_client_keys(self):
        self.seal()
        target = self.root / "target"
        target.mkdir()
        user = pwd.getpwuid(os.getuid()).pw_name
        with contextlib.redirect_stdout(io.StringIO()):
            state.import_state(target, self.packet, str(self.home), user)
        import yaml

        value = yaml.safe_load((target / ".config/cliproxyapi/config.yaml").read_text())
        self.assertEqual(value["auth-dir"], str(target / ".cli-proxy-api"))
        self.assertEqual(value["api-keys"], ["fixture-client-key"])
        for relative in state.DIRS:
            self.assertEqual(
                (target / relative / "saved.json").read_bytes(),
                (self.home / relative / "saved.json").read_bytes(),
            )

    def test_tampered_archive_does_not_replace_existing_target_state(self):
        self.seal()
        target = self.root / "target"
        target.mkdir()
        existing = target / "retained"
        existing.write_text("unchanged")
        with (self.packet / "state.tar.gz").open("ab") as handle:
            handle.write(b"changed")
        with self.assertRaises(AssertionError):
            state.import_state(
                target, self.packet, str(self.home), pwd.getpwuid(os.getuid()).pw_name
            )
        self.assertEqual(existing.read_text(), "unchanged")

    def reject_member(self, name, kind=tarfile.REGTYPE):
        archive = self.root / "unsafe.tar.gz"
        with tarfile.open(archive, "w:gz") as handle:
            member = tarfile.TarInfo(name)
            member.type = kind
            if kind == tarfile.SYMTYPE:
                member.linkname = "/etc/passwd"
            handle.addfile(member)
        with self.assertRaises(AssertionError):
            state.extract(archive, self.root / "extracted")

    def test_archive_rejects_absolute_names(self):
        self.reject_member("/etc/passwd")

    def test_archive_rejects_parent_traversal(self):
        self.reject_member(".cli-proxy-api/../escaped")

    def test_archive_rejects_files_outside_proxy_directories(self):
        self.reject_member(".ssh/id_ed25519")

    def test_archive_rejects_symlinks(self):
        self.reject_member(".cli-proxy-api/auth.json", tarfile.SYMTYPE)

    def test_path_rebase_does_not_change_embedded_secret_text(self):
        value = {"path": "/old/home/.cli-proxy-api", "key": "key-/old/home/value"}
        self.assertEqual(
            state.rebase(value, "/old/home", "/new/home"),
            {"path": "/new/home/.cli-proxy-api", "key": "key-/old/home/value"},
        )


if __name__ == "__main__":
    unittest.main()
