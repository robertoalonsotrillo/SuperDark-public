#!/usr/bin/env python3
"""Charter edition 7: restore m1_not_silent as FAILABLE, measuring a new quantity.

THE HOLE THIS CLOSES. rehearse_kernel_real showed the kernel does not fire on a
factory 40 dB down and silent in 98% of windows: only m2_level and
m1_audible_when_driving fail, which is exactly the tolerance of two. n1_audible
has four metrics and only two can fail against a level fault, because
m3_no_clipping passes when the fault is quietness and m1_not_silent was made
DESCRIPTIVE in edition 4. That demotion was mine and it removed the third
failure.

WHY THE OBVIOUS RESTORATION WOULD BE WRONG. m1_not_silent counted silent windows
unconditionally, and it was demoted because silence tracks the amplitude the
factory CHOOSES: 34.8% of windows are silent near amp 0 and 0.2% at amp >= 1e-2.
Restoring that verbatim re-adopts a metric that fails whenever the factory
composes quietly, which is not a fault. Making it conditional on driving turns it
into m1_audible_when_driving, which already exists -- and the two being the same
quantity is precisely why one level fault spends the whole tolerance.

SO IT MEASURES THE OTHER HALF. m1_audible_when_driving asks: when the factory
ASKED for sound, did sound arrive? That is a DELIVERY question. The restored
m1_not_silent asks: how often does the factory ask for nothing at all? That is a
COMPOSITION question, it reads the requested amplitude rather than the delivered
peak, and the two can fail independently -- a factory can deliver everything it
asks for while asking for silence most of the time, and that is the failure mode
Roberto named when he asked what chooses section amplitude.

The REQUEST line, added 2 Sept, carries mean requested amplitude per window and
makes this measurable for the first time. Runs predating it score None.

THE BOUND IS NOT SET IN THIS FILE, AND THAT IS DELIBERATE.
A bound picked from what recent runs happen to do would ratify current behaviour
as correct -- which is how m7 was set, how the 0.9 drift threshold was set, and
how an upper bound on m9_turnover was refused this same day. `--derive` computes
a bound from a SHUFFLED NULL over each run's own requested-amplitude sequence:
if the factory's silence were arranged independently of when it occurs, how often
would a window be requested near zero? A factory asking for silence more often
than its own shuffle is choosing silence, not encountering it.

    python3 tools/restore_m1.py --derive         # needs the run logs
    python3 tools/restore_m1.py --commit --bound 0.42
"""
import argparse
import datetime
import glob
import json
import os
import shutil
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")
CH = os.path.join(MUT, "charter.json")
RENDERS = "/Volumes/FMA/superdark/renders"
DRIVING = 1e-2          # the floor already used by m1_audible_when_driving


def requested(path):
    """Mean requested amplitude per window, from the REQUEST line."""
    out = []
    for line in open(path, errors="replace"):
        if line.startswith("REQUEST "):
            f = line.split()[1].split(",")
            try:
                out.append(float(f[3]))
            except (ValueError, IndexError):
                pass
    return np.array(out)


def null_rate(amps, trials=400, seed=7):
    """Shuffle the requested-amplitude sequence and ask how often a window lands
    below the driving floor. Shuffling cannot change the RATE -- it is the same
    multiset -- so the informative null is over RUNS of silence, not over the
    marginal. Returns the observed longest-run against the shuffled distribution:
    a factory that CHOOSES silence produces long stretches, one that merely
    encounters it produces the same fraction scattered."""
    if amps.size < 60:
        return None
    quiet = amps < DRIVING

    def longest(mask):
        best = cur = 0
        for x in mask:
            cur = cur + 1 if x else 0
            best = max(best, cur)
        return best

    obs = longest(quiet)
    r = np.random.default_rng(seed)
    nulls = []
    for _ in range(trials):
        nulls.append(longest(r.permutation(quiet)))
    nulls = np.array(nulls)
    return dict(rate=float(quiet.mean()), longest=obs,
                null_med=float(np.median(nulls)),
                null_p95=float(np.percentile(nulls, 95)),
                exceeds=bool(obs > np.percentile(nulls, 95)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--derive", action="store_true")
    ap.add_argument("--commit", action="store_true")
    ap.add_argument("--bound", type=float, default=None)
    a = ap.parse_args()

    ch = json.load(open(CH))

    if a.derive:
        logs = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")))
        rows = []
        for p in logs:
            amps = requested(p)
            res = null_rate(amps)
            if res:
                rows.append((os.path.basename(p), res))
        if not rows:
            print("  no run carries REQUEST lines yet (or the SSD is unmounted).")
            print("  REQUEST logging began 2 Sept; the bound needs runs after it.")
            return 1
        print()
        print(f"  {'run':30} {'quiet rate':>11} {'longest':>8} "
              f"{'null p95':>9}  chooses?")
        print("  " + "-" * 74)
        for n, r in rows:
            print(f"  {n[:30]:30} {r['rate']:11.3f} {r['longest']:8d} "
                  f"{r['null_p95']:9.1f}  {'YES' if r['exceeds'] else 'no'}")
        rates = np.array([r["rate"] for _, r in rows])
        print()
        print(f"  quiet-request rate across {len(rates)} runs: "
              f"median {np.median(rates):.3f}  max {rates.max():.3f}")
        print()
        print("  A BOUND IS STILL NOT AUTOMATIC. Read the 'chooses?' column: it")
        print("  says whether silence came in longer stretches than the same")
        print("  amount of silence shuffled. Set the bound above the rate of runs")
        print("  that answer 'no' and below those that answer 'YES', and record")
        print("  the runs it was set from.")
        return 0

    if a.commit:
        if a.bound is None:
            raise SystemExit("  --commit requires --bound. Run --derive first; "
                             "a bound without a derivation is the m7 mistake.")
        m = ch["metrics"]["m1_not_silent"]
        ed = ch["edition"]
        shutil.copy(CH, os.path.join(MUT, f"charter_edition_{ed}.json"))
        m.pop("descriptive", None)
        m["test"] = ("fraction of windows in which the factory REQUESTED a mean "
                     "amplitude below 1e-2 -- what it asks for, not what arrives")
        m["acceptable"] = [None, a.bound]
        m["_restored"] = (
            "Restored as failable in edition " + str(ed + 1) + ", measuring a "
            "DIFFERENT quantity from the one demoted in edition 4. The old "
            "version counted delivered silence unconditionally and was demoted "
            "because silence tracks the amplitude the factory chooses. This one "
            "reads the REQUESTED amplitude, so it asks how often the factory "
            "asks for nothing -- a composition question, independent of the "
            "delivery question m1_audible_when_driving asks. Restored because "
            "n1_audible had only two failable metrics against a level fault and "
            "the tolerance is two, so the kernel could not fire on a factory "
            "40 dB down and 98% silent. Bound " + str(a.bound) + " derived by "
            "--derive from a shuffled-run null, not from what recent runs do.")
        ch["edition"] = ed + 1
        ch["authored"] = datetime.date.today().isoformat()
        ch.setdefault("_lineage", []).append({
            "edition": ed + 1,
            "when": datetime.datetime.now().isoformat(timespec="seconds"),
            "by": "Roberto Alonso Trillo",
            "change": f"m1_not_silent restored as failable, bound [None, {a.bound}]",
            "because": "n1_audible had two failable metrics and a tolerance of two",
        })
        json.dump(ch, open(CH, "w"), indent=2)
        print(f"  charter is now edition {ch['edition']}; {ed} archived.")
        print("  n1_audible now has three failable metrics, so a level fault can")
        print("  exceed the tolerance instead of exactly filling it.")
        return 0

    print(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main())
