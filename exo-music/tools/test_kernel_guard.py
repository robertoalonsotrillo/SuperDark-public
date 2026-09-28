#!/usr/bin/env python3
"""Prove the kernel guard can FIRE, not only that it can decline.

WHY THIS EXISTS
A guard that has never fired is indistinguishable from a guard that cannot.
This project has already shipped two of those: a `.try` that swallowed a broken
capture rotation, and an alignment check whose exit status was piped into
`tail`. Both reported diligently and could not stop anything. So before the
kernel guard is trusted to be quiet, it has to be shown to be loud on a case
where loudness is correct.

The case is real, not synthetic: runs 171402, 174136 and 181123 of 31 Aug,
during which master_gain was mis-set to 4.0 and m3_no_clipping read 0.036,
0.079 and 0.205 against a bound of 0.02. m3 is never_tolerated, so consecutive
pairs from that sequence must trigger. If they do not, the guard is broken.

The negative control is the pair of runs either side of that window, which must
NOT trigger.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC      # noqa: E402
import kernel_guard as KG       # noqa: E402

W = KG.W
R = os.path.join(W, "renders")


def run_of(name):
    ch = json.load(open(os.path.join(W, "mutable", "charter.json")))
    n, rows, failed, und = SC.evaluate(os.path.join(R, name), ch)
    return (name, n, set(failed)), ch


def main():
    kern = json.load(open(os.path.join(W, "mutable", "kernel.json")))
    cases = [
        # (pair, must_fire, why the case was chosen)
        (["live_260831_171402.log", "live_260831_174136.log"], True,
         "master_gain 4.0; m3 0.036 then 0.079, both over the 0.02 bound"),
        (["live_260831_174136.log", "live_260831_181123.log"], True,
         "master_gain 4.0; m3 0.079 then 0.205, never_tolerated in both"),
        (["live_260828_013413.log", "live_260828_105156.log"], False,
         "healthy pair: m3 exactly 0.000 in both"),
        (["live_260830_163336.log", "live_260830_173925.log"], False,
         "healthy pair: m3 exactly 0.000 in both"),
    ]

    print()
    ok = True
    for names, must_fire, note in cases:
        missing = [n for n in names if not os.path.exists(os.path.join(R, n))]
        if missing:
            print(f"  SKIP  {names}: missing {missing}")
            continue
        runs = []
        ch = None
        for n in names:
            r, ch = run_of(n)
            runs.append(r)
        fire, why, detail = KG.decide(runs, ch, kern)
        good = (fire == must_fire)
        ok &= good
        print(f"  {'PASS' if good else 'FAIL'}  expected "
              f"{'FIRE' if must_fire else 'no fire'}, got "
              f"{'FIRE' if fire else 'no fire'}")
        print(f"        {names[0]} + {names[1]}")
        print(f"        {note}")
        print(f"        guard says: {why}")
        print()

    if ok:
        print("  The guard fires on the historical fault and stays quiet on")
        print("  healthy runs. It is capable of acting, which is the property")
        print("  a silent guard cannot otherwise demonstrate.")
    else:
        print("  GUARD IS WRONG. Do not arm it.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
