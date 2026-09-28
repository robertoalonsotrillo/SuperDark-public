#!/usr/bin/env python3
"""Does the versioning readout point the right way? Three chains, known answers.

WHY THIS EXISTS. version_operator.py reported 1 - |lambda2| under a sentence
saying a WIDE gap means durable versions. That reading is inverted: 1 - |lambda2|
governs mixing speed, so wide means the chain forgets its starting cell in a few
steps, which is versions bleeding into each other. The file was changed on
7 Sept to report the number of metastable sets m, the drop after the m-th
eigenvalue, and a dwell time. A claim about which way an instrument points needs
a case where the answer is known in advance, and that is what this is.

THE THREE ARMS, nine cells partitioned into three blocks throughout:

  hard    the chain almost never leaves its block (p_stay 0.995)
          -> three durable versions
  soft    it leaves often (p_stay 0.90)
          -> three versions, but provisional
  none    no block structure at all (p_stay 0.0)
          -> one version, which is to say none

WHAT MUST HOLD, fixed before running:
  1. `none` has the WIDEST 1 - |lambda2| of the three. If the old reading were
     right, the arm with no version structure would be the best-versioned one.
  2. `hard` and `soft` both return m = 3; `none` returns m = 1.
  3. dwell separates hard from soft by an order of magnitude, though their m and
     their drop are nearly the same. That is the whole reason dwell is reported:
     P432 distinguishes "durable and well defined" from "provisional or
     transitional", and m alone cannot see the difference.

    python3 tools/test_version_readout.py
"""
import sys
import os

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from version_operator import spectrum_of, versions_of, null_test

K, GROUPS, N = 9, 3, 4000
ARMS = [("hard  (metastable)", 0.995), ("soft  (transitional)", 0.90),
        ("none  (fast mixing)", 0.0)]


def chain(k, groups, p_stay, n, rng):
    g = np.repeat(np.arange(groups), k // groups)
    seq = [0]
    for _ in range(n):
        cur = seq[-1]
        cand = np.where(g == g[cur])[0] if rng.random() < p_stay else np.arange(k)
        seq.append(int(rng.choice(cand)))
    return seq


def main():
    rng = np.random.default_rng(0)
    print()
    print(f"  {K} cells, {GROUPS} blocks, {N} steps, theta from a block-shuffled null")
    print()
    print(f"  {'arm':22s} {'1-|l2|':>8} {'spectrum head':>26} {'m':>3} "
          f"{'drop':>7} {'dwell':>9}")
    got = {}
    for name, ps in ARMS:
        s = chain(K, GROUPS, ps, N, rng)
        ev, _ = spectrum_of(s, K)
        _, nulls, _ = null_test(s, K, draws=120, seed=1, block=20)
        theta = float(1.0 - np.percentile(nulls, 5))
        m, drop, dwell = versions_of(ev, theta)
        got[name.split()[0]] = dict(gap=float(1 - ev[1]), m=m, drop=drop, dwell=dwell)
        print(f"  {name:22s} {1-ev[1]:8.4f} {' '.join(f'{v:.3f}' for v in ev[:4]):>26} "
              f"{m:3d} {drop:7.3f} {dwell:9.1f}")

    print()
    h, s_, n_ = got["hard"], got["soft"], got["none"]
    c1 = n_["gap"] > h["gap"] and n_["gap"] > s_["gap"]
    c2 = h["m"] == GROUPS and s_["m"] == GROUPS and n_["m"] == 1
    c3 = h["dwell"] > 5 * s_["dwell"]
    print(f"  1. widest 1-|l2| belongs to the arm with NO versions   "
          f"{'PASS' if c1 else 'FAIL'}")
    print(f"  2. m = {GROUPS}, {GROUPS}, 1 across hard, soft, none              "
          f"{'PASS' if c2 else 'FAIL'}")
    print(f"  3. dwell separates hard from soft at equal m          "
          f"{'PASS' if c3 else 'FAIL'}")
    print()
    if c1 and c2 and c3:
        print("  The readout points the right way. Note arm 1 directly: the chain with")
        print("  no version structure has the WIDEST ordinary gap, so the sentence this")
        print("  file used to print would have called it the best-versioned of the")
        print("  three. And note arms hard/soft: same m, nearly the same drop, dwell")
        print("  differing twentyfold. Only dwell tells durable from provisional.")
        return 0
    print("  FAILED. Do not report a versioning figure from this readout.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
