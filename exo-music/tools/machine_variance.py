#!/usr/bin/env python3
"""When the same machine fires twice, does it do the same thing?

ROBERTO'S QUESTION, 4 Sept: "the recurrence of machines, as in how often is the
same machine (without the slightest variation) being used." It is the other half
of sonic_variety.py. That one asks whether the OUTPUT returns to itself; this
asks whether a MACHINE is a fixed stamp -- whether firing `hm` twice produces two
instances of one thing or two different things.

Nothing in the charter can answer it. m4_vocabulary_breadth counts behaviours,
m5_not_converging is entropy over selection, m9_turnover is how often the machine
CHANGES. All three treat a machine as an atom with no internal spread.

THERE ARE REASONS IN THE CODE TO EXPECT LITTLE SPREAD. Pshuf(buf, inf) shuffles
ONCE and repeats that order for ever, so a voice cycles the same grains in the
same sequence. macro_hold_grains is 1, so a macro voice is one grain looped. And
the macro trajectory period is derived deterministically from the machine's own
measured dur, so the same machine always gets the same arc. A machine's
randomness is mostly in Pwhite on amplitude and pan.

TWO FAILURE MODES, ONE MEASUREMENT.

  WITHIN-machine spread near zero: every firing of a machine sounds the same, so
  the vocabulary is a set of stamps and hearing one twice is hearing a repeat.

  BETWEEN-machine spread near zero: the machines do not differ from each other,
  so switching machines changes nothing -- which is what the hour of 3 Sept
  already suggested and what "different machines, same sound" describes.

The ratio between them is the answer. It is an intraclass correlation in
everything but name: high means machines are distinct and internally consistent,
low means they are interchangeable, and the two denominators separate WHICH.

AND A NULL, because windows are not independent. A machine held for a long dwell
contributes several windows from the same passage, which would look like low
within-machine spread whatever the machine does. The null reassigns the SAME
window features to machines at random while preserving how many windows each
machine had, so the run's own autocorrelation is present in both arms.

    python3 tools/machine_variance.py [logfile] [--min-windows 8]
"""
import argparse
import collections
import glob
import os
import random
import sys

import numpy as np

RENDERS = "/Volumes/FMA/superdark/renders"


def newest():
    c = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")), key=os.path.getmtime)
    return c[-1] if c else None


def read(path):
    """window rows: machine, and the features the factory logged for that window."""
    rows = []
    for line in open(path, errors="replace"):
        if not line or not line[0].isdigit():
            continue
        f = line.strip().split(",")
        if len(f) < 15 or f[3] not in ("runtime", "class"):
            continue
        try:
            amp, cent, flat = float(f[4]), float(f[5]), float(f[6])
            tgt = [float(x) for x in f[13].split("|")]
        except (ValueError, IndexError):
            continue
        if len(tgt) < 5:
            continue
        # amp and centroid are what the window SOUNDED like; the target is where
        # in the corpus it was drawing from. Both belong: a machine that always
        # sounds the same while drawing from everywhere is a different finding
        # from one that always draws from the same place.
        rows.append((f[2], [amp, cent / 5000.0, flat] + tgt))
    return rows


