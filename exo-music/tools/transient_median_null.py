#!/usr/bin/env python3
"""The run MEDIAN, not an upper order statistic: a per-layer threshold and its ROC.

WHY THIS FILE EXISTS
--------------------
tools/transient_null.py went looking for a defensible replacement for the
hand-picked pair (--max-transient 40, --transient-frac 0.25) and found something
it was not looking for. Quoting its own conclusion:

    SHELLAC DOES NOT PRODUCE RARE EXTREMES, IT RAISES THE WHOLE RUN.

That sentence questions the statistic, not just the number. The old gate counts
how many grains in a run exceed a level, so it is a test for SPIKES; the seven
tracks .lab/notes/BISECTION.md names carry 78rpm surface crackle, which at 2 s grains
is not a spike but a floor. And the clean population's upper tail is owned by
glitch and lowercase electronica, which are the opposite shape -- run median
around 5 with single grains past 460. Calibrating the old statistic correctly
makes it blind to the damage it exists for: transient_null measured a macro
T* = 178.6 at which NOT ONE GRAIN of ANY of the seven reaches the bar.

BOTH RULES ARE ORDER STATISTICS OF THE SAME RUN, WHICH IS WHAT MAKES THEM
COMPARABLE AT ALL
-------------------------------------------------------------------------
The old gate rejects when `count(grain > T) >= frac * n`. That is exactly:

    reject when the k-th LARGEST grain score in the run exceeds T,
    with k = ceil(frac * n)  --  6 of 24 at ev, 3 of 12 at mid, 2 of 8 at macro.

So the incumbent thresholds the run's ~75th percentile and the proposal
thresholds its 50th. Same run, same grain_score(), same family; the only
difference is WHICH order statistic. That reduces the whole question to one
comparison -- which quantile of a run separates damaged from clean material
better -- and it means the two can be put on the same ROC instead of being
compared at whatever operating points they happen to have been set to. A
detector that throws away four times as much clean material will catch more
damage; that is not evidence about the statistic. Only a MATCHED false-rejection
rate is.

WHAT IS IMPORTED AND WHY NOTHING IS REIMPLEMENTED
-------------------------------------------------
grain_score() from audit_grain_transients, SR/decode()/onsets() from
build_grains_onset, cut_run()/harvest()/load_exclusions() from transient_null.
Each is the instrument that will do the judging or the code that will cut the
grains. A reimplementation calibrates something other than the gate, which is
the failure that made the 0.9 drift target uncitable (tools/drift_null.py).

THE NULL IS THE SAME POPULATION, DRAWN AGAIN, ON A DIFFERENT SEED
-----------------------------------------------------------------
Licence-clean FMA ids, minus three PROVENANCE-BASED exclusions (transient_null's
load_exclusions, unchanged): the seven ids BISECTION.md names, every "Antique
Phonograph Music Program" transfer, every genre_top == "Old-Time / Historic".
Nothing is excluded for scoring high; a null truncated at the number under test
would be an artefact of its own construction.

The seed is DELIBERATELY NOT transient_null's. That file reports clean run-median
p99 of 24.8 / 70.6 / 173.4 at seed 20260901; re-running the same seed would
reproduce its arithmetic rather than verify its number. Seed 20260902 draws a
different 600 tracks from the same pool. THE TWO DISAGREE AT MACRO AND THE
DISAGREEMENT IS THE POINT -- see the measured section below.

THE RULE, STATED BEFORE ANY NUMBER CAME OUT
-------------------------------------------
    M*  =  the 99th percentile of the RUN MEDIAN of grain_score() over
           undamaged material AT THIS GEOMETRY.
    CRITERION: reject a source track when the median grain_score across its
    consecutive run exceeds M*.

Same percentile as transient_null's T*, deliberately: moving the percentile and
the statistic together would let the new rule win for a reason that has nothing
to do with the statistic.

One threshold per layer and never one number for three. grain_score()'s median
window is 15 ms, so a 60 ms grain gives the anomaly ratio ~4 chances to be large
and a 2 s grain ~133. Three geometries are three null distributions.

ONE STATISTIC, ONE PARAMETER. The quiet advantage over (40, 0.25): that pair had
a statistic AND a criterion, only the second decided anything, and neither could
be quoted without the other. The run median IS the statistic and M* IS the
criterion.

WHY THE IN-SAMPLE FALSE-REJECTION RATE IS NOT A RESULT
------------------------------------------------------
M* is the 99th percentile of the clean run medians, so it rejects ~1% of the
tracks it was derived on by definition. Printing that as a measured rate would
be reporting the definition back as a finding. The clean population is therefore
SPLIT: M* derived on one half, false rejection measured on the other. Both are
printed and only the held-out one means anything. The old rule is measured on
the same held-out half.

THE POSITIVE CONTROL, AND WHY IT IS CUT MANY TIMES
--------------------------------------------------
A run is cut from a RANDOM START and damage is not uniform along a track, so ONE
run per damaged track measures the draw as much as the track. transient_null saw
122539 with a macro run median of 76.5 on its draw; a different draw puts the
same track's ev median at 3.5 with nine of twenty-four grains over 40. Neither
number is wrong and neither is a property of the track.

So the control here cuts --control-reps INDEPENDENT runs from each damaged
track and reports the fraction of runs rejected -- a per-track detection
probability under the builder's own sampling, which is the quantity that
actually governs how often a damaged track slips through. It is still a LOWER
BOUND on sensitivity, for reasons no amount of resampling fixes:

  * BISECTION.md counts THIRTEEN damaged tracks and NAMES only the SEVEN that
    appeared in both the ev and macro corpora. The other six were never written
    down and the corpora they were found in have been rebuilt, so recovering
    them means re-running the detector on itself.
  * n = 7 tracks. Resampling runs sharpens the per-track estimate; it cannot
    make seven tracks into a population.

WHAT THIS STILL CANNOT DO
-------------------------
It separates a raised floor from a rare spike. It does not separate a DEFECT
from an AESTHETIC. Uniformly noisy music -- harsh noise, dense static -- has a
raised run median for compositional reasons and this rule rejects it exactly as
it rejects shellac. That is a narrowing of an unchosen supply and it belongs in
the record. classify_transients.py (duration, continuation, flatness) is the
only instrument here that can tell a defect from a snare and it is not wired
into the gate.

  python3 tools/transient_median_null.py --tracks 600
  python3 tools/transient_median_null.py --tracks 2500 --save /tmp/mnull.json

NOTHING HERE CHANGES A RUNNING SYSTEM. This file reads mp3s and prints numbers.
"""
import argparse
import json
import math
import os
import random
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_grains_onset import SR, decode, onsets                    # noqa: E402
from transient_null import (BISECTION_DAMAGED, GEOMETRIES,           # noqa: E402
                            AUDIO_DEFAULT, IDS_DEFAULT, META_DEFAULT,
                            cut_run, harvest, load_exclusions, pctl_line)

