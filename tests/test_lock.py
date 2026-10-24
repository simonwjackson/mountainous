#!/usr/bin/env python3
"""Focused public-contract tests for the lock planner, CLI and fallback wrapper."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(sys.argv.pop(1)).resolve()
sys.path.insert(0, str(SOURCE))
import configure  # noqa: E402
import lockplan  # noqa: E402

PANEL = dict(name="eDP-1", width=2880, height=1800, scale=1.5, focused=False)
EXTERNAL = dict(name="DP-3", width=1920, height=1080, scale=1, focused=True)


class LockConfigTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.art = self.root / "art"
        self.art.mkdir()
        for app in lockplan.PAL:
            for variant in ("regular", "compact"):
                for scale in lockplan.PREBUILT_SCALES:
                    (self.art / f"dialog-{app}-{variant}-s{scale}.png").touch()
        self.state = self.root / "state/mountainous"
        self.state.mkdir(parents=True)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.monitors = self.root / "monitors.json"
        self.monitors.write_text(json.dumps([PANEL, EXTERNAL]))
        self.env = dict(
            os.environ,
            XDG_STATE_HOME=str(self.state.parent),
            XDG_RUNTIME_DIR=str(self.runtime),
        )

    def wrapper_shell(self):
        return (
            (SOURCE / "mountainous-lock.sh")
            .read_text()
            .replace("@configure@", str(SOURCE / "configure.py"))
            .replace("@art@", str(self.art))
            .replace("@fallback@", str(SOURCE / "hyprlock-fallback.conf"))
        )

    def run_config(self):
        # Render through the shipped wrapper. This hyprlock consumer prints the
        # supplied config rather than opening a session-lock surface in a test.
        binary = self.root / "preview-bin"
        binary.mkdir(exist_ok=True)
        consumer = binary / "hyprlock"
        consumer.write_text(f'#!{shutil.which("bash")}\ncat "$2"\n')
        consumer.chmod(0o755)
        result = subprocess.run(
            [
                "bash",
                "-euo",
                "pipefail",
                "-c",
                self.wrapper_shell(),
                "mountainous-lock",
                "--monitors-json",
                str(self.monitors),
            ],
            env=dict(self.env, PATH=f"{binary}:{os.environ['PATH']}"),
            text=True,
            capture_output=True,
            check=True,
        )
        return result.stdout

    def test_all_four_appearance_combinations_and_win98(self):
        for theme, extra, app in (
            ("light", "off", "light"),
            ("light", "on", "light"),
            ("dark", "off", "grey"),
            ("dark", "on", "extra"),
        ):
            with self.subTest(theme=theme, extra=extra):
                (self.state / "theme").write_text(theme)
                (self.state / "theme-extra").write_text(extra)
                (self.state / "theme-name").write_text("win98")
                conf = self.run_config()
                self.assertEqual(conf.count("input-field {"), 2)
                self.assertIn(f"dialog-{app}-", conf)
                self.assertIn("capslock_color =", conf)
                self.assertIn("fail_timeout = 3000", conf)
                self.assertIn("Wrong password.", conf)
                self.assertIn("1 failed attempt", conf)
                self.assertNotIn("/sys/class/leds", conf)
                if app == "extra":
                    self.assertIn("color = rgb(000000)", conf)
                    self.assertNotIn("bg-peaks", conf)
                    self.assertIn("compact", conf)

    def test_missing_state_and_invalid_preferences_use_defaults(self):
        self.assertIn("dialog-grey-", self.run_config())
        (self.state / "theme").write_text("unknown")
        (self.state / "theme-extra").write_text("unknown")
        self.assertIn("dialog-grey-", self.run_config())

    def test_monitor_selection_and_physical_geometry(self):
        monitors = configure.monitors_from_json(
            [PANEL, EXTERNAL, dict(EXTERNAL, name="HDMI-A-1", focused=False)]
        )
        widgets = lockplan.plan(monitors, "light", "peaks")
        fields = [w for w in widgets if w["type"] == "input-field"]
        self.assertEqual([w["monitor"] for w in fields], ["eDP-1", "DP-3"])
        self.assertEqual(
            (fields[0]["x"], fields[0]["y"], fields[0]["w"], fields[0]["h"]),
            (1259, 638, 450, 36),
        )
        self.assertEqual(len([w for w in widgets if w["type"] == "background"]), 3)
        no_focus = configure.monitors_from_json([dict(EXTERNAL, focused=False)])
        self.assertTrue(no_focus[0]["focused"])

    def test_rotated_scale_cache_and_fit_ladder(self):
        for width, height, scale in (
            (2880, 1800, 1.5),
            (1920, 1080, 1),
            (3840, 2160, 2),
            (2560, 1600, 1.25),
            (1800, 2880, 1.5),
            (1280, 800, 1),
            (480, 320, 1),
            (400, 240, 1),
            (1920, 1080, 1.6),
        ):
            widgets = lockplan.plan(
                [dict(EXTERNAL, width=width, height=height, scale=scale)],
                "light",
                "peaks",
            )
            image = next(w for w in widgets if w["type"] == "image")
            self.assertLessEqual(image["w"], width)
            self.assertLessEqual(image["h"], height)
            self.assertEqual(image["scale_mismatch"], scale == 1.6)
            if width == 400:
                self.assertIn("compact", image["path"])
        rotated = lockplan.plan([dict(EXTERNAL, transform=1)], "light", "peaks")[0]
        self.assertEqual((rotated["gen"]["w"], rotated["gen"]["h"]), (1080, 1920))
        other_scale = lockplan.plan([dict(EXTERNAL, scale=1.25)], "light", "peaks")[0]
        self.assertNotEqual(
            other_scale["path"], lockplan.plan([EXTERNAL], "light", "peaks")[0]["path"]
        )

    def test_rejects_bad_ipc_before_generating_files(self):
        for data in (
            [],
            {},
            [dict(PANEL, name="x\ninput-field {")],
            [dict(PANEL, width=-1)],
            [dict(PANEL, scale=float("nan"))],
            [dict(PANEL, height=True)],
            [dict(PANEL, transform=8)],
            [dict(PANEL, focused="true")],
            [PANEL, PANEL],
        ):
            with self.subTest(data=data), self.assertRaises(ValueError):
                configure.monitors_from_json(data)

    def test_session_instance_is_explicit_and_fallback_really_runs(self):
        # Exercise the shipped shell with real executable recorders, not a live
        # compositor or PAM. The production template pins these programs in PATH.
        binary = self.root / "bin"
        binary.mkdir()
        calls = self.root / "calls"
        (binary / "hyprctl").write_text(
            f'#!{shutil.which("bash")}\nprintf "%s\\n" "$*" > "$IPC_CALLS"\nexit 1\n'
        )
        (binary / "hyprlock").write_text(
            f'#!{shutil.which("bash")}\nprintf "%s\\n" "$*" >> "$LOCK_CALLS"\n'
        )
        for path in binary.iterdir():
            path.chmod(0o755)
        fallback = SOURCE / "hyprlock-fallback.conf"
        shell = self.wrapper_shell()
        env = dict(
            self.env,
            PATH=f"{binary}:{os.environ['PATH']}",
            HYPRLAND_INSTANCE_SIGNATURE="nested-test-not-zero",
            IPC_CALLS=str(calls),
            LOCK_CALLS=str(self.root / "lock-calls"),
        )
        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", shell],
            env=env,
            check=True,
            capture_output=True,
        )
        self.assertEqual(
            calls.read_text().strip(), "--instance nested-test-not-zero -j monitors"
        )
        self.assertEqual(
            (self.root / "lock-calls").read_text().strip(), f"--config {fallback}"
        )
        # A generated config rejected by hyprlock gets a second, static attempt.
        (binary / "hyprlock").write_text(
            f'#!{shutil.which("bash")}\nprintf "%s\\n" "$*" >> "$LOCK_CALLS"\n'
            'case "$2" in */mountainous-lock/hyprlock.conf) exit 1;; esac\n'
        )
        subprocess.run(
            [
                "bash",
                "-euo",
                "pipefail",
                "-c",
                shell,
                "mountainous-lock",
                "--monitors-json",
                str(self.monitors),
            ],
            env=env,
            check=True,
            capture_output=True,
        )
        lock_calls = (self.root / "lock-calls").read_text().splitlines()
        self.assertTrue(lock_calls[-2].endswith("/mountainous-lock/hyprlock.conf"))
        self.assertEqual(lock_calls[-1], f"--config {fallback}")
        # Even an import/configurator failure reaches fallback.
        shell = shell.replace(
            str(SOURCE / "configure.py"), str(self.root / "missing.py")
        )
        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", shell],
            env=env,
            check=True,
            capture_output=True,
        )
        self.assertEqual(len((self.root / "lock-calls").read_text().splitlines()), 4)
        # Mutex errors must lock through fallback; contention alone is a no-op.
        flock = binary / "flock"
        flock.write_text(f"#!{shutil.which('bash')}\nexit 42\n")
        flock.chmod(0o755)
        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", shell],
            env=env,
            check=True,
            capture_output=True,
        )
        self.assertEqual(len((self.root / "lock-calls").read_text().splitlines()), 5)
        flock.write_text(f"#!{shutil.which('bash')}\nexit 75\n")
        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", shell],
            env=env,
            check=True,
            capture_output=True,
        )
        self.assertEqual(len((self.root / "lock-calls").read_text().splitlines()), 5)


if __name__ == "__main__":
    unittest.main()
