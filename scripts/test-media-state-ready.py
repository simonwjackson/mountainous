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
            db.execute("CREATE TABLE ScheduledTasks (Id INTEGER PRIMARY KEY, TypeName TEXT, Interval INTEGER, LastExecution TEXT, LastStartTime TEXT)")
            db.execute("INSERT INTO ScheduledTasks VALUES (1, 'NzbDrone.Core.Tv.Commands.RefreshSeriesCommand', 720, '2026-08-18 10:00:00', '2026-08-18 09:59:00')")
            db.execute("INSERT INTO ScheduledTasks VALUES (2, 'NzbDrone.Core.Housekeeping.HousekeepingCommand', 1440, '2026-08-17 10:00:00', NULL)")
            db.execute("CREATE TABLE Commands (Id INTEGER PRIMARY KEY, Name TEXT, Status INTEGER, Body TEXT)")
            db.execute("INSERT INTO Commands VALUES (1, 'RefreshSeries', 6, 'fixture-command-body')")
            if completed:
                db.execute("INSERT INTO Config (Key,Value) VALUES ('enablecompleteddownloadhandling','True')")
            for table, columns in guard.pause_columns(name).items():
                db.execute('CREATE TABLE "' + table + '" (Id INTEGER PRIMARY KEY, Settings TEXT, '
                           + ','.join('"' + column + '" INTEGER' for column in columns) + ')')
                db.execute('INSERT INTO "' + table + '" VALUES (' + ','.join('?' for _ in range(len(columns) + 2)) + ')',
                           [1, '{"password":"fixture-private-credential"}'] + [1] * len(columns))
            if name != 'prowlarr':
                db.execute('ALTER TABLE DownloadClients ADD COLUMN RemoveCompletedDownloads INTEGER DEFAULT 1')
                db.execute('ALTER TABLE DownloadClients ADD COLUMN RemoveFailedDownloads INTEGER DEFAULT 1')

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

    def test_client_flags_alone_do_not_hold_scheduled_scanning(self):
        self.seed_processing()
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE DownloadClients SET Enable=0")
            db.execute("UPDATE Indexers SET EnableRss=0, EnableAutomaticSearch=0, EnableInteractiveSearch=0")
            db.execute("UPDATE Config SET Value='False' WHERE Key='enablecompleteddownloadhandling'")
        with self.assertRaisesRegex(ValueError, "scheduled"):
            guard.validate_arr("sonarr", self.root, require_pause=True)

    def test_scheduler_hold_preserves_original_times_and_command_history(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        guard.prepare_arr_pause("sonarr", self.root, receipt)
        saved = json.loads(receipt.read_text())["scheduled_tasks"]
        self.assertEqual(saved[0]["LastExecution"], "2026-08-18 10:00:00")
        self.assertEqual(saved[0]["LastStartTime"], "2026-08-18 09:59:00")
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT DISTINCT LastExecution FROM ScheduledTasks").fetchall(), [(guard.SCHEDULE_HOLD_UNTIL,)])
            self.assertEqual(db.execute("SELECT Interval FROM ScheduledTasks ORDER BY Id").fetchall(), [(720,), (1440,)])
            self.assertEqual(db.execute("SELECT Status,Body FROM Commands").fetchall(), [(6, "fixture-command-body")])
            self.assertEqual(db.execute("SELECT LastStartTime FROM ScheduledTasks ORDER BY Id").fetchall(), [("2026-08-18 09:59:00",), (None,)])
        guard.validate_arr("sonarr", self.root, require_pause=True)

    def test_pending_arr_commands_fail_before_any_hold_write(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("INSERT INTO Commands VALUES (2, 'DownloadedEpisodesScan', 0, 'keep queued payload')")
        with self.assertRaisesRegex(ValueError, "queued"):
            guard.prepare_arr_pause("sonarr", self.root, receipt)
        self.assertFalse(receipt.exists())
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Enable FROM DownloadClients").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT Status,Body FROM Commands WHERE Id=2").fetchone(), (0, "keep queued payload"))

    def test_missing_scheduler_state_is_not_created(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("DROP TABLE ScheduledTasks")
        with self.assertRaisesRegex(ValueError, "scheduler"):
            guard.prepare_arr_pause("sonarr", self.root, receipt)
        self.assertFalse(receipt.exists())
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM sqlite_master WHERE name='ScheduledTasks'").fetchone()[0], 0)

    def test_scheduler_extension_keeps_the_first_hold_receipt(self):
        self.seed_processing()
        original = Path(self.temporary.name + "-original-hold.json")
        scheduler = Path(self.temporary.name + "-scheduler-hold.json")
        self.addCleanup(lambda: original.unlink(missing_ok=True))
        self.addCleanup(lambda: scheduler.unlink(missing_ok=True))
        original.write_text("keep the original processing flags")
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE DownloadClients SET Enable=0")
            db.execute("UPDATE Indexers SET EnableRss=0, EnableAutomaticSearch=0, EnableInteractiveSearch=0")
            db.execute("UPDATE Config SET Value='False' WHERE Key='enablecompleteddownloadhandling'")
        guard.prepare_arr_scheduler_pause("sonarr", self.root, scheduler)
        self.assertEqual(original.read_text(), "keep the original processing flags")
        self.assertEqual(json.loads(scheduler.read_text())["scheduled_tasks"][0]["LastExecution"], "2026-08-18 10:00:00")
        guard.validate_arr("sonarr", self.root, require_pause=True)
        with self.assertRaises(FileExistsError):
            guard.prepare_arr_scheduler_pause("sonarr", self.root, scheduler)

    def test_started_arr_command_is_not_orphaned_by_the_hold(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("INSERT INTO Commands VALUES (2, 'DownloadedEpisodesScan', 1, 'keep active payload')")
        with self.assertRaisesRegex(ValueError, "active"):
            guard.prepare_arr_pause("sonarr", self.root, receipt)
        self.assertFalse(receipt.exists())
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Status FROM Commands WHERE Id=2").fetchone()[0], 1)

    def test_native_iso_timestamp_format_remains_held_after_startup(self):
        self.seed_processing()
        receipt = Path(self.temporary.name + "-hold.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        guard.prepare_arr_pause("sonarr", self.root, receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE ScheduledTasks SET LastExecution='2099-01-01T00:00:00Z'")
        guard.validate_arr("sonarr", self.root, require_pause=True)

    def held_receipt(self, name="sonarr", completed=True):
        self.seed_processing(name=name, completed=completed)
        receipt = Path(self.temporary.name + "-restore.json")
        self.addCleanup(lambda: receipt.unlink(missing_ok=True))
        guard.prepare_arr_pause(name, self.root, receipt)
        return receipt

    def test_approved_restoration_preserves_credentials_history_and_original_times(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause("sonarr", self.root, receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Enable,Settings FROM DownloadClients").fetchone(),
                             (1, '{"password":"fixture-private-credential"}'))
            self.assertEqual(db.execute("SELECT LastExecution FROM ScheduledTasks ORDER BY Id").fetchall(),
                             [("2026-08-18 10:00:00",), ("2026-08-17 10:00:00",)])
            self.assertEqual(db.execute("SELECT Status,Body FROM Commands").fetchall(), [(6, "fixture-command-body")])
        guard.validate_arr("sonarr", self.root)
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, require_pause=True)
        self.assertTrue(receipt.exists())

    def test_read_admission_does_not_create_or_change_source_wal_sidecars(self):
        receipt = self.held_receipt()
        database = self.root / 'sonarr.db'
        with closing(sqlite3.connect(database)) as db:
            db.execute('PRAGMA journal_mode=WAL')
        before = {path.name: (path.read_bytes(), path.stat().st_mode, path.stat().st_uid, path.stat().st_gid, path.stat().st_mtime_ns) for path in self.root.iterdir() if path.is_file()}
        guard.validate_arr('sonarr', self.root, require_pause=True)
        after = {path.name: (path.read_bytes(), path.stat().st_mode, path.stat().st_uid, path.stat().st_gid, path.stat().st_mtime_ns) for path in self.root.iterdir() if path.is_file()}
        self.assertEqual(after, before)

    def test_private_read_admission_includes_committed_live_wal(self):
        self.held_receipt()
        database = self.root / 'sonarr.db'
        with closing(sqlite3.connect(database)) as db, db:
            db.execute('PRAGMA journal_mode=WAL')
            db.execute("INSERT INTO Commands (Id,Status,Body) VALUES (2,6,'committed-wal-command')")
            db.commit()
            before = {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in self.root.iterdir() if path.is_file()}
            with guard.arr_read_connection(database) as snapshot:
                self.assertEqual(snapshot.execute('SELECT Body FROM Commands WHERE Id=2').fetchone(), ('committed-wal-command',))
            guard.validate_arr('sonarr', self.root, require_pause=True)
            after = {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in self.root.iterdir() if path.is_file()}
            self.assertEqual(after, before)

    def test_enabled_startup_admits_original_flags_and_native_execution_progress(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause('sonarr', self.root, receipt)
        guard.validate_arr('sonarr', self.root, enabled_receipt=receipt)
        with closing(sqlite3.connect(self.root / 'sonarr.db')) as db, db:
            db.execute("UPDATE ScheduledTasks SET LastExecution='2026-10-08 12:00:00'")
        guard.validate_arr('sonarr', self.root, enabled_receipt=receipt)

    def test_enabled_startup_rejects_unrestored_flags_and_missing_receipt(self):
        receipt = self.held_receipt()
        with self.assertRaises(ValueError):
            guard.validate_arr('sonarr', self.root, enabled_receipt=receipt)
        guard.restore_arr_pause('sonarr', self.root, receipt)
        with closing(sqlite3.connect(self.root / 'sonarr.db')) as db, db:
            db.execute('UPDATE DownloadClients SET RemoveFailedDownloads=0')
        with self.assertRaises(ValueError):
            guard.validate_arr('sonarr', self.root, enabled_receipt=receipt)
        with self.assertRaises(ValueError):
            guard.validate_arr('sonarr', self.root, imports_receipt=receipt, enabled_receipt=receipt)

    def test_enabled_startup_rejects_scheduler_hold_with_original_flags(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause('sonarr', self.root, receipt)
        with closing(sqlite3.connect(self.root / 'sonarr.db')) as db, db:
            db.execute('UPDATE ScheduledTasks SET LastExecution=?', (guard.SCHEDULE_HOLD_UNTIL,))
        with self.assertRaises(ValueError):
            guard.validate_arr('sonarr', self.root, enabled_receipt=receipt)

    def test_enabled_prowlarr_startup_restores_original_sync_flags(self):
        receipt = self.held_receipt(name='prowlarr')
        guard.restore_arr_pause('prowlarr', self.root, receipt)
        guard.validate_arr('prowlarr', self.root, enabled_receipt=receipt)

    def test_original_default_import_handling_is_restored_without_new_configuration(self):
        receipt = self.held_receipt(name="radarr", completed=False)
        guard.restore_arr_pause("radarr", self.root, receipt)
        with closing(sqlite3.connect(self.root / "radarr.db")) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchone()[0], 0)

    def test_imports_only_restoration_keeps_schedules_and_indexers_held(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause("sonarr", self.root, receipt, mode="imports-only")
        guard.validate_arr("sonarr", self.root, imports_receipt=receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            guard.validate_scheduled_pause(db)
            self.assertEqual(db.execute("SELECT Enable FROM DownloadClients").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT EnableRss FROM Indexers").fetchone()[0], 0)

    def test_imports_only_startup_requires_original_clients_and_held_indexers(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause("sonarr", self.root, receipt, mode="imports-only")
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE Indexers SET EnableInteractiveSearch=1")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, imports_receipt=receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE Indexers SET EnableInteractiveSearch=0")
            db.execute("UPDATE DownloadClients SET Enable=0")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, imports_receipt=receipt)

    def test_imports_only_startup_rejects_running_schedules_and_import_changes(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause("sonarr", self.root, receipt, mode="imports-only")
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE ScheduledTasks SET LastExecution='2026-01-01 00:00:00'")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, imports_receipt=receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE ScheduledTasks SET LastExecution=?", (guard.SCHEDULE_HOLD_UNTIL,))
            db.execute("UPDATE Config SET Value='True' WHERE Key='enablecompleteddownloadhandling'")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, imports_receipt=receipt)

    def test_imports_only_startup_preserves_absent_config_and_requires_protected_receipt(self):
        receipt = self.held_receipt(name="radarr", completed=False)
        guard.restore_arr_pause("radarr", self.root, receipt, mode="imports-only")
        guard.validate_arr("radarr", self.root, imports_receipt=receipt)
        receipt.chmod(0o644)
        with self.assertRaises(ValueError):
            guard.validate_arr("radarr", self.root, imports_receipt=receipt)

    def test_imports_only_holds_automatic_import_and_removal_flags(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause('sonarr', self.root, receipt, mode='imports-only')
        with closing(sqlite3.connect(self.root / 'sonarr.db')) as db:
            self.assertEqual(db.execute('SELECT Enable,RemoveCompletedDownloads,RemoveFailedDownloads FROM DownloadClients').fetchall(), [(1, 0, 0)])
            self.assertEqual(db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall(), [('False',)])
            self.assertEqual(db.execute('SELECT Status,Body FROM Commands').fetchall(), [(6, 'fixture-command-body')])
        guard.validate_arr('sonarr', self.root, imports_receipt=receipt)
        guard.restore_arr_pause('sonarr', self.root, receipt)
        with closing(sqlite3.connect(self.root / 'sonarr.db')) as db:
            self.assertEqual(db.execute('SELECT Enable,RemoveCompletedDownloads,RemoveFailedDownloads FROM DownloadClients').fetchall(), [(1, 1, 1)])
            self.assertEqual(db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall(), [('True',)])

    def test_imports_only_fails_closed_when_native_cleanup_is_reenabled(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause('sonarr', self.root, receipt, mode='imports-only')
        for column in ('RemoveCompletedDownloads', 'RemoveFailedDownloads'):
            with closing(sqlite3.connect(self.root / 'sonarr.db')) as db, db:
                db.execute('UPDATE DownloadClients SET ' + column + '=1')
            with self.assertRaises(ValueError):
                guard.validate_arr('sonarr', self.root, imports_receipt=receipt)
            with closing(sqlite3.connect(self.root / 'sonarr.db')) as db, db:
                db.execute('UPDATE DownloadClients SET ' + column + '=0')

    def test_imports_only_requires_original_removal_receipt_before_any_updates(self):
        receipt = self.held_receipt()
        original = json.loads(receipt.read_text())
        del original['download_removal_flags']
        receipt.write_text(json.dumps(original))
        with self.assertRaises(ValueError):
            guard.restore_arr_pause('sonarr', self.root, receipt, mode='imports-only')
        guard.validate_arr('sonarr', self.root, require_pause=True)

    def test_imports_only_holds_absent_config_then_restores_original_absence(self):
        receipt = self.held_receipt(name='radarr', completed=False)
        guard.restore_arr_pause('radarr', self.root, receipt, mode='imports-only')
        with closing(sqlite3.connect(self.root / 'radarr.db')) as db:
            self.assertEqual(db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall(), [('False',)])
        guard.restore_arr_pause('radarr', self.root, receipt)
        with closing(sqlite3.connect(self.root / 'radarr.db')) as db:
            self.assertEqual(db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall(), [])

    def test_imports_only_startup_rejects_conflicting_holds(self):
        receipt = self.held_receipt()
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root, require_pause=True, imports_receipt=receipt)

    def test_prowlarr_cannot_use_imports_only_startup(self):
        receipt = self.held_receipt(name="prowlarr")
        with self.assertRaises(ValueError):
            guard.validate_arr("prowlarr", self.root, imports_receipt=receipt)

    def test_imports_only_stage_can_finish_with_original_schedules_and_flags(self):
        receipt = self.held_receipt()
        guard.restore_arr_pause("sonarr", self.root, receipt, mode="imports-only")
        guard.restore_arr_pause("sonarr", self.root, receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT EnableRss FROM Indexers").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT LastExecution FROM ScheduledTasks WHERE Id=1").fetchone()[0], "2026-08-18 10:00:00")

    def test_restoration_rejects_unprotected_receipt_without_writing_flags(self):
        receipt = self.held_receipt()
        receipt.chmod(0o644)
        with self.assertRaises(ValueError):
            guard.restore_arr_pause("sonarr", self.root, receipt)
        guard.validate_arr("sonarr", self.root, require_pause=True)

    def test_restoration_rejects_changed_task_identity_before_writing_flags(self):
        receipt = self.held_receipt()
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("UPDATE ScheduledTasks SET TypeName='unexpected task' WHERE Id=1")
        with self.assertRaises(ValueError):
            guard.restore_arr_pause("sonarr", self.root, receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Enable FROM DownloadClients").fetchone()[0], 0)

    def test_restoration_rejects_changed_client_set_before_writing_anything(self):
        receipt = self.held_receipt()
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db, db:
            db.execute("INSERT INTO DownloadClients (Id,Settings,Enable) VALUES (2,'retained new client',0)")
        with self.assertRaises(ValueError):
            guard.restore_arr_pause("sonarr", self.root, receipt)
        with closing(sqlite3.connect(self.root / "sonarr.db")) as db:
            self.assertEqual(db.execute("SELECT Enable FROM DownloadClients ORDER BY Id").fetchall(), [(0,), (0,)])

    def test_missing_api_identity_is_rejected(self):
        (self.root / "config.xml").write_text("<Config/>")
        with self.assertRaises(ValueError):
            guard.validate_arr("sonarr", self.root)


if __name__ == "__main__":
    unittest.main()
