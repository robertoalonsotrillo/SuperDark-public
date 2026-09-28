#!/usr/bin/env python3
"""Freeze the descriptor basis, then project new grains into it.

WHY THE BASIS MUST BE FROZEN
----------------------------
Self-ingestion replaces grains in the pool. Every replacement needs descriptors,
because the factory's whole selection mechanism -- target, neighbourhood,
nearest, grainPath -- reads descriptors.json and indexes it by grain number.

The tempting shortcut is to re-run analyse_mfcc.py over the pool after each
ingestion. THAT WOULD BE WRONG, and quietly so. analyse_mfcc.py derives the
standardisation and the PCA rotation FROM THE CORPUS IT IS GIVEN. Re-deriving
them from a corpus that self-ingestion is actively changing makes the descriptor
space non-stationary: the axes rotate under the factory between windows, "the
same" grain acquires different coordinates over time, and the generation-drift
measurement compares cohorts that were never in the same space. The corpus would
appear to move even if nothing about the material changed.

So the basis is frozen once, from the generation-0 archive, and every later grain
is projected into it. The space stops being a description of the current corpus
and becomes a fixed coordinate system that the corpus moves around in -- which is
the only arrangement in which "the corpus drifted" is a statement about the
material rather than about the measurement.

WHAT THE BASIS HAS TO CONTAIN, AND WHAT WAS MISSING
---------------------------------------------------
descriptors.json already stores `_pca_mean`, `_pca_scale` and `_pca_components`,
"so the transform is reproducible and auditable". Two things needed to place a
new grain on the SAME 0..1 axes are not stored:

  pca lo/hi   analyse_mfcc.py scales each component by its own min and max over
              the corpus (linear, deliberately not rank-normalised, so distances
              within an axis survive). Those bounds are consumed and discarded.
  pitch/      these are NOT linearly scaled. build_grains_onset.py:192-194
  clarity     rank-normalises them -- norm[D[:,j].argsort(), j] = linspace(0,1)
              -- so a value's coordinate is its RANK in the corpus, and placing a
              new grain requires the empirical distribution, not a range.

Both are recovered here from the archive audio and written into the basis.

VALIDATION IS NOT OPTIONAL
--------------------------
This file reproduces a transform that already ran. If the reproduction is even
slightly off, nothing errors -- a permuted or mis-scaled descriptor array is
still an array of plausible numbers. That exact failure has already cost this
project weeks: descriptors.json was written in lexicographic order while the
factory read it numerically, 2,389 of 2,400 grains carried another grain's
descriptors, and the space correlated with the truth at -0.07 to -0.24. Nothing
complained.

So `freeze` recomputes the coordinates of every archive grain and CHECKS THEM
AGAINST THE STORED ONES, and refuses to write a basis that does not reproduce
them. The functions are imported from analyse_mfcc.py and build_grains_onset.py
rather than reimplemented, so the arithmetic is identical by construction.

    python3 tools/descriptor_basis.py freeze  --dir CORPUS --out basis.json
    python3 tools/descriptor_basis.py project --basis basis.json --grain G.wav
"""
import argparse
import json
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse_mfcc as AM                      # noqa: E402
import build_grains_onset as BGO               # noqa: E402

PITCH_WINDOW_S = 0.2      # BGO.analyse bounds pitch to 0.2 s; np.correlate is O(n^2)


def numeric_wavs(d):
    return sorted((f for f in os.listdir(d) if f.endswith(".wav")),
                  key=lambda f: int(re.match(r"g(\d+)\.wav$", f).group(1)))


def raw_features(path):
    """MFCC statistics, pitch and clarity for one grain, using the ORIGINAL
    functions rather than a second implementation of them."""
    mono, sr = AM.read_mono(path)
    fb = AM.mel_filterbank(sr, AM.FFT, AM.N_MEL)
    x = AM.mfcc_stats(mono, sr, fb)
    p, clar = BGO.pitch_of(mono[: int(PITCH_WINDOW_S * sr)], sr)
    return x, p, clar


