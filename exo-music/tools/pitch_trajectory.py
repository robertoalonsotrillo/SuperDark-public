#!/usr/bin/env python3
"""Is the factory's movement along the PITCH axis structured, or a random walk?

WHY THIS IS THE RIGHT QUESTION FIRST. live_factory.scd says plainly that
selection used to be pitch-blind, "which is why nothing the factory assembled
was ever harmonic or tonal: the axis along which tonality lives was not in the
geometry." Pitch is now the sixth dimension of dKeys, beside five MFCC
components. So the factory CAN move along pitch. Nobody has asked whether it
does anything on that axis, and the answer decides what any harmonic mechanism
would be: a description of behaviour already present, or an imposition.

THE CONTROL IS THE OTHER FIVE AXES, NOT A SHUFFLE. Shuffling the sequence and
finding the real one more autocorrelated proves only that the path moves in
small steps, which is true of every axis by construction and says nothing about
tonality. The informative comparison is pitch against pc0..pc4: they are walked
by the same selector, over the same corpus, under the same policy, in the same
run. Anything pitch does that its five siblings do not is a property of pitch.

WHAT IT MEASURES, per axis.
  persistence   lag-1..8 autocorrelation of the coordinate. How long a
                direction is held.
  step          median absolute change per window. How far it moves at once.
  span          how much of the axis is used at all. An axis the factory never
                leaves is not being navigated.
  revisits      the axis is binned; how often the path returns to a bin it has
                left. Tonality is recurrence -- returning to a pitch region is
                the minimum behaviour that could be called tonal. A pure random
                walk revisits at a rate set by its step size, so the null here
                is a walk matched to this axis's own step distribution.

                THIS COLUMN IS DEGENERATE ON THIS DATA AND SHOULD BE IGNORED.
                Run at 12 and at 60 bins it returns 0.998 and 0.995 for every
                axis, null included, because a step of 0.03 inside a bounded
                unit range re-enters a visited bin almost every time it moves.
                The z-scores it prints are computed against a standard deviation
                of ~0.000 and mean nothing. Left in place, and labelled, because
                deleting it would hide that the first version of this test could
                not have detected what it was built to look for. The finding
                below rests on persistence, step and span, which are not
                saturated.
  drift         linear trend across the run. Whether the factory is going
                somewhere on this axis or circling.

WHAT IT CANNOT SAY. The axis is a corpus coordinate, not a musical pitch. A
return to the same coordinate is a return to similar material, which may or may
not be heard as the same pitch. This measures navigation, not perception, and
calling any of it harmony would be the same overreach this project has already
made four times with self-generated criteria.

    python3 tools/pitch_trajectory.py
    python3 tools/pitch_trajectory.py --logs /Volumes/FMA/superdark/renders/live_*.log
"""
import argparse
import glob
import os
import sys

import numpy as np

RENDERS = "/Volumes/FMA/superdark/renders"
NAMES = ["pc0", "pc1", "pc2", "pc3", "pc4", "PITCH"]


def read_targets(paths):
    """One 6-vector per window per run. Windows repeat across events; take the
    first, since the target is set once per window and the events report it."""
    runs = []
    for p in paths:
        seen, rows = set(), []
        for line in open(p, errors="replace"):
            if not line or line[0].isupper() or line[0] == "#":
                continue
            f = line.strip().split(",")
            if len(f) < 15 or "|" not in f[13]:
                continue
            try:
                w = int(f[1])
                v = [float(x) for x in f[13].split("|")]
            except ValueError:
                continue
            if len(v) != 6 or w in seen:
                continue
            seen.add(w)
            rows.append((w, v))
        if len(rows) >= 40:
            rows.sort()
            runs.append((os.path.basename(p), np.array([r[1] for r in rows])))
    return runs


def acf(x, k):
    x = x - x.mean()
    d = float((x * x).sum())
    if d <= 0:
        return 0.0
    return float((x[:-k] * x[k:]).sum() / d)


