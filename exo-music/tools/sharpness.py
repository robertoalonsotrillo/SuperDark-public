#!/usr/bin/env python3
"""Sharpness: the "extremely high-pitched material that hurts listening to".

Claim 163. Roberto reported it in run 34 and nothing in E0, E1, E2 or E3
penalises it: MERT's cosine is insensitive and the spectral scalars treat a
high centroid as neutral.

Three numbers, none of them invented here:

  sharpness  Zwicker's acum, the standard psychoacoustic measure of how
             piercing a sound is. Specific loudness across Bark bands,
             weighted by g(z) which is flat to 16 Bark and rises steeply
             above it, so energy above roughly 3 kHz dominates.
             Zwicker & Fastl, Psychoacoustics: Facts and Models, 3rd ed.

  hf_frac    fraction of total energy above 8 kHz. Blunt, but it is the
             quantity a mel filter bank would attenuate, which is what
             Roberto suggested.

  harsh      fraction of energy in 2-5 kHz, the region where the ear is most
             sensitive and where listening fatigue is generated. High
             sharpness with high harsh is the painful combination; high
             sharpness alone can just be air.

Reported per file and, more usefully, per machine, so the offenders can be
named rather than the whole render being filtered.
"""
import sys, os, wave
import numpy as np

FRAME, HOP = 2048, 512


def bark(f):
    """Traunmuller's analytic Bark scale."""
    return (26.81 * f) / (1960.0 + f) - 0.53


def g(z):
    """Zwicker's sharpness weighting: flat to 16 Bark, steep above."""
    return np.where(z < 16, 1.0, 0.066 * np.exp(0.171 * z))


def analyse(path):
    w = wave.open(path)
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    x = np.frombuffer(w.readframes(n), dtype='<i2').astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)

    win = np.hanning(FRAME)
    nf = 1 + (len(x) - FRAME) // HOP
    freqs = np.fft.rfftfreq(FRAME, 1.0 / sr)
    z = bark(freqs)
    gz = g(z)
    hf = freqs > 8000
    hz = (freqs >= 2000) & (freqs <= 5000)

    S = np.empty((nf, len(freqs)))
    for i in range(nf):
        S[i] = np.abs(np.fft.rfft(x[i * HOP:i * HOP + FRAME] * win)) ** 2

    e = S.sum(1)
    ref = e.max() if e.max() > 0 else 1.0
    live = e > ref * 1e-6            # ignore silence, it has no sharpness
    if live.sum() < 8:
        return None
    S, e = S[live], e[live]

    # specific loudness approximated by energy^0.23, Stevens' exponent
    N = S ** 0.23
    sharp = 0.11 * (N * gz * z).sum(1) / (N.sum(1) + 1e-12)
    return dict(sharpness=float(sharp.mean()),
                sharp_p95=float(np.percentile(sharp, 95)),
                hf_frac=float((S[:, hf].sum(1) / e).mean()),
                harsh=float((S[:, hz].sum(1) / e).mean()),
                live=int(live.sum()))


if __name__ == '__main__':
    print(f"{'file':16s}{'sharp':>8}{'p95':>8}{'hf>8k':>8}{'harsh':>8}")
    rows = []
    for f in sys.argv[1:]:
        if not os.path.exists(f):
            print(f'{os.path.basename(f):16s}  MISSING')
            continue
        r = analyse(f)
        if r is None:
            print(f'{os.path.basename(f)[:-4]:16s}  silent')
            continue
        rows.append((os.path.basename(f)[:-4], r))
    for name, r in sorted(rows, key=lambda kv: -kv[1]['sharpness']):
        print(f"{name:16s}{r['sharpness']:8.3f}{r['sharp_p95']:8.3f}"
              f"{r['hf_frac']:8.3f}{r['harsh']:8.3f}")