# The rule, fixed before any number came out.
MEDIAN_PCTL = 99.0

# The live gate, carried here only so it can be measured beside the new one.
LIVE_MAX_TRANSIENT = 40.0
LIVE_TRANSIENT_FRAC = 0.25

# False-rejection rates at which the two statistics are compared head to head.
# Chosen to bracket both rules' current operating points (the live pair sits
# near 1% at ev and near 4% at macro) so neither is flattered by the choice.
MATCH_FRR = (0.5, 1.0, 2.0, 5.0)

N_BOOT = 2000             # bootstrap replicates for the CI on M*; resamples TRACKS
SEED_DEFAULT = 20260902   # NOT transient_null's 20260901 -- see the docstring
CONTROL_REPS = 40


def old_k(n, frac=LIVE_TRANSIENT_FRAC):
    """The order statistic build_grains_onset.py's live gate actually thresholds.

    Its line 235 is `if hot >= a.transient_frac * len(batch)`. Greater-or-EQUAL
    against a possibly-fractional count, so the run is rejected exactly when its
    k-th largest grain score exceeds T, with k = ceil(frac * n). At the live
    geometries that is 6 of 24, 3 of 12 and 2 of 8. Derived rather than assumed
    because a comparison against a slightly-wrong transcription of the incumbent
    would be an argument for the new rule made out of a bug.
    """
    return max(1, math.ceil(frac * n - 1e-9))


