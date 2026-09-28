#!/usr/bin/env python3
"""Is the factory still going anywhere it has not been?

A DIFFERENT QUESTION FROM EVERY OTHER TOOL HERE. sonic_variety asks whether the
sound returns to itself within a run; machine_variance asks whether a machine is
a fixed stamp; vertical_census asks whether simultaneities recur. All three ask
whether the factory VARIES. None asks whether it DISCOVERS.

Those come apart completely. A factory can vary endlessly inside a region it
exhausted a week ago, and every variety metric will pass while nothing new has
happened since. For a project whose destination is "machines that learn from
accumulated behaviour and adapt in real time", that distinction is the whole
claim, and until now nothing measured it.

Roberto, 4 Sept: "can we monitor newness in long- and mid-term behaviours?"

WHAT COUNTS AS A PLACE. The factory navigates a six-dimensional descriptor space
and its target is logged every window. Discretised into cells, the sequence of
targets is a path, and the question is how often that path enters a cell no run
has ever entered. Cell size is the one real parameter: too fine and every window
is novel by rounding, too coarse and nothing ever is. Reported for several
resolutions so the reader can see whether the answer depends on it.

BY TIMESCALE, because that is what was asked. A "long-term behaviour" is a
section holding a macro machine; a mid-term one is the mid slot. So novelty is
counted over PAIRS -- (cell, machine) at each layer -- not over cells alone. The
factory reaching an old region with a machine that has never been there is new in
the sense that matters, and a figure that counted only cells would miss it.

AND AGAINST A NULL THAT GENERATES, because a bounded walk saturates on its own.
The comparison is a random walk of the same length taking steps of the same size
in the same bounded space. A DIRECTED explorer should beat it; a converging one
should not. m5_not_converging cannot answer this: it is entropy over machine
selection within a single run and has no memory of where earlier runs went.

The first version of this tool used a re-ORDERING as its null and reported
z = +10.27. That was an artefact: shuffling destroys the temporal clustering
that makes late-discovered states look novel, so it flattered the factory.
Recorded because it is the second time in this project that a shuffle has been
mistaken for a control -- the vertical census made the same error, scoring voice
persistence as harmony.

    python3 tools/novelty.py                 # every run, chronological
    python3 tools/novelty.py --cells 6 --since 260901
"""
import argparse
import collections
import glob
import os
import random
import sys

import numpy as np

RENDERS = "/Volumes/FMA/superdark/renders"


def read_run(path):
    """(window, machine, layerless target cell source) per window, plus slots."""
    rows, slots = [], {}
    for line in open(path, errors="replace"):
        if line.startswith("SLOT "):
            f = line[5:].strip().split(",")
            if len(f) >= 3:
                try:
                    slots.setdefault(f[1], []).append((int(f[0]), f[2]))
                except ValueError:
                    pass
            continue
        if not line or not line[0].isdigit():
            continue
        f = line.strip().split(",")
        if len(f) < 15 or f[3] not in ("runtime", "class"):
            continue
        try:
            w = int(f[1])
            tgt = [float(x) for x in f[13].split("|")]
        except (ValueError, IndexError):
            continue
        if len(tgt) >= 5:
            rows.append((w, f[2], tgt))
    return rows, slots


def slot_at(slots, layer, w):
    """Which machine held this layer at window w -- SLOT lines mark changes only."""
    cur = None
    for sw, m in slots.get(layer, []):
        if sw <= w:
            cur = m
        else:
            break
    return cur


