#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Test how Myoko's microphone capture bytes are really framed.

ALSA S24_LE stores each sample in 4 bytes. The AudioReach DSP can instead
write packed 3-byte samples when the kernel asks for 24 bits per sample. Read
the same raw byte stream both ways and report which framing yields a real
audio signal (high lag-1 autocorrelation, correlated stereo channels).
"""

import math
import sys
import wave


def correlation(left, right):
    count = min(len(left), len(right))
    if count == 0:
        return float("nan")
    left = left[:count]
    right = right[:count]
    left_mean = sum(left) / count
    right_mean = sum(right) / count
    numerator = sum((a - left_mean) * (b - right_mean) for a, b in zip(left, right))
    left_power = sum((a - left_mean) ** 2 for a in left)
    right_power = sum((b - right_mean) ** 2 for b in right)
    if not left_power or not right_power:
        return float("nan")
    return numerator / math.sqrt(left_power * right_power)


def frame(raw, width, channels, offset):
    """Split raw bytes into per-channel sample lists using the given framing."""
    values = [
        int.from_bytes(raw[index:index + width], "little", signed=True)
        for index in range(offset, len(raw) - width + 1, width)
    ]
    return [values[channel::channels] for channel in range(channels)]


def report(label, per_channel, width):
    full_scale = (1 << (width * 8 - 1)) - 1
    stats = []
    for samples in per_channel:
        samples = samples[:48000]
        rms = math.sqrt(sum(v * v for v in samples) / len(samples)) / full_scale
        stats.append((rms, correlation(samples[:-1], samples[1:])))
    stereo = correlation(per_channel[0][:48000], per_channel[1][:48000]) if len(per_channel) > 1 else float("nan")
    parts = " ".join(f"ch{i}_rms={rms:.4f} ch{i}_lag1={lag:.4f}" for i, (rms, lag) in enumerate(stats))
    print(f"{label:<28} {parts} stereo={stereo:.4f}")
    return max(lag for _, lag in stats)


path = sys.argv[1]
with wave.open(path, "rb") as wav:
    channels = wav.getnchannels()
    width = wav.getsampwidth()
    raw = wav.readframes(wav.getnframes())

print(f"file={path} wav_channels={channels} wav_width={width} bytes={len(raw)}")
best = []
best.append(("as-recorded", report("as-recorded 4-byte", frame(raw, width, channels, 0), width)))
for offset in range(3):
    label = f"packed 3-byte offset={offset}"
    best.append((label, report(label, frame(raw, 3, channels, offset), 3)))
for offset in range(2):
    label = f"16-bit offset={offset}"
    best.append((label, report(label, frame(raw, 2, channels, offset), 2)))

label, score = max(best, key=lambda item: item[1])
print(f"best_framing={label!r} lag1={score:.4f}")
if score > 0.5 and label != "as-recorded":
    print("MYOKO_MIC_FRAMING_MISMATCH")
elif score > 0.5:
    print("MYOKO_MIC_FRAMING_OK")
else:
    print("MYOKO_MIC_NO_SIGNAL_IN_ANY_FRAMING")
