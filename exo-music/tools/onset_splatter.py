#!/usr/bin/env python3
"""Measure onset splatter TIME-LOCKED to known event starts.

WHY THE BLIND DETECTOR CANNOT ANSWER THIS
audit_grain_transients / bisect_report normalise each moment against a RUNNING
MEDIAN of the local high-frequency background. That is what makes them click
detectors instead of brightness meters, and it is correct for finding faults in
unknown audio. It is wrong for a sweep over envelope attack time, because
changing the attack changes how densely grains overlap, which moves the very
baseline the measure divides by. Sweeping attack from 4 ms to 120 ms produced a
click RATE that rose with attack while the worst anomaly stayed flat and then
fell -- two measures disagreeing, which is the signature of a confound rather
than of a weak effect.

WHAT THIS DOES INSTEAD
bisect_render.scd plays from a fixed Score: events begin at t = k * 0.16 plus a
per-voice offset of 0.013. So the onset times are KNOWN, not inferred. This
measures, for each known onset, the high-frequency energy in a short window at
the onset against the energy in a window just before it. The ratio is onset
splatter, and it is immune to how dense the rest of the texture is, because
both windows sit in the same neighbourhood of the same event.

A fast amplitude ramp multiplied into broadband material produces sidebands;
that is the mechanism a short attack is suspected of. If short attacks splatter,
this number falls monotonically as attack lengthens. If it does not, the
hypothesis is wrong and no clamp should be added to the SynthDef on its account.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bisect_report import read_wav                    # noqa: E402
from scipy.signal import butter, sosfiltfilt          # noqa: E402

EV = 0.16          # seconds between events in the ladder's Score
SKIP = 0.5         # ignore the first half second


def splatter(path, hp_hz=6000.0, pre_ms=12.0, on_ms=6.0):
    x, sr, _ = read_wav(path)
    sos = butter(4, hp_hz / (sr / 2), btype="highpass", output="sos")
    hp = np.abs(sosfiltfilt(sos, x))

    npre, non = int(sr * pre_ms / 1000), int(sr * on_ms / 1000)
    ratios, ons = [], []
    t = SKIP
    while t * sr + non < len(x):
        i = int(t * sr)
        if i - npre >= 0:
            pre = hp[i - npre:i].mean()
            at = hp[i:i + non].mean()
            if pre > 1e-9:
                ratios.append(at / pre)
                ons.append(at)
        t += EV
    if not ratios:
        return None
    r = np.array(ratios)
    return {
        "n": len(r),
        "median": float(np.median(r)),
        "p90": float(np.percentile(r, 90)),
        "max": float(r.max()),
        "onset_hf": float(np.median(ons)),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirs", nargs="+", required=True,
                    help="render dirs, one per attack setting")
    ap.add_argument("--rung", default="R6_four_plus_master.wav")
    a = ap.parse_args()

    print()
    print(f"  onset splatter: HF energy AT the onset / HF energy 12 ms before it")
    print(f"  measured on {a.rung}, at known event times every {EV*1000:.0f} ms")
    print()
    print(f"  {'render':22} {'events':>7} {'median':>8} {'p90':>8} {'max':>9}")
    print("  " + "-" * 60)
    rows = []
    for d in a.dirs:
        p = os.path.join(d, a.rung)
        if not os.path.exists(p):
            print(f"  {os.path.basename(d):22} missing {a.rung}")
            continue
        s = splatter(p)
        if s is None:
            print(f"  {os.path.basename(d):22} too short")
            continue
        rows.append((os.path.basename(d), s))
        print(f"  {os.path.basename(d):22} {s['n']:7d} {s['median']:8.2f} "
              f"{s['p90']:8.2f} {s['max']:9.2f}")

    print()
    if len(rows) >= 3:
        med = [r[1]["median"] for r in rows]
        mono = all(med[i] >= med[i + 1] for i in range(len(med) - 1))
        print(f"  monotonically decreasing with attack length: "
              f"{'YES -- short attacks splatter' if mono else 'NO'}")
        if not mono:
            print("  The hypothesis that short attacks cause the residual clicks")
            print("  is NOT supported. Do not clamp the SynthDef on this evidence.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
