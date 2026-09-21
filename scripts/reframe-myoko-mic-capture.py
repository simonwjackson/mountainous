#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Re-read a Myoko S24_LE capture as packed 24-bit stereo and write a WAV.

Usage: reframe-myoko-mic-capture.py <in.wav> <out.wav> [window_seconds]

Also prints per-window statistics so gaps or garbage regions show up.
"""

import math
import sys
import wave

src, dst = sys.argv[1], sys.argv[2]
window_seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 0.25

with wave.open(src, "rb") as wav:
    channels = wav.getnchannels()
    rate = wav.getframerate()
    raw = wav.readframes(wav.getnframes())

usable = len(raw) - len(raw) % (3 * channels)
samples = [
    int.from_bytes(raw[i:i + 3], "little", signed=True)
    for i in range(0, usable, 3)
]
frames = len(samples) // channels
print(f"input_bytes={len(raw)} packed_frames={frames} seconds_at_{rate}Hz={frames / rate:.3f}")

full = (1 << 23) - 1
window = int(rate * window_seconds)
for start in range(0, frames, window):
    chunk = samples[start * channels:(start + window) * channels]
    left = chunk[0::channels]
    if len(left) < 2:
        break
    rms = math.sqrt(sum(v * v for v in left) / len(left)) / full
    peak = max(abs(v) for v in left) / full
    mean = sum(left) / len(left) / full
    num = sum((a - mean * full) * (b - mean * full) for a, b in zip(left[:-1], left[1:]))
    den = sum((a - mean * full) ** 2 for a in left)
    lag1 = num / den if den else float("nan")
    print(f"t={start / rate:6.2f}s rms={rms:.4f} peak={peak:.4f} dc={mean:+.4f} lag1={lag1:.4f}")

with wave.open(dst, "wb") as out:
    out.setnchannels(channels)
    out.setsampwidth(3)
    out.setframerate(rate)
    out.writeframes(raw[:usable])
print(f"wrote {dst}")
