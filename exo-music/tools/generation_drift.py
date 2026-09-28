#!/usr/bin/env python3
"""The pre-registered test: does the self-ingesting corpus converge?

THE TARGET WAS FIXED BEFORE ANY OF THIS WAS BUILT
-------------------------------------------------
Runs 12-13 measured the closed loop directly. With per-generation
normalisation, the noise-seeded condition CONVERGED BY GENERATION 4:
consecutive-generation spectral similarity 0.936, rising to 0.958. The target
recorded at the time, for a system with memory:

    keep consecutive-generation spectral similarity BELOW 0.9
    for TWENTY generations.

A system that does that has broken the attractor. A system that does not has
reproduced the pathology at a higher level. Either way the number is not
negotiable after the fact, which is the entire point of having written it down
first: this project's record on constants chosen after seeing the data is poor
-- nine hypotheses were proposed and killed by measurement on 21 August alone,
and every stipulated constant (the two-sided sparsity floor, E1's temporal
floors, E3's traversal term, the flatness target, the discretize length of 128)
turned out wrong.

WHY THIS IS THE RIGHT MEASUREMENT AND NOT A PROXY
-------------------------------------------------
Self-ingestion is iterated resynthesis: generation n+1 is granulated from a
recording of generation n sounding. Iterated resynthesis has an attractor. The
question is not whether the material changes -- it always does -- but whether
consecutive generations become MORE ALIKE, which is what convergence onto an
attractor looks like from the outside.

The related failure already happened once at a different level. Runs 53-58: a
self-generated criterion (the audibility score) became a convergence engine --
what sounded got weighted up, got selected more, kept sounding -- and the
vocabulary fell from nine machines to four. Nothing in that system's own
scoring could report it. This measurement exists so that the corpus-level
version cannot hide the same way.

    python3 tools/generation_drift.py --ring <ring root>
"""
import argparse
import glob
import json
import os
import wave

import numpy as np

TARGET = 0.9
TARGET_GENS = 20
NFFT = 1024


def read_grain(p):
    with wave.open(p) as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i4")
        sr = w.getframerate()
    return raw.reshape(-1, 2).astype(np.float32).mean(1) / (2 ** 31 - 1), sr


