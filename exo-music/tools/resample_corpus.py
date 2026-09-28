#!/usr/bin/env python3
"""Resample a grain corpus to the server's sample rate so PlayBuf never interpolates.

THE FAULT THIS REMOVES
The corpus was 22050 Hz and scsynth runs at 44100, so every grain played through
BufRateScale at rate 0.5 and SuperCollider filled in the missing samples by
interpolation. Interpolation is upsampling with a very short kernel, and short
kernels leave IMAGES of the signal above the original Nyquist. Measured on the
bisection ladder, identical grains and identical code, only the rate changed:

    energy above 11.025 kHz    22050 corpus  5.725e-04
                               44100 corpus  2.796e-05      20.5x, 13.1 dB
    broadband transients >12k  22050 corpus  13 in 21 s
                               44100 corpus   7 in 21 s
    worst local anomaly (R2)   22050 corpus  394.1
                               44100 corpus   18.7

The spectrogram shows it plainly: at 22050 the whole band to 22 kHz is lit on
every grain, where the material by definition has nothing at all.

WHY THE MUSIC DOES NOT CHANGE
The grains stay band-limited to 11.025 kHz. Resampling to 44100 adds no
content; it only stores the same signal on a grid the server does not have to
interpolate onto. Re-decoding the source MP3s at 44100 WOULD add a real top
octave and change the music, and that is a separate decision, deliberately not
taken here.

resample_poly, not linear interpolation. Using a short kernel here would
manufacture the artefact being removed, which is a mistake this codebase has
already made twice (bisect_report.build_r0, and PlayBuf itself).

  python3 resample_corpus.py --src DIR --out DIR [--sr 44100]
"""
import argparse
import glob
import json
import os
import shutil
import sys
import wave

import numpy as np
from scipy.signal import resample_poly


def read(path):
    with wave.open(path, "rb") as w:
        sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    if sw != 4:
        raise ValueError(f"{path}: expected 32-bit, got {sw*8}-bit")
    a = np.frombuffer(raw, "<i4").astype(np.float64) / 2 ** 31
    return a.reshape(-1, ch), sr


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--sr", type=int, default=44100)
    a = p.parse_args()

    files = sorted(glob.glob(os.path.join(a.src, "g*.wav")),
                   key=lambda f: int("".join(c for c in os.path.basename(f) if c.isdigit())))
    if not files:
        print(f"  no grains in {a.src}", file=sys.stderr)
        return 1
    os.makedirs(a.out, exist_ok=True)

    n_over, done, src_sr = 0, 0, None
    for f in files:
        x, sr = read(f)
        src_sr = src_sr or sr
        if sr != a.sr:
            g = np.gcd(int(sr), int(a.sr))
            x = np.stack([resample_poly(x[:, c], a.sr // g, sr // g)
                          for c in range(x.shape[1])], axis=1)
        # A band-limited resample overshoots slightly at transients: the
        # reconstructed waveform passes through the original samples but can
        # exceed them between. Attenuate rather than clip, for the same reason
        # the builders do.
        peak = float(np.abs(x).max())
        if peak > 0.999:
            x = x * (0.999 / peak)
            n_over += 1
        q = np.clip(x * 2 ** 31, -2 ** 31, 2 ** 31 - 1).astype("<i4")
        with wave.open(os.path.join(a.out, os.path.basename(f)), "wb") as w:
            w.setnchannels(x.shape[1]); w.setsampwidth(4); w.setframerate(a.sr)
            w.writeframes(q.tobytes())
        done += 1

    # manifest carries provenance and adjacency and is rate-independent; copy it
    # so continuity and the self-ingest lineage survive the resample.
    for side in ("manifest.json",):
        s = os.path.join(a.src, side)
        if os.path.exists(s):
            shutil.copyfile(s, os.path.join(a.out, side))

    # descriptors are NOT copied. Several are in Hz (centroid, rolloff, median)
    # and the analysis must be re-run at the new rate; copying them would
    # reintroduce exactly the descriptor/audio mismatch that verify_alignment.py
    # exists to catch.
    d = os.path.join(a.out, "descriptors.json")
    if os.path.exists(d):
        os.remove(d)

    print(f"  {done} grains {src_sr} -> {a.sr} Hz  ->  {a.out}")
    print(f"    {n_over} attenuated for resampling overshoot")
    print(f"    descriptors NOT copied; re-run analyse_mfcc.py on the new dir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
