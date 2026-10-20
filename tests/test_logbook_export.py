import importlib.util
import os
import sqlite3
import stat
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "export", Path(__file__).resolve().parents[1] / "modules/logbook-export.py"
)
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class ExportTest(unittest.TestCase):
    def test_atomic_snapshot_and_rejected_exports_preserve_last_good_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / "source.db", root / "Gadgetbridge.db"
            with sqlite3.connect(source) as db:
                db.execute("create table samples(value integer)")
                db.execute("insert into samples values (1)")
            bridge.publish(source, target, os.getuid(), os.getgid())
            original_inode = target.stat().st_ino
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
            self.assertEqual(target.stat().st_uid, os.getuid())
            self.assertEqual(source.read_bytes(), target.read_bytes())
            with sqlite3.connect(source) as db:
                db.execute("insert into samples values (2)")
            bridge.publish(source, target, os.getuid(), os.getgid())
            self.assertNotEqual(target.stat().st_ino, original_inode)
            with sqlite3.connect(target) as db:
                self.assertEqual(
                    db.execute("select value from samples").fetchall(), [(1,), (2,)]
                )
            last_good = target.read_bytes()
            for invalid in (
                b"",
                b"incomplete SQLite export",
                source.read_bytes()[:100],
            ):
                source.write_bytes(invalid)
                with self.assertRaises((ValueError, sqlite3.Error)):
                    bridge.publish(source, target, os.getuid(), os.getgid())
                self.assertEqual(target.read_bytes(), last_good)
                self.assertFalse(target.with_suffix(".db.tmp").exists())
            source.unlink()
            source.symlink_to(target)
            with self.assertRaises(OSError):
                bridge.publish(source, target, os.getuid(), os.getgid())
            self.assertEqual(target.read_bytes(), last_good)
            source.unlink()
            os.mkfifo(source)
            with self.assertRaises(ValueError):
                bridge.publish(source, target, os.getuid(), os.getgid())
            self.assertEqual(target.read_bytes(), last_good)


if __name__ == "__main__":
    unittest.main()
