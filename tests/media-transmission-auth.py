"""Run the production settings merge without a daemon or a fleet filesystem."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = sys.argv.pop(1)


class SettingsMerge(unittest.TestCase):
    def test_preserves_state_and_merges_both_setting_spellings(self):
        for spelling in ("rpc-password", "rpc_password"):
            with (
                self.subTest(spelling=spelling),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory)
                settings = root / "settings.json"
                original = {
                    "download-dir": "/saved/path",
                    "ratio-limit": 2.5,
                    "rpc-url": "/transmission/",
                    "unknown": {"keep": True},
                    spelling: "old",
                    spelling.replace("password", "username"): "old-user",
                }
                settings.write_text(json.dumps(original))
                settings.chmod(0o644)
                credential = root / "transmission-rpc-password"
                credential.write_text('quote" slash\\ secret\n')
                inode = settings.stat().st_ino
                owner = (settings.stat().st_uid, settings.stat().st_gid)
                env = dict(os.environ, CREDENTIALS_DIRECTORY=directory)
                for _ in range(2):
                    subprocess.run(
                        [sys.executable, SCRIPT, str(settings)], env=env, check=True
                    )
                    actual = json.loads(settings.read_text())
                    self.assertEqual(actual["rpc-password"], 'quote" slash\\ secret')
                    self.assertEqual(actual["rpc-username"], "torrents")
                    self.assertIs(actual["rpc-authentication-required"], True)
                    self.assertFalse(any(k.startswith("rpc_") for k in actual))
                    for key in ("download-dir", "ratio-limit", "rpc-url", "unknown"):
                        self.assertEqual(actual[key], original[key])
                    self.assertEqual(settings.stat().st_ino, inode)
                    self.assertEqual(
                        (settings.stat().st_uid, settings.stat().st_gid), owner
                    )
                    self.assertEqual(settings.stat().st_mode & 0o777, 0o600)

    def test_missing_or_empty_password_and_invalid_state_fail_without_writing(self):
        for content, password in (
            ("{}", None),
            ("{}", "\n"),
            ("broken", "secret"),
            ("[]", "secret"),
        ):
            with (
                self.subTest(content=content, password=password),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory)
                settings = root / "settings.json"
                settings.write_text(content)
                if password is not None:
                    (root / "transmission-rpc-password").write_text(password)
                result = subprocess.run(
                    [sys.executable, SCRIPT, str(settings)],
                    env=dict(os.environ, CREDENTIALS_DIRECTORY=directory),
                    capture_output=True,
                    check=False,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(settings.read_text(), content)


if __name__ == "__main__":
    unittest.main()
