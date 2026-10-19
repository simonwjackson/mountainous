"""modules/brightness.py: steps, scaling, ddcutil parsing, and sync.

The ddcutil text copies Myoko's output of 2026-10-19, with the YMK EM160TP-A
seen on two buses and answering on only one.
Run: python3 tests/test_brightness.py path/to/brightness.py
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

DETECT = """Invalid display
   I2C bus:          /dev/i2c-9
   DRM connector:    card1-eDP-1
   Monitor:          SDC::

Invalid display
   I2C bus:          /dev/i2c-10
   DRM connector:    card1-DP-1
   Monitor:          YMK:EM160TP-A:

Display 1
   I2C bus:          /dev/i2c-12
   DRM connector:    card1-DP-3
   Monitor:          YMK:EM160TP-A:

"""


def load(path, root):
    os.environ["XDG_STATE_HOME"] = os.path.join(root, "state")
    os.environ["XDG_RUNTIME_DIR"] = root
    os.environ["MOUNTAINOUS_BACKLIGHTS"] = os.path.join(root, "backlight")
    spec = importlib.util.spec_from_file_location("brightness", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeDdc:
    def __init__(self, maximum=100, fail=False):
        self.calls = []
        self.maximum = maximum
        self.fail = fail

    def __call__(self, *args):
        self.calls.append(args)
        out, code = "", 0
        if args[:1] == ("detect",):
            out = DETECT
        elif "getvcp" in args:
            out = f"VCP 10 C 2 {self.maximum}\n"
        elif "setvcp" in args and self.fail:
            code = 1
        return subprocess.CompletedProcess(args, code, out, "")

    def writes(self):
        return [a for a in self.calls if "setvcp" in a]


class Brightness(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        panel = os.path.join(self.root, "backlight", "intel_backlight")
        os.makedirs(panel)
        for name, value in [("brightness", "80"), ("max_brightness", "400")]:
            with open(os.path.join(panel, name), "w") as f:
                f.write(value + "\n")
        self.panel = os.path.join(panel, "brightness")
        self.m = load(sys.argv[1], self.root)

    def test_steps_land_on_multiples_and_stop_at_the_dim_minimum(self):
        self.assertEqual(self.m.step(20, 1), 25)
        self.assertEqual(self.m.step(22, 1), 25)
        self.assertEqual(self.m.step(22, -1), 20)
        self.assertEqual(self.m.step(5, -1), 5)
        self.assertEqual(self.m.step(100, 1), 100)

    def test_first_use_starts_from_the_panel(self):
        self.assertEqual(self.m.read_level(), 20)  # 80 of 400

    def test_a_key_press_sets_the_panel(self):
        self.m.main(["brightness", "up"])
        with open(self.panel) as f:
            self.assertEqual(f.read(), "100")  # 25% of 400
        self.m.main(["brightness", "set", "0"])
        with open(self.panel) as f:
            self.assertEqual(f.read(), "20")  # clamped to 5%

    def test_only_the_answering_display_is_used(self):
        self.assertEqual(
            self.m.parse_detect(DETECT),
            {12: {"manufacturer": "YMK", "model": "EM160TP-A"}},
        )
        self.assertEqual(self.m.parse_maximum("VCP 10 C 2 100\n"), 100)
        self.assertIsNone(self.m.parse_maximum("VCP 10 ERR\n"))

    def test_sync_writes_the_level_once_and_rewrites_after_a_rescan(self):
        fake = FakeDdc(maximum=50)
        level = [40]
        status = os.path.join(self.root, "status.json")
        monitors = self.m.Monitors(runner=fake, level=lambda: level[0], status=status)
        monitors.sync_once()
        self.assertEqual(fake.writes(), [("--bus", "12", "--noverify", "setvcp", "10", "20")])
        with open(status) as f:
            self.assertEqual(
                json.load(f),
                {"panel": True, "monitors": [{"manufacturer": "YMK", "model": "EM160TP-A"}]},
            )
        monitors.sync_once()
        self.assertEqual(len(fake.writes()), 1, "an unchanged level is not rewritten")
        level[0] = 60
        monitors.sync_once()
        self.assertEqual(fake.writes()[-1][-1], "30")
        monitors.request(rescan=True)
        monitors.sync_once()
        self.assertEqual(len(fake.writes()), 3, "a monitor that comes back is written again")

    def test_a_failed_write_forces_a_rescan(self):
        fake = FakeDdc(fail=True)
        status = os.path.join(self.root, "status.json")
        monitors = self.m.Monitors(runner=fake, level=lambda: 50, status=status)
        monitors.sync_once()
        self.assertTrue(monitors.rescan)


if __name__ == "__main__":
    unittest.main(argv=sys.argv[:1])
