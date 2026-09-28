#!/usr/bin/env python3
"""Re-analyse an existing grain corpus the way a concatenative system should.

WHAT WAS WRONG
--------------
The descriptor space was five hand-picked scalars -- centroid, flatness,
median, rms, zcr -- rank-normalised, searched by linear scan. Three problems,
all of them standard practice to avoid:

  1. Those scalars describe the spectrum very coarsely. Two grains can share a
     centroid and a flatness and sound nothing alike, so "nearest neighbour"
     regularly returns something unrelated. Roberto: "we sometimes get random
     concatenation again."

  2. Rank-normalisation flattens each axis to a uniform distribution, which
     destroys the actual distances within it. Two grains a hair apart in a dense
     region get pushed as far apart as two in a sparse one.

  3. No dimensionality reduction, so correlated descriptors double-count. rms and
     zcr are not independent of centroid, and the metric silently weights
     whatever happens to have the most variance.

WHAT THIS DOES
--------------
The FluCoMa pipeline, which is the established practice for exactly this:

    onset-aligned slice
      -> MFCC statistics per grain          (timbre, properly described)
      -> STANDARDISE                        (zero mean, unit variance per axis)
      -> PCA to a handful of dimensions     (decorrelated, variance-ordered)
      -> nearest neighbour in that space

MFCCs are the standard timbral description: a mel filterbank, log, then a DCT,
so the first coefficients capture spectral shape and the rest fine structure.
Coefficient 0 is overall loudness and is DROPPED -- otherwise the metric becomes
a loudness metric, which is the mistake that made grain neighbourhoods into
volume clusters earlier in this project.

Pitch and pitch-clarity are carried through unchanged from the existing
analysis, because pitch is not recoverable from MFCCs and it is the axis
harmonic coherence lives on.

Writes descriptors.json in place, keeping the same shape the factory already
reads, plus the PCA basis so the transform is reproducible and auditable.
"""
import argparse
import json
import os
import re
import wave

import numpy as np

N_MEL = 40
N_MFCC = 13
FFT = 1024


