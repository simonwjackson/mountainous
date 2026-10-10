#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise actual filesystem and SQLite state, not stand-in implementations."""
from contextlib import closing
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sqlite3
import struct
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).with_name("media-state")
loader = importlib.machinery.SourceFileLoader("media_state", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
state = importlib.util.module_from_spec(spec)
loader.exec_module(state)


class StateTransfer(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / "source"
        self.source.mkdir(mode=0o700)
        (self.source / "partial").mkdir(mode=0o750)
        (self.source / "partial/archive.rar").write_bytes(b"incomplete archive\0" * 20)
        (self.source / "settings.json").write_text(json.dumps({"testCredential": "private-fixture-value"}))
        (self.source / "settings.json").chmod(0o600)
        with closing(sqlite3.connect(self.source / "application.db")) as connection, connection:
            connection.execute("CREATE TABLE Users (Id INTEGER, Credential TEXT)")
            connection.execute("INSERT INTO Users VALUES (1, 'private-fixture-value')")
        (self.source / "relative-link").symlink_to("partial/archive.rar")
        self.target = self.base / "target"
        shutil.copytree(self.source, self.target, symlinks=True)
        self.expected = state.capture(self.source)

    def test_complete_state_copy_matches(self):
        state.verify(self.expected, state.capture(self.target))

    def test_disjoint_scope_preserves_cross_root_hardlinks(self):
        (self.source / "linked-settings").hardlink_to(self.source / "settings.json")
        roots = ["source/settings.json", "source/linked-settings"]
        expected = state.capture_scope(self.base, roots)
        self.assertEqual(expected["entries"][roots[0]]["hardlink_group"],
                         expected["entries"][roots[1]]["hardlink_group"])
        state.verify(expected, state.capture_scope(self.base, roots))

    def test_scope_preserves_private_state_symlink_without_following_it(self):
        (self.base / "private").mkdir()
        shutil.copytree(self.source, self.base / "private/app", symlinks=True)
        (self.base / "app").symlink_to("private/app")
        manifest = state.capture_scope(self.base, ["app", "private/app"])
        self.assertEqual(manifest["entries"]["app"]["link"], "private/app")
        self.assertIn("private/app/settings.json", manifest["entries"])
        self.assertNotIn("app/settings.json", manifest["entries"])

    def test_scope_rejects_overlapping_roots(self):
        with self.assertRaises(state.StateError):
            state.capture_scope(self.base, ["source", "source/partial"])

    def test_scope_rejects_parent_symlink(self):
        (self.base / "alias").symlink_to("source")
        with self.assertRaises(state.StateError):
            state.capture_scope(self.base, ["alias/partial"])

    def test_scope_rejects_escape(self):
        with self.assertRaises(state.StateError):
            state.capture_scope(self.base, ["../outside"])

    def test_scope_rejects_external_hardlink(self):
        (self.base / "outside").hardlink_to(self.source / "settings.json")
        with self.assertRaises(state.StateError):
            state.capture_scope(self.base, ["source"])

    def test_scope_rejects_duplicate_roots(self):
        with self.assertRaises(state.StateError):
            state.capture_scope(self.base, ["source", "source"])

    def test_scope_rejects_empty_scope(self):
        with self.assertRaises(state.StateError):
            state.capture_scope(self.base, [])

    def test_database_records_survive(self):
        state.verify(self.expected, state.capture(self.target))
        with closing(sqlite3.connect(self.target / "application.db")) as connection:
            self.assertEqual(connection.execute("SELECT count(*) FROM Users").fetchone()[0], 1)

    def test_same_size_content_change_is_detected(self):
        file = self.target / "partial/archive.rar"
        file.write_bytes(b"X" * file.stat().st_size)
        with self.assertRaises(state.StateError):
            state.verify(self.expected, state.capture(self.target))

    def test_missing_partial_is_detected(self):
        (self.target / "partial/archive.rar").unlink()
        with self.assertRaises(state.StateError):
            state.verify(self.expected, state.capture(self.target))

    def test_extra_file_is_not_silently_accepted(self):
        (self.target / "unapproved").write_text("extra")
        with self.assertRaises(state.StateError):
            state.verify(self.expected, state.capture(self.target))

    def test_permissions_are_verified(self):
        (self.target / "settings.json").chmod(0o644)
        with self.assertRaises(state.StateError):
            state.verify(self.expected, state.capture(self.target))

    def test_nanosecond_timestamps_are_verified(self):
        file = self.target / "settings.json"
        os.utime(file, ns=(file.stat().st_atime_ns, file.stat().st_mtime_ns + 1))
        with self.assertRaises(state.StateError):
            state.verify(self.expected, state.capture(self.target))

    def test_extended_attributes_are_verified_without_disclosing_values(self):
        os.setxattr(self.source / "settings.json", "user.protected", b"private-fixture-value")
        expected = state.capture(self.source)
        self.assertNotIn("private-fixture-value", json.dumps(expected))
        with self.assertRaises(state.StateError):
            state.verify(expected, state.capture(self.target))
        shutil.copystat(self.source / "settings.json", self.target / "settings.json")
        state.verify(expected, state.capture(self.target))

    def test_named_acl_ids_follow_explicit_owner_mappings(self):
        source_file, target_file = self.source / "settings.json", self.target / "settings.json"
        uid, gid = os.getuid() + 10, os.getgid() + 10
        def acl(user, group):
            entries = [(1, 6, 0xffffffff), (2, 4, user), (4, 4, 0xffffffff),
                       (8, 4, group), (16, 4, 0xffffffff), (32, 0, 0xffffffff)]
            return struct.pack("<I", 2) + b"".join(struct.pack("<HHI", *entry) for entry in entries)
        os.setxattr(source_file, "system.posix_acl_access", acl(uid, gid))
        os.setxattr(target_file, "system.posix_acl_access", acl(uid + 1, gid + 1))
        expected, actual = state.capture(self.source), state.capture(self.target)
        with self.assertRaises(state.StateError):
            state.verify(expected, actual)
        state.verify(expected, actual, uid_map={uid: uid + 1}, gid_map={gid: gid + 1})

    def test_hardlink_relationships_are_verified_not_only_contents(self):
        (self.source / "linked-settings").hardlink_to(self.source / "settings.json")
        (self.target / "linked-settings").hardlink_to(self.target / "settings.json")
        shutil.copystat(self.source, self.target)
        expected = state.capture(self.source)
        state.verify(expected, state.capture(self.target))
        (self.target / "linked-settings").unlink()
        shutil.copy2(self.source / "linked-settings", self.target / "linked-settings")
        shutil.copystat(self.source, self.target)
        with self.assertRaises(state.StateError):
            state.verify(expected, state.capture(self.target))

    def test_hardlinks_outside_scope_are_rejected(self):
        (self.base / "outside-linked-state").hardlink_to(self.source / "settings.json")
        with self.assertRaises(state.StateError):
            state.capture(self.source)

    def test_manifest_alias_into_state_is_rejected(self):
        alias = self.base / "state-alias"
        alias.symlink_to(self.source, target_is_directory=True)
        result = subprocess.run([sys.executable, SOURCE, "capture", self.source,
                                 alias / "manifest"], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.source / "manifest").exists())

    def test_symlink_target_is_verified(self):
        (self.target / "relative-link").unlink()
        (self.target / "relative-link").symlink_to("application.db")
        with self.assertRaises(state.StateError):
            state.verify(self.expected, state.capture(self.target))

    def test_links_are_not_followed(self):
        (self.source / "outside").symlink_to("/file-that-does-not-exist")
        self.assertEqual(state.capture(self.source)["entries"]["outside"]["kind"], "symlink")

    def test_symlink_root_requires_explicit_resolution(self):
        link = self.base / "private-app-link"
        link.symlink_to(self.source)
        with self.assertRaises(state.StateError):
            state.capture(link)
        state.verify(self.expected, state.capture(link.resolve()))

    @unittest.skipIf(os.getuid() == 0, "root bypasses directory read permissions")
    def test_unreadable_directory_is_not_silently_skipped(self):
        directory = self.source / "partial"
        directory.chmod(0)
        try:
            with self.assertRaises(state.StateError):
                state.capture(self.source)
        finally:
            directory.chmod(0o750)

    def test_socket_or_fifo_is_rejected(self):
        os.mkfifo(self.source / "fifo")
        with self.assertRaises(state.StateError):
            state.capture(self.source)

    def test_private_manifest_does_not_overwrite_existing_files(self):
        manifest = self.base / "manifest"
        state.save(self.expected, manifest)
        self.assertEqual(manifest.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError):
            state.save(self.expected, manifest)

    def test_ownership_mapping_is_explicit(self):
        actual = json.loads(json.dumps(self.expected))
        uid = actual["entries"]["."]["uid"]
        for value in actual["entries"].values():
            value["uid"] = uid + 10
        with self.assertRaises(state.StateError):
            state.verify(self.expected, actual)
        state.verify(self.expected, actual, uid_map={uid: uid + 10})

    def test_cli_refuses_manifest_inside_state(self):
        result = subprocess.run([sys.executable, SOURCE, "capture", self.source,
                                 self.source / "manifest"], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.source / "manifest").exists())
        self.assertNotIn("private-fixture-value", result.stdout + result.stderr)

    def test_cli_round_trip_and_redacted_failure(self):
        manifest = self.base / "manifest"
        for action in ("capture", "verify"):
            result = subprocess.run([sys.executable, SOURCE, action, self.source, manifest],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("private-fixture-value", result.stdout + result.stderr)
        (self.source / "settings.json").write_text("changed")
        result = subprocess.run([sys.executable, SOURCE, "verify", self.source, manifest],
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("settings.json", result.stderr)


if __name__ == "__main__":
    unittest.main()
