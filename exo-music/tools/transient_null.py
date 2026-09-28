#!/usr/bin/env python3
"""A threshold for build_grains_onset.py's transient gate, derived from a null.

WHY THIS FILE EXISTS
--------------------
build_grains_onset.py rejects a source track when too much of its grain run is
"impulsive":

    --max-transient 40.0     grain_score() ratio above which a grain is impulsive
    --transient-frac 0.25    reject the whole track if this fraction is impulsive

Both numbers were chosen BY LOOKING AT THE DAMAGE THEY WERE MEANT TO REMOVE.
.lab/notes/BISECTION.md is candid about it: a corpus was measured, 78rpm shellac
crackle was seen sitting above roughly 40 on the anomaly ratio, and the gate was
put at 40; 0.25 followed because it caught the tracks that wanted catching. The
document says so itself -- "40 is a reasonable threshold from the distributions
above, and it is a threshold I chose. It should be pre-registered before it is
used to make any claim."

A number fitted to its own outcome cannot be quoted as a criterion. It is the
same error as the 0.9 drift target (see tools/drift_null.py), and it gets the
same treatment: derive the number from a NULL -- from material where the thing
being detected is absent -- using the instrument that will actually do the
judging, and only then look at where the hand-picked number landed.

This file does not propose a better detector. It takes grain_score() as given,
IMPORTS it rather than reimplementing it (a reimplementation would calibrate
something other than the gate, which is exactly how the 0.9 target became
uncitable), imports build_grains_onset's decode(), onsets() and SR so the
segmentation is the builder's own, and asks the one question that turns the
detector into a threshold:

    WHAT DOES grain_score() READ ON MATERIAL WITH NO IMPULSIVE DAMAGE IN IT?

THE NULL
--------
Licence-clean FMA tracks (clean_vetted.txt), cut into grains by
build_grains_onset.py's own code: same sample rate, same spectral-flux onset
definition, same "consecutive run from a random start", same stereo fold, same
scoring of the RAW segment before write_grain()'s fade. The only thing this file
adds is the population it draws from, and what it removes from it.

Removed, and every removal is PROVENANCE-BASED rather than detector-based:

  1. the seven track ids named in .lab/notes/BISECTION.md as damaged;
  2. every track whose ALBUM is an "Antique Phonograph Music Program" transfer
     (450 of the 16,375 vetted ids) -- the 78rpm class the gate was built for;
  3. every track whose genre_top is "Old-Time / Historic" (516 of them; 520 in
     union with the above) -- the same class by a second name, since many
     phonograph transfers are catalogued only by genre.

THE RULE MUST NOT BE "EXCLUDE WHAT SCORES HIGH". If tracks were dropped from the
null because grain_score() flagged them, the surviving distribution would be
truncated at exactly the number under test and the derived threshold would be an
artefact of its own construction -- the fitting error again, wearing a lab coat.
So the exclusions are metadata: an album title and a genre label, decided by FMA
and not by this apparatus. Whatever damage remains in the null AFTER that stays
in, and shows up as a tail. A tail is a finding about the corpus, not noise to
be cleaned away. (Run --no-exclude to see how much of the tail the 78rpm class
owns; never derive a number from that run.)

WHAT --no-exclude ACTUALLY SHOWED, WHICH IS NOT WHAT IT WAS BUILT TO SHOW
------------------------------------------------------------------------
At 250 tracks the unexcluded population gave a LOWER T* than the excluded one
(49.3 vs 57.4 at ev, 108.7 vs 233.9 at macro) -- the opposite of the expected
direction. That is not the 78rpm class pulling the threshold down. The two runs
draw DIFFERENT TRACKS, because removing 525 ids reshuffles the pool, and at 250
tracks the p99 is dominated by whichever handful of extreme tracks happened to
be drawn. The comparison is confounded and is reported as uninformative rather
than dressed up as a result. What it does establish is that the estimator was
under-sampled at 250 tracks, which is why the figures below are from 600.

THE HONEST HOLE IN THE EXCLUSION LIST
-------------------------------------
BISECTION.md says THIRTEEN source tracks carry impulsive noise but NAMES only
the SEVEN that appeared in both the ev and macro corpora. The other six were
never written down, and the pre-gate corpora they were found in have since been
rebuilt with the gate on, so they cannot be recovered without re-running the
detector -- which is the circularity above. Six unnamed damaged tracks out of
~16,000 vetted ids will almost never be drawn, but the list is incomplete and
saying otherwise would be an invention.

WHICH WAY THIS NULL POINTS
--------------------------
Unlike drift_null.py, this one is a FLOOR and not a ceiling. Undamaged material
gives LOW ratios; damage gives high ones. The threshold is an upper percentile
of the null: the level ordinary music essentially never reaches.

THE GATE HAS TWO PARAMETERS AND ONLY ONE OF THEM IS A CRITERION
---------------------------------------------------------------
--max-transient defines the STATISTIC (how many grains in this run are
impulsive). --transient-frac is the CRITERION applied to that statistic. Only
the second decides anything, so only the second has to be pre-registered against
a null, and the quantity a null can actually control is the FALSE REJECTION
RATE: how much undamaged music the gate throws away.

    THE RULE, STATED BEFORE ANY NUMBER CAME OUT
      per-grain    T* = the 99th percentile of grain_score() over undamaged
                        material at THIS geometry.
      per-track    f* = the 99th percentile of the per-track impulsive fraction
                        over undamaged material at T*, floored at one grain in
                        the run (a run of 24 cannot express a finer fraction).
      target       ALPHA = 1 percent of undamaged tracks rejected. The measured
                        false-rejection rate of (T*, f*) is printed; it will not
                        land exactly on 1% because the per-track fraction is a
                        lumpy discrete quantity with a spike at zero.

f* is derived AT T*, not at 40, because the two move together: raise T and the
fraction distribution collapses toward zero, so a fraction threshold quoted
without the T it was derived at means nothing.

GEOMETRY MATTERS, AND ONE NUMBER CURRENTLY SERVES THREE GEOMETRIES
------------------------------------------------------------------
rebuild_gated.sh passes the SAME --max-transient 40 to all three layers:
ev (60 ms grains, runs of 24), mid (400 ms, runs of 12), macro (2 s, runs of 8).
But grain_score()'s own docstring says med_ms=15 was chosen so that "roughly
four windows per grain" fit inside a 60 ms grain. A 2 s macro grain holds ~133
such windows, so the statistic is a maximum over 133 chances instead of 4 and
its null distribution is necessarily higher. A threshold derived on ev and
applied to macro is not the same test. This file measures all three geometries
separately.

WHAT THIS NULL DOES NOT MODEL, AND ONE THING IT DISCOVERED
----------------------------------------------------------
It models "music with no impulsive DEFECT". It does not model "music whose
aesthetic is impulsive" -- glitch, noise, lowercase electronica. Those are IN
the clean population by design: they are licence-clean, they are not 78rpm
transfers, and a corpus meant to be an unchosen supply has no principled reason
to drop them. They own most of the upper tail, which makes the derived threshold
MORE permissive than one fitted to shellac. That is the right direction -- the
gate should reject defects, not genres -- but it means T* is a threshold for
DEFECT and tools/classify_transients.py (duration, continuation, flatness)
remains the only instrument here that separates a defect from a snare.

Running the positive control (--reference-ids, the seven named tracks) turned up
something the gate's design did not anticipate, and it is printed with the
control so it cannot be skipped: SHELLAC DOES NOT PRODUCE RARE EXTREMES, IT
RAISES THE WHOLE RUN. The phonograph tracks show run MEDIANS of 43-87 with
maxima barely over 100, while clean glitch material shows run medians of 4-6
with maxima up to 465. So 40 catches shellac by sitting just above the crackle's
median, and an upper-percentile threshold like T* -- which is designed to catch
rare spikes -- misses it: at macro, T* = 178.6 flags NO grain of any of the
seven, while the live 40 flags five of them on their entire run. The clean
run-median distribution says the same thing from the other side (ev p99 = 24.8,
mid 70.6, macro 173.4) against control medians of 43-87. The two failure modes
are different shapes and one statistic
cannot be tuned to both. That is not an argument for keeping 40 unexamined; it
is an argument that --max-transient is the wrong knob for shellac, and that a
run-median statistic would be the right one. This file measures both and
proposes neither as a replacement, because replacing the detector is a separate
decision from calibrating it.

WHAT THE FIRST RUN MEASURED (600 clean tracks, seed 20260901, 1 Sept 2026)
--------------------------------------------------------------------------
Recorded here the way drift_null.py records its own figures -- as the state of
the pool at one moment, NOT as constants to be copied into a charter. Re-run
this file at the geometry and population in force at the time of judgment.

    layer   grains   p50    p99=T*   [boot 95% CI]   40.0 sits at   f*     FRR
    ev      14400    4.5     53.4    [ 47.2,  59.8]     p98.58     0.250   1.2%
    mid      7200    5.5     80.0    [ 75.3,  85.7]     p97.08     0.333   1.3%
    macro    4800    7.9    178.6    [158.2, 217.7]     p92.67     0.251   1.0%

The live pair (40, 0.25) rejects 1.7% / 5.0% / 8.5% of undamaged tracks at ev /
mid / macro. At ev that is defensible and 40 is close to the derived T*: the
number was picked badly but landed in a reasonable place. At macro it is not
defensible. 40 is only the 93rd percentile of clean macro grain scores, 7.3% of
ordinary grains already exceed it, and the gate throws away roughly one clean
track in twelve.

SAMPLE SIZE: a p99 wants grains. At 250 tracks the macro T* read 233.9 with a
bootstrap CI of [178.6, 415.4] -- an interval so wide the point estimate is
almost decorative. At 600 tracks it reads 178.6 with [158.2, 217.7]. Do not
quote a macro threshold from fewer than ~500 tracks, and quote the interval with
it. ev and mid are stable by 250.

  python3 tools/transient_null.py --tracks 600 --geometry all
  python3 tools/transient_null.py --tracks 600 --geometry all --reference-ids bisection7

NOTHING HERE CHANGES A RUNNING SYSTEM. This file reads mp3s and prints numbers.
It does not touch the corpora, the pool, the factory or rebuild_gated.sh, and
the gate is still at (40, 0.25) on all three layers until someone decides
otherwise.
"""
import argparse
import os
import random
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audit_grain_transients import grain_score            # noqa: E402
from build_grains_onset import SR, decode, onsets         # noqa: E402

