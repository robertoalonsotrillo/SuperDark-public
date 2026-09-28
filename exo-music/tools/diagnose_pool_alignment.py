#!/usr/bin/env python3
"""Is the pool's descriptor error confined to ADMITTED grains?

WHY THE QUESTION IS NOT THE SAME AS "IS THE POOL ALIGNED"
verify_alignment.py demands Spearman > 0.999 and the pool returns 0.95-0.98.
That threshold was written for a FRESHLY BUILT corpus, where descriptors and
audio come from one code path and any disagreement is a bug. The pool is
different: generation-0 slots were written by the corpus builder, while
admitted slots were described through the FROZEN BASIS, a deliberately
different path that projects new audio into fixed coordinates and clips to the
stored range. Exact agreement there is not expected and never was --
descriptor_basis.py already accepts pitch at rank r 0.96 for the same reason,
noting "fade applied after analysis; exact agreement impossible".

So a pool-wide 0.97 is uninformative on its own. It is consistent with two very
different situations:

  BENIGN   generation-0 slots agree exactly, admitted slots agree approximately.
           The frozen basis is doing its job with some quantisation error.
  SERIOUS  generation-0 slots ALSO disagree, which would mean the descriptor
           file no longer lines up with the audio -- the 2,389-of-2,400
           permutation, and a reason to stop everything.

Splitting the correlation by generation separates them. Nothing else does.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse_mfcc import mel_filterbank, mfcc_stats, read_mono, N_MEL, FFT  # noqa: E402
from world_listen import load_transform                                     # noqa: E402
from scipy.stats import spearmanr                                           # noqa: E402

POOL = "/Volumes/FMA/superdark/self_corpus"


def rho_for(G, ids, mu, sc, C, norm, fb_holder):
    if len(ids) < 8:
        return None
    mine = []
    for i in ids:
        m, sr = read_mono(os.path.join(G, f"g{i:02d}.wav"))
        if fb_holder[0] is None:
            fb_holder[0] = mel_filterbank(sr, FFT, N_MEL)
        mine.append(C @ ((mfcc_stats(m, sr, fb_holder[0]) - mu) / sc))
    mine = np.array(mine)
    return min(spearmanr(mine[:, k], [norm[f"pc{k}"][i] for i in ids]).correlation
               for k in range(5))


def main():
    print()
    print("  descriptor agreement, split by how the slot was described")
    print(f"  {'layer':8} {'gen-0 slots':>14} {'admitted slots':>16}   reading")
    print("  " + "-" * 68)
    worst_seed = 1.0
    for layer in ("ev", "mid", "macro"):
        G = os.path.join(POOL, f"grains_pool_{layer}")
        d = json.load(open(os.path.join(G, "descriptors.json")))
        mu, sc, C = load_transform(os.path.join(G, "descriptors.json"))
        norm = d["norm"]
        man = {int(e["i"]): float(e.get("gen", 0.0))
               for e in json.load(open(os.path.join(G, "manifest.json")))["manifest"]}
        n = len(d["index"])
        seed = [i for i in range(n) if man.get(i, 0.0) == 0.0][:40]
        adm = [i for i in range(n) if man.get(i, 0.0) > 0.0][:40]
        fb = [None]
        rs = rho_for(G, seed, mu, sc, C, norm, fb)
        ra = rho_for(G, adm, mu, sc, C, norm, fb)
        if rs is not None:
            worst_seed = min(worst_seed, rs)
        # Three outcomes, not two. The seed test rules out the permutation; it
        # says nothing about whether admitted grains are described WELL. First
        # run: seed 1.00000 with admitted at 0.50 on ev -- no permutation, and
        # coordinates far too weak to navigate by.
        if rs is None or rs <= 0.999:
            verdict = "SERIOUS: seed slots disagree -- permutation"
        elif ra is None:
            verdict = "seed clean; no admitted grains yet"
        elif ra > 0.95:
            verdict = "clean: basis describes new grains well"
        else:
            verdict = f"seed clean, but admitted coords WEAK ({ra:.2f})"
        print(f"  {layer:8} {('n/a' if rs is None else f'{rs:+.5f}'):>14} "
              f"{('n/a' if ra is None else f'{ra:+.5f}'):>16}   {verdict}")

    print()
    if worst_seed > 0.999:
        print("  Generation-0 slots agree exactly, so descriptors and audio are")
        print("  correctly paired and this is NOT the permutation failure.")
        print("  verify_alignment's 0.999 is the wrong gate for a pool.")
        print()
        print("  But a weak admitted-slot figure is its own problem, and a")
        print("  different one. The factory selects grains by nearest neighbour")
        print("  in descriptor space, so a self-ingested grain with coordinates")
        print("  that only loosely track its sound is reachable by accident and")
        print("  unreachable on purpose. Running the loop on that measures the")
        print("  approximation as much as the music.")
    else:
        print("  Generation-0 slots DISAGREE. Descriptors no longer describe the")
        print("  audio beside them. Stop the factory and rebuild the pool.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
