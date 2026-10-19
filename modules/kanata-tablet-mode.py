"""Silence the built-in keyboard while a convertible is in tablet mode.

Kanata grabs every keyboard and sends all of their keys through one virtual
device. libinput can no longer suspend only the built-in keyboard in tablet
mode: it sees one keyboard, and kanata's i8042 bus type makes libinput call
that keyboard internal. modules/kanata.nix stops libinput from suspending the
kanata device, and this program does the built-in half of the job in the
kernel. It writes the input device's `inhibited` flag, which drops events
before any reader, kanata included, sees them.

Usage: kanata-tablet-mode          watch the tablet-mode switches
       kanata-tablet-mode release  clear the flag on every built-in keyboard
"""

import fcntl
import glob
import os
import select
import sys

INPUT = os.environ.get("KANATA_TABLET_MODE_SYSFS", "/sys/class/input")
DEV = os.environ.get("KANATA_TABLET_MODE_DEV", "/dev/input")

SW_TABLET_MODE = 1
BUS_I8042 = 0x11
KEY_Q, KEY_P = 16, 25  # the top letter row; libinput's keyboard test
KANATA = "kanata"  # kanata's output device name
EVIOCGSW_8 = (2 << 30) | (8 << 16) | (ord("E") << 8) | 0x1B  # EVIOCGSW(8)


def read(path):
    with open(path) as f:
        return f.read().strip()


def has_bit(mask, bit):
    """Test one bit of a sysfs capability mask: hex words, highest first."""
    words = mask.split()[::-1]
    word, offset = divmod(bit, 64)
    return word < len(words) and (int(words[word], 16) >> offset) & 1 == 1


def event_nodes():
    for node in sorted(glob.glob(os.path.join(INPUT, "event*"))):
        yield os.path.basename(node), os.path.join(node, "device")


def tablet_switches():
    found = []
    for name, device in event_nodes():
        try:
            if has_bit(read(os.path.join(device, "capabilities/sw")), SW_TABLET_MODE):
                found.append(name)
        except OSError:
            continue
    return found


def builtin_keyboards():
    """The `inhibited` files of every i8042 keyboard except kanata's."""
    found = []
    for _, device in event_nodes():
        try:
            if int(read(os.path.join(device, "id/bustype")), 16) != BUS_I8042:
                continue
            if read(os.path.join(device, "name")) == KANATA:
                continue
            keys = read(os.path.join(device, "capabilities/key"))
        except OSError:
            continue
        if all(has_bit(keys, key) for key in range(KEY_Q, KEY_P + 1)):
            found.append(os.path.join(device, "inhibited"))
    return found


def inhibit(on):
    for path in builtin_keyboards():
        with open(path, "w") as f:
            f.write("1" if on else "0")
        print(f"{'inhibited' if on else 'released'} {path}", flush=True)


def in_tablet_mode(fds):
    state = bytearray(8)
    for fd in fds:
        fcntl.ioctl(fd, EVIOCGSW_8, state)
        if (state[0] >> SW_TABLET_MODE) & 1:
            return True
    return False


def main(argv):
    if argv[1:] == ["release"]:
        inhibit(False)
        return 0

    switches = tablet_switches()
    if not switches:
        # intel-hid can create its switch device only at the first fold.
        # udev starts this service again when a switch appears.
        print("no tablet-mode switch yet", flush=True)
        return 0

    fds = [os.open(os.path.join(DEV, name), os.O_RDONLY) for name in switches]
    print(f"watching {', '.join(switches)}", flush=True)
    state = None
    while True:
        now = in_tablet_mode(fds)
        if now != state:
            inhibit(now)
            state = now
        ready, _, _ = select.select(fds, [], [])
        for fd in ready:
            # A removed device raises here. systemd restarts the service.
            os.read(fd, 24 * 64)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