def stat_old(run, frac=LIVE_TRANSIENT_FRAC):
    """The incumbent's per-run statistic: the k-th largest grain score."""
    r = np.sort(np.asarray(run, dtype=float))
    return float(r[-old_k(len(r), frac)])


def stat_new(run):
    """The proposal's per-run statistic: the median grain score."""
    return float(np.median(np.asarray(run, dtype=float)))


def thresh_at_frr(clean_stats, frr_pct):
    """The threshold on a statistic that rejects frr_pct of clean material.

    Rejection is `stat > thresh`, so the threshold is the (100 - frr)th
    percentile of the clean statistic. Returned with the rate it ACTUALLY
    achieves, because these distributions are lumpy near the tail and asking for
    0.5% of 300 tracks is asking for one and a half tracks.
    """
    t = float(np.percentile(clean_stats, 100.0 - frr_pct))
    return t, 100.0 * float(np.mean(np.asarray(clean_stats) > t))


def control_harvest(ids, audio, geoms, reps, seed):
    """Cut `reps` INDEPENDENT runs from each damaged track, per geometry.

    Decodes each track once (the expensive part) and re-cuts from a fresh random
    start each time, using transient_null.cut_run so the segmentation stays the
    builder's own. One run per track measures the draw; many runs per track
    measure the track.
    """
    per = {g: {"runs": [], "ids": []} for g in geoms}
    rng = {g: random.Random(seed + 977 + h) for h, g in enumerate(geoms)}
    t0 = time.time()
    for tid in ids:
        path = os.path.join(audio, f"{tid // 1000:03d}", f"{tid:06d}.mp3")
        if not os.path.exists(path):
            print(f"    [control] {tid}: NOT ON DISK, skipped")
            continue
        x = decode(path)
        if x is None:
            print(f"    [control] {tid}: decode failed, skipped")
            continue
        mono = x.mean(axis=1)
        on_all = onsets(mono, SR)
        for g in geoms:
            sec, per_track = GEOMETRIES[g]
            got = 0
            for _ in range(reps):
                r = cut_run(x, mono, on_all, sec, per_track, rng[g])
                if r is None:
                    continue
                per[g]["runs"].append((tid, np.asarray(r)))
                got += 1
            if got < reps:
                print(f"    [control] {tid} {g}: {got}/{reps} runs cut "
                      f"(the builder's own skip: too few usable onsets)")
        for g in geoms:
            if tid not in per[g]["ids"]:
                per[g]["ids"].append(tid)
    print(f"  [control] {len(ids)} ids, {reps} runs each, {time.time() - t0:.0f}s")
    return per


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", default=IDS_DEFAULT)
    ap.add_argument("--audio", default=AUDIO_DEFAULT)
    ap.add_argument("--meta", default=META_DEFAULT)
    ap.add_argument("--tracks", type=int, default=600,
                    help="clean tracks per geometry. A p99 over TRACKS is much "
                         "coarser than one over grains -- at 600 it is the 6th "
                         "largest of 600 -- so read the bootstrap interval")
    ap.add_argument("--geometry", default="all", help="ev | mid | macro | all")
    ap.add_argument("--seed", type=int, default=SEED_DEFAULT)
    ap.add_argument("--current-thresh", type=float, default=LIVE_MAX_TRANSIENT)
    ap.add_argument("--current-frac", type=float, default=LIVE_TRANSIENT_FRAC)
    ap.add_argument("--control-reps", type=int, default=CONTROL_REPS,
                    help="independent runs cut from each damaged track")
    ap.add_argument("--boot", type=int, default=N_BOOT)
    ap.add_argument("--min-clean", type=int, default=100,
                    help="refuse to report a threshold from fewer clean tracks "
                         "than this. Lower it only to smoke-test the plumbing")
    ap.add_argument("--save", help="write raw run scores here (JSON)")
    a = ap.parse_args()

    geoms = list(GEOMETRIES) if a.geometry == "all" else \
        [g.strip() for g in a.geometry.split(",") if g.strip()]
    for g in geoms:
        if g not in GEOMETRIES:
            raise SystemExit(f"  unknown geometry {g!r}; have {list(GEOMETRIES)}")

    ids = [int(x.strip()) for x in open(a.ids) if x.strip().isdigit()]
    drop, why = load_exclusions(a.meta, ids)

    print()
    print(f"  ids:        {a.ids}   ({len(ids)} vetted)")
    print(f"  audio:      {a.audio}")
    print(f"  sample rate {SR} Hz, imported from build_grains_onset.SR")
    print(f"  seed        {a.seed}"
          + ("   (transient_null used 20260901; a different draw on purpose)"
             if a.seed != 20260901 else
             "   (SAME DRAW as transient_null: reproduces its arithmetic, does "
             "NOT verify its number)"))
    print("  excluded from the null (provenance only, never a score):")
    for w in why:
        print(f"      {w}")
    print(f"      -> {len(drop)} ids removed, {len(ids) - len(drop)} remain")
    for g in geoms:
        sec, n = GEOMETRIES[g]
        print(f"  {g:>5}: {sec * 1000:.0f} ms x {n};  the live gate thresholds the "
              f"{old_k(n, a.current_frac)}th largest of {n}, the proposal the median")
    print()

    rng = random.Random(a.seed)
    pool = [i for i in ids if i not in drop]
    rng.shuffle(pool)
    null = harvest(pool, a.audio, geoms, a.tracks, a.seed, "null")
    ref = control_harvest(list(BISECTION_DAMAGED), a.audio, geoms,
                          a.control_reps, a.seed)
    print()

    boot_rng = np.random.default_rng(a.seed)
    derived = {}
    for g in geoms:
        sec, per_track = GEOMETRIES[g]
        runs = null[g]["track"]
        if len(runs) < a.min_clean:
            print(f"  {g}: only {len(runs)} clean tracks. A 99th percentile over "
                  f"tracks needs hundreds. No threshold reported.")
            continue

        med = np.array([stat_new(r) for r in runs])
        okd = np.array([stat_old(r, a.current_frac) for r in runs])
        print(f"  === {g}   ({sec * 1000:.0f} ms grains, runs of {per_track})")
        print(f"      {len(runs)} clean tracks, {sum(len(r) for r in runs)} grains")
        print(f"      RUN MEDIAN of grain_score over clean tracks")
        print(f"          mean {med.mean():7.2f}   sd {med.std(ddof=1):7.2f}   "
              f"min {med.min():6.2f}   max {med.max():8.2f}")
        print(f"          {pctl_line(med)}")
        print(f"      {old_k(per_track, a.current_frac)}th-LARGEST grain score "
              f"(the statistic the live gate thresholds at "
              f"{a.current_thresh:.0f})")
        print(f"          mean {okd.mean():7.2f}   sd {okd.std(ddof=1):7.2f}   "
              f"min {okd.min():6.2f}   max {okd.max():8.2f}")
        print(f"          {pctl_line(okd)}")

        # ---- M*, the pre-registered threshold -----------------------------
        M = float(np.percentile(med, MEDIAN_PCTL))
        ci = ""
        if a.boot:
            # Resample TRACKS, not grains. The unit of the statistic is a run;
            # bootstrapping grains would pretend the 24 grains inside one run
            # were 24 independent observations. They are 24 slices of one
            # recording.
            bs = np.array([np.percentile(boot_rng.choice(med, len(med)),
                                         MEDIAN_PCTL) for _ in range(a.boot)])
            ci = (f"   bootstrap 95% CI [{np.percentile(bs, 2.5):.1f}, "
                  f"{np.percentile(bs, 97.5):.1f}]")
        print()
        print(f"      M*  {M:.1f}{ci}")
        print(f"      RULE      the {MEDIAN_PCTL:g}th percentile of the clean RUN MEDIAN")
        print(f"                at this geometry.")
        print(f"      CRITERION reject a source track when the median grain_score")
        print(f"                across its run exceeds {M:.1f}.")

        # ---- held-out false rejection -------------------------------------
        half = len(runs) // 2
        dev, held = runs[:half], runs[half:]
        M_dev = float(np.percentile([stat_new(r) for r in dev], MEDIAN_PCTL))
        o_in = int(np.count_nonzero(okd > a.current_thresh))
        n_in = int(np.count_nonzero(med > M))
        o_ho = sum(stat_old(r, a.current_frac) > a.current_thresh for r in held)
        n_ho = sum(stat_new(r) > M_dev for r in held)
        print()
        print(f"      FALSE REJECTION on undamaged material")
        print(f"          in-sample   ({len(runs)} tracks, M* from these same tracks)")
        print(f"              old ({a.current_thresh:.0f}, {a.current_frac:.2f})  "
              f"{o_in:>4}/{len(runs)}  {100 * o_in / len(runs):5.2f}%")
        print(f"              new (median > {M:.1f})  {n_in:>4}/{len(runs)}  "
              f"{100 * n_in / len(runs):5.2f}%"
              f"   <- the DEFINITION of p{MEDIAN_PCTL:g}, not a measurement")
        print(f"          held out    ({len(held)} tracks, M* = {M_dev:.1f} from "
              f"the other {len(dev)})")
        print(f"              old ({a.current_thresh:.0f}, {a.current_frac:.2f})  "
              f"{o_ho:>4}/{len(held)}  {100 * o_ho / len(held):5.2f}%")
        print(f"              new (median > {M_dev:.1f})  {n_ho:>4}/{len(held)}  "
              f"{100 * n_ho / len(held):5.2f}%   <- the measured rate")

        derived[g] = dict(M=M, M_dev=M_dev, clean_med=med, clean_old=okd,
                          n_clean=len(runs), n_held=len(held),
                          old_in=o_in, new_in=n_in, old_ho=o_ho, new_ho=n_ho)
        print()

    # ---- positive control, per track ---------------------------------------
    print()
    print("  === POSITIVE CONTROL: the seven ids named in .lab/notes/BISECTION.md")
    print(f"      {a.control_reps} INDEPENDENT runs per track per layer, each from")
    print("      its own random start. The column is the fraction of runs the")
    print("      rule rejects: a detection PROBABILITY under the builder's own")
    print("      sampling, not a verdict on the track.")
    print("      SEVEN of THIRTEEN damaged tracks were ever named, so every")
    print("      detection figure below is a LOWER BOUND on sensitivity.")
    for g in geoms:
        if g not in derived or not ref[g]["runs"]:
            continue
        M = derived[g]["M"]
        print()
        print(f"      -- {g}   (M* {M:.1f}; live gate {a.current_thresh:.0f} on "
              f">= {a.current_frac:.2f} of the run)")
        print(f"         {'track':>8} {'runs':>5} {'med(median)':>12} "
              f"{'med(kth)':>9} {'old rej':>9} {'new rej':>9}")
        for tid in ref[g]["ids"]:
            rr = [r for t, r in ref[g]["runs"] if t == tid]
            if not rr:
                continue
            om = np.median([stat_old(r, a.current_frac) for r in rr])
            nm = np.median([stat_new(r) for r in rr])
            o = np.mean([stat_old(r, a.current_frac) > a.current_thresh for r in rr])
            n = np.mean([stat_new(r) > M for r in rr])
            print(f"         {tid:>8} {len(rr):>5} {nm:>12.1f} {om:>9.1f} "
                  f"{o:>9.3f} {n:>9.3f}")
        allr = [r for _, r in ref[g]["runs"]]
        derived[g]["dmg_runs"] = allr
        derived[g]["old_dmg"] = sum(stat_old(r, a.current_frac) > a.current_thresh
                                    for r in allr)
        derived[g]["new_dmg"] = sum(stat_new(r) > M for r in allr)
        derived[g]["n_dmg"] = len(allr)

    # ---- confusion matrix at each rule's own operating point ---------------
    print()
    print()
    print("  === CONFUSION MATRIX at each rule's OWN operating point")
    print("      (the live pair as it runs today, against M* as pre-registered)")
    print()
    print(f"  {'layer':>7} | {'clean rejected (held out)':^27} | "
          f"{'damaged runs rejected (LOWER BOUND)':^37}")
    print(f"  {'':>7} | {'old (40,0.25)':>13} {'new (M*)':>13} | "
          f"{'old (40,0.25)':>17} {'new (M*)':>18}")
    print(f"  {'-' * 7}-+-{'-' * 27}-+-{'-' * 37}")
    for g in geoms:
        d = derived.get(g)
        if not d or "n_dmg" not in d:
            continue
        print(f"  {g:>7} | {d['old_ho']:>4}/{d['n_held']:<4} "
              f"{100 * d['old_ho'] / d['n_held']:5.2f}%  "
              f"{d['new_ho']:>4}/{d['n_held']:<4} "
              f"{100 * d['new_ho'] / d['n_held']:5.2f}% | "
              f"{d['old_dmg']:>7}/{d['n_dmg']:<4} "
              f"{100 * d['old_dmg'] / d['n_dmg']:5.1f}%  "
              f"{d['new_dmg']:>7}/{d['n_dmg']:<4} "
              f"{100 * d['new_dmg'] / d['n_dmg']:5.1f}%")
    print()
    print("  THIS TABLE CANNOT DECIDE ANYTHING ON ITS OWN. The two rules sit at")
    print("  different false-rejection rates, and a gate that discards more clean")
    print("  material will catch more damage for that reason alone. The table")
    print("  below removes that confound.")

    # ---- the comparison that means something: matched false rejection ------
    print()
    print()
    print("  === HEAD TO HEAD AT MATCHED FALSE-REJECTION RATE")
    print("      Each statistic is thresholded at the clean percentile that")
    print("      rejects the same share of undamaged tracks, then measured on the")
    print("      damaged runs. Same null, same control, same cost. This is the")
    print("      only comparison that is about the STATISTIC and not about how")
    print("      permissively each happens to be set.")
    print("      Thresholds come from the held-out half so neither rule is scored")
    print("      at an operating point fitted to the tracks it is scored on.")
    for g in geoms:
        d = derived.get(g)
        if not d or "n_dmg" not in d:
            continue
        half = d["n_clean"] // 2
        dev_med = d["clean_med"][:half]
        dev_old = d["clean_old"][:half]
        ho_med = d["clean_med"][half:]
        ho_old = d["clean_old"][half:]
        allr = d["dmg_runs"]
        dmg_med = np.array([stat_new(r) for r in allr])
        dmg_old = np.array([stat_old(r, a.current_frac) for r in allr])
        print()
        print(f"      -- {g}   ({len(ho_med)} held-out clean tracks, "
              f"{len(allr)} damaged runs)")
        print(f"         {'target FRR':>10} | {'old: T':>8} {'actual':>7} "
              f"{'detect':>8} | {'new: M':>8} {'actual':>7} {'detect':>8}")
        for tgt in MATCH_FRR:
            To, _ = thresh_at_frr(dev_old, tgt)
            Tn, _ = thresh_at_frr(dev_med, tgt)
            fo = 100.0 * float(np.mean(ho_old > To))
            fn = 100.0 * float(np.mean(ho_med > Tn))
            do = 100.0 * float(np.mean(dmg_old > To))
            dn = 100.0 * float(np.mean(dmg_med > Tn))
            print(f"         {tgt:>9.1f}% | {To:>8.1f} {fo:>6.2f}% {do:>7.1f}% | "
                  f"{Tn:>8.1f} {fn:>6.2f}% {dn:>7.1f}%")

    print()
    print("  READ THE MATCHED TABLE, NOT THE OPERATING-POINT TABLE. If the new")
    print("  statistic does not detect more damage at the same false-rejection")
    print("  rate, it is not a better detector and no threshold derived for it")
    print("  makes it one. Say so rather than shipping it.")
    print()
    print("  DO NOT CACHE THESE THRESHOLDS ACROSS A GEOMETRY OR SAMPLE-RATE")
    print(f"  CHANGE. M* is a property of the grain length, the run length and")
    print(f"  grain_score()'s 15 ms window, measured here at SR = {SR}.")

    if a.save:
        payload = {g: {"clean": [list(map(float, r)) for r in null[g]["track"]],
                       "clean_ids": null[g]["ids"],
                       "damaged": [[int(t), list(map(float, r))]
                                   for t, r in ref[g]["runs"]],
                       "M_star": derived.get(g, {}).get("M")}
                   for g in geoms}
        payload["_meta"] = {"seed": a.seed, "tracks": a.tracks, "sr": SR,
                            "pctl": MEDIAN_PCTL, "reps": a.control_reps}
        json.dump(payload, open(a.save, "w"))
        print(f"\n  wrote raw run scores to {a.save}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