# The seven ids .lab/notes/BISECTION.md names. See "THE HONEST HOLE" above: the
# document counts thirteen and writes down these seven.
BISECTION_DAMAGED = (122539, 122726, 122411, 152328, 121312, 47074, 131922)

# Provenance exclusions. Both are FMA's own labels, applied before any audio is
# read, so nothing in the null is removed on the strength of its score.
EXCLUDE_ALBUM_SUBSTR = "antique phonograph"
EXCLUDE_GENRE_TOP = "Old-Time / Historic"

# (grain seconds, grains per run) -- verbatim from tools/rebuild_gated.sh, the
# script that actually built the three live corpora.
GEOMETRIES = {
    "ev":    (0.06, 24),
    "mid":   (0.40, 12),
    "macro": (2.00, 8),
}

# The rule, fixed here before any number comes out so it cannot be chosen
# afterwards to suit the answer.
GRAIN_PCTL = 99.0      # per-grain T* = this percentile of clean grain scores
FRAC_PCTL = 99.0       # per-track f* = this percentile of clean track fractions
ALPHA = 1.0            # target false-rejection rate on undamaged material, %

IDS_DEFAULT = "/Volumes/FMA/fma/clean/clean_vetted.txt"
AUDIO_DEFAULT = "/Volumes/FMA/fma/fma_large"
META_DEFAULT = "/Volumes/FMA/fma/fma_metadata/tracks.csv"

