"""Use the real upstream dist tree to prove that patch drift fails closed."""
import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("policy_patch", sys.argv.pop(1))
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)
UPSTREAM = Path(sys.argv.pop(1))


class PolicyPatchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.dist = Path(self.directory.name) / "dist"
        shutil.copytree(UPSTREAM, self.dist)
        self.dist.chmod(0o755)
        for path in self.dist.rglob("*"):
            path.chmod(0o755 if path.is_dir() else 0o644)

    def tearDown(self):
        self.directory.cleanup()

    def test_reviewed_code_applies(self):
        policy.patch(self.dist)
        self.assertIn("Global pi settings are Nix-owned and read-only", (self.dist / "core/settings-manager.js").read_text())

    def test_any_settings_module_drift_is_rejected(self):
        path = self.dist / "core/settings-manager.js"
        path.write_text(path.read_text() + "\n// upstream change\n")
        with self.assertRaisesRegex(SystemExit, "upstream SettingsManager changed"):
            policy.patch(self.dist)

    def test_bundled_entrypoint_is_rejected(self):
        (self.dist / "cli.js").write_text("// new compiled bundle\n")
        with self.assertRaisesRegex(SystemExit, "unbundled entry point"):
            policy.patch(self.dist)

    def test_startup_reader_change_is_rejected(self):
        path = self.dist / "main.js"
        path.write_text(path.read_text().replace("const bootstrapSettingsManager = SettingsManager.create", "const bootstrapSettingsManager = NewSettings.create"))
        with self.assertRaisesRegex(SystemExit, "startup no longer uses"):
            policy.patch(self.dist)

    def test_startup_import_redirect_is_rejected(self):
        path = self.dist / "main.js"
        path.write_text(path.read_text().replace('from "./core/settings-manager.js"', 'from "./unpatched-settings.mjs"'))
        with self.assertRaisesRegex(SystemExit, "startup no longer uses"):
            policy.patch(self.dist)

    def test_embedded_unpatched_reader_is_rejected(self):
        (self.dist / "embedded.mjs").write_text("export class SettingsManager {}")
        with self.assertRaisesRegex(SystemExit, "embedded/bundled"):
            policy.patch(self.dist)


if __name__ == "__main__":
    unittest.main()
