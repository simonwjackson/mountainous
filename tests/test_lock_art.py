#!/usr/bin/env python3
"""Validate every built PNG against the same plan the wrapper uses."""

import struct
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
import lockplan  # noqa: E402

art = Path(sys.argv[2])
count = 0
for appearance in lockplan.PAL:
    for variant in ("regular", "compact"):
        for scale in lockplan.PREBUILT_SCALES:
            path = art / f"dialog-{appearance}-{variant}-s{scale}.png"
            data = path.read_bytes()
            assert data[:8] == b"\x89PNG\r\n\x1a\n", path
            width, height = struct.unpack(">II", data[16:24])
            geometry = lockplan.layout(scale, variant)
            assert (width, height) == (geometry["W"], geometry["H"]), path
            print(f"{path.name}: {width}x{height}")
            count += 1
assert count == len(list(art.glob("*.png"))) == 24
