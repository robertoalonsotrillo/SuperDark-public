#!/usr/bin/env python3
"""Charter edition 6: add m9_turnover, DESCRIPTIVE, with no bound.

WHY THE CHARTER NEEDED THIS. On 2 Sept the listener called the factory "endless
radio-like fragmentary shit" and "worse than the immediately previous versions a
100%". Every charter metric passed. Turnover -- the fraction of consecutive
windows in which the sounding machine changes -- had climbed monotonically for a
week, 0.736 to 0.950, while median master peak fell 0.197 to 0.052, and nothing
in the charter measured either trend.

Worse than a blind spot: m4_vocabulary_breadth IMPROVES under this failure. A
factory that switches material every window sounds more distinct behaviours per
hundred windows than one that lets a behaviour last. The charter was rewarding
the thing the listener heard as broken.

WHY IT ARRIVES WITHOUT A BOUND, WHICH IS THE WHOLE POINT.

There is an obvious bound available and it must be refused. Twenty-one runs of
turnover data exist, and the listener has told us 0.736 sounded better than
0.950. Setting an upper bound around 0.8 from that would be:

  * a bound from ONE listener judgement on TWO runs, which is how m7 and the 0.9
    drift threshold were set and both had to be withdrawn;
  * a bound fitted to a distribution that CONTAINS THE FAILURE, so the week of
    drift would be ratified as the acceptable range;
  * an aesthetic preference entering the charter as a measurement, which is the
    Class 2 move the whole project is arranged against.

So m9 is descriptive, exactly as m1_not_silent became in edition 4: it is
computed and recorded every run and it cannot fail. The bound should come from
PAIRED DATA -- turnover measured on runs the listener has separately judged,
several of each, gathered without knowing the number. That experiment does not
exist yet, and inventing its answer now would be worse than having no bound.

WHAT A DESCRIPTIVE METRIC BUYS. The failure becomes visible in the record while
it is happening rather than a week later. That alone would have caught this: the
number moved 0.74 to 0.95 through five charter editions and a kernel arming with
nobody watching it.

    python3 tools/add_m9_turnover.py            # dry run
    python3 tools/add_m9_turnover.py --commit
"""
import argparse
import datetime
import glob
import json
import os
import shutil
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC                                    # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")
CH = os.path.join(MUT, "charter.json")
RENDERS = "/Volumes/FMA/superdark/renders"

SPEC = {
    "norm": "n2_varied",
    "test": "fraction of consecutive windows in which the sounding behaviour changes",
    "acceptable": [None, None],
    "min_windows": 100,
    "descriptive": True,
    "_why": (
        "Added in edition 6 because the charter had no metric for how long "
        "anything LASTS, and m4_vocabulary_breadth moves the WRONG WAY under "
        "fragmentation: a factory switching material every window sounds more "
        "behaviours per 100 windows than one that lets a behaviour hold. On "
        "2 Sept the listener called the output 'endless radio-like fragmentary "
        "shit' while every metric passed. Measured across the runs on disk, "
        "turnover had climbed monotonically 0.736 (27 Aug) to 0.950 (2 Sept) "
        "and median master peak had fallen 0.197 to 0.052. Neither trend was "
        "visible anywhere in the charter."),
    "_no_bound": (
        "DESCRIPTIVE ON PURPOSE. An upper bound near 0.8 is available from the "
        "data and is refused: it would rest on one listener's judgement of two "
        "runs, it would be fitted to a distribution that contains the failure "
        "and would therefore ratify a week of drift as acceptable, and it would "
        "install an aesthetic preference as a measurement. m7 and the 0.9 drift "
        "threshold were both set that way and both had to be withdrawn. The "
        "bound should come from turnover measured on runs the listener has "
        "judged blind, several of each. That experiment does not exist yet."),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--commit", action="store_true")
    a = ap.parse_args()

    ch = json.load(open(CH))
    if "m9_turnover" in ch.get("metrics", {}):
        print("  m9_turnover already present")
        return 0

    # The distribution, reported so the descriptive value has context from day
    # one. Reported, NOT converted into a bound.
    vals = []
    for p in sorted(glob.glob(os.path.join(RENDERS, "live_*.log"))):
        try:
            d = SC.read(p)
        except Exception:
            continue
        if d["n"] >= 100:
            t = SC.turnover(d["mach"])
            if t is not None:
                vals.append((os.path.basename(p), t))
    print()
    print(f"  charter edition {ch['edition']} -> {ch['edition'] + 1}")
    print(f"  adding m9_turnover, descriptive, acceptable [None, None]")
    print()
    if vals:
        v = np.array([x[1] for x in vals])
        print(f"  turnover across {len(v)} runs on disk:")
        print(f"    min {v.min():.3f}  median {np.median(v):.3f}  max {v.max():.3f}")
        print(f"    earliest {vals[0][0]}: {vals[0][1]:.3f}")
        print(f"    latest   {vals[-1][0]}: {vals[-1][1]:.3f}")
    else:
        print("  no scoreable runs reachable (SSD unmounted?) -- the metric is")
        print("  added anyway; it computes from the log at scoring time.")
    print()

    if not a.commit:
        print("  DRY RUN. Re-run with --commit.")
        return 0

    ed = ch["edition"]
    shutil.copy(CH, os.path.join(MUT, f"charter_edition_{ed}.json"))
    ch["metrics"]["m9_turnover"] = SPEC
    ch["edition"] = ed + 1
    ch["authored"] = datetime.date.today().isoformat()
    ch.setdefault("_lineage", [])
    ch["_lineage"].append({
        "edition": ed + 1,
        "when": datetime.datetime.now().isoformat(timespec="seconds"),
        "by": "Roberto Alonso Trillo",
        "change": "added m9_turnover as a descriptive metric, no bound",
        "because": ("the listener heard fragmentation that every metric passed, "
                    "and m4 rewards it"),
    })
    json.dump(ch, open(CH, "w"), indent=2)
    print(f"  charter is now edition {ch['edition']}; edition {ed} archived.")
    print("  m9 cannot fail. It is there so the number is on the record while it")
    print("  moves, which is the one thing that would have caught this.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
