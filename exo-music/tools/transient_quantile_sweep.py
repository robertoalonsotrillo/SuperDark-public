#!/usr/bin/env python3
"""Which ORDER STATISTIC of a grain run separates damaged material best?

WHY THIS FILE EXISTS
--------------------
tools/transient_median_null.py established that the two candidate gates are the
same test read at two places:

    old  reject when the k-th LARGEST grain score in the run exceeds T
         (k = ceil(0.25 n): 6 of 24 at ev, 3 of 12 at mid, 2 of 8 at macro)
    new  reject when the MEDIAN grain score exceeds M

so the choice between them is a choice of quantile, and there is no reason to
believe either of the two that happen to have been proposed is the best one.
This file sweeps EVERY order statistic of the run -- largest, second largest,
... , median, ... , smallest -- puts each at the threshold that rejects the same
share of undamaged material, and measures what each detects. That is the whole
family, evaluated on one axis, with the operating point held fixed so the
comparison is about the statistic.

It reads the JSON that transient_median_null.py --save writes, so it decodes
nothing and can be re-run freely against a stored draw. It cannot invent a new
sample: the sampling caveats of that file (seven named damaged tracks of
thirteen, runs cut from random starts, glitch aesthetics inside the clean null)
carry over unchanged and the detection column is still a LOWER BOUND.

Thresholds are derived on one half of the clean tracks and false rejection is
measured on the other, exactly as in transient_median_null.py; a sweep is a
search over many candidates and scoring a search in-sample is how a null gets
fitted to its own answer.

  python3 tools/transient_median_null.py --tracks 2500 --save /tmp/mnull.json
  python3 tools/transient_quantile_sweep.py --scores /tmp/mnull.json
"""
import argparse
import json

import numpy as np


def order_stat(run, j):
    """The j-th LARGEST value in a run (j = 1 is the maximum)."""
    return float(np.sort(np.asarray(run, dtype=float))[-j])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scores", required=True,
                    help="JSON written by transient_median_null.py --save")
    ap.add_argument("--frr", type=float, default=2.0,
                    help="false-rejection rate, in percent, at which every "
                         "candidate is compared. All candidates sit here, so "
                         "the only thing varying down the table is the quantile")
    a = ap.parse_args()

    d = json.load(open(a.scores))
    meta = d.get("_meta", {})
    print()
    print(f"  scores:  {a.scores}")
    print(f"  drawn at seed {meta.get('seed')}, {meta.get('tracks')} clean tracks, "
          f"{meta.get('reps')} runs per damaged track, SR {meta.get('sr')}")
    print(f"  every candidate held at a {a.frr:g}% false-rejection rate, threshold")
    print(f"  derived on half the clean tracks and measured on the other half")

    for g, blk in d.items():
        if g.startswith("_"):
            continue
        clean = [np.asarray(r, dtype=float) for r in blk["clean"]]
        dmg = [np.asarray(r, dtype=float) for _, r in blk["damaged"]]
        if not clean or not dmg:
            continue
        n = len(clean[0])
        half = len(clean) // 2
        print()
        print(f"  === {g}   runs of {n};  {len(clean)} clean tracks, "
              f"{len(dmg)} damaged runs")
        print(f"      {'j-th largest':>13} {'threshold':>10} {'clean rej':>10} "
              f"{'detect':>8}   note")
        for j in range(1, n + 1):
            cd = np.array([order_stat(r, j) for r in clean[:half]])
            ch = np.array([order_stat(r, j) for r in clean[half:]])
            dm = np.array([order_stat(r, j) for r in dmg])
            t = float(np.percentile(cd, 100.0 - a.frr))
            note = []
            if j == max(1, int(np.ceil(0.25 * n - 1e-9))):
                note.append("LIVE GATE reads here")
            if j in (n // 2, n // 2 + 1) and n % 2 == 0:
                note.append("median")
            if j == (n + 1) // 2 and n % 2 == 1:
                note.append("median")
            print(f"      {j:>13} {t:>10.1f} "
                  f"{100 * float(np.mean(ch > t)):>9.2f}% "
                  f"{100 * float(np.mean(dm > t)):>7.1f}%   {', '.join(note)}")
    print()
    print("  A FLAT COLUMN MEANS THE CHOICE OF QUANTILE DOES NOT MATTER and the")
    print("  argument was never about max versus median. A column that peaks")
    print("  somewhere names the statistic worth using -- and if the peak is not")
    print("  where the live gate reads, that is a finding about the gate.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
