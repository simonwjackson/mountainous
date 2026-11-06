#!/usr/bin/env python3
"""A virtual pointer for headless checks (wlr-virtual-pointer-unstable-v1).

A headless compositor has no pointer device, so its seat offers no pointer
and no client sees motion. This client keeps a virtual pointer alive and
reads commands from a FIFO, one per line:

    move X Y        absolute position in the output's logical px
    down / up       the left button
    middle          a middle click
    right           a right click
    wheel N         N wheel steps (negative: up)
    quit

Usage: pointer.py <fifo> <width> <height>   (needs WAYLAND_DISPLAY)
Env: WLR_PROTOCOL (wlr-virtual-pointer-unstable-v1.xml), WAYLAND_XML.
"""
import os
import sys
import tempfile
import time

fifo, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
from pywayland.scanner import Protocol  # noqa: E402

out = tempfile.mkdtemp(prefix="vptr-")
protocols = [Protocol.parse_file(f) for f in (os.environ["WAYLAND_XML"], os.environ["WLR_PROTOCOL"])]
imports = {i.name: p.name for p in protocols for i in p.interface}
os.makedirs(os.path.join(out, "proto"))
open(os.path.join(out, "proto", "__init__.py"), "w").close()
for p in protocols:
    p.output(os.path.join(out, "proto"), imports)
sys.path.insert(0, out)

from pywayland.client import Display  # noqa: E402
from proto.wayland import WlSeat  # noqa: E402
from proto.wlr_virtual_pointer_unstable_v1 import ZwlrVirtualPointerManagerV1  # noqa: E402

display = Display()
display.connect()
registry = display.get_registry()
found = {}


def on_global(reg, name, interface, version):
    if interface == "wl_seat" and "seat" not in found:
        found["seat"] = reg.bind(name, WlSeat, 1)
    elif interface == "zwlr_virtual_pointer_manager_v1":
        found["manager"] = reg.bind(name, ZwlrVirtualPointerManagerV1, 1)


registry.dispatcher["global"] = on_global
display.dispatch(block=True)
display.roundtrip()
pointer = found["manager"].create_virtual_pointer(found["seat"])
display.roundtrip()
BTN_LEFT, BTN_RIGHT, BTN_MIDDLE = 0x110, 0x111, 0x112


def now():
    return int(time.monotonic() * 1000) & 0xFFFFFFFF


def button(code, state):
    pointer.button(now(), code, state)
    pointer.frame()


with open(fifo, "r") as commands:
    print("ready", flush=True)
    for line in commands:
        part = line.split()
        if not part:
            continue
        if part[0] == "quit":
            break
        if part[0] == "move":
            pointer.motion_absolute(now(), int(float(part[1])), int(float(part[2])), width, height)
            pointer.frame()
        elif part[0] == "down":
            button(BTN_LEFT, 1)
        elif part[0] == "up":
            button(BTN_LEFT, 0)
        elif part[0] == "middle":
            button(BTN_MIDDLE, 1)
            button(BTN_MIDDLE, 0)
        elif part[0] == "right":
            button(BTN_RIGHT, 1)
            button(BTN_RIGHT, 0)
        elif part[0] == "wheel":
            steps = int(part[1])
            pointer.axis_source(0)
            pointer.axis_discrete(now(), 0, 15.0 * steps, steps)
            pointer.frame()
        display.flush()
        display.roundtrip()
pointer.destroy()
display.flush()
