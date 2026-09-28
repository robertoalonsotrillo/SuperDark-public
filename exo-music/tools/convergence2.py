#!/usr/bin/env python3
"""Convergence, second attempt, with a null distribution.

WHY THE FIRST ONE WAS WRONG
---------------------------
convergence.py declared convergence when M2 (normalised selection entropy over
a 12-window frame) fell below 0.50 for 3 consecutive frames. That fires on any
transient dip. It fired on run 57 at window 18 while that run ENDED MORE VARIED
than it started (rho +0.354, vocabulary 6 -> 7). The criterion and the
trajectory disagreed, and the criterion was wrong.

It also had no null. "Converged" was asserted against a threshold picked by
hand, so it could not distinguish narrowing produced by the factory's dynamics
from narrowing that any sequence with that machine distribution would show.
That matters directly: a 22-machine vocabulary cannot narrow as fast as a
3-machine one, so a fixed threshold measures vocabulary size as much as
behaviour.

THE INSTRUMENT
--------------
Same M1-M4 as before. Two conditions, BOTH required:

  C1  TERMINAL, not transient.
      median M2 over the final quarter of frames
        <= 0.75 x median M2 over the first quarter.
      A dip that recovers fails this.

  C2  MORE THAN CHANCE, given this vocabulary.
      Spearman rho of M2 against frame index, compared against a null built by
      permuting the window->machine assignment 2000 times. The permutation
      keeps the machine COUNTS exactly and destroys only the temporal order,
      so the null already contains whatever narrowing the distribution alone
      implies. p = fraction of null rho at or below observed rho.
      Require p <= 0.05.

Convergence is declared iff C1 and C2 both hold. Convergence TIME, reported
only when declared, is the first frame after which M2 never again rises above
the first-quarter median x 0.75.

WHAT WOULD MAKE THIS WRONG TOO. The permutation holds the machine counts fixed,
so it cannot detect a factory that narrows by never selecting most of its
vocabulary in the first place -- that shows up in M1, which is reported
alongside and must be read with it. And C1's 0.75 is a stipulation; it is
reported as a continuous ratio as well, so a reader can apply their own.

STATUS OF RESULTS
-----------------
Runs 53, 54, 57 and 58 were already seen before this criterion was written, so
re-scoring them is EXPLORATORY and is labelled as such in the output. The
confirmatory test is any run scored after this file was committed.
"""
import csv
import math
import random
import sys
from collections import Counter

FRAME = 12
N_MACHINES = 22
TERMINAL_RATIO = 0.75
N_PERM = 2000
ALPHA = 0.05


def spearman(xs, ys):
    def rank(v):
        order = sorted(range(len(v)), key=lambda i: v[i])
        r = [0.0] * len(v)
        for pos, i in enumerate(order):
            r[i] = pos
        return r

    rx, ry = rank(xs), rank(ys)
    n = len(xs)
    if n < 3:
        return float("nan")
    mx, my = sum(rx) / n, sum(ry) / n
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    den = math.sqrt(sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry))
    return num / den if den else float("nan")


def entropy_series(machines):
    out = []
    for i in range(len(machines) - FRAME + 1):
        c = Counter(machines[i:i + FRAME])
        tot = sum(c.values())
        e = -sum((n / tot) * math.log(n / tot) for n in c.values())
        out.append(e / math.log(N_MACHINES))
    return out


def load(path):
    rows = []
    for line in open(path):
        if not line or not line[0].isdigit():
            continue
        p = line.rstrip("\n").split(",")
        if len(p) < 15:
            continue
        try:
            tgt = [float(x) for x in p[13].split("|")] if p[13] != "-" else None
        except ValueError:
            tgt = None
        rows.append({"win": int(p[1]), "machine": p[2], "amp": float(p[4]), "target": tgt})
    return rows


def main(path, label=""):
    rows = load(path)
    machines = [r["machine"] for r in rows]
    if len(machines) < FRAME + 8:
        sys.exit(f"only {len(machines)} windows")

    m2 = entropy_series(machines)
    idx = list(range(len(m2)))
    rho = spearman(idx, m2)

    q = max(2, len(m2) // 4)
    first_q = sorted(m2[:q])[q // 2]
    last_q = sorted(m2[-q:])[q // 2]
    ratio = last_q / first_q if first_q else float("nan")
    c1 = ratio <= TERMINAL_RATIO

    rnd = random.Random(20260823)
    null = []
    for _ in range(N_PERM):
        sh = machines[:]
        rnd.shuffle(sh)
        null.append(spearman(idx, entropy_series(sh)))
    p = sum(1 for v in null if v <= rho) / len(null)
    c2 = p <= ALPHA

    vocab = [len(set(machines[i:i + FRAME])) for i in range(len(machines) - FRAME + 1)]

    print(f"=== {path.split('/')[-1]}  {label}")
    print(f"windows {len(machines)}   frames {len(m2)}   "
          f"machines used {len(set(machines))} of {N_MACHINES}")
    print(f"audible {sum(1 for r in rows if r['amp'] > 0.0004)}/{len(rows)}")
    print()
    print(f"  M2 first quarter median  {first_q:.3f}")
    print(f"  M2 last  quarter median  {last_q:.3f}")
    print(f"  C1 terminal ratio        {ratio:.3f}   "
          f"(<= {TERMINAL_RATIO} required)   {'PASS' if c1 else 'fail'}")
    print(f"  observed rho             {rho:+.3f}")
    print(f"  null rho  median         {sorted(null)[len(null)//2]:+.3f}   "
          f"5th pct {sorted(null)[int(0.05*len(null))]:+.3f}")
    print(f"  C2 permutation p         {p:.4f}   "
          f"(<= {ALPHA} required)   {'PASS' if c2 else 'fail'}")
    print(f"  M1 vocabulary            {vocab[0]} -> {vocab[-1]}")
    print()
    if c1 and c2:
        thresh = first_q * TERMINAL_RATIO
        t = next((i for i in range(len(m2)) if all(v <= thresh for v in m2[i:])), None)
        print(f"  CONVERGED   (C1 and C2 both hold)   from frame {t}, "
              f"window {rows[t]['win'] if t is not None and t < len(rows) else '?'}")
    else:
        why = " and ".join([w for w, ok in [("C1 terminal", c1), ("C2 vs null", c2)] if not ok])
        print(f"  NOT CONVERGED   ({why} not met)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