def curve(states):
    """Cumulative distinct states as the sequence is walked."""
    seen, out = set(), []
    for s in states:
        seen.add(s)
        out.append(len(seen))
    return np.array(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cells", type=int, default=6, help="bins per descriptor dimension")
    ap.add_argument("--since", default=None, help="YYMMDD, ignore earlier runs")
    ap.add_argument("--draws", type=int, default=50)
    a = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")), key=os.path.getmtime)
    if a.since:
        paths = [p for p in paths if os.path.basename(p)[5:11] >= a.since]
    if not paths:
        print("  no logs", file=sys.stderr)
        return 2

    # ---- gather every window, in chronological order across runs ----------
    per_layer = {"macro": [], "mid": [], "micro": []}
    plain, runs_used, total = [], 0, 0
    for p in paths:
        rows, slots = read_run(p)
        if len(rows) < 20:
            continue
        runs_used += 1
        for w, mach, tgt in rows:
            cell = tuple(min(a.cells - 1, int(v * a.cells)) for v in tgt[:5])
            plain.append(cell)
            total += 1
            for lay in per_layer:
                m = slot_at(slots, lay, w)
                if m:
                    per_layer[lay].append((cell, m))

    print()
    print(f"  {runs_used} runs, {total} windows, {a.cells}^5 = "
          f"{a.cells**5} possible cells")
    if total < 200:
        print("  too little history")
        return 0

    # ---- the plain discovery curve ---------------------------------------
    c = curve(plain)
    print()
    print("  REGIONS OF THE CORPUS ENTERED (cells alone, no machine)")
    print(f"    distinct cells visited ever: {c[-1]}")
    for frac, name in ((0.25, "first quarter"), (0.5, "first half"), (1.0, "all")):
        i = int(len(c) * frac) - 1
        print(f"    after the {name:14} {c[i]:6} cells")
    # novelty rate in the last tenth vs the first tenth
    tenth = max(50, len(plain) // 10)
    first_new = len(set(plain[:tenth]))
    seen_before_last = set(plain[:-tenth])
    last_new = len({x for x in plain[-tenth:] if x not in seen_before_last})
    print(f"    novelty in the FIRST {tenth} windows: {first_new} new cells "
          f"({100*first_new/tenth:.1f}% of windows)")
    print(f"    novelty in the LAST  {tenth} windows: {last_new} new cells "
          f"({100*last_new/tenth:.1f}% of windows)")

    # ---- by timescale, which is what was asked ---------------------------
    print()
    print("  NEWNESS BY TIMESCALE  (cell + the machine holding that layer)")
    for lay in ("macro", "mid", "micro"):
        seq = per_layer[lay]
        if len(seq) < 100:
            print(f"    {lay:6} too few windows ({len(seq)})")
            continue
        cc = curve(seq)
        t = max(50, len(seq) // 10)
        before = set(seq[:-t])
        newlast = len({x for x in seq[-t:] if x not in before})
        # A RE-ORDERING IS NOT A NULL FOR THIS QUESTION, and the first version
        # of this tool used one. Shuffling destroys temporal CLUSTERING, and
        # states discovered late are clustered late by construction: spread
        # them uniformly and some of their occurrences fall before the window
        # being scored, so they count as already-seen and the shuffled novelty
        # drops. The result was z = +10.27, +7.06, +5.58 -- an artefact of
        # clustering that reads as "still discovering faster than chance".
        # Exactly the error the vertical census made when its shuffle scored
        # voice persistence as harmony.
        #
        # The null has to GENERATE, not re-order: a random walk of the same
        # length, taking steps of the same size distribution, in the same
        # bounded space. That answers the question actually being asked --
        # is this factory exploring as well as an undirected walk would --
        # and a directed explorer should beat it while a converging one
        # should not.
        cells_seen = sorted({c for c, _ in seq})
        machs = sorted({m for _, m in seq})
        # observed per-window step, in cells, to give the walk the same scale
        # SAMPLED FROM THE OBSERVED STEP DISTRIBUTION, not from its median.
        # The first generating null took exactly the median step every window,
        # and the observed distribution is nothing like that: 31.7% of windows
        # do not change cell at all, 33% move one, and there is a tail out past
        # seven. A fixed-median walk moves 1.00 cells per window where the
        # factory moves 1.55, so the comparison would have been partly about
        # SPEED. Sampling the real distribution makes it a comparison about
        # DIRECTION, which is the question.
        steps = [sum(abs(x - y) for x, y in zip(seq[i][0], seq[i-1][0]))
                 for i in range(1, min(len(seq), 6000))]
        steps = np.array(steps) if steps else np.array([1])
        rng = np.random.default_rng(0)
        sh = []
        for _ in range(max(8, a.draws // 4)):
            pos = list(seq[0][0])
            mi = 0
            walk = []
            for i in range(len(seq)):
                for _ in range(int(rng.choice(steps))):
                    d = rng.integers(0, len(pos))
                    pos[d] = int(np.clip(pos[d] + rng.choice([-1, 1]), 0, a.cells - 1))
                # the machine changes as often as it did in the observed run
                if i > 0 and seq[i][1] != seq[i-1][1]:
                    mi = int(rng.integers(0, len(machs)))
                walk.append((tuple(pos), machs[mi]))
            b2 = set(walk[:-t])
            sh.append(len({x for x in walk[-t:] if x not in b2}))
        mu, sd = float(np.mean(sh)), float(np.std(sh) + 1e-9)
        z = (newlast - mu) / sd
        print(f"    {lay:6} {len(seq):6} windows, {cc[-1]:5} distinct states")
        print(f"           last {t} windows: {newlast:4} new   "
              f"random walk {mu:6.1f} +/- {sd:.1f}   z = {z:+.2f}")

    print()
    print("  HOW TO READ z, against an undirected walk of the same step size in")
    print("  the same bounded space. NEGATIVE means the factory finds new states")
    print("  LESS often than an aimless walk would -- it is being held somewhere,")
    print("  which is convergence and is the thing m5 cannot see. NEAR ZERO means")
    print("  its exploration is indistinguishable from undirected: not a fault,")
    print("  but not navigation either. POSITIVE means the transfer operator is")
    print("  taking it somewhere a random walk would not go, which is the claim")
    print("  the operator exists to support and the only result here that would")
    print("  count as evidence for it.")
    print()
    print("  WHAT THIS DOES NOT SAY. A cell is a region of the corpus, so 'new' here")
    print("  means unvisited MATERIAL, not unheard SOUND. tools/sonic_variety.py")
    print("  measures the second and reports that the corpus occupies 4.79 of 24")
    print("  spectral dimensions -- a factory can exhaust that in an hour and still")
    print("  be entering new cells for weeks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
