#!/usr/bin/env python3
"""A threshold for generation_drift.py, derived ON generation_drift.py.

WHY THIS FILE EXISTS
--------------------
generation_drift.py carries a pre-registered target -- "keep consecutive-
generation spectral similarity below 0.9 for twenty generations" -- taken from
runs 12-13. That number cannot be quoted against the estimator that file
actually computes, and the reason is not a rounding difference:

  runs 12-13    UNCENTRED cosine on a 5-vector of LINEAR band-energy
                proportions (0-500 / 0.5-1.5k / 1.5-4k / 4-8k / 8k+), taken
                from ONE whole 20 s render per generation.
  this tool     MEAN-CENTRED cosine (a Pearson correlation) on 513-bin
                LOG-magnitude spectra of grain COHORTS inside a mixed pool.

Run over identical inputs they disagree badly. The current estimator was
reported to floor around 0.965 on real corpus material -- ABOVE the old target
-- where the old one scores maximally dissimilar pairs at 0.598. Centring
removes the mean log-level, which is most of what separates two piles of the
same music; log compresses the band ratios the old measure lived on; and 513
correlated bins of the same broadband material correlate near 1 almost
regardless of content. "Stay below 0.9" is therefore close to unsatisfiable
here, and a criterion that cannot be met is not a criterion, it is a
decoration.

(That 0.965 floor is a figure inherited from the earlier comparison and is NOT
reproduced by this file. The one real pair in the pool measures 0.921 pooled,
below it. Nothing here depends on the 0.965 being right -- the argument is that
the two measures are on different scales, and the null below establishes the
scale of THIS one without reference to either number.)

So the threshold has to be derived on the instrument that will judge it, from a
null, BEFORE it judges anything. That is this file. It does not propose a
better similarity measure; it takes generation_drift.py's measure as given --
including its quirks -- and asks the only question that makes a number out of
it: HOW SIMILAR ARE TWO COHORTS WHEN THE GENERATION LABEL MEANS NOTHING?

THE NULL
--------
Within a layer, take every grain in the pool and SHUFFLE the generation labels
across them, keeping the cohort sizes exactly (2192 gen-0 and 208 gen-1 in
grains_pool_ev, and so on). Recompute the same consecutive-generation
similarity. Repeat. The resulting distribution is what the estimator reports
when the two cohorts are two random slices of ONE population -- when generation
carries no information at all.

This follows convergence2.py, which permutes the window->machine assignment to
build a null for its Spearman rho. Same logic, same reason: a threshold picked
by hand cannot separate structure produced by the factory from structure any
sample of this size and this material would show. Cohort sizes are held fixed
by construction, so the null already contains whatever similarity the 10.5:1
size imbalance implies.

WHICH WAY THE NULL POINTS -- READ THIS BEFORE USING THE NUMBER
--------------------------------------------------------------
The intuition from convergence2.py is inverted here and getting it backwards
would invert the verdict.

Under this null the two cohorts are drawn from the SAME population, so their
mean spectra differ only by sampling noise and the similarity is HIGH -- near
the ceiling. The null is therefore not a floor to clear, it is the CEILING a
converging system climbs toward. Convergence is generation n+1 becoming
indistinguishable from generation n, which is exactly the state the shuffle
manufactures on purpose.

  observed BELOW the null band   the label carries information; the material
                                 moved between generations; the loop is still
                                 producing difference.
  observed INSIDE the null band  generation n+1 is statistically the same
                                 material as generation n. Nothing distinguishes
                                 a real generation step from a coin flip. That
                                 is what the attractor looks like from outside.

THE RULE PROPOSED, STATED PLAINLY
---------------------------------
    THRESHOLD = the 5th percentile of the pooled null distribution.
    A consecutive-generation pair FAILS when its similarity is at or above
    that value, i.e. when it has entered the band where shuffled labels live.

and, because one high value proves nothing (see below):

    CONVERGENCE is declared only when similarity RISES across successive pairs
    and the last three consecutive pairs are all at or above the threshold.

The rise clause is not decoration. Generation 1 is granulated from a recording
of generation 0 SOUNDING, so it is generation-0 material re-cut and a high
similarity at the first step is definitional. Convergence is a similarity that
CLIMBS. A single pair contains no trend, and this tool refuses to report one.

The threshold is a property of the pool's size, layer structure and material.
It is NOT 0.9 rescaled, it is not comparable to runs 12-13, and it must not be
quoted alongside that number as though it were the same quantity.

THE THRESHOLD IS A FUNCTION, NOT A CONSTANT
-------------------------------------------
It moves with cohort size, and hard. Measured on this pool:

    cohort sizes (gen0/gen1)      pooled null p5
    2192/208 etc. (all grains)        0.9996
    208/208                           0.9987
    40/40                             0.9939

which is the sampling noise in a cohort mean shrinking as 1/sqrt(n): bigger
cohorts, tighter null, higher bar. The OBSERVED value barely moved across the
same three conditions (0.9210 / 0.9208 / 0.9234), so the observation is stable
and the threshold is what is fragile.

The consequence is a rule about use, not a caveat: DO NOT CACHE THE NUMBER.
Recompute the null at the cohort sizes in force at the moment of judgment.
This file already does that -- one null per consecutive pair, built from that
pair's own sizes -- so the discipline is simply to re-run it rather than to
copy 0.9996 into a charter. As self-ingestion fills the pool, gen-1 stops
being 8 percent of it and the correct bar rises on its own.

WHAT THIS NULL DOES NOT MODEL -- THE HONEST HOLE
------------------------------------------------
Generation-1 grains are not a random subsample of the pool. They got in by
ADMISSION CONTROL: a new grain enters only by beating an incumbent on score.
The shuffle assigns labels at random and so models "no difference"; it does not
model "no difference beyond what the admission filter would produce anyway".
A departure from this null therefore means "the gen-1 cohort is not a random
slice", which is consistent with generational drift AND with the selection
filter alone. Distinguishing those needs a second null that permutes labels
within score strata, and that is not built. Until it is, a p-value from this
file is evidence about the LABEL, not yet about the LOOP.

Two smaller cautions, both real:

  * gen is stored fractional (ingested grains sit at ~1.06-1.08) and is floored
    to an integer, exactly as generation_drift.py does. Two integer values
    exist in the pool today, so "consecutive generations" is one pair.
  * generation_drift.cohorts() derives the layer name as the LAST underscored
    token of the pool directory, so in a self_corpus root the archived pools
    grains_pool_ev_ungated_lineage, _clicky, _wrongrate and _prevet_0203 arrive
    as layers named "lineage", "clicky", "wrongrate" and "0203" -- and the last
    of those silently merges ev, mid and macro into one bucket. That is a
    naming hazard in the corpus directory, not a bug worth changing in a tool
    that is running. This file defaults to the three live layers and names them
    explicitly; --layers all reproduces the other tool's behaviour if wanted.

    python3 tools/drift_null.py --ring /Volumes/FMA/superdark/self_corpus
"""
import argparse
import random
import sys
import time

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from generation_drift import NFFT, TARGET, cohorts, mean_spectrum  # noqa: E402