def freeze(corpus, out, tol=0.02):
    dpath = os.path.join(corpus, "descriptors.json")
    if not os.path.exists(dpath):
        raise SystemExit(f"  {dpath} missing; cannot freeze a basis without it")
    d = json.load(open(dpath))
    mu = np.array(d["_pca_mean"], float)
    sd = np.array(d["_pca_scale"], float)
    comp = np.array(d["_pca_components"], float)

    # ZERO SCALES ARE REAL AND MUST NOT DIVIDE.
    #
    # 12 of the 24 entries in _pca_scale are exactly 0.0 for the ev corpus. An ev
    # grain is 0.060 s = 1323 samples and mfcc_stats uses a 1024-sample window at
    # hop 512, so exactly ONE frame fits and F.std(axis=0) is identically zero
    # across all 12 std features. analyse_mfcc.py writes sd.round(6), and
    # max(1e-9, std) rounds to 0.0 at six decimals.
    #
    # Dividing by that produced NaN across every component and the validation
    # caught it. Those columns carry no information -- the numerator is zero
    # there too -- so dividing by 1 leaves them at zero and contributes nothing,
    # which is the correct behaviour rather than a patch over it.
    #
    # Worth stating plainly: for the ev layer HALF the descriptor space is
    # constant, so its timbral description is mean-only with no
    # temporal-variation term. That is a property of the corpus, not of this
    # file.
    dead = sd <= 0
    if dead.any():
        print(f"  {int(dead.sum())} of {len(sd)} scale entries are zero "
              f"(constant features); they contribute nothing and are not divided by")
    sd = np.where(dead, 1.0, sd)

    files = numeric_wavs(corpus)
    print(f"  {corpus}: recomputing {len(files)} grains against the stored basis ...")
    X, P, C = [], [], []
    for i, f in enumerate(files):
        x, p, c = raw_features(os.path.join(corpus, f))
        X.append(x); P.append(p); C.append(c)
        if (i + 1) % 500 == 0:
            print(f"    {i+1}/{len(files)}", flush=True)
    X = np.array(X); P = np.array(P, float); C = np.array(C, float)

    Y = ((X - mu) / sd) @ comp.T
    lo, hi = Y.min(axis=0), Y.max(axis=0)
    Yn = (Y - lo) / np.maximum(1e-9, hi - lo)

    # --- validation against what the factory is actually reading -------------
    ok = True
    for j in range(comp.shape[0]):
        k = f"pc{j}"
        if k not in d.get("norm", {}):
            continue
        stored = np.array(d["norm"][k], float)
        if len(stored) != len(Yn):
            print(f"    {k}: LENGTH MISMATCH {len(stored)} vs {len(Yn)}")
            ok = False
            continue
        err = float(np.abs(stored - Yn[:, j]).mean())
        r = float(np.corrcoef(stored, Yn[:, j])[0, 1])
        flag = "ok" if (err < tol and r > 0.999) else "MISMATCH"
        if flag != "ok":
            ok = False
        print(f"    {k}: mean|diff| {err:.5f}   r {r:.6f}   {flag}")

    # pitch/clarity are RANK-normalised, so validate the rank mapping, not values
    for name, raw in (("pitch", P), ("clarity", C)):
        if name not in d.get("norm", {}):
            continue
        stored = np.array(d["norm"][name], float)
        if len(stored) != len(raw):
            continue
        rank = np.zeros(len(raw))
        rank[np.argsort(raw)] = np.linspace(0, 1, len(raw))
        r = float(np.corrcoef(stored, rank)[0, 1])
        # Looser than the PCA axes, and for a reason that is not sloppiness.
        # build_grains_onset.py computes pitch on the RAW slice and only then
        # calls write_grain, which applies a 3 ms fade. The stored pitch
        # therefore describes unfaded audio, while anything recomputed from the
        # written file describes faded audio. The two cannot agree exactly, and
        # a threshold that demanded they did would be demanding a falsehood.
        lim = 0.95
        print(f"    {name}: rank r {r:.6f}   "
              f"{'ok' if r > lim else 'MISMATCH'}"
              f"   (fade applied after analysis; exact agreement impossible)")
        if r <= lim:
            ok = False

    if not ok:
        raise SystemExit(
            "\n  REFUSING TO WRITE THE BASIS.\n"
            "  The recomputation does not reproduce the descriptors the factory\n"
            "  is reading, so projecting new grains through it would place them\n"
            "  in a different space from the corpus they join -- silently, since\n"
            "  wrong descriptors are still plausible numbers. Resolve the\n"
            "  mismatch before self-ingestion touches descriptors.json.")

    basis = {
        "_comment": "FROZEN descriptor basis, derived from the generation-0 "
                    "archive and never re-derived. New grains are PROJECTED "
                    "into it so the descriptor space stays stationary while the "
                    "corpus changes underneath it.",
        "source": os.path.abspath(corpus),
        "keys": d["_keys"],
        "pca_mean": mu.tolist(), "pca_scale": sd.tolist(),
        "pca_components": comp.tolist(),
        "pca_lo": lo.tolist(), "pca_hi": hi.tolist(),
        # sorted raw values ARE the empirical distribution; a new grain's
        # coordinate is where it falls in them
        "pitch_sorted": np.sort(P).tolist(),
        "clarity_sorted": np.sort(C).tolist(),
        "n": len(files),
    }
    json.dump(basis, open(out, "w"))
    print(f"\n  basis validated and written -> {out}")
    print(f"  {len(files)} grains, {comp.shape[0]} PCA dims + pitch, clarity")


