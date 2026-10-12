#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""The second screen's placement and its disconnect rule, without Hyprland."""
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

SOURCE = Path(__file__).parent.parent / "modules/second-screen.py"
spec = importlib.util.spec_from_file_location("second_screen", SOURCE)
screen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen)

# Myoko's panel as `hyprctl -j monitors` reports it.
PANEL = screen.Panel(x=0, y=0, width=2880, height=1800, scale=1.5)


class Placement(unittest.TestCase):
    def test_tablet_sits_centred_under_the_panel(self):
        # Galaxy Tab S11 Ultra, native resolution.
        rule = screen.plan(PANEL, 2960, 1848, 60)
        self.assertEqual(rule.scale, "1.600000")
        self.assertEqual((rule.logical_width, rule.logical_height), (1850, 1155))
        self.assertEqual((rule.x, rule.y), (35, 1200))

    def test_scale_is_always_legal(self):
        # Hyprland rejects a scale that leaves fractional logical pixels.
        for width, height in ((2960, 1848), (2560, 1600), (1920, 1200), (2000, 1200), (2800, 1752), (1366, 768)):
            rule = screen.plan(PANEL, width, height, 60)
            self.assertEqual(width * 120 % rule.scale_n, 0, (width, height))
            self.assertEqual(height * 120 % rule.scale_n, 0, (width, height))

    def test_same_logical_height_gives_the_same_width(self):
        rule = screen.plan(PANEL, 2560, 1600, 60)
        self.assertEqual((rule.logical_width, rule.logical_height), (1920, 1200))
        self.assertEqual((rule.x, rule.y), (0, 1200))

    def test_small_client_is_never_magnified(self):
        rule = screen.plan(PANEL, 1280, 800, 60)
        self.assertEqual(rule.scale_n, 120)
        self.assertEqual((rule.x, rule.y), (320, 1200))

    def test_wider_client_starts_at_the_panel_edge(self):
        rule = screen.plan(PANEL, 3440, 1440, 60)
        self.assertGreater(rule.logical_width, PANEL.logical_width)
        self.assertEqual((rule.x, rule.y), (0, 1200))

    def test_panel_offset_carries_over(self):
        moved = screen.Panel(x=100, y=50, width=2880, height=1800, scale=1.5)
        rule = screen.plan(moved, 2960, 1848, 60)
        self.assertEqual((rule.x, rule.y), (135, 1250))

    def test_rule_is_lua_hyprland_can_read(self):
        text = screen.plan(PANEL, 2960, 1848, 60).lua()
        self.assertIn('output   = "SUNSHINE"', text)
        self.assertIn('mode     = "2960x1848@60"', text)
        self.assertIn('position = "35x1200"', text)

    def test_panel_is_the_internal_one(self):
        panel = screen.pick_panel([
            {"name": "SUNSHINE", "x": 0, "y": 1200, "width": 2960, "height": 1848, "scale": 1.6},
            {"name": "DP-3", "x": 1920, "y": 0, "width": 2560, "height": 1440, "scale": 1.0},
            {"name": "eDP-1", "x": 0, "y": 0, "width": 2880, "height": 1800, "scale": 1.5},
        ])
        self.assertEqual(panel, PANEL)

    def test_bad_client_size_is_refused(self):
        good = {"SUNSHINE_CLIENT_WIDTH": "2960", "SUNSHINE_CLIENT_HEIGHT": "1848", "SUNSHINE_CLIENT_FPS": "60"}
        self.assertEqual(screen.client_size(good), (2960, 1848, 60))
        for key, value in (("SUNSHINE_CLIENT_WIDTH", ""), ("SUNSHINE_CLIENT_HEIGHT", "0"), ("SUNSHINE_CLIENT_FPS", "x")):
            with self.assertRaises(screen.Refused):
                screen.client_size({**good, key: value})

    def test_live_monitor_matches_its_rule(self):
        rule = screen.plan(PANEL, 2960, 1848, 60)
        live = {"width": 2960, "height": 1848, "x": 35, "y": 1200, "scale": 1.6}
        self.assertTrue(screen.matches(rule, live))
        self.assertFalse(screen.matches(rule, {**live, "x": 1920, "y": 0}))


