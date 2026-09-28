#!/usr/bin/env python3
"""Score the warm-up experiment against its pre-registered criterion.

PRIMARY, fixed before any run: windows until the spectral gap first falls below
0.8 and STAYS below for 5 consecutive windows.

The gap is available in both arms because the operator observes regardless of
whether its weight is zero -- it is a diagnostic that happens to also be a
control input, and here only the diagnostic half is used.
"""
import glob
import os
import sys

import numpy as np

THRESH = 0.8
HOLD = 5


def gaps(path):
    out = []
    for line in open(path, errors="replace"):
        if line.startswith("OPERATOR"):
            p = line.split()[1].split(",")
            try:
                out.append((int(p[0]), float(p[2]), int(p[5])))
            except (ValueError, IndexError):
                pass
    return out


def cohere_at(g):
    """First window after which the gap stays under THRESH for HOLD windows."""
    for i in range(len(g) - HOLD):
        if all(g[j][1] < THRESH for j in range(i, i + HOLD)):
            return g[i][0]
    return None


def main(out_dir):
    print(f"  pre-registered: windows until spectral gap < {THRESH} for "
          f"{HOLD} consecutive windows\n")
    print(f"  {'run':16} {'windows':>8} {'cohered at':>11} {'gap w1-20':>10} "
          f"{'gap w60+':>9}")
    res = {}
    for f in sorted(glob.glob(f"{out_dir}/windows_*.log")):
        g = gaps(f)
        if not g:
            continue
        name = os.path.basename(f)[8:-4]
        arm = name.rsplit("_r", 1)[0]
        c = cohere_at(g)
        early = np.median([x[1] for x in g if x[0] <= 20]) if any(x[0] <= 20 for x in g) else float("nan")
        late = np.median([x[1] for x in g if x[0] >= 60]) if any(x[0] >= 60 for x in g) else float("nan")
        res.setdefault(arm, []).append(c)
        print(f"  {name:16} {len(g):>8} {str(c):>11} {early:>10.3f} {late:>9.3f}")

    if len(res) < 2:
        print("\n  need both arms before the comparison means anything.")
        return
    print()
    for arm in sorted(res):
        v = [x for x in res[arm] if x is not None]
        n_never = len(res[arm]) - len(v)
        s = f"{np.mean(v):.0f}" if v else "never"
        print(f"  {arm:10} cohered at {s:>8} windows (n={len(v)})"
              + (f", {n_never} never cohered" if n_never else ""))

    a = [x for x in res.get("op0.00", []) if x is not None]
    b = [x for x in res.get("op0.35", []) if x is not None]
    print()
    if not a or not b:
        print("  one arm never cohered; report that rather than a difference.")
        return
    d = np.mean(b) - np.mean(a)
    print("  PRE-REGISTERED READING:")
    if d > 10:
        print(f"    op0.00 coheres {d:.0f} windows SOONER. The operator causes")
        print("    warm-up by steering on no data. Fix: ramp operator_weight with")
        print("    observation count instead of applying it from window 0.")
    elif abs(d) <= 10:
        print(f"    difference {d:+.0f} windows -- within noise at n=2.")
        print("    Warm-up is intrinsic to sections and vocabulary accumulating;")
        print("    the operator is exonerated. This was the stated likely outcome.")
    else:
        print(f"    op0.35 coheres {-d:.0f} windows sooner. The operator HELPS a")
        print("    cold factory and the premise of this experiment was wrong.")
    print()
    print("  n=2 per arm. A direction check, not a significance test.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
