"""Safety contracts use real processes and real temporary Git repositories."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(os.environ.get("SERVICE_APP_SCRIPTS", Path(__file__).parents[1] / "scripts"))
sys.path.insert(0, str(SCRIPTS))
from service_apps import all_units_active, recovery_units, require_cutover_ready


class ServiceAppSafetyTests(unittest.TestCase):
    def test_requires_every_unit_not_any_unit(self):
        # Real process with configured status; rejects multi-unit invocations.
        status = ["sh", "-c", 'test "$#" = 3 && test "$3" = active', "unit-status"]
        self.assertTrue(all_units_active(status, ["active", "active"]))
        self.assertFalse(all_units_active(status, ["active", "failed"]))
        self.assertFalse(all_units_active(status, ["failed", "active"]))
        self.assertFalse(all_units_active(status, ["failed", "failed"]))

    def test_completed_cutover_never_stops_or_recovers_source(self):
        with self.assertRaisesRegex(RuntimeError, "source unit"):
            require_cutover_ready({"backend": False, "sidecar": False}, True)
        with self.assertRaisesRegex(RuntimeError, "profile already exists"):
            require_cutover_ready({"backend": True, "sidecar": True}, True)

    def test_partly_running_source_is_not_a_cutover(self):
        with self.assertRaises(RuntimeError):
            require_cutover_ready({"backend": True, "sidecar": False}, False)
        self.assertEqual(require_cutover_ready({"backend": True, "sidecar": True}, False), ["backend", "sidecar"])

    def test_recovery_requires_confirmed_destination_stop(self):
        initial = {"previously-active": True, "previously-inactive": False}
        with self.assertRaisesRegex(RuntimeError, "must stay stopped"):
            recovery_units(initial, False)
        self.assertEqual(recovery_units(initial, True), ["previously-active"])

    def test_real_cli_rejects_invalid_plan_before_transport(self):
        with tempfile.TemporaryDirectory() as directory:
            plan = Path(directory) / "plan.json"
            plan.write_text(json.dumps({"app": "example", "source_host": "not-this-host"}))
            result = subprocess.run([sys.executable, str(SCRIPTS / "service-apps-cutover"), "source", "--plan", str(plan)],
                                    env={**os.environ, "HOME": directory}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Wrong source host", result.stderr)

    def test_stage_accepts_a_different_branch_and_repo(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original, checkout = root / "original", root / "checkout"
            def git(*args):
                return subprocess.check_output(["git", *map(str, args)], text=True, stderr=subprocess.DEVNULL).strip()
            git("init", original)
            git("-C", original, "config", "user.name", "Fixture")
            git("-C", original, "config", "user.email", "fixture@example.invalid")
            git("-C", original, "commit", "--allow-empty", "-m", "original")
            old = git("-C", original, "rev-parse", "HEAD")
            git("clone", original, checkout)
            git("-C", original, "switch", "-c", "stage-three-service")
            git("-C", original, "commit", "--allow-empty", "-m", "candidate")
            new = git("-C", original, "rev-parse", "HEAD")
            bundle = root / "source.bundle"
            git("-C", original, "bundle", "create", bundle, "stage-three-service")
            subprocess.run([sys.executable, str(SCRIPTS / "service-apps-stage-source-target"),
                "--runner-host", socket.gethostname(), "--repo", str(checkout), "--bundle", str(bundle),
                "--branch", "stage-three-service", "--expected-sha", new], check=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.assertEqual(git("-C", checkout, "rev-parse", "HEAD"), new)
            self.assertEqual(git("-C", checkout, "rev-parse", "refs/heads/before-service-apps-" + old), old)
            # A mismatched branch/SHA must not change the current checkout.
            result = subprocess.run([sys.executable, str(SCRIPTS / "service-apps-stage-source-target"),
                "--runner-host", socket.gethostname(), "--repo", str(checkout), "--bundle", str(bundle),
                "--branch", "stage-three-service", "--expected-sha", old],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(git("-C", checkout, "rev-parse", "HEAD"), new)


if __name__ == "__main__":
    unittest.main()
