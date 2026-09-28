#!/usr/bin/env python3
"""What would flattening the life arc actually do?

THE ARC. Every voice is wrapped in
    Pmul(\\amp, Pseg(Pseq([0.05, 1.0, 0.85, 0.0]),
                     Pseq([enter, middle, recede]), \\sin), machine)
with life_enter 0.25 and life_recede 0.45, so a voice rises from 0.05, holds
near 1.0 for 30% of its life, and spends its LAST 45% fading to nothing. Its
span is voice_span (14 s) times U(0.7, 1.4), which is 9.8 to 19.6 s against an
11.7 s window -- so a voice covers roughly one to two windows and its phase is
effectively random with respect to them.

WHY THIS MATTERS. The instrumentation showed that 85% of silent windows have
notes playing, at a requested amplitude of 0.046 against 0.058 in sounding ones.
The factory is sitting so close to its audibility floor that a modest amplitude
difference decides whether anything is heard. The arc is the largest systematic
source of that difference, because it multiplies every event.

This simulates the arc's contribution: voices arriving at the observed rate,
each with a random span, summed per window, over many windows. It compares the
current arc against alternatives, and reports what each does to the LEVEL and to
the frequency of near-silent windows.

It does NOT predict the music. It predicts the multiplier, which is the part
that is arithmetic rather than taste.

    python3 tools/simulate_life_arc.py
"""
import argparse
import sys

import numpy as np

WINDOW = 11.7          # seconds
SPAN = 14.0            # policy voice_span
FIRES_PER_WINDOW = 2.5  # observed median (silent 3.0, sounding 2.0)


def arc_value(u, levels, times):
    """Value of a piecewise sinusoidal envelope at fraction u of its life."""
    cum = np.cumsum(times) / np.sum(times)
    lo = 0.0
    for i, hi in enumerate(cum):
        if u <= hi:
            t = (u - lo) / max(hi - lo, 1e-9)
            # SuperCollider's \sin curve: a raised-cosine S between the levels.
            s = 0.5 - 0.5 * np.cos(np.pi * t)
            return levels[i] + (levels[i + 1] - levels[i]) * s
        lo = hi
    return levels[-1]


def simulate(levels, times, windows=4000, seed=3):
    rng = np.random.default_rng(seed)
    # Voices arrive as a Poisson process at the observed rate; each lives for
    # SPAN * U(0.7, 1.4), exactly as fireVoice draws it.
    total = windows * WINDOW
    n = rng.poisson(FIRES_PER_WINDOW * windows)
    starts = rng.uniform(0, total, n)
    spans = SPAN * rng.uniform(0.7, 1.4, n)
    # Sample each window at its midpoint: the sum of the arc across every voice
    # alive at that moment is the level multiplier the window receives.
    mids = (np.arange(windows) + 0.5) * WINDOW
    out = np.zeros(windows)
    for s, sp in zip(starts, spans):
        live = (mids >= s) & (mids < s + sp)
        if not live.any():
            continue
        u = (mids[live] - s) / sp
        out[live] += np.array([arc_value(x, levels, times) for x in u])
    return out


def report(name, levels, times):
    v = simulate(levels, times)
    med = np.median(v)
    mean_mult = np.mean([arc_value(u, levels, times) for u in np.linspace(0, 1, 400)])
    # "Near-silent" relative to this configuration's own median, so shapes are
    # compared on distribution rather than on absolute level.
    q = np.mean(v < 0.25 * med)
    print(f"  {name:34} mean arc {mean_mult:5.3f}   median sum {med:5.2f}   "
          f"windows under a quarter of median {100*q:5.1f}%")
    return mean_mult, med, q


def main():
    argparse.ArgumentParser().parse_args()
    print()
    print(f"  {FIRES_PER_WINDOW} voices fired per window, span "
          f"{SPAN}s x U(0.7,1.4), {WINDOW}s windows")
    print()
    cur = report("current  [.05, 1, .85, 0] 25/30/45",
                 [0.05, 1.0, 0.85, 0.0], [0.25, 0.30, 0.45])
    print()
    alts = [
        ("shorter fade    25/50/25", [0.05, 1.0, 0.85, 0.0], [0.25, 0.50, 0.25]),
        ("higher floor    .3 -> .3", [0.30, 1.0, 0.90, 0.30], [0.25, 0.30, 0.45]),
        ("both            .3, 25/50/25", [0.30, 1.0, 0.90, 0.30], [0.25, 0.50, 0.25]),
        ("flat            constant 1", [1.0, 1.0, 1.0, 1.0], [0.25, 0.30, 0.45]),
    ]
    for nm, lv, tm in alts:
        m, md, q = report(nm, lv, tm)
        print(f"  {'':34} -> {20*np.log10(md/cur[1]):+5.1f} dB vs current, "
              f"near-silent windows {100*cur[2]:.1f}% -> {100*q:.1f}%")
    print()
    print("  READING IT")
    print("  The mean arc is how much quieter every event is made, on average.")
    print("  The last column is how often the summed arc collapses far below its")
    print("  own median -- the windows where every live voice happens to be in")
    print("  its fade at once, which is what turns a playing factory into a")
    print("  silent one.")
    print()
    print("  WHAT THIS DOES NOT SAY. Flattening the arc removes the shape that")
    print("  makes voices enter and leave rather than switch on and off. That")
    print("  shape is doing compositional work, and the arithmetic here cannot")
    print("  weigh it. The middle options keep an arc and lift its floor, which")
    print("  is the interesting direction: the same gesture, less collapse.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
