#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Query one running Ghostty terminal's rendered background through OSC 11."""
import os
from pathlib import Path
import select
import sys
import termios
import time
import tty

output = Path(sys.argv[1])
fd = os.open('/dev/tty', os.O_RDWR | os.O_NOCTTY)
saved = termios.tcgetattr(fd)
try:
    tty.setraw(fd)
    for _ in range(120):
        termios.tcflush(fd, termios.TCIFLUSH)
        os.write(fd, b'\x1b]11;?\x07')
        if select.select([fd], [], [], 1)[0]:
            reply = os.read(fd, 256).decode('ascii')
            output.write_text(repr(reply) + '\n')
        time.sleep(0.25)
finally:
    termios.tcsetattr(fd, termios.TCSANOW, saved)
    os.close(fd)
