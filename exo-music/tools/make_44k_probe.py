#!/usr/bin/env python3
"""Resample the first N grains to 44100 with a proper anti-imaging filter.

THE HYPOTHESIS THIS TESTS
The corpus is 22050 Hz and the server runs at 44100. Every grain is therefore
played through BufRateScale at rate 0.5, and SuperCollider interpolates between
buffer samples to fill in the missing ones. Interpolation is upsampling with a
very short kernel, and short-kernel upsampling leaves IMAGES of the signal
above the original Nyquist. The material cannot contain anything above
11.025 kHz, so everything up there is manufactured, and broadband manufactured
energy across the top octave is heard as HISS.

Measured on the bisection ladder, energy above 11.025 kHz as a fraction of the
total, on identical material:
    R0  raw grains resampled with scipy resample_poly   1.13e-05
    R1  the same grains through PlayBuf                 2.85e-04
i.e. twenty-five times more, from the resampler alone.

If that is the cause, then feeding SuperCollider a corpus already at 44100 --
so BufRateScale is 1.0 and no interpolation happens at all -- should drop the
>11k figure to roughly the R0 level. That is the test this file sets up. It
writes a PROBE, not a corpus: 64 grains, enough to render a rung.

resample_poly applies the anti-imaging lowpass that PlayBuf's interpolator does
not. Using linear interpolation here instead would manufacture the very
artefact being measured, which is a mistake already made once in this codebase
(see bisect_report.py, build_r0).
"""
import argparse
import glob
import os
import wave

import numpy as np
from scipy.signal import resample_poly


def read(path):
    with wave.open(path, "rb") as w:
        sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    a = np.frombuffer(raw, "<i4").astype(np.float64) / 2 ** 31
    return a.reshape(-1, ch), sr


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--n", type=int, default=64)
    p.add_argument("--sr", type=int, default=44100)
    a = p.parse_args()

    os.makedirs(a.out, exist_ok=True)
    files = sorted(glob.glob(os.path.join(a.src, "g*.wav")))[: a.n]
    done = 0
    for i, f in enumerate(files):
        x, sr = read(f)
        if sr != a.sr:
            g = np.gcd(int(sr), int(a.sr))
            x = np.stack([resample_poly(x[:, c], a.sr // g, sr // g)
                          for c in range(x.shape[1])], axis=1)
        peak = float(np.abs(x).max())
        if peak > 0.999:                       # resampling overshoots slightly
            x = x * (0.999 / peak)
        q = np.clip(x * 2 ** 31, -2 ** 31, 2 ** 31 - 1).astype("<i4")
        with wave.open(os.path.join(a.out, f"g{i:02d}.wav"), "wb") as w:
            w.setnchannels(x.shape[1]); w.setsampwidth(4); w.setframerate(a.sr)
            w.writeframes(q.tobytes())
        done += 1
    print(f"  {done} grains -> {a.out} at {a.sr} Hz "
          f"(BufRateScale will now be 1.0, no interpolation)")


if __name__ == "__main__":
    main()