def mel_filterbank(sr, n_fft, n_mel):
    def hz_to_mel(f):
        return 2595.0 * np.log10(1.0 + f / 700.0)

    def mel_to_hz(m):
        return 700.0 * (10 ** (m / 2595.0) - 1.0)

    lo, hi = hz_to_mel(20.0), hz_to_mel(sr / 2.0)
    pts = mel_to_hz(np.linspace(lo, hi, n_mel + 2))
    bins = np.floor((n_fft + 1) * pts / sr).astype(int)
    fb = np.zeros((n_mel, n_fft // 2 + 1))
    for m in range(1, n_mel + 1):
        a, b, c = bins[m - 1], bins[m], bins[m + 1]
        if b == a:
            b = a + 1
        if c == b:
            c = b + 1
        if c >= fb.shape[1]:
            c = fb.shape[1] - 1
        if b >= c or a >= b:
            continue
        fb[m - 1, a:b] = (np.arange(a, b) - a) / (b - a)
        fb[m - 1, b:c] = (c - np.arange(b, c)) / (c - b)
    return fb


def mfcc_stats(mono, sr, fb):
    """Mean and standard deviation of each MFCC across the grain. The std is what
    tells a steady tone from one that moves, which a single mean cannot."""
    n = min(FFT, len(mono))
    hop = max(1, n // 2)
    frames = []
    for i in range(0, max(1, len(mono) - n + 1), hop):
        seg = mono[i:i + n]
        if len(seg) < n:
            break
        S = np.abs(np.fft.rfft(seg * np.hanning(n))) ** 2
        if S.shape[0] != fb.shape[1]:
            f2 = mel_filterbank(sr, n, N_MEL)
            e = f2 @ S
        else:
            e = fb @ S
        e = np.log(e + 1e-10)
        # DCT-II, the MFCC step
        k = np.arange(N_MFCC)[:, None]
        j = np.arange(len(e))[None, :]
        frames.append((e[None, :] * np.cos(np.pi * k * (2 * j + 1) / (2 * len(e)))).sum(axis=1))
    if not frames:
        return np.zeros(2 * (N_MFCC - 1))
    F = np.array(frames)[:, 1:]          # DROP coefficient 0: it is loudness
    return np.concatenate([F.mean(axis=0), F.std(axis=0)])


def read_mono(path):
    with wave.open(path) as w:
        sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    dt = "<i4" if sw == 4 else "<i2"
    sc = 2 ** 31 if sw == 4 else 2 ** 15
    a = np.frombuffer(raw, dtype=dt).astype(np.float64) / sc
    return a.reshape(-1, ch).mean(axis=1), sr


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    p.add_argument("--dims", type=int, default=5)
    a = p.parse_args()

    # NUMERIC ORDER, NOT LEXICOGRAPHIC.
    #
    # This line used to be `sorted(...)`. The grains are written g{n:02d}.wav,
    # padded only two wide, so lexicographically `g10.wav` is followed by
    # `g100.wav` and the order diverges from the numeric one at position 11 and
    # never recovers. Everything else in the system is numeric --
    # build_grains_onset.py:182 writes g{made:02d}.wav, manifest.json has
    # i == position, live_factory.scd:663 loads g{i:02d}.wav -- so the descriptor
    # file was the only thing in a different order, and 2,389 of 2,400 grains
    # carried another grain's descriptors.
    #
    # Nothing raised an error, because a permuted array is still an array of
    # plausible numbers. Measured 25 Aug 2026: the factory's descriptor space
    # correlated with the true one at -0.07 to -0.24 across the five components,
    # i.e. it was noise, and every nearest-neighbour lookup was effectively
    # random. `continuity` was unaffected and kept working because it reads the
    # manifest, which is why provenance was the only channel carrying anything.
    #
    # Same failure class as the five inherited constants and the 24 kHz
    # transport: wrong input, no complaint, output that looks like data.
    files = sorted((f for f in os.listdir(a.dir) if f.endswith(".wav")),
                   key=lambda f: int(re.match(r"g(\d+)\.wav$", f).group(1)))
    old = json.load(open(os.path.join(a.dir, "descriptors.json")))

    fb, sr0 = None, None
    X = []
    for i, f in enumerate(files):
        mono, sr = read_mono(os.path.join(a.dir, f))
        if fb is None or sr != sr0:
            fb, sr0 = mel_filterbank(sr, FFT, N_MEL), sr
        X.append(mfcc_stats(mono, sr, fb))
        if (i + 1) % 400 == 0:
            print(f"  {i + 1}/{len(files)}", flush=True)
    X = np.array(X)

    # STANDARDISE: zero mean, unit variance. Without this, PCA follows whichever
    # coefficient happens to have the largest raw range.
    mu, sd = X.mean(axis=0), np.maximum(1e-9, X.std(axis=0))
    Z = (X - mu) / sd

    # PCA by SVD, keeping the leading dims. Components are decorrelated and
    # ordered by variance explained, so distance in this space is not
    # double-counting correlated descriptors.
    U, S, Vt = np.linalg.svd(Z - Z.mean(axis=0), full_matrices=False)
    comp = Vt[: a.dims]
    Y = Z @ comp.T
    var = (S ** 2 / (S ** 2).sum())[: a.dims]

    # scale each component to 0..1 by its own range -- linear, so distances
    # WITHIN an axis are preserved, unlike rank-normalisation
    lo, hi = Y.min(axis=0), Y.max(axis=0)
    Yn = (Y - lo) / np.maximum(1e-9, hi - lo)

    # STATE THE ORDERING CONVENTION IN THE FILE.
    #
    # For weeks descriptors.json was written in lexicographic order while the
    # factory read it numerically, so 2,389 of 2,400 grains carried another
    # grain's descriptors and the space correlated with the truth at -0.07.
    # Nothing said which convention a file used, so a correct file and a broken
    # one were indistinguishable without re-deriving the whole transform. That
    # is the property worth fixing, not just the sort order.
    order_note = ("numeric: entry i belongs to g{i}.wav, matching "
                  "live_factory.scd:663, manifest.json and "
                  "build_grains_onset.py. Written by analyse_mfcc.py, which "
                  "sorts by the integer in the filename, NOT lexicographically "
                  "-- g10.wav must not be followed by g100.wav.")

    keys = [f"pc{i}" for i in range(a.dims)]
    norm = {k: Yn[:, i].round(5).tolist() for i, k in enumerate(keys)}
    # pitch is not recoverable from MFCCs and is the axis harmony lives on
    for carried in ("pitch", "clarity"):
        if carried in old.get("norm", {}):
            norm[carried] = old["norm"][carried]
            keys.append(carried)

    json.dump({
        "_order": order_note,
        "_comment": "MFCC statistics -> standardised -> PCA. Coefficient 0 dropped "
                    "so the metric is timbral rather than loudness-driven. Scaling "
                    "is linear per component, NOT rank-normalised, so distances "
                    "within an axis survive. pitch and clarity carried through "
                    "from the onset analysis.",
        "_keys": keys,
        "_variance_explained": var.round(4).tolist(),
        "_pca_mean": mu.round(6).tolist(),
        "_pca_scale": sd.round(6).tolist(),
        "_pca_components": comp.round(6).tolist(),
        "index": list(range(len(files))),
        "norm": norm,
        # CARRIED FOR THE SAME REASON pitch IS, and it has to be carried HERE or
        # it is lost: this step rewrites descriptors.json wholesale, so a key
        # present in the onset analysis and absent from this dict disappears at
        # the PCA stage without anything failing. `norm.pitch` is a rank, and
        # the ratio of two ranks is not an interval; raw_hz is the only column
        # from which an interval can be computed.
        **({"raw_hz": old["raw_hz"]} if "raw_hz" in old else {}),
    }, open(os.path.join(a.dir, "descriptors.json"), "w"))
    if "raw_hz" not in old:
        print("  NOTE: no raw_hz in the source descriptors. This corpus predates "
              "the Hz column; rebuild it with build_grains_onset.py before "
              "anything downstream tries to compute an interval.")

    print(f"\n{len(files)} grains -> {a.dims} PCA dims + pitch, clarity")
    print(f"  variance explained: {', '.join(f'{v:.1%}' for v in var)}"
          f"   total {var.sum():.1%}")


if __name__ == "__main__":
    main()