def revisit_rate(x, bins=12, rng=None):
    """Fraction of steps that re-enter a bin the path had already left."""
    lo, hi = (rng if rng else (float(x.min()), float(x.max())))
    if hi - lo < 1e-9:
        return 0.0
    b = np.clip(((x - lo) / (hi - lo) * bins).astype(int), 0, bins - 1)
    visited, left, hits, moves = {b[0]}, set(), 0, 0
    for i in range(1, len(b)):
        if b[i] != b[i - 1]:
            moves += 1
            left.add(b[i - 1])
            if b[i] in left:
                hits += 1
            visited.add(b[i])
    return hits / max(1, moves)


def matched_walk_null(x, bins, rng, trials=400, seed=5):
    """A random walk with THIS axis's own step distribution, reflected into the
    same range. Isolates recurrence from step size, which is the confound."""
    r = np.random.default_rng(seed)
    steps = np.diff(x)
    if steps.size < 4:
        return float("nan"), float("nan")
    lo, hi = rng
    out = []
    for _ in range(trials):
        s = r.choice(steps, size=len(x) - 1, replace=True)
        y = np.empty(len(x)); y[0] = x[0]
        for i, d in enumerate(s):
            v = y[i] + d
            if v < lo: v = lo + (lo - v)
            if v > hi: v = hi - (v - hi)
            y[i + 1] = min(max(v, lo), hi)
        out.append(revisit_rate(y, bins, rng))
    return float(np.mean(out)), float(np.std(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="*", default=None)
    ap.add_argument("--bins", type=int, default=12)
    a = ap.parse_args()

    paths = a.logs or sorted(glob.glob(os.path.join(RENDERS, "*.log")))
    runs = read_targets(paths)
    if not runs:
        print("  no run had 40+ windows with a 6-vector target", file=sys.stderr)
        return 2
    X = np.vstack([r[1] for r in runs])
    print()
    print(f"  {len(runs)} runs, {X.shape[0]} windows with a target")
    for n, v in runs:
        print(f"      {n:34} {len(v):5d}")
    print()

    # The range is taken across everything so axes are compared on one scale.
    print(f"  {'axis':7} {'persist l1':>10} {'l4':>7} {'l8':>7} "
          f"{'step':>8} {'span':>7} {'revisit':>8} {'null':>13} {'drift':>8}")
    print("  " + "-" * 82)
    rows = []
    for j, nm in enumerate(NAMES):
        x = X[:, j]
        rng = (float(x.min()), float(x.max()))
        rv = revisit_rate(x, a.bins, rng)
        mu, sd = matched_walk_null(x, a.bins, rng)
        z = (rv - mu) / sd if sd and sd > 1e-9 else float("nan")
        t = np.arange(len(x))
        drift = float(np.polyfit(t, x, 1)[0] * len(x))   # total change over the run
        rows.append((nm, rv, mu, sd, z))
        print(f"  {nm:7} {acf(x,1):10.3f} {acf(x,4):7.3f} {acf(x,8):7.3f} "
              f"{np.median(np.abs(np.diff(x))):8.4f} {rng[1]-rng[0]:7.3f} "
              f"{rv:8.3f} {mu:6.3f}±{sd:5.3f} {drift:+8.3f}")

    pit = rows[-1]
    sib = [r for r in rows[:-1]]
    print()
    print("  READING IT")
    print(f"    pitch revisits {pit[1]:.3f} against a step-matched walk at "
          f"{pit[2]:.3f} (z = {pit[4]:+.2f})")
    zs = [r[4] for r in sib if r[4] == r[4]]
    if zs:
        print(f"    its five siblings sit at z = "
              f"{', '.join(f'{v:+.2f}' for v in zs)}")
    print()
    print("    The claim 'the factory is developing tonal behaviour' needs pitch")
    print("    to depart from BOTH its own step-matched null AND its five")
    print("    siblings. Departing from the null alone means the walk is not")
    print("    Brownian, which is true of a selector that follows a corpus.")
    print("    Departing from the siblings too would mean pitch is being treated")
    print("    differently by a selector that has no term for pitch -- and that")
    print("    would be a finding worth the name.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
