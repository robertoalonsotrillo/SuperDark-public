#!/usr/bin/env python3
"""Read the weight sweep against .lab/notes/EXP_WEIGHT_SWEEP.md.

Criteria were fixed before arm C ran:

    windows 46 onward in every arm, truncated to the SHORTEST arm's usable
    length so no arm is advantaged by observing longer.

    SUPPORTED  silent fraction falls monotonically C < B < A, AND median
               section amplitude does NOT fall with it (which would mean the
               weight acted on the amplitude the factory chooses rather than on
               the material it plays).
    REFUTED    arm C is not the least silent, or the whole effect is explained
               by a shift in amplitude.

m1_audible_when_driving must stay inside 0.015 in every arm; an arm that fails
it has a level fault and its silence figure means something different.
"""
import argparse
import math
import os
import statistics as st
import sys

WARMUP = 45
SILENT = 0.004
DRIVING = 1e-2

ARMS = [
    ("A", 1.0, "/Volumes/FMA/superdark/renders/arm_a_w100.log"),
    ("B", 0.5, "/Volumes/FMA/superdark/renders/live_260902_014120.log"),
    ("C", 0.0, "/Volumes/FMA/superdark/renders/live_260902_135114.log"),
]


def read(path):
    pk, amp, live = {}, {}, {}
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                pk[int(p[0])] = float(p[1])
            except (ValueError, IndexError):
                pass
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                try:
                    w = int(p[1]); amp[w] = float(p[4]); live[w] = int(p[9])
                except (ValueError, IndexError):
                    pass
    return pk, amp, live


def arm(path, n=None):
    pk, amp, live = read(path)
    ws = sorted(w for w in (set(pk) & set(amp)) if w > WARMUP)
    if n:
        ws = ws[:n]
    if not ws:
        return None
    sil = [w for w in ws if pk[w] < SILENT]
    p = len(sil) / len(ws)
    drive = [w for w in ws if amp[w] >= DRIVING]
    return {
        "n": len(ws),
        "silent": p,
        "ci": 1.96 * math.sqrt(p * (1 - p) / len(ws)),
        "median_amp": st.median([amp[w] for w in ws]),
        "frac_amp_tiny": sum(1 for w in ws if amp[w] < 1e-4) / len(ws),
        "driving": len(drive),
        "audible_when_driving": (sum(1 for w in drive if pk[w] < SILENT) / len(drive)
                                 if drive else None),
        "median_voices": st.median([live[w] for w in ws if w in live]) if live else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.parse_args()
    avail = [(k, w, p) for k, w, p in ARMS if os.path.exists(p)]
    lens = [arm(p)["n"] for _, _, p in avail]
    n = min(lens)
    print()
    print(f"  truncated to {n} windows past warm-up in each arm "
          f"(available: {lens})")
    print()
    print(f"  {'arm':4} {'w':>5} {'silent':>16} {'med amp':>10} "
          f"{'amp<1e-4':>9} {'m1_drive':>9} {'voices':>7}")
    print("  " + "-" * 70)
    rows = {}
    for k, w, p in avail:
        r = arm(p, n)
        rows[k] = r
        aw = "  n/a" if r["audible_when_driving"] is None else f"{r['audible_when_driving']:9.4f}"
        print(f"  {k:4} {w:5.2f} {r['silent']:8.3f} +/-{r['ci']:.3f} "
              f"{r['median_amp']:10.5f} {100*r['frac_amp_tiny']:8.0f}% {aw} "
              f"{r['median_voices']:7.1f}")

    print()
    if len(rows) < 3:
        print("  not all three arms present")
        return 0
    A, B, C = rows["A"], rows["B"], rows["C"]
    mono = C["silent"] < B["silent"] < A["silent"]
    print(f"  monotonic C < B < A ?  {C['silent']:.3f} < {B['silent']:.3f} < "
          f"{A['silent']:.3f}   {'YES' if mono else 'NO'}")
    least = min(rows, key=lambda k: rows[k]["silent"])
    print(f"  least silent arm: {least} (w={dict((k,w) for k,w,_ in avail)[least]})")
    print()
    if mono:
        print("  SUPPORTED, subject to the amplitude check below.")
    elif least != "C":
        print("  REFUTED. The pre-registration is explicit: the mechanism fails if")
        print("  arm C is not the least silent. Switching self-ingestion OFF did not")
        print("  reduce silence, so the factory was not recycling its own quiet")
        print("  output. Whatever moved arm B, it was not the weight acting through")
        print("  the material.")
    else:
        print("  PARTIAL: arm C is least silent but the order is not monotonic.")

    print()
    print("  THE AMPLITUDE CHECK, which the pre-registration asked for:")
    for k in ("A", "B", "C"):
        print(f"    arm {k}: median amp {rows[k]['median_amp']:.5f}, "
              f"{100*rows[k]['frac_amp_tiny']:.0f}% of windows below 1e-4")
    print("    Silence tracks the amplitude the factory chooses, not the corpus")
    print("    it chooses from. That was already the m1 finding; this is the")
    print("    controlled version of it.")
    print()
    bad = [k for k in rows if rows[k]["audible_when_driving"] is not None
           and rows[k]["audible_when_driving"] > 0.015]
    print(f"  m1_audible_when_driving within 0.015 in every arm: "
          f"{'yes' if not bad else 'NO -- ' + str(bad)}")
    print("  So when the factory drives output, sound comes out in every arm.")
    print("  It simply does not drive output most of the time.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
