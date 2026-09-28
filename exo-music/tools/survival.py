#!/usr/bin/env python3
"""Transition survival: how much sounding material persists across boundaries.

Claim 187 says two results are explained by one quantity. Within the run-34
seven, fewer machine transitions predicted Roberto's preference at rho +0.674.
Between base90, parallel90 and parallel390 the machine schedule is IDENTICAL,
so transition count cannot explain his preference there, yet he preferred the
parallel render for "greater sustained coherence over time".

Both are cases of material surviving a boundary. Fewer transitions means fewer
boundaries; parallel voicing means the outgoing machine keeps sounding across
the boundary instead of being cut.

Measured WITHOUT transition times, because the behaviour file changed in run 39
and the old renders' schedules are no longer reproducible. Instead:

  survival = mean cosine similarity between consecutive spectral frames

A render whose material is cut has many large frame-to-frame discontinuities
and a low mean. A render whose material persists has a high mean. `cuts` is
the fraction of frames whose novelty exceeds the 90th percentile of a
white-noise reference, which is a scale-free way to count hard edges.

Deliberately a DESCRIPTOR and not a score. Per docs/15 and the argument in
run 38, making the evaluator agree with the composer tightens the governor's
cap; the gap between measure and ear is the finding, not the defect.
"""
import sys, os, wave
import numpy as np

FRAME, HOP = 2048, 512


def spectra(path):
    w = wave.open(path)
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    x = np.frombuffer(w.readframes(n), dtype='<i2').astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    win = np.hanning(FRAME)
    nf = 1 + (len(x) - FRAME) // HOP
    S = np.empty((nf, FRAME // 2 + 1))
    for i in range(nf):
        S[i] = np.abs(np.fft.rfft(x[i * HOP:i * HOP + FRAME] * win))
    return S, sr


def survival(path, floor_db=-60.0):
    S, sr = spectra(path)
    # keep only frames with audible energy; silence-to-silence is not a
    # transition and would otherwise dominate a sparse render
    e = S.sum(1)
    ref = e.max() if e.max() > 0 else 1.0
    live = e > ref * (10 ** (floor_db / 20))
    idx = np.where(live[:-1] & live[1:])[0]
    if len(idx) < 8:
        return dict(survival=float('nan'), cuts=float('nan'), live_pairs=len(idx))
    A, B = S[idx], S[idx + 1]
    num = (A * B).sum(1)
    den = np.linalg.norm(A, axis=1) * np.linalg.norm(B, axis=1) + 1e-12
    cos = num / den
    return dict(survival=float(cos.mean()),
                cuts=float((cos < 0.5).mean()),
                live_pairs=int(len(idx)))


if __name__ == '__main__':
    files = sys.argv[1:]
    print(f"{'file':18s}{'survival':>10}{'cuts':>8}{'frames':>9}")
    for f in files:
        if not os.path.exists(f):
            print(f'{os.path.basename(f):18s}  MISSING')
            continue
        r = survival(f)
        print(f"{os.path.basename(f)[:-4]:18s}{r['survival']:10.4f}"
              f"{r['cuts']:8.3f}{r['live_pairs']:9d}")
