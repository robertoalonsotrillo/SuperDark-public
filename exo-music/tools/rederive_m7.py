#!/usr/bin/env python3
"""Is m7 measuring the factory, or measuring how long the factory has run?

THE SUSPICION
m7_spectral_gap_settles tests the interquartile range of the operator's spectral
gap against [0.02, 0.45]. TransferOperator.sc accumulates transition counts with
NO decay -- `row[cell] = (row[cell] ? 0) + 1` -- so the matrix is a cumulative
estimate over every transition since boot. A cumulative estimator converges; its
eigenvalues stop moving as n grows whatever the factory does. If that is what
drives the IQR, then m7 falls with age by construction, and on a factory whose
kernel says it runs forever it must eventually fail no matter how the factory
behaves. That is m6's fault inverted: m6 could never fail, m7 cannot keep passing.

This measures it instead of asserting it.

  1  VALIDATION. Rebuild the cumulative operator offline from the machine
     sequence and compare with the lambda2 the factory logged. If they disagree
     the rest is worthless, so it is checked first and printed either way.
  2  AGE. Measure the IQR of lambda2 in equal-sized blocks as transitions
     accumulate. Falling with age = the statistic is about the estimator.
  3  ALTERNATIVE. The same series from a WINDOWED operator (exponential
     forgetting), which describes recent behaviour rather than the average since
     boot, and whose variability is therefore age-invariant.
  4  NULL. Shuffle the machine sequence, preserving its marginal. This says what
     the statistic does when there is no sequential structure at all, which is
     the only way to know whether a given IQR means "coherent" or "nothing".

Nothing here re-prices anything. It reports what the current statistic is a
function of, and what an age-invariant replacement would look like.

    python3 tools/rederive_m7.py --log <windows.log>
"""
import argparse
import glob
import os
import statistics as st
import sys

import numpy as np


def machines(path):
    seq = []
    logged = {}
    for line in open(path, errors="replace"):
        if line.startswith("OPERATOR"):
            p = line.split()[1].split(",")
            try:
                logged[int(p[0])] = float(p[2])       # field 2 is lambda2
            except (ValueError, IndexError):
                pass
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                try:
                    seq.append((int(p[1]), p[2]))
                except (ValueError, IndexError):
                    pass
    seq.sort()
    return seq, logged


def lambda2_of(counts, cells):
    """Second-largest |eigenvalue| of the row-normalised transition matrix."""
    n = len(cells)
    if n < 3:
        return 0.0
    idx = {c: i for i, c in enumerate(cells)}
    M = np.zeros((n, n))
    for a, row in counts.items():
        for b, v in row.items():
            M[idx[a], idx[b]] = v
    rs = M.sum(axis=1, keepdims=True)
    rs[rs == 0] = 1.0
    M = M / rs
    ev = np.linalg.eigvals(M)
    mags = np.sort(np.abs(ev))[::-1]
    return float(mags[1]) if len(mags) > 1 else 0.0


def series(seq, decay=None, every=1):
    """lambda2 after each observation. decay=None is the cumulative operator the
    factory actually runs; a decay in (0,1) multiplies all counts each step, so
    the matrix forgets with a half-life of ln(2)/-ln(decay) transitions."""
    counts, cells, out = {}, [], []
    prev = None
    for k, (w, m) in enumerate(seq):
        if prev is not None:
            if decay is not None:
                for row in counts.values():
                    for b in row:
                        row[b] *= decay
            counts.setdefault(prev, {})
            counts[prev][m] = counts[prev].get(m, 0.0) + 1.0
            if prev not in cells:
                cells.append(prev)
            if m not in cells:
                cells.append(m)
        prev = m
        if k % every == 0 and len(cells) >= 3:
            out.append((w, lambda2_of(counts, cells)))
    return out


def iqr(v):
    if len(v) < 8:
        return float("nan")
    q = st.quantiles(v, n=4)
    return q[2] - q[0]


def blocks(sr, nblocks=6):
    vals = [x for _, x in sr]
    n = len(vals) // nblocks
    return [(i * n, iqr(vals[i * n:(i + 1) * n])) for i in range(nblocks) if n >= 8]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=None)
    ap.add_argument("--every", type=int, default=4,
                    help="recompute every k transitions (eigendecomposition is "
                         "O(n^3) and the factory itself only does it every 8th)")
    a = ap.parse_args()
    log = a.log or sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                          key=os.path.getmtime)[-1]
    seq, logged = machines(log)
    print(f"\n  {os.path.basename(log)}: {len(seq)} transitions, "
          f"{len(set(m for _, m in seq))} distinct machines")

    # ---- 1. validation ----------------------------------------------------
    cum = series(seq, decay=None, every=a.every)
    pairs = [(logged[w], v) for w, v in cum if w in logged]
    if len(pairs) > 30:
        mine = np.array([b for _, b in pairs]); theirs = np.array([a_ for a_, _ in pairs])
        r = float(np.corrcoef(mine, theirs)[0, 1])
        md = float(np.median(np.abs(mine - theirs)))
        print(f"  validation vs the factory's own lambda2: r = {r:+.4f}, "
              f"median |diff| = {md:.4f}  ({len(pairs)} points)")
        if r < 0.9:
            print("  RECONSTRUCTION DOES NOT MATCH. Everything below is about a")
            print("  different operator than the one the factory runs; stop here.")
    else:
        print("  too few overlapping points to validate")

    # ---- 2. does the statistic fall with age? -----------------------------
    print()
    print("  IQR of lambda2 in equal blocks, as transitions accumulate:")
    print(f"    {'from transition':>16} {'cumulative':>12} {'windowed':>12}")
    win = series(seq, decay=0.995, every=a.every)     # half-life ~139 transitions
    bc, bw = blocks(cum), blocks(win)
    for (i, c), (_, w) in zip(bc, bw):
        print(f"    {i*a.every:16d} {c:12.5f} {w:12.5f}")
    if len(bc) >= 4:
        first = st.mean([c for _, c in bc[:2]])
        last = st.mean([c for _, c in bc[-2:]])
        fw = st.mean([w for _, w in bw[:2]])
        lw = st.mean([w for _, w in bw[-2:]])
        print()
        print(f"  cumulative: first blocks {first:.5f} -> last {last:.5f}  "
              f"({'FALLS with age' if last < first * 0.7 else 'no clear fall'})")
        print(f"  windowed:   first blocks {fw:.5f} -> last {lw:.5f}  "
              f"({'falls' if lw < fw * 0.7 else 'age-invariant'})")

    # ---- 3. what does no structure look like? -----------------------------
    rng = np.random.default_rng(11)
    ms = [m for _, m in seq]
    null_c, null_w = [], []
    for _ in range(5):
        sh = list(ms); rng.shuffle(sh)
        s2 = list(zip([w for w, _ in seq], sh))
        null_c.append(iqr([v for _, v in series(s2, None, a.every)]))
        null_w.append(iqr([v for _, v in series(s2, 0.995, a.every)]))
    print()
    print(f"  shuffled null (no sequential structure), 5 permutations:")
    print(f"    cumulative IQR {st.mean(null_c):.5f}   observed {iqr([v for _,v in cum]):.5f}")
    print(f"    windowed   IQR {st.mean(null_w):.5f}   observed {iqr([v for _,v in win]):.5f}")
    print()
    print("  A statistic worth a charter bound has to separate the observed")
    print("  factory from that null. Whichever of the two does so, at every age,")
    print("  is the one m7 should be re-derived on -- and the bound then comes")
    print("  from the null, not from a run that happened to pass.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
