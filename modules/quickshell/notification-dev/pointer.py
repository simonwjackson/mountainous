#!/usr/bin/env python3
"""A virtual pointer for the headless capture session. Development only.

Headless sway has no input devices, and a one-shot tool such as wlrctl
removes its device before Qt has bound the pointer, so its clicks are lost.
This client keeps one zwlr_virtual_pointer_v1 alive for as long as stdin
stays open. It speaks the Wayland wire protocol directly, so it needs no
library.

    pointer.py WIDTH HEIGHT < commands

Commands, one per line, in layout coordinates (logical pixels):
    move X Y     put the pointer at X, Y
    down | up    press or release the left button
    click        down, then up
"""

import os
import socket
import struct
import sys
import time

BTN_LEFT = 0x110


class Wire:
    def __init__(self):
        path = os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.next_id = 2
        self.buffer = b""

    def new_id(self):
        value = self.next_id
        self.next_id += 1
        return value

    def send(self, obj, opcode, payload=b""):
        size = 8 + len(payload)
        self.sock.sendall(struct.pack("<II", obj, (size << 16) | opcode) + payload)

    @staticmethod
    def string(text):
        data = text.encode() + b"\0"
        return struct.pack("<I", len(data)) + data + b"\0" * (-len(data) % 4)

    def events(self):
        while True:
            while len(self.buffer) >= 8:
                obj, word = struct.unpack_from("<II", self.buffer)
                size = word >> 16
                if len(self.buffer) < size:
                    break
                body = self.buffer[8:size]
                self.buffer = self.buffer[size:]
                yield obj, word & 0xFFFF, body
            chunk = self.sock.recv(65536)
            if not chunk:
                return
            self.buffer += chunk

    def roundtrip(self, on_event):
        callback = self.new_id()
        self.send(1, 0, struct.pack("<I", callback))  # wl_display.sync
        for obj, opcode, body in self.events():
            if obj == 1 and opcode == 0:
                raise SystemExit("wayland error: " + repr(body))
            if obj == callback:
                return
            on_event(obj, opcode, body)


def main():
    width, height = int(sys.argv[1]), int(sys.argv[2])
    wire = Wire()
    registry = wire.new_id()
    wire.send(1, 1, struct.pack("<I", registry))  # wl_display.get_registry
    globals_ = {}

    def on_event(obj, opcode, body):
        if obj == registry and opcode == 0:
            name, length = struct.unpack_from("<II", body)
            interface = body[8:8 + length - 1].decode()
            offset = 8 + length + (-length % 4)
            (version,) = struct.unpack_from("<I", body, offset)
            globals_[interface] = (name, version)

    wire.roundtrip(on_event)

    def bind(interface, version):
        name, offered = globals_[interface]
        new = wire.new_id()
        wire.send(registry, 0, struct.pack("<I", name) + wire.string(interface)
                  + struct.pack("<II", min(version, offered), new))
        return new

    seat = bind("wl_seat", 1)
    manager = bind("zwlr_virtual_pointer_manager_v1", 1)
    pointer = wire.new_id()
    wire.send(manager, 0, struct.pack("<II", seat, pointer))  # create_virtual_pointer
    wire.roundtrip(lambda *a: None)

    def stamp():
        return int(time.monotonic() * 1000) & 0xFFFFFFFF

    def frame():
        wire.send(pointer, 4)
        wire.roundtrip(lambda *a: None)

    def button(state):
        wire.send(pointer, 2, struct.pack("<III", stamp(), BTN_LEFT, state))
        frame()

    print("pointer ready", flush=True)
    for line in sys.stdin:
        words = line.split()
        if not words:
            continue
        if words[0] == "move":
            x, y = int(float(words[1])), int(float(words[2]))
            wire.send(pointer, 1, struct.pack("<IIIII", stamp(), x, y, width, height))
            frame()
        elif words[0] == "down":
            button(1)
        elif words[0] == "up":
            button(0)
        elif words[0] == "click":
            button(1)
            time.sleep(0.05)
            button(0)
        print("ok", flush=True)


if __name__ == "__main__":
    main()
