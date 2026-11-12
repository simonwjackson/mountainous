import importlib.util
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "scripts/openclaw-wait-idle.py"
SPEC = importlib.util.spec_from_file_location("openclaw_wait_idle", SCRIPT)
idle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(idle)


class GatewayIdleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.db = self.root / "claw-simon/var/lib/openclaw/state/openclaw.sqlite"
        self.db.parent.mkdir(parents=True)
        with sqlite3.connect(self.db) as connection:
            connection.execute(
                "CREATE TABLE audit_events (action TEXT, run_id TEXT, occurred_at INTEGER)"
            )

    def event(self, action, run, timestamp):
        with sqlite3.connect(self.db) as connection:
            connection.execute(
                "INSERT INTO audit_events VALUES (?, ?, ?)", (action, run, timestamp)
            )

    def test_empty_gateway_is_idle(self):
        self.assertEqual(idle.active_runs(self.db), (0, None))

    def test_unfinished_run_blocks_switch(self):
        self.event("agent.run.started", "run-a", 100)
        self.assertEqual(idle.active_runs(self.db), (1, 100))
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--check",
                "--container-root",
                str(self.root),
                "claw-simon",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn('"activeRuns": 1', result.stdout)

    def test_matching_finish_releases_run_but_not_another(self):
        self.event("agent.run.started", "run-a", 100)
        self.event("agent.run.started", "run-b", 200)
        self.event("agent.run.finished", "run-a", 300)
        self.assertEqual(idle.active_runs(self.db), (1, 200))
        self.event("agent.run.finished", "run-b", 400)
        self.assertEqual(idle.active_runs(self.db), (0, None))

    def test_old_finish_does_not_hide_a_new_start(self):
        self.event("agent.run.finished", "run-a", 90)
        self.event("agent.run.started", "run-a", 100)
        self.assertEqual(idle.active_runs(self.db), (1, 100))

    def test_unknown_run_id_fails_closed(self):
        self.event("agent.run.started", None, 100)
        self.event("agent.run.finished", None, 200)
        self.assertEqual(idle.active_runs(self.db), (1, 100))

    def test_missing_database_is_not_idle(self):
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--check",
                "--container-root",
                str(self.root),
                "claw-laure",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)

    def test_invalid_container_cannot_escape_root(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "../openclaw"],
            check=False,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