def spreads(rows):
    """Mean within-machine distance, and mean between-machine distance."""
    by = collections.defaultdict(list)
    for m, v in rows:
        by[m].append(v)
    within, cents = [], {}
    for m, vs in by.items():
        A = np.array(vs)
        c = A.mean(0)
        cents[m] = c
        if len(A) > 1:
            within.append(np.linalg.norm(A - c, axis=1).mean())
    ks = list(cents)
    between = []
    for i in range(len(ks)):
        for j in range(i + 1, len(ks)):
            between.append(np.linalg.norm(cents[ks[i]] - cents[ks[j]]))
    return (float(np.mean(within)) if within else 0.0,
            float(np.mean(between)) if between else 0.0, by)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", nargs="?", default=None)
    ap.add_argument("--min-windows", type=int, default=8)
    ap.add_argument("--draws", type=int, default=200)
    a = ap.parse_args()

    p = a.log or newest()
    if not p or not os.path.exists(p):
        print("  no log", file=sys.stderr)
        return 2
    rows = read(p)
    if len(rows) < 50:
        print(f"  {len(rows)} usable windows -- too few")
        return 0

    # normalise each feature so no column dominates by its units
    A = np.array([v for _, v in rows])
    sd = A.std(0)
    sd[sd == 0] = 1
    A = (A - A.mean(0)) / sd
    rows = [(rows[i][0], A[i]) for i in range(len(rows))]

    counts = collections.Counter(m for m, _ in rows)
    kept = {m for m, n in counts.items() if n >= a.min_windows}
    rows = [(m, v) for m, v in rows if m in kept]

    w, b, by = spreads(rows)
    print()
    print(f"  {os.path.basename(p)}")
    print(f"  {len(rows)} windows, {len(kept)} machines with >= {a.min_windows} windows")
    print()
    print(f"  within-machine  spread {w:.3f}   how much ONE machine varies between firings")
    print(f"  between-machine spread {b:.3f}   how much machines differ from EACH OTHER")
    print(f"  ratio  between/within  {b / (w + 1e-9):.3f}")

    # null: same windows, machine labels reassigned, block sizes preserved
    random.seed(0)
    labels = [m for m, _ in rows]
    vals = [v for _, v in rows]
    rw, rb = [], []
    for _ in range(a.draws):
        lab = labels[:]
        random.shuffle(lab)
        w2, b2, _ = spreads(list(zip(lab, vals)))
        rw.append(w2)
        rb.append(b2)
    mw, sw = float(np.mean(rw)), float(np.std(rw) + 1e-9)
    mb, sb = float(np.mean(rb)), float(np.std(rb) + 1e-9)
    print()
    print(f"  AGAINST CHANCE ({a.draws} label shuffles)")
    print(f"    within   observed {w:.3f}   shuffled {mw:.3f} +/- {sw:.3f}   z = {(w-mw)/sw:+.2f}")
    print(f"    between  observed {b:.3f}   shuffled {mb:.3f} +/- {sb:.3f}   z = {(b-mb)/sb:+.2f}")

    print()
    zw, zb = (w - mw) / sw, (b - mb) / sb
    if zw > -2 and zb < 2:
        print("  MACHINES ARE INTERCHANGEABLE. A machine's windows are no more alike")
        print("  than windows drawn at random, and machines are no more different from")
        print("  each other than chance. Whatever distinguishes them is not reaching")
        print("  the output, and switching machines is not changing the sound.")
    elif zw < -2 and zb > 2:
        print("  MACHINES ARE DISTINCT AND INTERNALLY CONSISTENT. Each is recognisable")
        print("  and reproducible -- which is what a vocabulary means, and also what")
        print("  makes hearing one twice a repeat. The question of whether it should")
        print("  vary WITHIN itself is then a musical decision, not a fault.")
    elif zw < -2:
        print("  MACHINES ARE STAMPS. Each repeats itself closely, but they do not")
        print("  differ from one another more than chance -- so the vocabulary is a")
        print("  set of near-identical stamps and both halves of variety are missing.")
    else:
        print("  Machines differ from each other but do not repeat themselves. That is")
        print("  variety without identity: a machine is a distribution rather than a")
        print("  behaviour, and calling it by name overstates what it is.")

    print()
    print("  THE FIVE LEAST VARIABLE MACHINES (the closest to fixed stamps)")
    per = []
    for m, vs in by.items():
        A2 = np.array(vs)
        per.append((float(np.linalg.norm(A2 - A2.mean(0), axis=1).mean()), m, len(vs)))
    per.sort()
    for s, m, n in per[:5]:
        print(f"    {m:22} spread {s:.3f}  over {n:4} windows")
    print("  THE FIVE MOST VARIABLE")
    for s, m, n in per[-5:]:
        print(f"    {m:22} spread {s:.3f}  over {n:4} windows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
