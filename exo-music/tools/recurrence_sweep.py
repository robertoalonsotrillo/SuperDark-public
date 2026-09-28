#!/usr/bin/env python3
"""At WHICH timescale does the factory return to itself?

sonic_variety.py asks the question at one match window. Run 6 Sept at 20-300 s
against the two calibration arms, it placed the factory at 0.848 between a loop
at 0.993 and 140 unrelated tracks at 0.811 -- that is 21% of the way from maximal
diversity to literal repetition, so at THAT timescale the factory is varied and
the exhaustion Roberto reports after an hour is not there to be found.

The pre-registration says what to do with that outcome: find the timescale that
does separate, or report that none does. Roberto's account is about RECOGNITION
after an hour ("I can identify most behaviours"), which is a claim about a
vocabulary being exhausted over tens of minutes, not about a phrase recurring
within five. A window that ends 300 s back cannot see it.

WHAT IS REPORTED. Every arm at every window, and the factory's POSITION on the
diverse-to-loop axis, which is the only figure comparable across windows. The raw
recurrence rises with window length for every signal -- a longer past holds more
chances to match -- so comparing 0.85 at one window with 0.90 at another says
nothing. The position does: 0 is as varied as 140 unrelated artists, 1 is a loop.

    python3 tools/recurrence_sweep.py loop.wav factory.wav diverse.wav
"""
import subprocess
import sys
import tempfile
import os

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sonic_variety import features, recurrence, blockwise_se, SR

WINDOWS = [(2, 20), (5, 60), (20, 300), (60, 900), (300, 1800), (600, 3600)]

# A WINDOW WIDER THAN THE FILE SCORES ALMOST NOTHING. recurrence() starts at
# frame `far/hop` and runs to the end, so a 3600 s window on a 3570 s file scores
# the last EIGHT frames and returns their mean as if it were the run's. On the
# first sweep that row put the factory at 0.9453, ABOVE a literal loop, and the
# separation flag caught it only by accident. Rows with fewer than this many
# scored frames are reported as underpowered and carry no position.
MIN_SCORED = 200


def decode(path):
    raw = tempfile.mktemp(suffix=".f32")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path,
                    "-ac", "1", "-ar", str(SR), "-f", "f32le", raw], check=True)
    x = np.fromfile(raw, dtype="<f4")
    os.unlink(raw)
    return x


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    names = ["LOOP", "FACTORY", "DIVERSE"]
    hop = 0.5
    B = {}
    for nm, p in zip(names, sys.argv[1:4]):
        B[nm] = features(decode(p), hop)
        print(f"  {nm:8s} {len(B[nm])} frames from {os.path.basename(p)}")

    print()
    print("  RECURRENCE BY MATCH WINDOW")
    print()
    print(f"  {'window':>14}  {'LOOP':>8} {'FACTORY':>8} {'DIVERSE':>8}   "
          f"{'factory position':>16}")
    print(f"  {'':>14}  {'':>8} {'':>8} {'':>8}   {'0=diverse 1=loop':>16}")
    for near, far in WINDOWS:
        vals, ses, ns = {}, {}, {}
        for nm in names:
            v = recurrence(B[nm], hop, near, far)
            vals[nm], ses[nm], ns[nm] = float(v.mean()), blockwise_se(v), len(v)
        span = vals["LOOP"] - vals["DIVERSE"]
        pos = (vals["FACTORY"] - vals["DIVERSE"]) / span if span > 1e-9 else float("nan")
        # the position is only meaningful if the arms are separated by more than
        # their own noise; otherwise the window has failed to discriminate and
        # the position is a ratio of two noise terms
        ok = span > 5 * max(ses.values())
        note = ""
        if min(ns.values()) < MIN_SCORED:
            note = f"   UNDERPOWERED, {min(ns.values())} frames scored"
            pos = float("nan")
        elif not ok:
            note = "   (arms not separated)"
        print(f"  {near:5.0f}-{far:<8.0f}  {vals['LOOP']:8.4f} "
              f"{vals['FACTORY']:8.4f} {vals['DIVERSE']:8.4f}   "
              f"{pos:16.2f}{note}")

    print()
    print("  A position near 0 means the factory is as varied as 140 unrelated")
    print("  artists AT THAT TIMESCALE. A position that climbs with window length")
    print("  is a factory that varies locally and repeats globally, which is")
    print("  exactly the report 'after an hour it does not surprise me anymore'.")
    print("  A flat position says the exhaustion is not spectral recurrence at any")
    print("  timescale and the next measure has to look at something else.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
