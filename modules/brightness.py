"""One brightness level for every screen.

The brightness keys move one level, a percentage, and every screen follows it:
the laptop panel through its sysfs backlight, and every external monitor that
answers DDC/CI. The level lives in a state file on this machine. A monitor's
own value is never trusted, because another computer, or the monitor's own
buttons, may have changed it. The level is sent to a monitor whenever it
appears, when the daemon starts, and at every key press.

Usage:
  mountainous-brightness up | down    move the level one step
  mountainous-brightness set N        set the level to N percent
  mountainous-brightness get          print the level
  mountainous-brightness daemon       keep the monitors on the level

The key commands set the panel at once and then ask the daemon to update the
monitors. A DDC/CI write takes about 0.1 s, and the daemon sends only the
newest level, so a held key does not queue a write per step.
"""

import fcntl
import glob
import os
import re
import socket
import subprocess
import sys
import threading

STEP = 5
# The dim minimum: the screens never go fully dark from the keys.
MINIMUM = 5
MAXIMUM = 100

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
STATE_HOME = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
STATE = os.path.join(STATE_HOME, "mountainous", "brightness")
SOCKET = os.path.join(RUNTIME, "mountainous-brightness.sock")
BACKLIGHTS = os.environ.get("MOUNTAINOUS_BACKLIGHTS", "/sys/class/backlight")
DDCUTIL = os.environ.get("MOUNTAINOUS_DDCUTIL", "ddcutil")


def clamp(level):
    return max(MINIMUM, min(MAXIMUM, int(level)))


def step(level, direction):
    """Move one step, landing on a multiple of STEP."""
    if direction > 0:
        target = (level // STEP + 1) * STEP
    else:
        target = (-(-level // STEP) - 1) * STEP
    return clamp(target)


def scaled(level, maximum):
    """A level in percent as a raw value of a device with this maximum."""
    return max(1, round(level * maximum / 100))


# --- the panel ----------------------------------------------------------


def backlights():
    return sorted(glob.glob(os.path.join(BACKLIGHTS, "*")))


def read_int(path):
    with open(path) as f:
        return int(f.read().strip())


def panel_level():
    """The panel's level in percent, or None with no backlight."""
    for device in backlights():
        try:
            value = read_int(os.path.join(device, "brightness"))
            maximum = read_int(os.path.join(device, "max_brightness"))
        except (OSError, ValueError):
            continue
        return clamp(round(value * 100 / maximum))
    return None


def set_panel(level):
    for device in backlights():
        try:
            maximum = read_int(os.path.join(device, "max_brightness"))
            with open(os.path.join(device, "brightness"), "w") as f:
                f.write(str(scaled(level, maximum)))
        except (OSError, ValueError) as e:
            print(f"panel {device}: {e}", file=sys.stderr, flush=True)


# --- the level ----------------------------------------------------------


def update_level(change):
    """Apply change(level) to the stored level under a lock; return it."""
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "a+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        text = f.read().strip()
        if text.isdigit():
            level = clamp(int(text))
        else:
            # First use: start from wherever the panel is now.
            level = panel_level() or 50
        new = clamp(change(level))
        f.seek(0)
        f.truncate()
        f.write(f"{new}\n")
        return new


def read_level():
    return update_level(lambda level: level)


# --- external monitors over DDC/CI -------------------------------------


def run(*args):
    return subprocess.run(
        [DDCUTIL, *args], capture_output=True, text=True, timeout=20
    )


def parse_detect(text):
    """The I2C bus numbers of the valid displays in `ddcutil detect --terse`."""
    buses = []
    for block in re.split(r"\n\s*\n", text):
        lines = block.strip().splitlines()
        if not lines or not lines[0].startswith("Display "):
            continue
        for line in lines:
            match = re.search(r"I2C bus:\s*/dev/i2c-(\d+)", line)
            if match:
                buses.append(int(match.group(1)))
    return buses


def parse_maximum(text):
    """The maximum of `ddcutil getvcp 10 --terse`: `VCP 10 C <cur> <max>`."""
    match = re.search(r"VCP 10 C \d+ (\d+)", text)
    return int(match.group(1)) if match and int(match.group(1)) > 0 else None


class Monitors:
    """Keeps every DDC/CI monitor on the stored level."""

    def __init__(self, runner=run, level=read_level):
        self.runner = runner
        self.level = level
        self.wake = threading.Event()
        self.rescan = True
        self.displays = {}  # bus -> maximum
        self.sent = {}  # bus -> raw value last written

    def detect(self):
        result = self.runner("detect", "--terse")
        displays = {}
        for bus in parse_detect(result.stdout):
            maximum = parse_maximum(
                self.runner("--bus", str(bus), "getvcp", "10", "--terse").stdout
            )
            if maximum:
                displays[bus] = maximum
        self.displays = displays
        # A new or returning monitor is never assumed to be in sync.
        self.sent = {}
        print(f"monitors on i2c buses: {sorted(displays) or 'none'}", flush=True)

    def sync_once(self):
        if self.rescan:
            self.rescan = False
            self.detect()
        level = self.level()
        for bus, maximum in list(self.displays.items()):
            value = scaled(level, maximum)
            if self.sent.get(bus) == value:
                continue
            result = self.runner(
                "--bus", str(bus), "--noverify", "setvcp", "10", str(value)
            )
            if result.returncode == 0:
                self.sent[bus] = value
            else:
                print(f"i2c-{bus}: {result.stderr.strip()}", flush=True)
                self.rescan = True

    def loop(self):
        while True:
            self.wake.wait()
            self.wake.clear()
            try:
                self.sync_once()
            except Exception as e:  # keep the daemon alive
                print(f"sync failed: {e}", flush=True)
                self.rescan = True

    def request(self, rescan=False):
        if rescan:
            self.rescan = True
        self.wake.set()


def hyprland_events(monitors):
    """Rescan whenever Hyprland adds or removes a monitor."""
    while True:
        paths = sorted(
            glob.glob(os.path.join(RUNTIME, "hypr", "*", ".socket2.sock")),
            key=os.path.getmtime,
        )
        if not paths:
            threading.Event().wait(2)
            continue
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(paths[-1])
                for line in s.makefile():
                    if line.startswith(("monitoradded", "monitorremoved")):
                        monitors.request(rescan=True)
        except OSError:
            pass
        threading.Event().wait(2)


def daemon():
    monitors = Monitors()
    set_panel(read_level())
    try:
        os.unlink(SOCKET)
    except FileNotFoundError:
        pass
    server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    server.bind(SOCKET)
    threading.Thread(target=monitors.loop, daemon=True).start()
    threading.Thread(target=hyprland_events, args=(monitors,), daemon=True).start()
    monitors.request(rescan=True)
    while True:
        message = server.recv(64)
        monitors.request(rescan=message == b"rescan")


def notify(message=b"sync"):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
            s.sendto(message, SOCKET)
    except OSError:
        pass  # no daemon: the panel still changed


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    if command in ("up", "down"):
        direction = 1 if command == "up" else -1
        level = update_level(lambda level: step(level, direction))
    elif command == "set" and len(argv) == 3 and argv[2].isdigit():
        level = update_level(lambda _: int(argv[2]))
    elif command == "get":
        print(read_level())
        return 0
    elif command == "daemon":
        daemon()
        return 0
    else:
        print(__doc__, file=sys.stderr)
        return 2
    set_panel(level)
    notify()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
