#!/usr/bin/env python3
"""Measure whether the live factory converges, and by when.

PRE-REGISTERED 2026-08-22, BEFORE THE RUN THAT IT SCORES.

Why this needs measuring at all. "Converged by generation 4" comes from runs
12-13, which were OFFLINE agent iterations. It stands for what it measured. But
no live run has ever been scored for variability, because until 22 August 19 of
the 22 machines were silent no-ops: machine names reached the dispatch switch as
Strings while the switch matches Symbols, so every class machine except \\sc
returned nil and never ran. Any live diversity figure recorded before today
describes a three-machine vocabulary. This is the first measurement of the
system that actually exists.

Note the units differ and are not comparable: a GENERATION is one agent
iteration rewriting the behaviour model; a WINDOW is one selection inside a
single performance. This measures within-performance convergence only. It says
nothing about the closed loop.

FIXED BEFORE SEEING THE DATA
----------------------------
Frame: 12 consecutive windows, stepping by 1. Twelve because that is
`history_len`, the depth the novelty penalty already looks back, so the frame
matches the memory the factory has rather than a number chosen to flatter it.

M1  vocabulary      distinct machines selected in the frame, of 22
M2  entropy         Shannon entropy of the selection distribution in the frame,
                    normalised by log(22). 1.0 is uniform over everything,
                    0.0 is one machine.
M3  repeat rate     fraction of adjacent window pairs choosing the same machine
M4  wandering       mean pairwise Euclidean distance between target positions in
                    the frame, in rank-normalised descriptor space (0..1 per axis)

CONVERGENCE IS DECLARED IF, AND ONLY IF:
    M2 falls below 0.50 and stays below it for 3 consecutive frames.
The window index of the first of those three frames is the convergence point.

SECONDARY, REPORTED WHETHER OR NOT CONVERGENCE IS DECLARED:
    - Spearman rho of M2 against window index. Negative means narrowing.
    - M1 and M4 at first frame vs last frame.

WHAT WOULD FALSIFY THE ANTI-CONVERGENCE MACHINERY: sections, the novelty
penalty and per-machine drift were all built to keep the factory moving. If M2
declines monotonically anyway, they do not work, and that is the finding.

A REASON TO DISTRUST A GOOD RESULT: 22 machines cannot converge as fast as 3,
so a flat M2 may reflect vocabulary size alone. M1 is reported next to it for
exactly that reason -- a high M2 with M1 near 22 is breadth; a high M2 with M1
near 5 is churn inside a small set.
"""
import csv
import math
import sys
from collections import Counter

FRAME = 12
ENTROPY_FLOOR = 0.50
CONSECUTIVE = 3
N_MACHINES = 22


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


def load(path):
    rows = []
    with open(path) as f:
        for line in f:
            if not line or not line[0].isdigit():
                continue
            p = line.rstrip("\n").split(",")
            if len(p) < 15:
                continue
            try:
                target = [float(x) for x in p[13].split("|")] if p[13] != "-" else None
            except ValueError:
                target = None
            rows.append({"t": float(p[0]), "win": int(p[1]), "machine": p[2],
                         "kind": p[3], "amp": float(p[4]), "target": target,
                         "section": p[14]})
    return rows


def main(path):
    rows = load(path)
    if len(rows) < FRAME + CONSECUTIVE:
        sys.exit(f"only {len(rows)} windows; need at least {FRAME + CONSECUTIVE}")

    frames = []
    for i in range(len(rows) - FRAME + 1):
        fr = rows[i:i + FRAME]
        ms = [r["machine"] for r in fr]
        c = Counter(ms)
        total = sum(c.values())
        ent = -sum((n / total) * math.log(n / total) for n in c.values())
        ent /= math.log(N_MACHINES)
        rep = sum(1 for a, b in zip(ms, ms[1:]) if a == b) / (len(ms) - 1)
        ts = [r["target"] for r in fr if r["target"]]
        if len(ts) > 1:
            d, k = 0.0, 0
            for a in range(len(ts)):
                for b in range(a + 1, len(ts)):
                    d += math.dist(ts[a], ts[b])
                    k += 1
            wander = d / k
        else:
            wander = float("nan")
        frames.append({"win": fr[0]["win"], "M1": len(c), "M2": ent,
                       "M3": rep, "M4": wander})

    run, conv = 0, None
    for f in frames:
        run = run + 1 if f["M2"] < ENTROPY_FLOOR else 0
        if run >= CONSECUTIVE and conv is None:
            conv = f["win"] - CONSECUTIVE + 1

    print(f"windows {len(rows)}   duration {rows[-1]['t'] / 60:.1f} min   "
          f"frames {len(frames)}")
    print(f"machines ever selected: {len(set(r['machine'] for r in rows))} of {N_MACHINES}")
    print(f"sections visited: {len(set(r['section'] for r in rows))}")
    print(f"windows audible (amp>0.0004): "
          f"{sum(1 for r in rows if r['amp'] > 0.0004)}/{len(rows)}")
    print()
    print("  win    M1 vocab   M2 entropy   M3 repeat   M4 wander")
    step = max(1, len(frames) // 25)
    for f in frames[::step]:
        print(f"  {f['win']:4d}   {f['M1']:8d}   {f['M2']:10.3f}   "
              f"{f['M3']:9.3f}   {f['M4']:9.3f}")
    print()
    rho = spearman([f["win"] for f in frames], [f["M2"] for f in frames])
    print(f"M2 vs window index, Spearman rho = {rho:+.3f}"
          f"   ({'narrowing' if rho < -0.3 else 'widening' if rho > 0.3 else 'flat'})")
    print(f"M1 first frame {frames[0]['M1']}  ->  last frame {frames[-1]['M1']}")
    print(f"M4 first frame {frames[0]['M4']:.3f}  ->  last frame {frames[-1]['M4']:.3f}")
    print()
    if conv is None:
        print(f"NO CONVERGENCE by the pre-registered criterion "
              f"(M2 < {ENTROPY_FLOOR} for {CONSECUTIVE} consecutive frames).")
        print(f"M2 minimum over the run: {min(f['M2'] for f in frames):.3f}")
    else:
        print(f"CONVERGED at window {conv} "
              f"(M2 < {ENTROPY_FLOOR} for {CONSECUTIVE} consecutive frames).")
    counts = Counter(r["machine"] for r in rows)
    print()
    print("selection counts: " + "  ".join(
        f"{m}:{n}" for m, n in counts.most_common()))
    never = N_MACHINES - len(counts)
    print(f"machines never selected: {never}")


if __name__ == "__main__":
    main(sys.argv[1])
