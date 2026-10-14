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

    def test_unrelated_setting_addition_is_allowed(self):
        path = self.dist / "core/settings-manager.js"
        path.write_text(path.read_text().replace("    getDefaultModel() {", "    getNewSetting() { return this.settings.newSetting; }\n    getDefaultModel() {"))
        policy.patch(self.dist)
        self.assertIn("getNewSetting", path.read_text())

    def test_each_changed_method_is_rejected(self):
        path = self.dist / "core/settings-manager.js"
        original = path.read_text()
        changes = {
            "FileSettingsStorage.withLock": ('const fileExists = existsSync(path);', 'const fileExists = false;'),
            "SettingsManager.loadFromStorage": ('JSON.parse(stripBom(content))', 'JSON.parse(content)'),
            "SettingsManager.tryLoadFromStorage": ('return { settings: {}, error: error };', 'return { settings: {}, error: null };'),
        }
        for name, (before, _) in policy.REGIONS.items():
            with self.subTest(region=name):
                old, new = changes[name]
                path.write_text(original.replace(before, before.replace(old, new, 1), 1))
                with self.assertRaisesRegex(SystemExit, "patch context changed"):
                    policy.patch(self.dist)

    def test_each_missing_method_is_rejected(self):
        path = self.dist / "core/settings-manager.js"
        original = path.read_text()
        for name, (before, _) in policy.REGIONS.items():
            with self.subTest(region=name):
                path.write_text(original.replace(before, "", 1))
                with self.assertRaisesRegex(SystemExit, "patch context changed"):
                    policy.patch(self.dist)

    def test_duplicate_method_is_rejected(self):
        path = self.dist / "core/settings-manager.js"
        path.write_text(path.read_text() + "\n" + policy.LOAD)
        with self.assertRaisesRegex(SystemExit, "patch context changed"):
            policy.patch(self.dist)

    def test_project_lock_retry_changes_are_allowed(self):
        path = self.dist / "core/settings-manager.js"
        path.write_text(path.read_text().replace("const delayMs = 20;", "const delayMs = 30;"))
        policy.patch(self.dist)

    def test_bundled_entrypoint_is_rejected(self):
        (self.dist / "cli.js").write_text("// new compiled bundle\n")
        with self.assertRaisesRegex(SystemExit, "unknown CLI entry point"):
            policy.patch(self.dist)

    def test_unrelated_startup_statement_change_is_allowed(self):
        path = self.dist / "main.js"
        path.write_text(path.read_text().replace("bootstrapSettingsManager", "renamedBootstrapSettingsManager"))
        policy.patch(self.dist)

    def test_startup_import_redirect_is_rejected(self):
        path = self.dist / "main.js"
        path.write_text(path.read_text().replace('from "./core/settings-manager.js"', 'from "./unpatched-settings.mjs"'))
        with self.assertRaisesRegex(SystemExit, "startup no longer uses"):
            policy.patch(self.dist)

    def test_identical_embedded_reader_uses_same_narrow_patch(self):
        embedded = self.dist / "embedded.mjs"
        embedded.write_text((self.dist / "core/settings-manager.js").read_text())
        policy.patch(self.dist)
        self.assertIn("Global pi settings are Nix-owned and read-only", embedded.read_text())

    def test_changed_embedded_reader_is_rejected(self):
        (self.dist / "embedded.mjs").write_text("export class SettingsManager {}")
        with self.assertRaisesRegex(SystemExit, "patch context changed"):
            policy.patch(self.dist)


if __name__ == "__main__":
    unittest.main()
