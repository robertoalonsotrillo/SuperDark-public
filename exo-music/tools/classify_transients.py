#!/usr/bin/env python3
"""Separate DEFECTS from musical ATTACKS. The click detector cannot.

WHY THIS IS NEEDED NOW AND WAS NOT BEFORE
audit_grain_transients.py finds energy that is locally anomalous. That was the
right instrument while the corpus contained shellac pops and the engine was
manufacturing imaging. Both are fixed, and the residual is measured at 3.65
events per second in R0 -- the raw grains with NO ENGINE AT ALL -- against 1.52
through the full playback chain. So the remainder is in the material.

The problem is that the material is ONSET-ALIGNED BY DESIGN. build_grains_onset
cuts every grain at a detected onset precisely so the machines have an attack to
place. A detector for locally anomalous energy will therefore flag every grain
start, because a musical attack IS locally anomalous energy. At this point the
instrument can no longer tell a snare from a fault, and continuing to tighten
thresholds against it would remove the music.

THE DISCRIMINATOR
A digital defect and a musical attack differ in ways that do not depend on how
loud they are:

  DURATION     a click is an impulse, tens of microseconds to about a
               millisecond. An attack has a body that lasts tens of ms.
  CONTINUATION a click is followed by nothing in particular. An attack is
               followed by the note it started -- energy persists.
  FLATNESS     a click is broadband and spectrally flat. An attack excites the
               instrument's resonances and is tonal.

Any one of these can be fooled. Together they separate the two populations
cleanly enough to COUNT the defects, which is the number that decides whether
more work on the corpus is worth doing.

This reports a count and a rate, and deliberately does not repair anything.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bisect_report import read_wav                       # noqa: E402
from scipy.signal import butter, sosfiltfilt             # noqa: E402
from scipy.ndimage import median_filter                  # noqa: E402


def find_events(x, sr, hp=6000.0, thresh=8.0):
    sos = butter(4, hp / (sr / 2), btype="highpass", output="sos")
    e = np.abs(sosfiltfilt(sos, x))
    k = max(1, int(sr * 0.0005))
    env = np.convolve(e, np.ones(k) / k, mode="same")
    floor = median_filter(env, size=int(sr * 0.05) | 1, mode="nearest")
    r = env / np.maximum(floor, 1e-9 + 0.02 * np.median(env))
    hot = r > thresh
    starts = np.flatnonzero(hot[1:] & ~hot[:-1]) + 1
    out = []
    for s in starts:
        if out and s - out[-1] < int(sr * 0.02):
            continue
        out.append(int(s))
    return np.array(out, dtype=int), env, r


def classify(x, sr, i, env):
    """Return (kind, duration_ms, continuation, flatness) for one event."""
    half = env[i] * 0.5
    j = i
    while j < min(len(env) - 1, i + int(sr * 0.05)) and env[j] > half:
        j += 1
    dur_ms = (j - i) / sr * 1000

    a0, a1 = i, min(len(x), i + int(sr * 0.002))
    b0, b1 = min(len(x), i + int(sr * 0.005)), min(len(x), i + int(sr * 0.040))
    at = np.sqrt((x[a0:a1] ** 2).mean()) if a1 > a0 else 0.0
    after = np.sqrt((x[b0:b1] ** 2).mean()) if b1 > b0 else 0.0
    cont = float(after / (at + 1e-12))

    w = x[max(0, i - int(sr * 0.0005)): i + int(sr * 0.0015)]
    if len(w) > 16:
        P = np.abs(np.fft.rfft(w * np.hanning(len(w)))) ** 2 + 1e-30
        flat = float(np.exp(np.log(P).mean()) / P.mean())
    else:
        flat = 0.0

    # A DEFECT is short AND does not continue AND is spectrally flat. Requiring
    # all three keeps a percussive but musical hit -- short, flat, but followed
    # by the body of the sound -- out of the defect count.
    is_defect = (dur_ms < 1.0) and (cont < 0.25) and (flat > 0.25)
    return ("defect" if is_defect else "attack"), dur_ms, cont, flat


def main():
    p = argparse.ArgumentParser()
    p.add_argument("files", nargs="+")
    p.add_argument("--verbose", action="store_true")
    a = p.parse_args()

    print()
    print(f"{'file':30} {'sec':>5} {'events':>7} {'defects':>8} {'attacks':>8} "
          f"{'defect/s':>9} {'med dur ms':>11} {'med cont':>9}")
    print("-" * 95)
    for f in a.files:
        x, sr, _ = read_wav(f)
        ev, env, _ = find_events(x, sr)
        kinds, durs, conts = [], [], []
        for i in ev:
            k, d, c, fl = classify(x, sr, i, env)
            kinds.append(k); durs.append(d); conts.append(c)
            if a.verbose and k == "defect":
                print(f"      defect at {i/sr:7.3f}s  dur {d:5.2f} ms  "
                      f"cont {c:5.2f}  flat {fl:.2f}")
        nd = kinds.count("defect")
        sec = len(x) / sr
        print(f"{os.path.basename(f)[:30]:30} {sec:5.1f} {len(ev):7d} {nd:8d} "
              f"{len(ev)-nd:8d} {nd/sec:9.2f} "
              f"{np.median(durs) if durs else 0:11.2f} "
              f"{np.median(conts) if conts else 0:9.2f}")
    print()
    print("  defect  = under 1 ms, no continuation, spectrally flat -> a click")
    print("  attack  = has a body and a note after it -> the music, leave it alone")
    return 0


if __name__ == "__main__":
    sys.exit(main())
