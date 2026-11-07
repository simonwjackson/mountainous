"""Safety contracts use real processes and real temporary Git repositories."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
from urllib.error import HTTPError

SCRIPTS = Path(os.environ.get("SERVICE_APP_SCRIPTS", Path(__file__).parents[1] / "scripts"))
sys.path.insert(0, str(SCRIPTS))
from service_apps import Health, all_units_active, declared_units, migration_source_units, package_canary_expression, recovery_units, require_cutover_ready


class ServiceAppSafetyTests(unittest.TestCase):
    def test_health_contract_rejects_mismatch_and_non_public_transports(self):
        contract = Health("http://127.0.0.1:4398/healthz", {"status": "ok", "phase": "ready"})
        self.assertEqual(contract.validate({"status": "ok", "phase": "ready"})["phase"], "ready")
        with self.assertRaises(RuntimeError):
            contract.validate({"status": "ok", "phase": "starting"})
        with self.assertRaises(ValueError):
            Health("file:///run/secrets/token", {})
        with self.assertRaises(ValueError):
            Health("http://127.0.0.1:4398/healthz", [])

    def test_explicit_status_only_contract_accepts_empty_200_not_errors(self):
        class EmptyHealth(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200 if self.path == '/healthz' else 503)
                self.end_headers()
            def log_message(self, *args):
                pass
        server = ThreadingHTTPServer(('127.0.0.1', 0), EmptyHealth)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = 'http://127.0.0.1:' + str(server.server_port)
            self.assertEqual(Health(url + '/healthz', {}, status_only=True).read(), {})
            with self.assertRaises(HTTPError):
                Health(url + '/unready', {}, status_only=True).read()
            with self.assertRaises(json.JSONDecodeError):
                Health(url + '/healthz', {}).read()
            with self.assertRaises(ValueError):
                Health(url, {'status': 'ok'}, status_only=True)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_package_canary_deployment_is_pinned_without_input_override(self):
        ref = "git+file:///checked/repository?rev=" + "a" * 40
        expression = package_canary_expression(ref, "host", "canary", "x86_64-linux", "tests/fixtures/broken/default.nix")
        self.assertIn('builtins.getFlake "' + ref + '"', expression)
        self.assertIn('fixture = f.outPath + "/tests/fixtures/broken/default.nix"', expression)
        self.assertIn("serviceAppCanaryDeployment", expression)
        self.assertNotIn("override-input", expression)
        with self.assertRaises(ValueError):
            package_canary_expression(ref, "host", "canary", "x86_64-linux", "../outside.nix")
        with self.assertRaises(ValueError):
            package_canary_expression(ref, "host", "canary", "x86_64-linux", "/outside.nix")

    def test_migration_includes_timers_but_recovers_only_previously_active_units(self):
        primary = ["pace.service", "pace-proxy.service"]
        auxiliary = ["pace-sync.service", "pace-sync.timer"]
        self.assertEqual(migration_source_units(primary, auxiliary), primary + auxiliary)
        states = {"pace.service": True, "pace-proxy.service": True, "pace-sync.service": False, "pace-sync.timer": True}
        self.assertEqual(require_cutover_ready({unit: states[unit] for unit in primary}, False), primary)
        self.assertEqual(recovery_units(states, True), primary + ["pace-sync.timer"])
        for invalid_primary, invalid_auxiliary in (([], []), (["pace.timer"], []), (primary, ["../pace.timer"]), (primary, ["pace.service"])):
            with self.assertRaises(ValueError):
                migration_source_units(invalid_primary, invalid_auxiliary)

    def test_declared_units_follow_installed_single_and_paired_manifests(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / "app.json"
            for units in (["app.service"], ["app.service", "app-tsnet.service"]):
                manifest.write_text(json.dumps(units))
                self.assertEqual(declared_units("app", root), units)
            for units in ([], ["other.service"], ["app-tsnet.service"], "app.service"):
                manifest.write_text(json.dumps(units))
                with self.assertRaises(ValueError):
                    declared_units("app", root)
            with self.assertRaises(FileNotFoundError):
                declared_units("missing", root)

    def test_requires_every_unit_not_any_unit(self):
        # Real process with configured status; rejects multi-unit invocations.
        status = ["sh", "-c", 'test "$#" = 3 && test "$3" = active', "unit-status"]
        self.assertFalse(all_units_active(status, []))
        self.assertTrue(all_units_active(status, ["active"]))
        self.assertFalse(all_units_active(status, ["failed"]))
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

    def test_canary_bootstrap_refuses_selecting_a_broken_fixture(self):
        command = [sys.executable, str(SCRIPTS / "service-apps-rollback-probe"),
                   "--runner-host", socket.gethostname(), "--repo", "/unused",
                   "--expected-sha", "a" * 40, "--state", "/unused", "--host", "host",
                   "--app", "canary", "--system", "x86_64-linux", "--health-url",
                   "http://127.0.0.1:4400/healthz", "--health-equals", "{}", "--output", "/unused"]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("--fixture is required", result.stderr)
        result = subprocess.run(command + ["--bootstrap-healthy", "--fixture", "broken"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("cannot select a broken fixture", result.stderr)

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
