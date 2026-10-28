"""Exercise the login migration only in private Chromium user-data roots."""

import importlib.util
import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "chromium_frame",
    os.environ.get(
        "FRAME_SCRIPT", Path(__file__).parents[1] / "scripts/chromium-frame.py"
    ),
)
frame = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(frame)


class ChromiumFrameTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.prefs = self.root / "Default/Preferences"
        self.prefs.parent.mkdir()
        self.original = b'{"browser":{"custom_chrome_frame":true,"other":42},"secret":"preserved"}\n'
        self.prefs.write_bytes(self.original)
        self.prefs.chmod(0o640)

    def test_changes_only_frame_and_keeps_original_once(self):
        frame.apply(self.root)
        expected = json.loads(self.original)
        expected["browser"]["custom_chrome_frame"] = False
        self.assertEqual(json.loads(self.prefs.read_bytes()), expected)
        self.assertEqual(self.prefs.stat().st_mode & 0o777, 0o640)
        backup = self.prefs.with_name("Preferences.before-mountainous-frame")
        self.assertEqual(backup.read_bytes(), self.original)
        before = self.prefs.stat().st_mtime_ns
        frame.apply(self.root)
        self.assertEqual(self.prefs.stat().st_mtime_ns, before)
        self.assertEqual(backup.read_bytes(), self.original)
        # A later browser choice can require another migration. Do not replace
        # the first backup, and do not keep it linked to the new Preferences.
        changed = json.loads(self.original)
        changed["browser"]["other"] = 99
        self.prefs.write_text(json.dumps(changed))
        frame.apply(self.root)
        self.assertEqual(backup.read_bytes(), self.original)
        self.assertEqual(json.loads(self.prefs.read_text())["browser"]["other"], 99)

    def test_stale_local_lock_does_not_block_or_get_deleted(self):
        # Above pid_max: the kernel cannot allocate this PID to another process.
        dead_pid = int(Path("/proc/sys/kernel/pid_max").read_text()) + 1
        lock = self.root / "SingletonLock"
        target = f"{socket.gethostname()}-{dead_pid}"
        lock.symlink_to(target)
        frame.apply(self.root)
        self.assertFalse(
            json.loads(self.prefs.read_text())["browser"]["custom_chrome_frame"]
        )
        self.assertEqual(os.readlink(lock), target)

    def test_pid_reused_by_non_chromium_process_is_stale(self):
        lock = self.root / "SingletonLock"
        lock.symlink_to(f"{socket.gethostname()}-{os.getpid()}")
        frame.apply(self.root)
        self.assertFalse(
            json.loads(self.prefs.read_text())["browser"]["custom_chrome_frame"]
        )
        self.assertTrue(lock.is_symlink())

    def test_live_local_chromium_lock_defers(self):
        # A real Linux process with a controlled comm, without starting a GUI.
        process = subprocess.Popen(
            [
                sys.executable,
                "-c",
                "import ctypes,sys; ctypes.CDLL(None).prctl(15,b'chromium-test',0,0,0); print('ready',flush=True); sys.stdin.read()",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
        )
        try:
            self.assertEqual(process.stdout.readline().strip(), "ready")
            self.assertIn("chromium", Path(f"/proc/{process.pid}/comm").read_text())
            lock = self.root / "SingletonLock"
            target = f"{socket.gethostname()}-{process.pid}"
            lock.symlink_to(target)
            frame.apply(self.root)
            self.assertEqual(self.prefs.read_bytes(), self.original)
            self.assertEqual(os.readlink(lock), target)
        finally:
            try:
                process.communicate(timeout=5)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)

    def test_foreign_host_lock_defers(self):
        lock = self.root / "SingletonLock"
        lock.symlink_to(f"foreign-{socket.gethostname()}-999999999")
        frame.apply(self.root)
        self.assertEqual(self.prefs.read_bytes(), self.original)
        self.assertTrue(lock.is_symlink())

    def test_unparseable_lock_defers(self):
        lock = self.root / "SingletonLock"
        for target in (
            "unknown",
            f"{socket.gethostname()}-not-a-pid",
            f"{socket.gethostname()}-0",
        ):
            lock.symlink_to(target)
            frame.apply(self.root)
            self.assertEqual(self.prefs.read_bytes(), self.original)
            lock.unlink()
        lock.write_text("not a Chromium symlink")
        frame.apply(self.root)
        self.assertEqual(self.prefs.read_bytes(), self.original)

    def test_all_existing_profiles_but_not_symlinks(self):
        other = self.root / "Profile 1/Preferences"
        other.parent.mkdir()
        other.write_text('{"browser":{}}')
        (self.root / "Linked profile").symlink_to(other.parent)
        frame.apply(self.root)
        self.assertFalse(
            json.loads(other.read_text())["browser"]["custom_chrome_frame"]
        )
        self.assertFalse((self.root / "Local State").exists())

    def test_cli_uses_both_roots_in_private_home(self):
        config = self.root / "config"
        shared = self.root / ".local/share/mountainous/browser"
        for root in (config / "chromium", shared):
            prefs = root / "Default/Preferences"
            prefs.parent.mkdir(parents=True)
            prefs.write_bytes(self.original)
        result = subprocess.run(
            [sys.executable, frame.__file__],
            env={**os.environ, "HOME": str(self.root), "XDG_CONFIG_HOME": str(config)},
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            result.stdout.count("set browser.custom_chrome_frame=false"), 2
        )
        for root in (config / "chromium", shared):
            prefs = root / "Default/Preferences"
            self.assertFalse(
                json.loads(prefs.read_bytes())["browser"]["custom_chrome_frame"]
            )

    def test_symlink_preferences_are_not_followed(self):
        other = self.root / "outside-preferences"
        self.prefs.rename(other)
        self.prefs.symlink_to(other)
        with self.assertRaises(ValueError):
            frame.apply(self.root)
        self.assertEqual(other.read_bytes(), self.original)

    def test_missing_root_is_not_created(self):
        frame.apply(self.root / "missing")
        self.assertFalse((self.root / "missing").exists())

    def test_invalid_json_is_not_overwritten(self):
        self.prefs.write_text("incomplete{")
        with self.assertRaises(ValueError):
            frame.apply(self.root)
        self.assertEqual(self.prefs.read_text(), "incomplete{")

    def test_invalid_browser_is_not_overwritten(self):
        self.prefs.write_text('{"browser":false}')
        with self.assertRaises(TypeError):
            frame.apply(self.root)
        self.assertEqual(self.prefs.read_text(), '{"browser":false}')


if __name__ == "__main__":
    unittest.main()
