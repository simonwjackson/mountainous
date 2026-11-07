import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("app_update", Path(__file__).parents[1] / "scripts/app-update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class AppUpdateTests(unittest.TestCase):
    def test_original_ref_tracks_branch_not_old_revision(self):
        self.assertEqual(updater.input_ref({"type": "github", "owner": "a", "repo": "b", "ref": "main", "rev": "old"}), "github:a/b/main")

    def test_unknown_transport_is_rejected(self):
        with self.assertRaises(ValueError):
            updater.input_ref({"type": "path"})

    def test_no_version_downgrade(self):
        with self.assertRaises(ValueError):
            updater.require_not_downgrade({"version": "2", "lastModified": 1}, {"version": "1", "lastModified": 2}, lambda a, b: int(a) - int(b))

    def test_no_revision_downgrade(self):
        with self.assertRaises(ValueError):
            updater.require_not_downgrade({"version": "1", "lastModified": 2}, {"version": "2", "lastModified": 1}, lambda a, b: int(a) - int(b))

    def test_same_revision_can_retry_failed_hosts(self):
        release = {"version": "1", "lastModified": 2}
        updater.require_not_downgrade(release, release, lambda a, b: 0)

    def test_failure_does_not_skip_later_hosts(self):
        def command(host):
            subprocess.run(["sh", "-c", "exit 1" if host == "offline" else "exit 0"], check=True)
        results = updater.deploy_hosts(["before", "offline", "after"], command)
        self.assertEqual([results[h]["status"] for h in results], ["deployed", "failed", "deployed"])

    def test_builds_are_bounded_and_do_not_delegate(self):
        command = updater.build_command("x86_64-linux", ".#checks.x86_64-linux.app-pi", [], {"hostName": "fuji"})
        self.assertIn("2", command[command.index("--max-jobs") + 1:])
        self.assertEqual(command[command.index("--option") + 1:command.index("--option") + 3], ["builders", ""])
        self.assertNotIn("--store", command)

    def test_arm_builds_on_target_without_builder_hops(self):
        command = updater.build_command("aarch64-linux", ".#checks.aarch64-linux.app-pi", [], {"hostName": "fuji"})
        self.assertEqual(command[command.index("--store") + 1], "ssh-ng://simon@fuji")
        self.assertIn("--eval-store", command)
        self.assertEqual(command[command.index("--option") + 1:command.index("--option") + 3], ["builders", ""])

    def test_receipt_is_private_and_atomic(self):
        import os
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.json"
            previous = os.umask(0o077)
            try:
                updater.write_json(path, {"rev": "accepted"})
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(updater.read_json(path)["rev"], "accepted")
                self.assertFalse(path.with_suffix(".tmp").exists())
            finally:
                os.umask(previous)


if __name__ == "__main__":
    unittest.main()
