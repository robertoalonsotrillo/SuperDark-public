#!/usr/bin/env python3
"""Build a grain corpus that REMEMBERS WHERE IT CAME FROM.

WHAT WAS WRONG WITH THE OLD ONE
-------------------------------
build_grains.py cut fixed-length slices at RANDOM offsets, up to three per
track, and recorded nothing but five spectral descriptors per grain. No track
id, no position, no order. So:

  * the factory could never play two consecutive moments of the same music --
    not as a policy choice, but because the information did not exist;
  * every grain boundary was a hard cut to a different piece, in a different
    key, at a different tempo, five to ten times a second;
  * grains_600 is 600 x 0.5 s = 300 SECONDS of audio, three grains from each of
    ~200 tracks, drawn from a vetted corpus of 2,422 tracks and 20.2 hours.
    About 0.4% of the available material.

Roberto, hearing it: "rapid concatenative transitions, like a broken radio
shifting among FM frequencies, not too much variance, nor sustained sections,
nothing harmonic or tonal, nothing structurally coherent." All five follow from
the construction. The sources are tonal; interleaving unrelated half-seconds of
them at 5-10 Hz destroys that, and no amount of work in the factory can put it
back.

WHAT THIS DOES INSTEAD
----------------------
Cuts each track as a RUN of consecutive slices -- by default 24 in a row, which
is 12 seconds of continuous music -- and records (track, seq) for every grain.
The factory then has a choice it has never had: play seq+1 from the same track
and keep line, harmony and tempo intact, or cut to another track deliberately,
as a gesture. That is the difference between concatenative synthesis and
shuffling.

Runs start at a random position in the track, so this is not just "the first
twelve seconds of everything".

manifest.json carries track, seq and run_id per grain. Nothing downstream is
forced to use it: descriptors.json keeps its existing shape, so the old path
logic still works unchanged and the two corpora can be compared by ear.
"""
import argparse
import json
import os
import random
import subprocess
import sys
import wave

import numpy as np

SR = 22050


def decode(path, sr=SR):
    try:
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le",
             "-acodec", "pcm_f32le", "-ac", "2", "-ar", str(sr), "-"],
            capture_output=True, timeout=120).stdout
    except Exception:
        return None
    a = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    if len(a) < sr * 8:
        return None
    return a.reshape(-1, 2)


def write_grain(path, a, sr, fade_ms=5.0):
    k = max(1, int(sr * fade_ms / 1000.0))
    ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, k))
    a = a.copy()
    a[:k] *= ramp[:, None]
    a[-k:] *= ramp[::-1][:, None]
    # ATTENUATE, DO NOT CLIP -- see build_grains_onset.py for the full note. A
    # bare clip here put hard clipping into every corpus these builders made:
    # 55,910 pinned samples and 3,360 flat-topped runs in grains_lic_macro
    # alone. FMA is MP3 and MP3 decodes exceed +/-1.0 on intersample peaks.
    peak = float(np.abs(a).max())
    if peak > 0.999:
        a = a * (0.999 / peak)
    q = np.clip(a * 2 ** 31, -2 ** 31, 2 ** 31 - 1).astype("<i4")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(4)
        w.setframerate(sr)
        w.writeframes(q.tobytes())


def descriptors(mono, sr):
    S = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    fr = np.fft.rfftfreq(len(mono), 1 / sr)
    tot = max(1e-20, S.sum())
    cent = float((S * fr).sum() / tot)
    flat = float(np.exp(np.log(S + 1e-20).mean()) / (S.mean() + 1e-20))
    c = np.cumsum(S) / tot
    # a silent grain has a flat cumulative sum that never reaches 0.5, so
    # searchsorted returns len(fr) and indexing throws. Clamp.
    med = float(fr[min(np.searchsorted(c, 0.5), len(fr) - 1)])
    rms = float(np.sqrt((mono ** 2).mean()))
    zcr = float(((mono[:-1] * mono[1:]) < 0).mean())
    return [cent, flat, med, rms, zcr]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ids", required=True, help="vetted track ids, one per line")
    p.add_argument("--audio", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--grain", type=float, default=0.5)
    p.add_argument("--run-len", type=int, default=24,
                   help="consecutive slices per track (24 x 0.5 s = 12 s)")
    p.add_argument("--tracks", type=int, default=250)
    p.add_argument("--seed", type=int, default=20260823)
    a = p.parse_args()

    ids = [int(x.strip()) for x in open(a.ids) if x.strip().isdigit()]
    rng = random.Random(a.seed)
    rng.shuffle(ids)
    os.makedirs(a.out, exist_ok=True)

    n = int(a.grain * SR)
    manifest, desc, made, used = [], [], 0, 0

    for tid in ids:
        if used >= a.tracks:
            break
        path = os.path.join(a.audio, f"{tid // 1000:03d}", f"{tid:06d}.mp3")
        if not os.path.exists(path):
            continue
        x = decode(path)
        if x is None or len(x) < n * (a.run_len + 2):
            continue
        # a run starting somewhere other than the top of the track
        span = n * a.run_len
        start = rng.randrange(0, len(x) - span)
        for s in range(a.run_len):
            seg = x[start + s * n: start + (s + 1) * n]
            if len(seg) < n:
                break
            gp = os.path.join(a.out, f"g{made:02d}.wav")
            write_grain(gp, seg, SR)
            manifest.append({"i": made, "track": tid, "seq": s, "run": used})
            desc.append(descriptors(seg.mean(axis=1), SR))
            made += 1
        used += 1
        if used % 25 == 0:
            print(f"  {used} tracks, {made} grains", flush=True)

    D = np.array(desc)
    lo, hi = D.min(axis=0), D.max(axis=0)
    # rank-normalise, same convention as analyse_grains.py
    norm = np.zeros_like(D)
    for j in range(D.shape[1]):
        order = D[:, j].argsort()
        norm[order, j] = np.linspace(0, 1, len(D))

    keys = ["centroid", "flatness", "median", "rms", "zcr"]
    json.dump({
        "_comment": "Descriptors for a corpus cut as CONSECUTIVE runs per track. "
                    "Same shape as the old descriptors.json so existing path "
                    "logic works unchanged.",
        "_keys": keys,
        "index": list(range(made)),
        # COLUMNAR, keyed by descriptor name: the factory indexes
        # desc["norm"][key][grain]. Writing rows here cost a run.
        "norm": {k: norm[:, j].round(5).tolist() for j, k in enumerate(keys)},
        "raw_ranges": {k: [float(lo[j]), float(hi[j])] for j, k in enumerate(keys)},
    }, open(os.path.join(a.out, "descriptors.json"), "w"))

    json.dump({
        "_comment": "Provenance and adjacency. seq is the grain's position "
                    "within a consecutive run from one track, so grain i and "
                    "grain i+1 with the same track and seq+1 are ACTUALLY "
                    "consecutive audio. This is what lets the factory continue "
                    "a phrase instead of cutting to unrelated material on every "
                    "event.",
        "grain_seconds": a.grain,
        "run_len": a.run_len,
        "tracks": used,
        "grains": made,
        "total_seconds": round(made * a.grain, 1),
        "manifest": manifest,
    }, open(os.path.join(a.out, "manifest.json"), "w"))

    print(f"\n{made} grains from {used} tracks -> {a.out}")
    print(f"  {made * a.grain / 60:.1f} minutes of audio, "
          f"runs of {a.run_len} x {a.grain}s = {a.run_len * a.grain:.0f}s continuous")


if __name__ == "__main__":
    main()
