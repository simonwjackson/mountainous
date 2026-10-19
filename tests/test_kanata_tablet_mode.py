"""Device selection of modules/kanata-tablet-mode.py, on a fake sysfs.

The devices copy Myoko's /proc/bus/input/devices of 2026-10-18.
Run: python3 tests/test_kanata_tablet_mode.py path/to/kanata-tablet-mode.py
"""

import importlib.util
import os
import sys
import tempfile
import unittest

LETTERS = "1c0000 0 0 0 0 1500f02000403 ff803078f870d001 febfffdffbcfffff fffffffffffffffe"
DEVICES = {
    # name, bustype, key mask, switch mask
    "event0": ("AT Translated Set 2 keyboard", "0011", LETTERS, "0"),
    "event1": ("kanata", "0011", "ffffffffffff " + LETTERS, "0"),
    "event2": ("USB Keyboard", "0003", LETTERS, "0"),
    "event3": ("Intel HID switches", "0019", "0", "2"),
    "event5": ("Lid Switch", "0019", "0", "1"),
    "event9": ("Samsung Galaxy Book Camera Lens Cover", "0019", "100000000000000 0 0 0", "200"),
    "event10": ("PS/2 Generic Mouse", "0011", "70000 0 0 0 0", "0"),
}


def load(path, root):
    os.environ["KANATA_TABLET_MODE_SYSFS"] = root
    spec = importlib.util.spec_from_file_location("kanata_tablet_mode", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Selection(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        for node, (name, bus, keys, sw) in DEVICES.items():
            device = os.path.join(self.root, node, "device")
            os.makedirs(os.path.join(device, "id"))
            os.makedirs(os.path.join(device, "capabilities"))
            for rel, text in [
                ("name", name),
                ("id/bustype", bus),
                ("capabilities/key", keys),
                ("capabilities/sw", sw),
                ("inhibited", "0"),
            ]:
                with open(os.path.join(device, rel), "w") as f:
                    f.write(text + "\n")
        self.m = load(sys.argv[1], self.root)

    def inhibited(self, node):
        with open(os.path.join(self.root, node, "device", "inhibited")) as f:
            return f.read().strip()

    def test_only_the_intel_hid_switch_reports_tablet_mode(self):
        self.assertEqual(self.m.tablet_switches(), ["event3"])

    def test_only_the_at_keyboard_is_built_in(self):
        self.assertEqual(
            self.m.builtin_keyboards(),
            [os.path.join(self.root, "event0", "device", "inhibited")],
        )

    def test_inhibit_and_release_touch_only_the_at_keyboard(self):
        self.m.inhibit(True)
        self.assertEqual(
            {node: self.inhibited(node) for node in DEVICES},
            {node: "1" if node == "event0" else "0" for node in DEVICES},
        )
        self.m.inhibit(False)
        self.assertEqual(self.inhibited("event0"), "0")


if __name__ == "__main__":
    unittest.main(argv=sys.argv[:1])
