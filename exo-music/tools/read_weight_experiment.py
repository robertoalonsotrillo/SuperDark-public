#!/usr/bin/env python3
"""Read the w=1.0 vs w=0.5 experiment against its pre-registration.

The criteria live in .lab/notes/EXP_WEIGHT_M1_M7.md and were fixed BEFORE arm B ran.
This file implements them and nothing else. It does not choose a window, a
threshold or an exclusion; all three were chosen in advance, for reasons the
document states.

    windows 46 onward in each arm      (warm-up is about 45 windows)
    truncated to equal length          (a longer sample of a wandering series
                                        has a wider IQR by construction, which
                                        would hand m7 a free pass)
    m1 supported if silent fraction  < 0.15
    m7 supported if gap IQR         >= 0.02
    BOTH must hold for the claim to be supported.

It prints the numbers whichever way they fall, including the case where the
diagnosis was wrong.
"""
import argparse
import glob
import os
import statistics as st
import sys

WARMUP = 45          # pre-registered
M1_BOUND = 0.15      # charter bound for m1_not_silent
M7_BOUND = 0.02      # charter lower bound for m7_spectral_gap_settles
SILENT = 0.004       # the master-peak level m1 counts as silence


def read(path):
    peak, gap, live = {}, {}, {}
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                peak[int(p[0])] = float(p[1])
            except (ValueError, IndexError):
                pass
        elif line.startswith("OPERATOR"):
            p = line.split()[1].split(",")
            try:
                gap[int(p[0])] = float(p[2])
            except (ValueError, IndexError):
                pass
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                try:
                    live[int(p[1])] = int(p[9])
                except (ValueError, IndexError):
                    pass
    return peak, gap, live


def arm(path, n_windows=None):
    peak, gap, live = read(path)
    ws = sorted(w for w in peak if w > WARMUP)
    if n_windows is not None:
        ws = ws[:n_windows]
    pk = [peak[w] for w in ws]
    gp = [gap[w] for w in sorted(gap) if w > WARMUP][:len(ws)]
    lv = [live[w] for w in ws if w in live]
    sil = [w for w in ws if peak[w] < SILENT]
    q = st.quantiles(gp, n=4) if len(gp) > 8 else [0, 0, 0]
    return {
        "windows": len(ws),
        "m1": len(sil) / len(ws) if ws else None,
        "m7": q[2] - q[0] if len(gp) > 8 else None,
        "gap_lo": min(gp) if gp else None, "gap_hi": max(gp) if gp else None,
        "median_peak": st.median(pk) if pk else None,
        "median_voices": st.median(lv) if lv else None,
        "voices_when_silent": st.median([live[w] for w in sil if w in live])
                              if any(w in live for w in sil) else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", default="/Volumes/FMA/superdark/renders/arm_a_w100.log")
    ap.add_argument("--b", default=None)
    a = ap.parse_args()
    b = a.b or sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                      key=os.path.getmtime)[-1]

    # Length is set by the SHORTER arm, so neither is advantaged.
    na, nb = arm(a.a)["windows"], arm(b)["windows"]
    n = min(na, nb)
    A, B = arm(a.a, n), arm(b, n)

    print()
    print(f"  arm A  w=1.0  {os.path.basename(a.a)}   {na} windows available")
    print(f"  arm B  w=0.5  {os.path.basename(b)}   {nb} windows available")
    print(f"  compared over the first {n} windows past warm-up in each")
    print()
    print(f"  {'':26} {'A (w=1.0)':>12} {'B (w=0.5)':>12}   bound")
    print("  " + "-" * 66)
    print(f"  {'m1 silent fraction':26} {A['m1']:12.3f} {B['m1']:12.3f}   < {M1_BOUND}")
    print(f"  {'m7 spectral-gap IQR':26} {A['m7']:12.4f} {B['m7']:12.4f}   >= {M7_BOUND}")
    print(f"  {'   gap range':26} {A['gap_hi']-A['gap_lo']:12.4f} "
          f"{B['gap_hi']-B['gap_lo']:12.4f}")
    print(f"  {'median master peak':26} {A['median_peak']:12.4f} {B['median_peak']:12.4f}")
    print(f"  {'median voices':26} {A['median_voices']:12.1f} {B['median_voices']:12.1f}")
    va = A['voices_when_silent']; vb = B['voices_when_silent']
    print(f"  {'voices while silent':26} {va if va is None else f'{va:12.1f}'} "
          f"{vb if vb is None else f'{vb:12.1f}'}")

    m1_ok = B["m1"] < M1_BOUND
    m7_ok = B["m7"] >= M7_BOUND
    print()
    print(f"  m1 inside its bound at w=0.5:  {'YES' if m1_ok else 'no'}")
    print(f"  m7 inside its bound at w=0.5:  {'YES' if m7_ok else 'no'}")
    print()
    if m1_ok and m7_ok:
        print("  SUPPORTED. Both metrics move inside their bounds when the corpus")
        print("  stops being purely self-derived. Next is a sweep, not the")
        print("  assumption that 0.5 is the right value -- and any choice has to")
        print("  be argued against generation depth, which 0.5 caps at 2.")
    elif m1_ok or m7_ok:
        print("  PARTIALLY SUPPORTED. One moved, one did not. Per the")
        print("  pre-registration this does NOT license calling the other solved,")
        print("  and specifically does not license re-pricing the bound that")
        print("  stayed outside.")
    else:
        print("  REFUTED. Neither metric moved inside its bound, so the weight is")
        print("  not the cause and the diagnosis was wrong. The silence and the")
        print("  frozen operator need a different explanation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