def load_basis(p):
    b = json.load(open(p))
    for k in ("pca_mean", "pca_scale", "pca_components", "pca_lo", "pca_hi",
              "pitch_sorted", "clarity_sorted"):
        b[k] = np.array(b[k], float)
    return b


def project(basis, path=None, feats=None):
    """Coordinates for one grain in the FROZEN space.

    Returns (dict of key -> 0..1, n_clipped). Out-of-range values are clipped:
    the factory draws targets in 0.15..0.85 and assumes a bounded space, so a
    grain outside it would distort every neighbourhood that reached for it. The
    CLIP COUNT is returned rather than swallowed -- grains landing outside the
    generation-0 range are the corpus leaving the space it was measured in, and
    that is a drift signal worth having.
    """
    if feats is None:
        feats = raw_features(path)
    x, p, c = feats
    y = ((np.asarray(x, float) - basis["pca_mean"]) / basis["pca_scale"]) @ \
        basis["pca_components"].T
    yn = (y - basis["pca_lo"]) / np.maximum(1e-9, basis["pca_hi"] - basis["pca_lo"])
    clipped = int((yn < 0).sum() + (yn > 1).sum())
    yn = np.clip(yn, 0.0, 1.0)

    out = {f"pc{j}": float(round(v, 5)) for j, v in enumerate(yn)}
    for name, val, arr in (("pitch", p, basis["pitch_sorted"]),
                           ("clarity", c, basis["clarity_sorted"])):
        # rank-normalise against the frozen empirical distribution, matching
        # build_grains_onset.py's argsort/linspace convention
        out[name] = float(round(
            np.searchsorted(arr, val) / max(1, len(arr) - 1), 5))
        out[name] = min(1.0, max(0.0, out[name]))
    return out, clipped


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("freeze")
    f.add_argument("--dir", required=True)
    f.add_argument("--out", required=True)
    pr = sub.add_parser("project")
    pr.add_argument("--basis", required=True)
    pr.add_argument("--grain", required=True)
    a = ap.parse_args()

    if a.cmd == "freeze":
        freeze(a.dir, a.out)
    else:
        v, clipped = project(load_basis(a.basis), a.grain)
        print(json.dumps(v, indent=1))
        print(f"  clipped axes: {clipped}")


if __name__ == "__main__":
    main()
