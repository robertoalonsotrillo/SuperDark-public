#!/usr/bin/env python3
"""What ARE the live clicks? Shape, timing and periodicity of the worst events.

WHY THIS COMES NOW AND NOT EARLIER
Every clean verdict in this investigation came from an NRT render. Measured
31 Aug on 60 s of the live factory against the same detector on the same
material rendered offline:

    LIVE                worst local anomaly  6517.9
    OFFLINE R6                                  9.4
    OFFLINE raw grains                         13.5

Three orders of magnitude. The fault is REALTIME-ONLY, so the corpus gate, the
44.1 kHz resample and the attack clamp could never have fixed it -- they were
all aimed at a signal path that does not have the problem. The offline ladder
was the right instrument for the two artefacts it did find and the wrong one
for this.

WHAT DISTINGUISHES THE CANDIDATES
  DROPOUT       a run of exact zeros, or a sudden step to silence and back.
                Means the audio callback missed its deadline: buffer underrun,
                FIFO starvation, a blocked language thread.
  FULL-SCALE    a sample at or near +/-1.0 with nothing around it. Means a bad
  SPIKE         sample value reached the output, not a scheduling failure.
  STEP          a discontinuity between two adjacent samples with normal audio
                either side. Means a synth was freed or a buffer swapped
                mid-cycle.
  PERIODIC      evenly spaced events point at a clock: a block boundary, a
                window tick, a rotation interval. Irregular points at content.

Each has a different fix and they are not distinguishable by ear, which is why
this measures rather than guesses.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bisect_report import read_wav                    # noqa: E402
from scipy.signal import butter, sosfiltfilt          # noqa: E402
from scipy.ndimage import median_filter               # noqa: E402


def find(x, sr, thresh=40.0):
    sos = butter(4, 6000 / (sr / 2), btype="highpass", output="sos")
    env = np.abs(sosfiltfilt(sos, x))
    k = max(1, int(sr * 0.0005))
    env = np.convolve(env, np.ones(k) / k, mode="same")
    floor = median_filter(env, size=int(sr * 0.05) | 1, mode="nearest")
    r = env / np.maximum(floor, 1e-9 + 0.02 * np.median(env))
    hot = r > thresh
    starts = np.flatnonzero(hot[1:] & ~hot[:-1]) + 1
    out = []
    for s in starts:
        if out and s - out[-1] < int(sr * 0.02):
            continue
        out.append(int(s))
    return np.array(out), r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--top", type=int, default=8)
    a = ap.parse_args()

    x, sr, ch = read_wav(a.file)
    ev, ratio = find(x, sr)
    print()
    print(f"  {os.path.basename(a.file)}: {len(x)/sr:.1f}s, {sr} Hz, {len(ev)} events over ratio 40")
    if len(ev) == 0:
        return 0

    ev = ev[np.argsort(-ratio[ev])][: a.top]
    print()
    print(f"  {'t (s)':>9} {'ratio':>9} {'zeros':>7} {'|step|':>8} {'peak':>8} {'silence us':>11}   shape")
    print("  " + "-" * 82)
    kinds = []
    for i in sorted(ev):
        w = x[max(0, i - int(sr * 0.005)): i + int(sr * 0.005)]
        if len(w) < 16:
            continue
        zeros = int((np.abs(w) < 1e-7).sum())
        step = float(np.abs(np.diff(w)).max())
        peak = float(np.abs(w).max())
        # longest run of near-silence inside the window
        run, best = 0, 0
        for v in np.abs(w) < 1e-7:
            run = run + 1 if v else 0
            best = max(best, run)
        sil_us = best / sr * 1e6

        if best > sr * 0.0002:
            kind = "DROPOUT (a run of exact zeros)"
        elif peak > 0.99:
            kind = "FULL-SCALE SPIKE"
        elif step > 0.25:
            kind = "STEP discontinuity"
        else:
            kind = "burst, no zeros and no step"
        kinds.append(kind.split()[0])
        print(f"  {i/sr:9.3f} {ratio[i]:9.1f} {zeros:7d} {step:8.4f} {peak:8.4f} "
              f"{sil_us:11.0f}   {kind}")

    print()
    from collections import Counter
    c = Counter(kinds)
    print(f"  shapes: {dict(c)}")

    allev, _ = find(x, sr)
    if len(allev) > 3:
        d = np.diff(allev) / sr
        cv = d.std() / max(d.mean(), 1e-9)
        print(f"  spacing: median {np.median(d):.3f}s  mean {d.mean():.3f}s  cv {cv:.2f}"
              f"  -> {'PERIODIC, suspect a clock' if cv < 0.35 else 'irregular, suspect content or load'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
