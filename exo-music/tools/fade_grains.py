#!/usr/bin/env python3
"""Put a short fade on both ends of every grain.

build_grains.py cuts 0.5 s slices with ffmpeg and no fade, so each grain
begins and ends on a step discontinuity. Measured over 200 grains of
grains_600:

    first-sample |amp|   median 0.0539   max 0.7403   above 0.01 in 87%
    last-sample  |amp|   median 0.0533   max 0.8230   above 0.01 in 84%

A step is a click, and a click is broadband. The grains are 22050 Hz
material carrying a median of 0.0000 of their energy above 8 kHz, so any
high-frequency hash in the output cannot have come from the corpus: the
playback chain is manufacturing it, one click per grain. At grain rates that
reads as a continuous layer over everything, which is what Roberto heard --
"that white noise element is always there as a patina" -- and why it survived
every fix applied at the level of voices and machines.

5 ms is 1% of a grain at each end, short enough to leave a transient intact
and long enough to remove the step. Raised-cosine rather than linear, because
a linear fade leaves a slope discontinuity of its own.

The originals are copied to <dir>_raw first, so the corpus can be restored and
the two can be compared by ear.
"""
import os
import shutil
import sys
import wave

import numpy as np

FADE_MS = 5.0


def read_wav(path):
    with wave.open(path) as w:
        n, sw, ch, sr = w.getnframes(), w.getsampwidth(), w.getnchannels(), w.getframerate()
        raw = w.readframes(n)
    dtype = "<i4" if sw == 4 else "<i2"
    scale = 2 ** 31 if sw == 4 else 2 ** 15
    a = np.frombuffer(raw, dtype=dtype).astype(np.float64) / scale
    return a.reshape(-1, ch), sr, sw, ch


def write_wav(path, a, sr, sw, ch):
    dtype = "<i4" if sw == 4 else "<i2"
    scale = 2 ** 31 if sw == 4 else 2 ** 15
    q = np.clip(a * scale, -scale, scale - 1).astype(dtype)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(sw)
        w.setframerate(sr)
        w.writeframes(q.tobytes())


def main(d, fade_ms=FADE_MS):
    raw_dir = d.rstrip("/") + "_raw"
    if not os.path.isdir(raw_dir):
        shutil.copytree(d, raw_dir)
        print(f"  originals preserved in {raw_dir}")
    else:
        print(f"  {raw_dir} exists; fading FROM it so this is idempotent")

    files = [f for f in sorted(os.listdir(raw_dir)) if f.endswith(".wav")]
    before, after = [], []
    for f in files:
        a, sr, sw, ch = read_wav(os.path.join(raw_dir, f))
        k = max(1, int(sr * fade_ms / 1000.0))
        if 2 * k >= len(a):
            k = len(a) // 4
        before.append(max(abs(a[0].mean()), abs(a[-1].mean())))
        ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, k))
        a = a.copy()
        a[:k] *= ramp[:, None]
        a[-k:] *= ramp[::-1][:, None]
        after.append(max(abs(a[0].mean()), abs(a[-1].mean())))
        write_wav(os.path.join(d, f), a, sr, sw, ch)

    before, after = np.array(before), np.array(after)
    print(f"  faded {len(files)} grains, {fade_ms} ms raised-cosine each end")
    print(f"  worst edge sample: median {np.median(before):.4f} -> {np.median(after):.6f}"
          f"   max {before.max():.4f} -> {after.max():.6f}")


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else FADE_MS)
