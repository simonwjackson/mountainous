#!/usr/bin/env python3
"""A virtual keyboard for headless checks (virtual-keyboard-unstable-v1).

One keyboard for the whole run, so the surface that has the keyboard keeps
it between keys (a new wtype keyboard per key loses keys while the client
loads its keymap). Reads commands from a FIFO, one per line, and exits
when the FIFO closes (the test's end) or on "quit":

    key NAME        press and release (Up, Down, Left, Right, Tab, Return,
                    Escape, Delete, F2, Home, End, or a letter a-z)
    shift NAME      the same with Shift held

Usage: keyboard.py <fifo>   (needs WAYLAND_DISPLAY, WAYLAND_XML,
XKB_LIB: libxkbcommon.so, XKB_CONFIG_ROOT: xkeyboard-config's xkb dir)
"""
import ctypes
import os
import sys
import tempfile
import time

fifo = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
from pywayland.scanner import Protocol  # noqa: E402

out = tempfile.mkdtemp(prefix="vkbd-")
protocols = [Protocol.parse_file(f) for f in (os.environ["WAYLAND_XML"], os.path.join(here, "virtual-keyboard-unstable-v1.xml"))]
imports = {i.name: p.name for p in protocols for i in p.interface}
os.makedirs(os.path.join(out, "proto"))
open(os.path.join(out, "proto", "__init__.py"), "w").close()
for p in protocols:
    p.output(os.path.join(out, "proto"), imports)
sys.path.insert(0, out)

from pywayland.client import Display  # noqa: E402
from proto.wayland import WlSeat  # noqa: E402
from proto.virtual_keyboard_unstable_v1 import ZwpVirtualKeyboardManagerV1  # noqa: E402

# The US keymap, as text, from libxkbcommon itself.
xkb = ctypes.CDLL(os.environ["XKB_LIB"])
xkb.xkb_context_new.restype = ctypes.c_void_p
xkb.xkb_keymap_new_from_names.restype = ctypes.c_void_p
xkb.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
xkb.xkb_keymap_get_as_string.restype = ctypes.c_void_p
xkb.xkb_keymap_get_as_string.argtypes = [ctypes.c_void_p, ctypes.c_int]
context = xkb.xkb_context_new(0)
keymap = xkb.xkb_keymap_new_from_names(context, None, 0)
if not keymap:
    raise SystemExit("no keymap (XKB_CONFIG_ROOT?)")
text = ctypes.string_at(xkb.xkb_keymap_get_as_string(keymap, 1)) + b"\0"
keymap_file = tempfile.TemporaryFile()
keymap_file.write(text)
keymap_file.flush()

display = Display()
display.connect()
registry = display.get_registry()
found = {}


def on_global(reg, name, interface, version):
    if interface == "wl_seat" and "seat" not in found:
        found["seat"] = reg.bind(name, WlSeat, 1)
    elif interface == "zwp_virtual_keyboard_manager_v1":
        found["manager"] = reg.bind(name, ZwpVirtualKeyboardManagerV1, 1)


registry.dispatcher["global"] = on_global
display.dispatch(block=True)
display.roundtrip()
keyboard = found["manager"].create_virtual_keyboard(found["seat"])
keyboard.keymap(1, keymap_file.fileno(), len(text))
display.roundtrip()

# evdev key codes.
CODES = {"Escape": 1, "Tab": 15, "Return": 28, "Up": 103, "Down": 108, "Left": 105, "Right": 106,
         "Delete": 111, "F2": 60, "Home": 102, "End": 107, "space": 57, "Shift_L": 42}
for letter, code in zip("qwertyuiop", range(16, 26)):
    CODES[letter] = code
for letter, code in zip("asdfghjkl", range(30, 39)):
    CODES[letter] = code
for letter, code in zip("zxcvbnm", range(44, 51)):
    CODES[letter] = code


def now():
    return int(time.monotonic() * 1000) & 0xFFFFFFFF


def tap(code, shift=False):
    if shift:
        keyboard.key(now(), CODES["Shift_L"], 1)
        keyboard.modifiers(1, 0, 0, 0)
    keyboard.key(now(), code, 1)
    display.roundtrip()
    keyboard.key(now(), code, 0)
    if shift:
        keyboard.key(now(), CODES["Shift_L"], 0)
        keyboard.modifiers(0, 0, 0, 0)
    display.roundtrip()


with open(fifo, "r") as commands:
    print("ready", flush=True)
    for line in commands:
        part = line.split()
        if len(part) < 1:
            continue
        if part[0] == "quit":
            break
        if part[0] in ("key", "shift") and len(part) > 1 and part[1] in CODES:
            tap(CODES[part[1]], part[0] == "shift")
        display.flush()
keyboard.destroy()
display.flush()