N_PERM = 2000
PCTL = 5          # the threshold percentile of the null
LIVE_LAYERS = ("ev", "mid", "macro")
SEED = 20260901
MIN_PAIRS_FOR_TREND = 3


def centred_cosine(u, v):
    """VERBATIM transcription of generation_drift.py's similarity.

    That file computes the similarity inline in main() rather than exposing it,
    so it cannot be imported. These three lines are copied character for
    character from generation_drift.py lines 173-175. If that expression ever
    changes, this one must change with it or the threshold silently stops
    calibrating the tool it claims to calibrate -- which is the exact failure
    that made the 0.9 target unusable in the first place.
    """
    u = u - u.mean()
    v = v - v.mean()
    return float(u @ v / (np.linalg.norm(u) * np.linalg.norm(v) + 1e-12))


def grain_spectra(paths, nfft=NFFT):
    """Per-grain log-magnitude spectra, cached so permutation is cheap.

    mean_spectrum() is a MEAN over grains of log(mean |FFT| over blocks). So
    the cohort spectrum is the arithmetic mean of the per-grain vectors, and
    mean_spectrum([p]) returns exactly the term for grain p. Caching those and
    averaging subsets is therefore not an approximation of the imported
    function -- it is algebraically identical to calling it on the subset.

    This matters practically: 2000 permutations x 5400 grains would be eleven
    million FFT passes over an external SSD that a live factory is also
    reading. With the cache it is 5400 passes once, then arithmetic on 513-long
    vectors. Nothing about the estimator is relaxed to buy that.
    """
    keep, spec = [], []
    for p in paths:
        s, n = mean_spectrum([p], nfft=nfft)
        if s is None or n == 0:
            continue      # unreadable or shorter than 32 samples; same skip
        keep.append(p)     # rule mean_spectrum applies internally
        spec.append(s)
    return keep, (np.array(spec) if spec else np.zeros((0, nfft // 2 + 1)))


def summarise(v):
    v = np.asarray(v, dtype=float)
    return dict(mean=float(v.mean()), sd=float(v.std(ddof=1)) if len(v) > 1 else float("nan"),
                p5=float(np.percentile(v, 5)), p50=float(np.percentile(v, 50)),
                p95=float(np.percentile(v, 95)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ring", required=True)
    ap.add_argument("--perms", type=int, default=N_PERM)
    ap.add_argument("--min-grains", type=int, default=12,
                    help="cohorts smaller than this are too noisy to compare; "
                         "same default as generation_drift.py")
    ap.add_argument("--max-grains", type=int, default=0,
                    help="subsample this many grains per layer before doing "
                         "anything (0 = all). Subsampling widens the null, so "
                         "it makes the threshold MORE permissive, not less; it "
                         "is reported loudly when used")
    ap.add_argument("--layers", default=",".join(LIVE_LAYERS),
                    help="comma-separated layer names, or 'all' to accept "
                         "whatever generation_drift.cohorts() names -- see the "
                         "naming hazard in the module docstring")
    a = ap.parse_args()

    coh = cohorts(a.ring)
    if not coh:
        raise SystemExit("  no grains found in the ring")

    want = None if a.layers.strip() == "all" else \
        [s.strip() for s in a.layers.split(",") if s.strip()]
    layers = sorted({l for _, l in coh} if want is None
                    else {l for _, l in coh if l in want})
    if not layers:
        raise SystemExit(f"  none of the requested layers {want} are in the ring; "
                         f"found {sorted({l for _, l in coh})}")

    rnd = random.Random(SEED)
    print(f"  ring:   {a.ring}")
    print(f"  layers: {', '.join(layers)}"
          + ("" if want is None else "   (live pools only)"))
    print(f"  perms:  {a.perms}   seed {SEED}")
    if a.max_grains:
        print(f"  SUBSAMPLED to {a.max_grains} grains per layer")
    print()

    # ---- cohort census -------------------------------------------------
    gens_all = sorted({g for g, l in coh if l in layers})
    print(f"  {'gen':>5} " + " ".join(f"{l:>8}" for l in layers))
    for g in gens_all:
        print(f"  {g:>5} " + " ".join(
            f"{len(coh.get((g, l), [])):>8}" for l in layers))
    print()

    # ---- the one thing that can kill the run outright -------------------
    # Reported before any spectra are computed, so nobody waits four minutes
    # to be told the test has no trend in it.
    n_pairs = max(0, len(gens_all) - 1)
    if n_pairs < 1:
        print("  FEWER THAN TWO GENERATIONS IN THE POOL. There is no")
        print("  consecutive pair, so there is nothing to build a null around.")
        print("  No threshold is reported. Raise self_ingest_weight and re-run.")
        return

    # ---- per-grain spectra, computed once -------------------------------
    t0 = time.time()
    cache = {}
    for l in layers:
        for g in gens_all:
            paths = coh.get((g, l), [])
            if a.max_grains and len(paths) > a.max_grains:
                paths = rnd.sample(paths, a.max_grains)
            _, spec = grain_spectra(paths)
            cache[(g, l)] = spec
    print(f"  spectra: {sum(len(v) for v in cache.values())} grains "
          f"in {time.time() - t0:.1f}s")
    print()

    # ---- observed and null, per consecutive pair ------------------------
    print("  observed similarity, and the distribution the SAME estimator")
    print("  produces when the generation labels are shuffled within a layer:")
    print()
    hdr = (f"  {'pair':>8} {'layer':>7} {'observed':>9} {'null mean':>10} "
           f"{'sd':>7} {'null p5':>9} {'p50':>9} {'p95':>9} {'z':>8} {'p_ge':>7}")
    print(hdr)

    pooled_obs, pooled_null, pooled_thresh = [], [], []
    for x, y in zip(gens_all, gens_all[1:]):
        per_obs, per_null = {}, {}
        for l in layers:
            A, B = cache.get((x, l)), cache.get((y, l))
            if A is None or B is None:
                continue
            n0, n1 = len(A), len(B)
            if n0 < a.min_grains or n1 < a.min_grains:
                print(f"  {f'{x}->{y}':>8} {l:>7}   skipped: cohort sizes "
                      f"{n0}/{n1}, below --min-grains {a.min_grains}")
                continue

            per_obs[l] = centred_cosine(A.mean(0), B.mean(0))

            # The shuffle. Pool the layer's grains, then re-split into two
            # cohorts of the SAME sizes. Sizes fixed, labels destroyed: any
            # similarity left in the null is what the sample sizes and the
            # material give you for free.
            allg = np.concatenate([A, B], axis=0)
            idx = np.arange(n0 + n1)
            draws = []
            for _ in range(a.perms):
                rnd.shuffle(idx)
                draws.append(centred_cosine(allg[idx[:n0]].mean(0),
                                            allg[idx[n0:]].mean(0)))
            per_null[l] = np.array(draws)

        if not per_obs:
            continue

        for l in layers:
            if l not in per_obs:
                continue
            s = summarise(per_null[l])
            o = per_obs[l]
            z = (o - s["mean"]) / s["sd"] if s["sd"] and np.isfinite(s["sd"]) else float("nan")
            p_ge = float(np.mean(per_null[l] <= o))   # how ordinary is a value
            print(f"  {f'{x}->{y}':>8} {l:>7} {o:>9.4f} {s['mean']:>10.4f} "  # this high?
                  f"{s['sd']:>7.4f} {s['p5']:>9.4f} {s['p50']:>9.4f} "
                  f"{s['p95']:>9.4f} {z:>8.2f} {p_ge:>7.3f}")

        # Pooled = mean across layers, matching generation_drift.py's verdict
        # column. The null is pooled the same way, layer by layer within each
        # permutation, so the pooled null is the null OF THE POOLED STATISTIC
        # and not an average of per-layer percentiles.
        used = [l for l in layers if l in per_obs]
        obs_mean = float(np.mean([per_obs[l] for l in used]))
        null_mean = np.mean(np.vstack([per_null[l] for l in used]), axis=0)
        s = summarise(null_mean)
        z = (obs_mean - s["mean"]) / s["sd"] if s["sd"] and np.isfinite(s["sd"]) else float("nan")
        p_ge = float(np.mean(null_mean <= obs_mean))
        print(f"  {f'{x}->{y}':>8} {'POOLED':>7} {obs_mean:>9.4f} {s['mean']:>10.4f} "
              f"{s['sd']:>7.4f} {s['p5']:>9.4f} {s['p50']:>9.4f} "
              f"{s['p95']:>9.4f} {z:>8.2f} {p_ge:>7.3f}")
        pooled_obs.append((x, y, obs_mean))
        pooled_null.append(null_mean)
        pooled_thresh.append(s["p5"])

    if not pooled_obs:
        print()
        print("  NO PAIR HAD TWO USABLE COHORTS. No threshold reported.")
        return

    # ---- the threshold ---------------------------------------------------
    # One null per pair; they should agree closely, since the null depends on
    # cohort sizes and pool material rather than on which pair it came from.
    # The threshold quoted is the MOST CONSERVATIVE (lowest) of them, so that
    # the criterion is the hardest to satisfy across the pairs measured, and
    # cannot be softened later by pointing at a friendlier pair.
    thresh = float(min(pooled_thresh))
    print()
    print(f"  THRESHOLD  {thresh:.4f}")
    print(f"  RULE       the {PCTL}th percentile of the pooled permutation null.")
    print("             A consecutive-generation pair FAILS at or above it: at")
    print("             that similarity the two cohorts are indistinguishable")
    print("             from two random halves of one pool, which is what")
    print("             'generation stopped meaning anything' looks like.")
    print("  DIRECTION  convergence is similarity RISING across successive")
    print("             generations INTO this band and staying there. A high")
    print("             value at step one is definitional, not evidence.")
    print(f"  DECLARE    convergence only when the last {MIN_PAIRS_FOR_TREND} "
          f"consecutive pairs are all")
    print(f"             >= {thresh:.4f} AND the sequence of similarities is rising.")
    print()
    print("  DO NOT CACHE THIS NUMBER. It is a function of the cohort sizes")
    print("  above, not a constant of the system: the null tightens as 1/sqrt(n),")
    print("  so the bar RISES on its own as self-ingestion fills the pool. On")
    print("  this pool it read 0.9996 at full size, 0.9987 at 208/208 and 0.9939")
    print("  at 40/40, while the observed value moved by 0.003. Re-run this file")
    print("  at judgment time; do not copy the figure into a charter.")
    print()
    print(f"  NOT COMPARABLE to the {TARGET} of runs 12-13. Different measure,")
    print("  different object, different scale. Do not print them together.")
    print()
    print("  AND THE NULL DOES NOT MODEL ADMISSION CONTROL. Gen-1 grains got in")
    print("  by beating an incumbent on score, so they are a selected subsample.")
    print("  A gap from this null says the LABEL is informative; it does not yet")
    print("  separate generational drift from the selection filter itself.")

    # ---- what the data can and cannot support ---------------------------
    print()
    if len(pooled_obs) < MIN_PAIRS_FOR_TREND:
        print(f"  TREND NOT MEASURABLE. {len(pooled_obs)} consecutive pair(s) "
              f"exist; {MIN_PAIRS_FOR_TREND} are needed")
        print("  before 'rising' is a statement about anything. The threshold")
        print("  above is a calibrated property of this pool and this")
        print("  estimator, and it is usable. THE VERDICT IS NOT. Nothing here")
        print("  says whether the corpus is converging, and a number quoted")
        print("  from this run as if it did would be an invention.")
        for x, y, o in pooled_obs:
            side = "inside the null band" if o >= thresh else "below the null band"
            print(f"    observed {x}->{y}: {o:.4f}  ({side})")
        print()
        print("  Read the single pair only as a BASELINE: generation 1 is")
        print("  generation 0 re-cut, so whatever it measures is the starting")
        print("  point of the trend, not the trend. Get to generation 4 and")
        print("  this section stops printing.")
        return

    tail = [o for _, _, o in pooled_obs[-MIN_PAIRS_FOR_TREND:]]
    rising = all(b >= a_ for a_, b in zip(tail, tail[1:]))
    in_band = all(o >= thresh for o in tail)
    print(f"  last {MIN_PAIRS_FOR_TREND} pooled similarities: "
          + ", ".join(f"{o:.4f}" for o in tail))
    if rising and in_band:
        print("  CONVERGED. Rising, and inside the band where the generation")
        print("  label carries no information.")
    else:
        why = " and ".join([w for w, ok in
                            [("not rising", rising), ("not in band", in_band)] if not ok])
        print(f"  NOT CONVERGED ({why}).")


if __name__ == "__main__":
    main()