def mean_spectrum(paths, nfft=NFFT):
    """Mean log-magnitude spectrum over a cohort, on a fixed frequency grid.

    A fixed grid matters: the layers have different grain lengths (0.060,
    0.400, 2.000 s), so their native FFT resolutions differ by a factor of 33.
    Comparing cohorts without resampling onto a common grid would measure the
    layer mix rather than the material.
    """
    acc, n = np.zeros(nfft // 2 + 1), 0
    for p in paths:
        try:
            x, _ = read_grain(p)
        except Exception:
            continue
        if len(x) < 32:
            continue
        # Welch-ish: average |FFT| over as many nfft-blocks as the grain holds,
        # zero-padding when the grain is shorter than one block.
        if len(x) < nfft:
            x = np.pad(x, (0, nfft - len(x)))
        w = np.hanning(nfft)
        blocks, i = [], 0
        while i + nfft <= len(x):
            blocks.append(np.abs(np.fft.rfft(x[i:i + nfft] * w)))
            i += nfft // 2
        if not blocks:
            continue
        acc += np.log(np.mean(blocks, axis=0) + 1e-10)
        n += 1
    return (acc / n) if n else None, n


def cohorts(ring):
    """Grains grouped by (generation, LAYER).

    Grouping by generation alone is wrong and would have reported an artefact
    as a finding. The generation-0 working copy is 2400/1800/1200 across
    ev/mid/macro -- 44/33/22 percent -- while an ingested generation takes 40 of
    each, 33/33/33. The layers differ enormously in spectral character, since a
    0.060 s grain and a 2 s grain are not the same kind of object, so a
    similarity computed over the pooled mixture partly measures the CHANGING
    PROPORTIONS rather than the material. Comparing within a layer removes that
    confound; the layers are then aggregated for the verdict.
    """
    out = {}
    for d in sorted(glob.glob(os.path.join(ring, "grains_pool_*"))):
        layer = os.path.basename(d).split("_")[-1]
        mp = os.path.join(d, "manifest.json")
        if not os.path.exists(mp):
            continue
        try:
            m = json.load(open(mp))
        except (OSError, ValueError):
            continue
        for e in m.get("manifest", []):
            p = os.path.join(d, e.get("file", ""))
            if os.path.exists(p):
                out.setdefault((int(np.floor(e.get("gen", 0))), layer), []).append(p)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ring", required=True)
    ap.add_argument("--min-grains", type=int, default=12,
                    help="cohorts smaller than this are too noisy to compare")
    a = ap.parse_args()

    coh = cohorts(a.ring)
    if not coh:
        raise SystemExit("  no grains found in the ring")

    layers = sorted({l for _, l in coh})
    gens_all = sorted({g for g, _ in coh})
    print(f"  ring: {a.ring}")
    print(f"  {'gen':>5} " + " ".join(f"{l:>8}" for l in layers))
    for g in gens_all:
        print(f"  {g:>5} " + " ".join(f"{len(coh.get((g, l), [])):>8}" for l in layers))

    usable = [g for g in gens_all
              if any(len(coh.get((g, l), [])) >= a.min_grains for l in layers)]
    if len(usable) < 2:
        print()
        print("  FEWER THAN TWO COMPARABLE GENERATIONS. The test cannot run yet.")
        print("  This is the expected state at self_ingest_weight = 0: with the")
        print("  loop OPEN, the factory never hears its own grains, so every")
        print("  ingested grain is generation 1 and no second generation is ever")
        print("  produced. Raising the weight is what starts the experiment --")
        print("  it is not a setting to leave alone, it IS the independent")
        print("  variable. Raise it, then run this again.")
        return

    print()
    print("  mean log-magnitude spectrum per generation, WITHIN LAYER, cosine")
    print("  similarity between CONSECUTIVE generations:")
    print()
    print(f"  {'pair':>10} " + " ".join(f"{l:>9}" for l in layers) + f" {'mean':>9}   verdict")

    spectra = {}
    for (g, l), paths in coh.items():
        if len(paths) >= a.min_grains:
            s, _ = mean_spectrum(paths)
            if s is not None:
                spectra[(g, l)] = s

    gens = sorted({g for g, _ in spectra})
    sims, breached = [], None
    for x, y in zip(gens, gens[1:]):
        per = {}
        for l in layers:
            u, v = spectra.get((x, l)), spectra.get((y, l))
            if u is None or v is None:
                continue
            u = u - u.mean()
            v = v - v.mean()
            per[l] = float(u @ v / (np.linalg.norm(u) * np.linalg.norm(v) + 1e-12))
        if not per:
            continue
        mean_sim = float(np.mean(list(per.values())))
        sims.append((x, y, mean_sim))
        bad = mean_sim >= TARGET
        if bad and breached is None:
            breached = y
        cells = " ".join(f"{per[l]:>9.4f}" if l in per else f"{'-':>9}" for l in layers)
        print(f"  {f'{x}->{y}':>10} {cells} {mean_sim:>9.4f}   "
              f"{'CONVERGING (>= 0.9)' if bad else 'ok'}")

    print()
    n_ok = len(sims)
    print(f"  PRE-REGISTERED TARGET: similarity < {TARGET} for {TARGET_GENS} generations.")

    if n_ok < 3:
        print()
        print(f"  BASELINE ONLY -- {n_ok} consecutive pair(s). THIS IS NOT A")
        print("  CONVERGENCE TEST AND MUST NOT BE REPORTED AS ONE.")
        print()
        print("  Generation 1 is granulated from a recording of generation 0")
        print("  SOUNDING, so it is generation-0 material re-cut. A high")
        print("  similarity at the first step is definitional, not evidence of an")
        print("  attractor. Convergence is a similarity that RISES across")
        print("  successive generations, and a single pair has no trend in it.")
        print()
        print("  Two things to settle before the threshold means anything here:")
        print(f"    1. Raise self_ingest_weight. At 0 the loop is open and there")
        print("       is never a generation 2, so the test cannot run at all.")
        print(f"    2. Check this metric against the runs 12-13 code before")
        print(f"       treating {TARGET} as the same number. Those runs used")
        print("       per-generation normalisation; if the first step here")
        print(f"       already measures {sims[0][2]:.3f}, either the measures are")
        print(f"       not commensurable or {TARGET} was always breached at step")
        print("       one, and neither has been established.")
        return

    if breached is not None:
        print(f"  BREACHED at generation {breached}.")
        print(f"  For comparison, runs 12-13 (noise-seeded, no memory) converged")
        print(f"  by generation 4 at 0.936. Convergence at or before that is the")
        print(f"  same pathology; later is a weaker version of it; not at all")
        print(f"  within {TARGET_GENS} generations is the target met.")
    elif max(g for g in gens) >= TARGET_GENS:
        print(f"  MET: {n_ok} consecutive pairs all below {TARGET}, reaching "
              f"generation {max(gens)}.")
        print("  The attractor is broken. That is the result the target was set for.")
    else:
        print(f"  NOT YET DECIDABLE: {n_ok} pairs measured, all below {TARGET}, "
              f"but only reaching generation {max(gens)} of {TARGET_GENS}.")
        print("  Keep running. A target met early is not met.")


if __name__ == "__main__":
    main()
