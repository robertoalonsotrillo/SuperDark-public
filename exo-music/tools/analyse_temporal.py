#!/usr/bin/env python3
"""Measure the TEMPORAL structure of FMA tracks, and cluster it into regimes.

WHY THIS EXISTS
---------------
Every analysis in this project so far is spectral and per-grain: centroid,
flatness, median, rms, zcr, computed over 0.5 s. Nothing in the pipeline can
see a structure longer than one grain, so nothing about how the corpus behaves
IN TIME has ever reached the factory. Grain analysis feeds selection -- which
grain plays next -- and stops there.

Behaviour lives in the part that was never measured. A machine is a pattern of
durations, envelopes and filter trajectories over seconds, and in Archon every
one of those numbers is a constant somebody typed. Three of them have already
turned out to be wrong for this corpus: `discretize(128)`, `~sampleSize = 1.0`
against 0.5 s grains, and filter envelopes sweeping to 25740 Hz over material
whose 99% rolloff is 2335 Hz.

So this measures three things per track, all of them over seconds:

  IOI          inter-onset intervals, from spectral-flux onset detection.
               How the music is SPACED. Becomes \\dur.
  attack shape rise time and decay time around each onset, median per track.
               Whether energy ARRIVES or SWELLS. Becomes \\atk and \\rel, which
               are currently derived from ~sampleSize, a constant that was
               wrong by a factor of two.
  flux drift   how far the spectral centroid travels over a 4 s window.
               Whether a passage HOLDS STILL or MOVES. Becomes the filter
               envelope, currently hard-coded per machine.

Tracks are then clustered on those features (k-means, k from the caller) and
each cluster is a temporal REGIME: a way music behaves in time, measured rather
than composed. derive_machines.py turns each regime into a runtime machine.

WHAT THIS IS NOT. It is not learning, and it should not be described as such.
It is measurement plus k-means. I chose the three features and the number of
clusters, so the derivation still terminates in my inputs (P113). What it does
change is that the NUMBERS inside the resulting machines come from the corpus
instead of from a person, and can be checked against it.
"""
import argparse
import json
import os
import random
import subprocess
import sys

import numpy as np

SR = 22050
HOP = 512


def decode(path, seconds=30):
    try:
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-t", str(seconds), "-f", "f32le",
             "-acodec", "pcm_f32le", "-ac", "1", "-ar", str(SR), "-"],
            capture_output=True, timeout=90).stdout
    except Exception:
        return None
    a = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    return a if len(a) > SR * 5 else None


def spectral_flux(a):
    """Onset strength: positive change in magnitude spectrum, frame to frame."""
    n = 1024
    frames = 1 + (len(a) - n) // HOP
    if frames < 8:
        return None, None
    win = np.hanning(n)
    S = np.abs(np.fft.rfft(np.lib.stride_tricks.as_strided(
        a, (frames, n), (a.strides[0] * HOP, a.strides[0])) * win, axis=1))
    diff = np.diff(S, axis=0)
    flux = np.maximum(diff, 0).sum(axis=1)
    cent = (S * np.fft.rfftfreq(n, 1 / SR)).sum(axis=1) / np.maximum(1e-12, S.sum(axis=1))
    return flux, cent