REPORT_PCTLS = (50, 75, 90, 95, 99, 99.5, 99.9)
N_BOOT = 400           # bootstrap replicates for the CI on T*


def load_exclusions(meta_path, ids):
    """Ids to drop from the null, and why. Metadata only -- never a score.

    If the metadata file is missing the null still runs, but it then contains
    ~520 78rpm transfers out of 16,375 vetted ids and its upper tail is
    contaminated with exactly the damage the gate exists to remove. That case is
    reported loudly rather than allowed to pass quietly.
    """
    drop = set(BISECTION_DAMAGED)
    why = [f"{len(drop)} ids named in .lab/notes/BISECTION.md"]
    if not os.path.exists(meta_path):
        return drop, why + ["NO FMA METADATA -- 78rpm class NOT excluded"]
    try:
        import pandas as pd
    except ImportError:
        return drop, why + ["pandas missing -- 78rpm class NOT excluded"]

    t = pd.read_csv(meta_path, index_col=0, header=[0, 1], low_memory=False)
    sub = t.reindex(ids)
    album = sub[("album", "title")].astype(str).str.lower()
    genre = sub[("track", "genre_top")]

    hit_album = album.str.contains(EXCLUDE_ALBUM_SUBSTR, na=False)
    hit_genre = (genre == EXCLUDE_GENRE_TOP)
    drop |= set(int(i) for i in sub.index[hit_album])
    drop |= set(int(i) for i in sub.index[hit_genre])
    why.append(f"{int(hit_album.sum())} '{EXCLUDE_ALBUM_SUBSTR}' album transfers")
    why.append(f"{int(hit_genre.sum())} genre_top == '{EXCLUDE_GENRE_TOP}'")
    # fma_large is largely unlabelled, so the genre rule can only reach the
    # labelled part. The null certainly still holds unlabelled 78rpm material.
    why.append(f"({int(genre.isna().sum())} of {len(ids)} vetted ids carry NO "
               f"genre_top, so the genre rule cannot reach them)")
    return drop, why


