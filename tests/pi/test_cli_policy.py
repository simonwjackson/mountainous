"""The redirected-reader attack must fail the same CLI guard used at install."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("cli_policy", Path(__file__).with_name("cli-policy.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
spec = importlib.util.spec_from_file_location("patch", sys.argv.pop(1))
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)
UPSTREAM = Path(sys.argv.pop(1))
SETTINGS = Path(sys.argv.pop(1))


class RedirectedReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="pi-redirected-reader-")
        cls.package = Path(cls.temp.name) / "package"
        shutil.copytree(UPSTREAM, cls.package, symlinks=True)
        for path in [cls.package, *cls.package.rglob("*")]:
            if not path.is_symlink():
                path.chmod(0o755 if path.is_dir() or path.name == "pi" else 0o644)
        dist = cls.package / "lib/node_modules/@earendil-works/pi-coding-agent/dist"
        original = (dist / "core/settings-manager.js").read_text()
        (dist / "core/alternate-settings-manager.js").write_text(original.replace("SettingsManager", "AlternateSettingsManager"))
        main = dist / "main.js"
        main.write_text('import { AlternateSettingsManager } from "./core/alternate-settings-manager.js";\n' +
                        main.read_text().replace("SettingsManager.create(", "AlternateSettingsManager.create("))
        # Keep the original import and class. The narrow layout guard accepts it.
        patcher.patch(dist)
        cli = cls.package / "bin/pi"
        cli.write_text(cli.read_text().replace(str(UPSTREAM), str(cls.package)))
        cls.cli = cli
        cls.result = guard.check_policy(cli, SETTINGS, Path(__file__).with_name("cli-probe.ts"))

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_redirected_locked_reader_is_rejected(self):
        self.assertEqual(self.result["cases"]["locked"]["exit_code"], 0)
        self.assertEqual(self.result["cases"]["locked"]["effective"], {})
        self.assertTrue(any(failure.startswith("locked:") for failure in self.result["failures"]))

    def test_redirected_invalid_readers_are_rejected(self):
        for name in ["empty", "missing", "malformed"]:
            with self.subTest(case=name):
                self.assertEqual(self.result["cases"][name]["exit_code"], 0)
                self.assertTrue(any(failure.startswith(name + ":") for failure in self.result["failures"]))

    def test_same_build_guard_returns_failure(self):
        self.assertEqual(len(self.result["failures"]), 4)
        # Execute the exact command used by installCheckPhase, not just its
        # Python function. The rejected package must make the build command fail.
        command = [sys.executable, str(Path(__file__).with_name("cli-policy.py")),
                   str(self.cli), str(SETTINGS)]
        completed = subprocess.run(command, capture_output=True, text=True, timeout=90)
        self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
        self.assertEqual(completed.stdout.count("CLI policy FAIL:"), 4)
        print(f"Redirected-reader negative guard: 4 rejections in {self.result['seconds']:.3f}s")


if __name__ == "__main__":
    unittest.main()