def pick_onsets(flux):
    """Peaks above a local adaptive threshold. Deliberately simple and stated:
    a median filter plus a fixed multiplier, not a tuned detector."""
    if flux is None or len(flux) < 16:
        return np.array([])
    k = 9
    pad = np.pad(flux, (k // 2, k // 2), mode="edge")
    local = np.array([np.median(pad[i:i + k]) for i in range(len(flux))])
    thresh = local + 0.6 * np.std(flux)
    peaks = [i for i in range(1, len(flux) - 1)
             if flux[i] > thresh[i] and flux[i] >= flux[i - 1] and flux[i] > flux[i + 1]]
    return np.array(peaks)


def features(path):
    a = decode(path)
    if a is None:
        return None
    flux, cent = spectral_flux(a)
    if flux is None:
        return None
    on = pick_onsets(flux)
    if len(on) < 6:
        return None

    ioi = np.diff(on) * HOP / SR
    ioi = ioi[(ioi > 0.02) & (ioi < 4.0)]
    if len(ioi) < 4:
        return None

    # attack and decay around each onset, in frames -> seconds
    rises, falls = [], []
    for i in on[:200]:
        lo = max(0, i - 12)
        hi = min(len(flux), i + 40)
        seg = flux[lo:hi]
        pk = int(np.argmax(seg))
        pre = seg[:pk + 1]
        post = seg[pk:]
        if len(pre) > 1:
            r = np.argmax(pre >= pre.max() * 0.5)
            rises.append((pk - r) * HOP / SR)
        if len(post) > 1:
            below = np.where(post <= post.max() * 0.37)[0]
            falls.append((below[0] if len(below) else len(post)) * HOP / SR)

    # how far the centroid travels over 4 s windows
    w = int(4 * SR / HOP)
    drift = []
    for s in range(0, max(1, len(cent) - w), w):
        seg = cent[s:s + w]
        if len(seg) > 4 and seg.mean() > 0:
            drift.append(float(np.std(seg) / seg.mean()))

    return {
        "ioi_median": float(np.median(ioi)),
        "ioi_spread": float(np.percentile(ioi, 75) - np.percentile(ioi, 25)),
        "ioi_fastest": float(np.percentile(ioi, 10)),
        "rise": float(np.median(rises)) if rises else 0.01,
        "fall": float(np.median(falls)) if falls else 0.2,
        "drift": float(np.median(drift)) if drift else 0.0,
        "density": float(len(on) / (len(flux) * HOP / SR)),
    }


def kmeans(X, k, iters=60, seed=20260823):
    rng = np.random.default_rng(seed)
    C = X[rng.choice(len(X), k, replace=False)].copy()
    for _ in range(iters):
        d = ((X[:, None, :] - C[None, :, :]) ** 2).sum(axis=2)
        lab = d.argmin(axis=1)
        for j in range(k):
            if (lab == j).any():
                C[j] = X[lab == j].mean(axis=0)
    return lab, C


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--audio", required=True, help="fma audio root")
    p.add_argument("--tracks", type=int, default=300)
    p.add_argument("--clusters", type=int, default=5)
    p.add_argument("--out", default="temporal_regimes.json")
    a = p.parse_args()

    paths = []
    for root, _, fs in os.walk(a.audio):
        for f in fs:
            if f.endswith(".mp3"):
                paths.append(os.path.join(root, f))
    random.Random(20260823).shuffle(paths)
    paths = paths[: a.tracks * 2]

    rows, used = [], []
    for pth in paths:
        if len(rows) >= a.tracks:
            break
        f = features(pth)
        if f:
            rows.append(f)
            used.append(os.path.basename(pth))
        if len(rows) % 25 == 0 and rows:
            print(f"  {len(rows)} tracks analysed", flush=True)

    if len(rows) < a.clusters * 3:
        sys.exit(f"only {len(rows)} usable tracks")

    keys = ["ioi_median", "ioi_spread", "ioi_fastest", "rise", "fall", "drift", "density"]
    X = np.array([[r[k] for k in keys] for r in rows])
    # z-score so no feature dominates by unit alone
    mu, sd = X.mean(axis=0), np.maximum(1e-9, X.std(axis=0))
    lab, C = kmeans((X - mu) / sd, a.clusters)

    regimes = []
    for j in range(a.clusters):
        sel = X[lab == j]
        if len(sel) == 0:
            continue
        med = {k: float(np.median(sel[:, i])) for i, k in enumerate(keys)}
        med["n_tracks"] = int(len(sel))
        regimes.append(med)
    regimes.sort(key=lambda r: r["ioi_median"])

    out = {
        "_comment": "Temporal regimes measured from FMA audio, not composed. "
                    "IOI from spectral-flux onsets; rise/fall from the flux "
                    "envelope around each onset; drift is centroid variation "
                    "over 4 s windows. k-means over z-scored features. "
                    "derive_machines.py turns each regime into a runtime machine.",
        "_source": a.audio,
        "_tracks_analysed": len(rows),
        "_features": keys,
        "regimes": regimes,
    }
    json.dump(out, open(a.out, "w"), indent=2)
    print(f"\nwrote {a.out}: {len(regimes)} regimes from {len(rows)} tracks\n")
    print(f"  {'ioi_med':>8} {'spread':>8} {'fastest':>8} {'rise':>7} {'fall':>7} "
          f"{'drift':>7} {'dens':>6} {'n':>5}")
    for r in regimes:
        print(f"  {r['ioi_median']:8.3f} {r['ioi_spread']:8.3f} {r['ioi_fastest']:8.3f} "
              f"{r['rise']:7.3f} {r['fall']:7.3f} {r['drift']:7.3f} "
              f"{r['density']:6.2f} {r['n_tracks']:5d}")


if __name__ == "__main__":
    main()
