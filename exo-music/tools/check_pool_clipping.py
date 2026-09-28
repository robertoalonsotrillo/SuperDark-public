#!/usr/bin/env python3
"""How much of the pool's descriptor space is CLIPPED, and does that explain it?

THE CORRECTION THIS MAKES
I first read the weak admitted-slot correlation (0.50 on ev) as self_ingest
describing new grains from a cheaper feature set than the factory navigates by.
That was wrong: descriptor_basis.raw_features calls AM.mfcc_stats, the very
function analyse_mfcc uses. The feature vector is identical.

The real candidate is project(), which min-max normalises into the FROZEN
generation-0 range and then CLIPS to [0,1]. Clipping is rank-destroying: every
grain past the edge is written as exactly 0.0 or exactly 1.0, so a Spearman
correlation over a set containing many clipped values collapses toward zero
even when the underlying coordinates are perfectly good.

If that is what is happening, the number is not a bug report. It is the drift
signal descriptor_basis.py already names: "grains landing outside the
generation-0 range are the corpus leaving the space it was measured in". The
factory's own output occupying descriptor space the FMA corpus never reached is
a RESULT, and one the proposal wants.

The two readings need separating before anything is changed:
  CLIPPING     admitted grains carry many exact 0.0 / 1.0 values. Coordinates
               are right; the space is too small; widen it or record the clip
               rate as the finding.
  BAD CODING   few clipped values and still weak correlation. Then the
               projection really is wrong and self_ingest needs fixing.
"""
import json
import os
import sys

import numpy as np

POOL = "/Volumes/FMA/superdark/self_corpus"
PCS = [f"pc{j}" for j in range(5)]


def main():
    print()
    print(f"  {'layer':8} {'slots':>7} {'admitted':>9} "
          f"{'clipped vals, gen-0':>21} {'clipped vals, admitted':>24}")
    print("  " + "-" * 76)
    tot_adm_clip, tot_adm_vals = 0, 0
    for layer in ("ev", "mid", "macro"):
        G = os.path.join(POOL, f"grains_pool_{layer}")
        d = json.load(open(os.path.join(G, "descriptors.json")))
        man = {int(e["i"]): float(e.get("gen", 0.0))
               for e in json.load(open(os.path.join(G, "manifest.json")))["manifest"]}
        n = len(d["index"])
        seed = [i for i in range(n) if man.get(i, 0.0) == 0.0]
        adm = [i for i in range(n) if man.get(i, 0.0) > 0.0]

        def clipfrac(ids):
            if not ids:
                return None, 0, 0
            vals = np.array([[float(d["norm"][k][i]) for k in PCS] for i in ids])
            hit = int(((vals <= 0.0) | (vals >= 1.0)).sum())
            return hit / vals.size, hit, vals.size

        fs, _, _ = clipfrac(seed)
        fa, ha, va = clipfrac(adm)
        tot_adm_clip += ha
        tot_adm_vals += va
        print(f"  {layer:8} {n:7d} {len(adm):9d} "
              f"{(f'{100*fs:.2f}%' if fs is not None else 'n/a'):>21} "
              f"{(f'{100*fa:.2f}%' if fa is not None else 'n/a'):>24}")

    print()
    overall = 100 * tot_adm_clip / max(tot_adm_vals, 1)
    print(f"  {overall:.2f}% of admitted grains' PCA coordinates sit on a clip edge")
    print()
    if overall > 15:
        print("  CLIPPING EXPLAINS IT. The coordinates are computed correctly and")
        print("  then flattened at the boundary, which is what wrecks the rank")
        print("  correlation. The factory's own output is landing outside the")
        print("  descriptor range the FMA corpus defined. That is a finding about")
        print("  the material, not a defect in the code, and the clip rate is the")
        print("  number to report.")
    else:
        print("  Clipping does NOT explain it. Too few values sit at the edge, so")
        print("  the projection itself is suspect and self_ingest needs the fix.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