def cut_run(x, mono, on_all, sec, per_track, rng):
    """One track's grain run, cut EXACTLY as build_grains_onset.main() cuts it.

    Its lines 206-217: filter onsets away from the head and the tail, require at
    least per_track of them, choose a random START and take a CONSECUTIVE
    stretch. Consecutive and not scattered, because that is what the builder
    does and because the track-level fraction is a property of a consecutive
    run.

    Scoring is on seg.mean(axis=1) -- the raw stereo fold, BEFORE write_grain's
    fade and peak attenuation -- because that is the array the gate itself hands
    to grain_score(). Scoring the written file would calibrate a different
    signal from the one the gate reads.
    """
    n = int(sec * SR)
    on = on_all[(on_all > SR) & (on_all < len(mono) - n - 1)]
    if len(on) < per_track:
        return None
    s0 = rng.randrange(0, len(on) - per_track)
    out = []
    for s in range(per_track):
        st = int(on[s0 + s])
        seg = x[st: st + n]
        if len(seg) < n:
            break
        out.append(grain_score(seg.mean(axis=1), SR)[0])
    return out if len(out) == per_track else None


def harvest(pool, audio, geoms, want, seed, label):
    """Decode each track once and cut every requested geometry from it."""
    per = {g: {"grain": [], "track": [], "ids": []} for g in geoms}
    run_rng = {g: random.Random(seed + h) for h, g in enumerate(geoms)}
    t0, seen, decoded = time.time(), 0, 0
    for tid in pool:
        if all(len(per[g]["ids"]) >= want for g in geoms):
            break
        seen += 1
        path = os.path.join(audio, f"{tid // 1000:03d}", f"{tid:06d}.mp3")
        if not os.path.exists(path):
            continue
        x = decode(path)                       # build_grains_onset.decode
        if x is None:
            continue
        decoded += 1
        mono = x.mean(axis=1)
        on_all = onsets(mono, SR)              # build_grains_onset.onsets
        if len(on_all) == 0:
            continue
        for g in geoms:
            if len(per[g]["ids"]) >= want:
                continue
            sec, per_track = GEOMETRIES[g]
            r = cut_run(x, mono, on_all, sec, per_track, run_rng[g])
            if r is None:
                continue                       # the builder's own skip
            per[g]["grain"].extend(r)
            per[g]["track"].append(np.asarray(r))
            per[g]["ids"].append(tid)
        if decoded % 25 == 0:
            done = ", ".join(f"{g} {len(per[g]['ids'])}" for g in geoms)
            print(f"    [{label}] {decoded} decoded / {seen} drawn   [{done}]   "
                  f"{time.time() - t0:.0f}s", flush=True)
    print(f"  [{label}] {seen} ids drawn, {decoded} decoded, "
          f"{time.time() - t0:.0f}s")
    return per


