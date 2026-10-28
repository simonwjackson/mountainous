#!/usr/bin/env python3
"""Original period-style UI miniatures. No sampled or transcribed OS audio.

Copyright 2026 mountainous contributors. SPDX-License-Identifier: CC0-1.0
The generated WAV recordings are also dedicated to the public domain (CC0).
"""

import argparse
import math
import struct
import wave
from pathlib import Path

RATE = 48000
# (frequency Hz, duration seconds). Gaps separate alert tones. The clicks use
# short decaying high notes, Platinum a dry sine and Win98 a hollow triangle.
SCORES = {
    "platinum": {
        "menu-open": [(1600, .012)],
        "menu-choose": [(2100, .016)],
        "alert": [(660, .09), (0, .025), (440, .09)],
        "empty-trash": [(155, .035), (210, .025), (95, .05)],
        "notification": [(880, .045), (1174, .06)],
        "minimize": [(620, .025), (310, .035)],
        "restore": [(310, .025), (620, .035)],
    },
    "win98": {
        "start-menu": [(1350, .018)],
        "menu-choose": [(1800, .014)],
        "default-beep": [(740, .1)],
        "exclamation": [(880, .055), (0, .015), (587, .085)],
        "critical-stop": [(392, .08), (0, .02), (277, .12)],
        "asterisk": [(784, .045), (988, .045), (1175, .07)],
        "minimize": [(880, .025), (659, .025), (440, .03)],
        "restore": [(440, .025), (659, .025), (880, .03)],
    },
}


def generate(output: Path) -> None:
    for theme, scores in SCORES.items():
        directory = output / theme / "sounds"
        directory.mkdir(parents=True, exist_ok=True)
        for name, notes in scores.items():
            frames = []
            for frequency, duration in notes:
                count = round(duration * RATE)
                for i in range(count):
                    t = i / RATE
                    phase = 2 * math.pi * frequency * t
                    tone = math.sin(phase)
                    if theme == "win98":
                        tone = (tone + math.sin(3 * phase) / 9) / 1.112
                    envelope = min(1, t / .0015) * min(1, (duration - t) / .004)
                    envelope *= math.exp(-2.5 * t / duration)
                    frames.append(round(32767 * .32 * tone * envelope) if frequency else 0)
            with wave.open(str(directory / f"{name}.wav"), "wb") as recording:
                recording.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
                recording.writeframes(struct.pack(f"<{len(frames)}h", *frames))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    generate(parser.parse_args().output)
