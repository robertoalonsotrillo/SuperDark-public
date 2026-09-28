#!/usr/bin/env python3
"""Place a treatment run inside the distribution of CONTROL runs.

WHY NOT SPLIT-HALF, which is what this tool did first. The obvious null for "do
these two runs differ" is to split each run in half and ask how much a run
differs from itself. Run against two runs that were BOTH the control arm, that
null declared six of seven metrics significantly different. It is wrong for two
reasons, and the second is the interesting one:

  * Several metrics are CUMULATIVE. Distinct machines, first-time machines and
    operator cells only ever grow, so a run's second half must differ from its
    first, and the "null" is measuring accumulation rather than noise.
  * Even for the non-cumulative ones, within-run variation is not between-run
    variation. Two runs see different sections, different self-ingested grains
    and a different warm-up. A null built inside one run cannot see any of that.

So the null is the SPREAD ACROSS CONTROL RUNS, of which this project has many on
disk. A treatment is interesting only if it falls outside where the control arm
already sits, and cumulative quantities are expressed per 100 windows so that a
long run is not automatically "broader" than a short one.

    python3 tools/compare_arms.py --treatment new.log
    python3 tools/compare_arms.py --treatment new.log --controls '/path/live_*.log'
"""
import argparse
import glob
import math
import os
import sys

import numpy as np

RENDERS = "/Volumes/FMA/superdark/renders"


def parse(path):
    mach, peak, gap, cells, simul = {}, {}, {}, {}, []
    for line in open(path, errors="replace"):
        try:
            if line.startswith("MASTER "):
                f = line.split()[1].split(",")
                peak[int(f[0])] = float(f[1])
            elif line.startswith("OPERATOR "):
                f = line.split()[1].split(",")
                gap[int(f[0])] = float(f[1])
                if len(f) > 3:
                    cells[int(f[0])] = int(float(f[3]))
            elif line.startswith("SIMUL "):
                f = line.split()[1].split(",")
                simul.append([float(x) for x in f[3].split("|")])
            elif line[0].isdigit():
                f = line.strip().split(",")
                if len(f) > 3 and f[3] in ("runtime", "class"):
                    mach.setdefault(int(f[1]), set()).add(f[2])
        except (ValueError, IndexError):
            continue
    return mach, peak, gap, cells, simul


def stats(path, warmup=45, budget=400):
    """Metrics for one run, over a FIXED window budget.

    Per-100-windows was not enough. Distinct machines SATURATE -- a run sees most
    of its vocabulary early and then repeats -- so dividing by length rewards
    short runs and the control range came out 2.82 to 46.46, which is not a null,
    it is an artefact of comparing 100-window runs with 2,500-window ones. Every
    run is now truncated to the same number of post-warm-up windows, and runs too
    short to fill the budget are dropped rather than scaled up.
    """
    mach, peak, gap, cells, simul = parse(path)
    ws = [w for w in sorted(mach) if w >= warmup]
    if len(ws) < budget:
        return None
    ws = ws[:budget]
    seen = set()
    for w in ws:
        seen |= mach[w]
    pk = [peak[w] for w in ws if w in peak]
    gp = [gap[w] for w in ws if w in gap]
    cl = [cells[w] for w in ws if w in cells]
    ent = None
    if simul:
        h = np.array(simul[-1], dtype=float)
        if h.sum() > 30:
            p = h / h.sum()
            p = p[p > 0]
            ent = float(-(p * np.log2(p)).sum() / math.log2(len(h)))
    n100 = len(ws) / 100.0   # constant across runs now, kept for readability
    return dict(
        windows=len(ws),
        # PER 100 WINDOWS, because these accumulate and a longer run would
        # otherwise look broader for no reason but its length
        breadth=len(seen) / n100,
        cells=(np.median(cl) / n100) if cl else float("nan"),
        gap=float(np.median(gp)) if gp else float("nan"),
        level=float(np.median(pk)) if pk else float("nan"),
        silent=float(np.mean([p < 0.004 for p in pk])) if pk else float("nan"),
        intervals=ent,
    )


FIELDS = [("breadth", "distinct machines / 100 win", 2),
          ("cells", "operator cells / 100 win", 2),
          ("gap", "operator spectral gap", 3),
          ("level", "median master peak", 4),
          ("silent", "fraction silent", 3),
          ("intervals", "interval entropy", 3)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--treatment", required=True)
    ap.add_argument("--controls", default=os.path.join(RENDERS, "live_*.log"))
    ap.add_argument("--warmup", type=int, default=45)
    ap.add_argument("--budget", type=int, default=400,
                    help="post-warm-up windows scored per run; runs shorter "
                         "than this are dropped, not scaled")
    a = ap.parse_args()

    tpath = os.path.abspath(a.treatment)
    ctrl = []
    for p in sorted(glob.glob(a.controls)):
        if os.path.abspath(p) == tpath:
            continue
        s = stats(p, a.warmup, a.budget)
        if s:
            ctrl.append((os.path.basename(p), s))
    T = stats(tpath, a.warmup, a.budget)
    if T is None:
        print("  treatment run has too few scoreable windows", file=sys.stderr)
        return 2
    if len(ctrl) < 4:
        print(f"  only {len(ctrl)} usable control runs; the null needs more",
              file=sys.stderr)
        return 2

    print()
    print(f"  treatment {os.path.basename(tpath)}  {T['windows']} windows "
          f"(budget {a.budget} after {a.warmup} warm-up)")
    print(f"  control   {len(ctrl)} runs, "
          f"{sum(c[1]['windows'] for c in ctrl)} windows total")
    print()
    print(f"  {'':30} {'treatment':>10} {'control median':>15} "
          f"{'control range':>22} {'':>10}")
    print("  " + "-" * 92)
    for k, label, dp in FIELDS:
        vs = [c[1][k] for c in ctrl
              if c[1].get(k) is not None and not (isinstance(c[1][k], float)
                                                  and math.isnan(c[1][k]))]
        t = T.get(k)
        if t is None or (isinstance(t, float) and math.isnan(t)) or len(vs) < 4:
            print(f"  {label:30} {'—':>10}   (no control data)")
            continue
        vs = np.array(vs, dtype=float)
        lo, hi = float(vs.min()), float(vs.max())
        med = float(np.median(vs))
        inside = lo <= t <= hi
        verdict = "inside" if inside else "OUTSIDE"
        print(f"  {label:30} {t:10.{dp}f} {med:15.{dp}f} "
              f"{lo:10.{dp}f} to {hi:<9.{dp}f} {verdict:>8}")

    print()
    print("  READING IT")
    print("    'inside' means the treatment sits within the range the CONTROL arm")
    print("    already occupies across separate runs, so the treatment explains")
    print("    nothing this factory does not already do on its own.")
    print("    'OUTSIDE' is worth a second look and is still one run: the control")
    print("    range is a range of observations, not a confidence interval, and")
    print("    it widens with every run added to it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