def pctl_line(v, pctls=REPORT_PCTLS, fmt="8.2f"):
    return "  ".join(f"p{p:g} {np.percentile(v, p):{fmt}}" for p in pctls)


def pctl_of(v, value):
    """Where an existing number sits in a measured distribution."""
    return 100.0 * float(np.mean(np.asarray(v, dtype=float) <= value))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", default=IDS_DEFAULT)
    ap.add_argument("--audio", default=AUDIO_DEFAULT)
    ap.add_argument("--meta", default=META_DEFAULT)
    ap.add_argument("--tracks", type=int, default=600,
                    help="clean tracks to accept per geometry. 600 because the "
                         "macro p99 is still unstable at 250 -- see the docstring")
    ap.add_argument("--geometry", default="all", help="ev | mid | macro | all")
    ap.add_argument("--seed", type=int, default=20260901)
    ap.add_argument("--current-thresh", type=float, default=40.0,
                    help="the hand-picked number to locate in the null")
    ap.add_argument("--current-frac", type=float, default=0.25)
    ap.add_argument("--no-exclude", action="store_true",
                    help="SENSITIVITY ONLY: keep the 78rpm class in the null, to "
                         "show how much of the tail it owns. Never derive a "
                         "threshold from this run")
    ap.add_argument("--reference-ids", default="",
                    help="positive control: 'bisection7' for the seven ids named "
                         "in .lab/notes/BISECTION.md, or a path to an id list. Read the "
                         "caveat printed with it -- it is a WEAK control")
    ap.add_argument("--boot", type=int, default=N_BOOT,
                    help="bootstrap replicates for the CI on T* (0 to skip)")
    ap.add_argument("--save", help="write per-grain and per-track scores here")
    a = ap.parse_args()

    geoms = list(GEOMETRIES) if a.geometry == "all" else \
        [g.strip() for g in a.geometry.split(",") if g.strip()]
    for g in geoms:
        if g not in GEOMETRIES:
            raise SystemExit(f"  unknown geometry {g!r}; have {list(GEOMETRIES)}")

    ids = [int(x.strip()) for x in open(a.ids) if x.strip().isdigit()]
    if a.no_exclude:
        drop, why = set(), ["--no-exclude: NOTHING EXCLUDED"]
    else:
        drop, why = load_exclusions(a.meta, ids)

    print()
    print(f"  ids:        {a.ids}   ({len(ids)} vetted)")
    print(f"  audio:      {a.audio}")
    print(f"  sample rate {SR} Hz, imported from build_grains_onset.SR")
    print(f"  seed        {a.seed}")
    print("  excluded from the null (provenance only, never a score):")
    for w in why:
        print(f"      {w}")
    print(f"      -> {len(drop)} ids removed, {len(ids) - len(drop)} remain")
    if a.no_exclude:
        print("  *** --no-exclude IS A SENSITIVITY RUN. The 78rpm transfers the")
        print("  *** gate exists to remove are IN this population. Do not quote")
        print("  *** a threshold from it.")
    print()

    rng = random.Random(a.seed)
    pool = [i for i in ids if i not in drop]
    rng.shuffle(pool)
    null = harvest(pool, a.audio, geoms, a.tracks, a.seed, "null")

    ref = None
    if a.reference_ids:
        if a.reference_ids == "bisection7":
            ref_ids = list(BISECTION_DAMAGED)
        else:
            ref_ids = [int(x.strip()) for x in open(a.reference_ids)
                       if x.strip().isdigit()]
        ref = harvest(ref_ids, a.audio, geoms, len(ref_ids), a.seed, "control")
    print()

    boot_rng = np.random.default_rng(a.seed)
    for g in geoms:
        sec, per_track = GEOMETRIES[g]
        scores = np.asarray(null[g]["grain"], dtype=float)
        runs = null[g]["track"]
        if len(scores) < 500:
            print(f"  {g}: only {len(scores)} grains from {len(runs)} tracks. Too "
                  f"few to put a 99th percentile on. No threshold reported.")
            continue

        print(f"  === {g}   ({sec * 1000:.0f} ms grains, runs of {per_track})")
        print(f"      {len(runs)} clean tracks, {len(scores)} grains")
        print(f"      grain_score   mean {scores.mean():7.2f}   "
              f"sd {scores.std(ddof=1):7.2f}   min {scores.min():6.2f}   "
              f"max {scores.max():8.2f}")
        print(f"                    {pctl_line(scores)}")

        # ---- T*, the per-grain threshold ---------------------------------
        T = float(np.percentile(scores, GRAIN_PCTL))
        ci = ""
        if a.boot:
            # A 99th percentile estimated from a few thousand draws is not a
            # precise number, and quoting it to one decimal without an interval
            # would repeat the sin of quoting 40 as if it were exact.
            bs = np.array([np.percentile(boot_rng.choice(scores, len(scores)),
                                         GRAIN_PCTL) for _ in range(a.boot)])
            ci = (f"   bootstrap 95% CI [{np.percentile(bs, 2.5):.1f}, "
                  f"{np.percentile(bs, 97.5):.1f}]")
        print()
        print(f"      T*  {T:.1f}{ci}")
        print(f"      RULE      the {GRAIN_PCTL:g}th percentile of grain_score() over")
        print(f"                undamaged material at this geometry.")
        n_over = int(np.count_nonzero(scores > a.current_thresh))
        print(f"      CURRENT   {a.current_thresh:.1f} sits at the "
              f"{pctl_of(scores, a.current_thresh):.2f}th percentile "
              f"({n_over}/{len(scores)} = "
              f"{100 * n_over / len(scores):.2f}% of clean grains are above it)")

        # ---- f*, the criterion, and the false-rejection rate --------------
        # The gate is reject-by-track, so THIS is the distribution that decides
        # anything. It is not the per-grain rate: grains inside one run come
        # from one recording and their scores are correlated, so a 1% per-grain
        # rate does not give a 1% per-track rate.
        print()
        frr_live = None
        for lbl, TT in ((f"at current {a.current_thresh:.0f}", a.current_thresh),
                        (f"at T* {T:.1f}", T)):
            fr = np.array([float(np.mean(r > TT)) for r in runs])
            print(f"      impulsive fraction per clean track, {lbl}:")
            print(f"          mean {fr.mean():.4f}  sd {fr.std(ddof=1):.4f}  "
                  f"max {fr.max():.4f}   "
                  f"({int(np.count_nonzero(fr))}/{len(fr)} tracks have any)")
            print(f"          {pctl_line(fr, fmt='.3f')}")
            frr_cur = 100 * float(np.mean(fr >= a.current_frac))
            print(f"          criterion frac >= {a.current_frac:.2f} rejects "
                  f"{frr_cur:.1f}% of undamaged tracks")
            if frr_live is None:
                # the LIVE pair: current threshold AND current fraction. Held so
                # the comparison below cannot silently quote the fraction
                # criterion measured at T* as though it were the live gate.
                frr_live = frr_cur
            if lbl.startswith("at T*"):
                f_star = max(float(np.percentile(fr, FRAC_PCTL)), 1.0 / per_track)
                frr = 100 * float(np.mean(fr >= f_star))
                print()
                print(f"      f*  {f_star:.3f}")
                print(f"      RULE      the {FRAC_PCTL:g}th percentile of the per-track")
                print(f"                impulsive fraction at T*, floored at one grain")
                print(f"                in {per_track} ({1.0 / per_track:.3f}); a run of "
                      f"{per_track} cannot express less.")
                print(f"      CRITERION reject a track when more than {f_star:.3f} of its")
                print(f"                run scores above {T:.1f}.")
                print(f"      MEASURED  false-rejection rate on undamaged material "
                      f"{frr:.1f}%  (target ALPHA {ALPHA:g}%)")
                print(f"      CURRENT   frac {a.current_frac:.2f} sits at the "
                      f"{pctl_of(fr, a.current_frac):.2f}th percentile of this "
                      f"distribution")
                print(f"      COMPARE   the live pair "
                      f"({a.current_thresh:.0f}, {a.current_frac:.2f}) rejects "
                      f"{frr_live:.1f}% of undamaged tracks;")
                print(f"                the derived pair ({T:.1f}, {f_star:.3f}) "
                      f"rejects {frr:.1f}%.")
            print()

        # ---- the shape finding -------------------------------------------
        # Printed for every geometry because it is the reason T* and 40 are not
        # interchangeable: an upper percentile catches SPIKES, and shellac is
        # not a spike, it is a raised floor.
        med = np.array([float(np.median(r)) for r in runs])
        print(f"      run MEDIAN of grain_score over clean tracks (the statistic")
        print(f"      that separates a raised floor from a rare spike):")
        print(f"          mean {med.mean():.2f}   {pctl_line(med, fmt='.1f')}")
        print()

    # ---- positive control ------------------------------------------------
    if ref is not None:
        print("  === POSITIVE CONTROL: the seven ids named in .lab/notes/BISECTION.md")
        print("      READ THE CAVEAT FIRST. These runs are cut from a RANDOM START,")
        print("      not from the position the original build happened to draw, and")
        print("      the damage in these tracks is not uniform along their length.")
        print("      A track that reads clean here is not exonerated; it means this")
        print("      run missed the damaged stretch. Treat the control as a lower")
        print("      bound on sensitivity, never as a measurement of it.")
        for g in geoms:
            if not ref[g]["ids"]:
                continue
            scores = np.asarray(null[g]["grain"], dtype=float)
            T = float(np.percentile(scores, GRAIN_PCTL))
            print()
            print(f"      -- {g}   (clean T* {T:.1f}, live threshold "
                  f"{a.current_thresh:.0f})")
            print(f"         {'track':>8} {'median':>8} {'max':>9} "
                  f"{'frac>live':>10} {'frac>T*':>9}")
            for i, r in zip(ref[g]["ids"], ref[g]["track"]):
                print(f"         {i:>8} {np.median(r):>8.1f} {r.max():>9.1f} "
                      f"{np.mean(r > a.current_thresh):>10.3f} "
                      f"{np.mean(r > T):>9.3f}")
        print()

    # ---- how to use it ---------------------------------------------------
    print()
    print("  READ THE THRESHOLD AS A FLOOR, NOT A CEILING. Undamaged material")
    print("  scores low; T* is the level ordinary music essentially never")
    print("  reaches. This is the opposite orientation to drift_null.py.")
    print()
    print("  ONLY f* IS A CRITERION. T* defines the statistic; f* decides. Quote")
    print("  them as a PAIR and never separately: raise T and the fraction")
    print("  distribution collapses toward zero, so an f quoted without its T is")
    print("  meaningless.")
    print()
    print("  DO NOT QUOTE ONE NUMBER FOR THREE GEOMETRIES. grain_score()'s median")
    print("  window is 15 ms, so a 60 ms grain gives the maximum ~4 chances and a")
    print("  2 s grain gives it ~133. rebuild_gated.sh currently passes")
    print("  --max-transient 40 to all three layers; the per-layer numbers above")
    print("  are what that decision should be made on.")
    print()
    print("  T* IS AN UPPER PERCENTILE AND SHELLAC IS NOT AN UPPER PERCENTILE.")
    print("  The control shows phonograph transfers raising the run MEDIAN into")
    print("  the 25-70 band with maxima under 100, while clean glitch material")
    print("  keeps a median near 5 and spikes past 400. A percentile threshold")
    print("  catches the spike and misses the floor. If the gate is meant for")
    print("  shellac, the statistic should be the run median and not the count")
    print("  of grains over a level -- that is a change to the detector, and it")
    print("  is a separate decision from calibrating the one in place.")
    print()
    print("  THE NULL CANNOT SEPARATE DEFECT FROM AESTHETIC. Glitch and lowercase")
    print("  electronica are in the clean population on purpose. They own most of")
    print("  the upper tail, which makes T* MORE permissive than a threshold")
    print("  fitted to shellac. classify_transients.py is the instrument for that")
    print("  distinction; this one only sets a scale.")

    if a.save:
        import json
        payload = {g: {"grain": list(map(float, null[g]["grain"])),
                       "tracks": [list(map(float, r)) for r in null[g]["track"]],
                       "ids": null[g]["ids"]} for g in geoms}
        if ref is not None:
            payload["_control"] = {
                g: {"tracks": [list(map(float, r)) for r in ref[g]["track"]],
                    "ids": ref[g]["ids"]} for g in geoms}
        json.dump(payload, open(a.save, "w"))
        print(f"\n  wrote raw scores to {a.save}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
