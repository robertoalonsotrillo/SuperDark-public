#!/usr/bin/env python3
"""
Density-regime descriptors: does the music MOVE between continuous sound,
silence, and fragmentary intersection, or does it sit at one density?

Roberto's specification, 2026-08-20: "we still need silence but it should be
generated non-linearly, we should be able to move from continuous sound to
silence to fragmentary intersections."

This is not a sparsity target. A two-sided sparsity floor would push every
render toward one middling density, which is the opposite of the requirement,
and it is the mistake E1's one-sided floor already made in the other direction.
What is wanted is *traversal*: the density curve should visit distinct regimes
and change between them.

E1's failure here is measurable. Its `sparsity` term is a floor at 0.15 and the
renders sit at 0.65, so a render that is 92% silent passes perfectly. The floor
punishes too little silence and never punishes too much, and it is blind to
whether the silence is placed or merely left over.

Four descriptors, computed on a local-activity curve (fraction of active frames
per window):

  span        max - min local density. Zero if the piece never changes regime.
  regimes     how many of {sparse <0.25, middle, dense >0.6} the curve visits.
  crossings   regime changes per minute. Structure, not just variety.
  runlength   median frames a regime is held. Distinguishes composed sections
              from frame-by-frame flicker, which is the failure mode a naive
              variance reward would produce.

No target is stipulated here. Run this over real music first and read the
targets off the material, which is what should have happened with flatness.

Usage:  density_profile.py <wav> [<wav> ...]
"""
import os
import sys

import numpy as np
from scipy.io import wavfile

FRAME, HOP = 2048, 512
WIN_S, WIN_HOP_S = 1.0, 0.25
SPARSE, DENSE = 0.25, 0.60


def load(path):
    rate, data = wavfile.read(path)
    x = data.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.issubdtype(data.dtype, np.integer):
        x = x / float(np.iinfo(data.dtype).max)
    return rate, x


def profile(path, limit_s=90.0):
    rate, x = load(path)
    x = x[: int(limit_s * rate)]
    frames = [x[i:i + FRAME] for i in range(0, max(1, len(x) - FRAME), HOP)]
    if len(frames) < 8:
        return None
    rms = np.array([np.sqrt((f ** 2).mean()) for f in frames])
    peak = np.abs(x).max() + 1e-12
    active = rms > peak * 0.05

    per_win = max(2, int(WIN_S * rate / HOP))
    step = max(1, int(WIN_HOP_S * rate / HOP))
    density = np.array([active[i:i + per_win].mean()
                        for i in range(0, max(1, len(active) - per_win), step)])
    if len(density) < 4:
        return None

    regime = np.where(density < SPARSE, 0, np.where(density > DENSE, 2, 1))
    changes = int((np.diff(regime) != 0).sum())
    dur_min = (len(x) / rate) / 60.0
    runs, cur, n = [], regime[0], 1
    for r in regime[1:]:
        if r == cur:
            n += 1
        else:
            runs.append(n)
            cur, n = r, 1
    runs.append(n)

    return dict(
        dur=round(len(x) / rate, 1),
        mean=round(float(density.mean()), 3),
        span=round(float(density.max() - density.min()), 3),
        regimes=int(len(set(regime.tolist()))),
        crossings=round(changes / max(dur_min, 1e-9), 1),
        runlength=round(float(np.median(runs)) * WIN_HOP_S, 2),
    )


def main():
    print(f"{'file':<44}{'dur':>7}{'mean':>7}{'span':>7}"
          f"{'regimes':>9}{'cross/min':>11}{'runlen s':>10}")
    for path in sys.argv[1:]:
        try:
            p = profile(path)
        except Exception as exc:
            print(f"{os.path.basename(path)[:43]:<44}  error: {exc}")
            continue
        if p is None:
            print(f"{os.path.basename(path)[:43]:<44}  too short")
            continue
        print(f"{os.path.basename(path)[:43]:<44}{p['dur']:>7}{p['mean']:>7}"
              f"{p['span']:>7}{p['regimes']:>9}{p['crossings']:>11}"
              f"{p['runlength']:>10}")


if __name__ == "__main__":
    main()