LOG = """\
[2026-10-12 10:00:00.000]: Info: CLIENT CONNECTED
[2026-10-12 10:00:09.000]: Info: CLIENT DISCONNECTED
[2026-10-12 10:01:00.000]: Info: Executing Do Cmd: [/bin/mountainous-second-screen attach]
[2026-10-12 10:01:00.100]: Info: Executing: [/bin/mountainous-second-screen hold] in [/]
[2026-10-12 10:01:00.900]: Info: CLIENT CONNECTED
"""


class Disconnect(unittest.TestCase):
    def test_only_this_launch_counts(self):
        lines = screen.lines_since_launch(LOG)
        self.assertEqual(lines, ["[2026-10-12 10:01:00.900]: Info: CLIENT CONNECTED"])

    def test_waits_out_the_grace_period(self):
        tracker = screen.Tracker(now=0, grace=15)
        tracker.seen("Info: CLIENT CONNECTED", 1)
        tracker.seen("Info: CLIENT DISCONNECTED", 100)
        self.assertFalse(tracker.expired(114))
        self.assertTrue(tracker.expired(115))

    def test_reconnect_inside_the_grace_keeps_the_screen(self):
        tracker = screen.Tracker(now=0, grace=15)
        tracker.seen("Info: CLIENT CONNECTED", 1)
        tracker.seen("Info: CLIENT DISCONNECTED", 100)
        tracker.seen("Info: CLIENT CONNECTED", 110)
        self.assertFalse(tracker.expired(1000))

    def test_ping_timeout_counts_as_gone(self):
        tracker = screen.Tracker(now=0, grace=15)
        tracker.seen("Info: CLIENT CONNECTED", 1)
        tracker.seen("Info: 100.80.57.45: Ping Timeout", 50)
        # Sunshine may also log the disconnect for the same session.
        tracker.seen("Info: CLIENT DISCONNECTED", 51)
        self.assertEqual(tracker.clients, 0)
        self.assertTrue(tracker.expired(65))

    def test_streaming_never_expires(self):
        tracker = screen.Tracker(now=0, grace=15, first_connect=60)
        tracker.seen("Info: CLIENT CONNECTED", 1)
        self.assertFalse(tracker.expired(100000))

    def test_a_client_that_never_arrives_is_given_up(self):
        tracker = screen.Tracker(now=0, grace=15, first_connect=60)
        self.assertFalse(tracker.expired(59))
        self.assertTrue(tracker.expired(60))


class Hold(unittest.TestCase):
    """The real `hold` loop against a log file that Sunshine would write."""

    def test_hold_exits_after_the_client_leaves(self):
        with tempfile.TemporaryDirectory() as home:
            log = Path(home) / ".config/sunshine/sunshine.log"
            log.parent.mkdir(parents=True)
            log.write_text(LOG)
            # No hyprctl on PATH: hold must still finish when it cannot
            # reach a compositor to remove the output from.
            env = {**os.environ, "HOME": home, "MOUNTAINOUS_SECOND_SCREEN_GRACE": "1",
                   "PATH": "/nonexistent", "XDG_RUNTIME_DIR": home}
            env.pop("XDG_CONFIG_HOME", None)
            proc = subprocess.Popen([sys.executable, str(SOURCE), "hold"], env=env,
                                    stdout=subprocess.PIPE, text=True)
            try:
                with self.assertRaises(subprocess.TimeoutExpired):
                    proc.wait(timeout=2)  # still streaming
                with log.open("a") as handle:
                    handle.write("[2026-10-12 10:05:00.000]: Info: CLIENT DISCONNECTED\n")
                out, _ = proc.communicate(timeout=5)
            finally:
                proc.kill()
            self.assertEqual(proc.returncode, 0)
            self.assertIn("client gone for 1s", out)
            self.assertIn("no Hyprland to detach from", out)


if __name__ == "__main__":
    unittest.main(verbosity=1)
