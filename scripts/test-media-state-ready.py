#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
from contextlib import closing
import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

SOURCE = Path(__file__).parents[1] / "modules/media-state-ready.py"
spec = importlib.util.spec_from_file_location("media_state_ready", SOURCE)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ExistingStateRequired(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "config.xml").write_text("<Config><ApiKey>test-only-identity</ApiKey></Config>")
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("CREATE TABLE Users (Id INTEGER)")
            db.execute("INSERT INTO Users VALUES (1)")
            db.execute("CREATE TABLE VersionInfo (Version INTEGER)")
            db.execute("INSERT INTO VersionInfo VALUES (211)")

    def test_existing_configured_database_is_accepted(self):
        guard.validate_arr("sonarr", self.root)

    def test_missing_database_is_not_created(self):
        (self.root / "sonarr.db").unlink()
        with self.assertRaises(sqlite3.Error):
            guard.validate_arr("sonarr", self.root)
        self.assertFalse((self.root / "sonarr.db").exists())

    def test_empty_database_is_rejected(self):
        (self.root / "sonarr.db").write_bytes(b"")
        with self.assertRaises(sqlite3.Error):
            guard.validate_arr("sonarr", self.root)

    def test_corrupt_database_is_rejected(self):
        (self.root / "sonarr.db").write_bytes(b"not a database")
        with self.assertRaises(sqlite3.Error):
            guard.validate_arr("sonarr", self.root)

    def test_missing_user_is_not_reset(self):
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("DELETE FROM Users")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM Users").fetchone()[0], 0)

    def seed_processing(self, name="sonarr", completed=True):
        if name != "sonarr":
            (self.root / "sonarr.db").rename(self.root / (name + ".db"))
        with closing(sqlite3.connect(self.root / (name + ".db"))) as db, db:
            db.execute("CREATE TABLE Config (Id INTEGER PRIMARY KEY, Key TEXT, Value TEXT)")
            if completed:
                db.execute("INSERT INTO Config (Key,Value) VALUES ('enablecompleteddownloadhandling','True')")
            for table, columns in guard.pause_columns(name).items():
                db.execute('CREATE TABLE "' + table + '" (Id INTEGER PRIMARY KEY, Settings TEXT, '
                           + ','.join('"' + column + '" INTEGER' for column in columns) + ')')
                db.execute('INSERT INTO "' + table + '" VALUES (' + ','.join('?' for _ in range(len(columns) + 2)) + ')',
                           [1, '{"password":"fixture-private-credential"}'] + [1] * len(columns))

    def test_live_processing_is_rejected_by_hold_gate(self):
        self.seed_processing()
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, require_pause=True)

    def test_hold_preserves_client_credentials_and_original_flags(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        guard.prepare_arr_pause("sonarr", self.root, receipt)
        guard.validate_arr("sonarr", self.root, require_pause=True)
        original = json.loads(receipt.read_text())
        self.assertEqual(original["completed_download_handling"], "True")
        self.assertEqual(original["flags"]["DownloadClients"][0]["Enable"], 1)
        self.assertNotIn("fixture-private-credential", receipt.read_text())
        self.assertEqual(receipt.stat().st_mode & 0o777, 0o600)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Settings FROM DownloadClients").fetchone()[0],
                             '{"password":"fixture-private-credential"}')
            self.assertEqual(db.execute("SELECT count(*) FROM Users").fetchone()[0], 1)

    def test_default_import_handling_is_held_without_losing_original_absence(self):
        self.seed_processing(name="radarr", completed=False)
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        guard.prepare_arr_pause("radarr", self.root, receipt)
        guard.validate_arr("radarr", self.root, require_pause=True)
        self.assertIsNone(json.loads(receipt.read_text())["completed_download_handling"])

    def test_prowlarr_sync_cannot_reenable_downstream_indexers(self):
        self.seed_processing(name="prowlarr")
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        guard.prepare_arr_pause("prowlarr", self.root, receipt)
        guard.validate_arr("prowlarr", self.root, require_pause=True)
        with closing(sqlite3.connect(self.root / "prowlarr.db")) as db:
            self.assertEqual(db.execute("SELECT SyncLevel FROM Applications").fetchone()[0], 0)

    def test_existing_receipt_cannot_be_replaced(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        receipt.write_text("previous protected receipt")
        with self.assertRaises(FileExistsError):
            guard.prepare_arr_pause("sonarr", self.root, receipt)
        self.assertEqual(receipt.read_text(), "previous protected receipt")
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Enable FROM DownloadClients").fetchone()[0], 1)

    def test_receipt_inside_state_is_rejected_before_any_write(self):
        self.seed_processing()
        with self.assertRaises(ValueError):
            guard.prepare_arr_pause("sonarr", self.root, self.root / "receipt.json")
        self.assertFalse((self.root / "receipt.json").exists())

    def test_receipt_alias_into_state_is_rejected(self):
        self.seed_processing()
        alias = Path(self.temporary.name + "-alias")
        alias.symlink_to(self.root, target_is_directory=True)
        self.addCleanup(alias.unlink)
        with self.assertRaises(ValueError):
            guard.prepare_arr_pause("sonarr", self.root, alias / "receipt.json")
        self.assertFalse((self.root / "receipt.json").exists())

    def test_missing_api_identity_is_rejected(self):
        (self.root / "config.xml").write_text("<Config/>")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root)


if __name__ == "__main__":
    unittest.main()
