#!/usr/bin/env python3
"""Is m1_audible_when_driving measuring anything m2_level does not?

THE WORRY, stated when the metric was written. `amp` is Amplitude.kr on the
output bus, so a metric that asks "was the output silent while the output was
driving" compares a quantity to itself. That is the same circularity that let the
multiplier-at-zero fault survive every check for an unknown number of runs.

THE KERNEL DOC ALREADY ASSERTS THIS AND SHOULD NOT. Writing up the depth hole I
said m1 and m2 "are not independent: both are functions of master peak", and used
that to explain why one fault spends the whole tolerance of two. That was an
argument from the definitions, not a measurement, and this project has been wrong
about exactly this kind of inference before -- the 0.9 drift threshold turned out
to measure a different quantity than the one it was quoted for.

WHAT REDUNDANCY WOULD MEAN. If m1 is a near-deterministic function of m2 across
runs, then the charter has seven metrics and six quantities, the audibility norm
has ONE failable dimension rather than two, and the tolerance of two can never be
exceeded by a level fault however deep it goes. That is a stronger statement of
the depth hole than the one currently written down, and it changes which of the
three candidate fixes is right.

WHAT IT CANNOT SETTLE. Correlation across runs is not proof of redundancy: two
metrics can track each other in normal operation and separate exactly when it
matters. So the degraded cases are scored too, since a metric earns its place by
what it does when something is wrong.

    python3 tools/m1_redundancy.py
"""
import argparse
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC                                    # noqa: E402
from rehearse_kernel_real import degrade                      # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")
RENDERS = "/Volumes/FMA/superdark/renders"


def vals(path, ch):
    n, rows, failed, und = SC.evaluate(path, ch)
    out = {}
    for r in rows:
        out[r[0]] = r[2]
    return n, out


def main():
    argparse.ArgumentParser().parse_args()
    ch = json.load(open(os.path.join(MUT, "charter.json")))

    logs = sorted(glob.glob(os.path.join(RENDERS, "*.log")))
    m1, m2, sil, names = [], [], [], []
    for p in logs:
        try:
            n, v = vals(p, ch)
        except Exception:
            continue
        if n < 120:
            continue
        a, b = v.get("m1_audible_when_driving"), v.get("m2_level")
        # d1_silence is m1_not_silent, renamed in charter edition 7. `v` is keyed
        # by whatever the LIVE charter calls its metrics, so the old name here
        # would not raise -- it would return None and quietly fill the column
        # with NaN, which is the silent degradation a rename invites.
        s = v.get("d1_silence")
        if a is None or b is None:
            continue
        m1.append(a); m2.append(b); sil.append(s if s is not None else float("nan"))
        names.append(os.path.basename(p))

    if len(m1) < 5:
        print("  too few scoreable runs", file=sys.stderr)
        return 2
    m1 = np.array(m1); m2 = np.array(m2); sil = np.array(sil)

    print()
    print(f"  {len(m1)} runs of 120+ windows")
    print()
    print(f"  {'run':34} {'m2_level':>10} {'m1_awd':>10} {'d1_silence':>14}")
    print("  " + "-" * 72)
    for i in np.argsort(m2):
        print(f"  {names[i][:34]:34} {m2[i]:10.4f} {m1[i]:10.4f} {sil[i]:14.3f}")

    print()
    print("  IN NORMAL OPERATION")
    nz = m1 > 0
    print(f"    m1 is exactly 0.0 in {int((~nz).sum())} of {len(m1)} runs")
    if nz.sum() >= 4 and m2[nz].std() > 0 and m1[nz].std() > 0:
        r = float(np.corrcoef(m2[nz], m1[nz])[0, 1])
        print(f"    where m1 moves at all, corr(m2, m1) = {r:+.3f} over {int(nz.sum())} runs")
    else:
        print(f"    m1 does not vary enough across healthy runs to correlate."
              f"  THAT IS THE ANSWER:")
        print(f"    a metric that is 0.0 on almost every run is not measuring the")
        print(f"    factory, it is measuring whether the factory is broken -- which")
        print(f"    m2 already does, at the same bound, from the same samples.")

    print()
    print("  UNDER DEGRADATION, which is where a metric earns its place")
    src = [p for p in logs if os.path.getsize(p) > 40000]
    src = src[-1] if src else logs[-1]
    print(f"    perturbing {os.path.basename(src)}")
    print(f"    {'gain':>8} {'m2_level':>10} {'m1_awd':>10}   {'both fail?':>12}")
    for g, lab in ((1.0, "as-is"), (0.5, "-6 dB"), (0.25, "-12 dB"),
                   (0.1, "-20 dB"), (0.01, "-40 dB")):
        degrade(src, "/tmp/m1_deg.log", gain=g)
        n, v = vals("/tmp/m1_deg.log", ch)
        a, b = v.get("m1_audible_when_driving"), v.get("m2_level")
        # bounds from the charter itself
        # the charter key is "acceptable", not "bound", and either side may be
        # null for a one-sided metric
        def fails(spec, v):
            lo, hi = spec["acceptable"]
            if v is None: return False
            return (lo is not None and v < lo) or (hi is not None and v > hi)
        f2 = fails(ch["metrics"]["m2_level"], b)
        f1 = fails(ch["metrics"]["m1_audible_when_driving"], a)
        print(f"    {lab:>8} {b:10.5f} {a:10.4f}   "
              f"{('m2 ' if f2 else '')+('m1' if f1 else ''):>12}")

    print()
    print("  READING IT")
    print("    If m1 and m2 fail at the SAME degradation and never separately,")
    print("    the audibility norm has one failable dimension and not two, and a")
    print("    level fault can never exceed a tolerance of two however deep it")
    print("    goes. That is a sharper statement of the depth hole than the one")
    print("    in THE_KERNEL_IS_BROAD_BUT_NOT_DEEP.md, which argued it from the")
    print("    definitions instead of measuring it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
