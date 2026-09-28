#!/usr/bin/env python3
"""Analyse every grain, so selection can be by proximity rather than by shuffle.

Roberto, listening to the live factory on 600 FMA grains: "I hear mostly
fragmentary sciarrino like material and the spectral coherence is not
sustained."

Checked against the code, and he is right in a way that names something never
built. All 22 machines choose grains with `Pshuf(buf, inf)` — a uniform random
draw over the WHOLE corpus. Consecutive grains come from unrelated tracks every
50 to 300 ms, so spectral coherence cannot be sustained: the mechanism that
would produce it does not exist. What the system does is granular playback with
a shuffle. Concatenative synthesis means selecting each unit by descriptor
proximity to a target, and nothing here has ever done that.

Five descriptors per grain, all cheap and all robust on 500 ms of audio:

  centroid   spectral centre of mass, the main perceptual brightness axis
  flatness   geometric over arithmetic mean; noise against tone
  median     frequency below which half the energy sits. This matches Archon's
             own `SpecPcile.kr(chain, 0.5)`, which is NOT the conventional 85%
             rolloff — the behaviour model has always read it as `avgrolloff`
  rms        level
  zcr        zero-crossing rate, cheap and complements flatness on transients

RANK-NORMALISED, not min-max. Each descriptor becomes its percentile within the
corpus, so the five-dimensional space is uniformly populated. That matters for
neighbourhood queries: a fixed radius then returns a comparable number of
grains everywhere, instead of thousands in one dense clump and none elsewhere.

  python3 analyse_grains.py --grains workdir_music/grains_600 \\
      --out workdir_music/grains_600/descriptors.json
"""
import argparse, json, os, wave
import numpy as np

FRAME = 2048


def read_grain(path):
    w = wave.open(path)
    n, ch, sw, sr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    dt = {1: np.int8, 2: '<i2', 4: '<i4'}[sw]
    x = np.frombuffer(raw, dtype=dt).astype(np.float64)
    x /= float(2 ** (8 * sw - 1))
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    return x, sr


def descriptors(x, sr):
    if len(x) < FRAME:
        x = np.pad(x, (0, FRAME - len(x)))
    win = np.hanning(FRAME)
    hop = FRAME // 2
    nf = max(1, 1 + (len(x) - FRAME) // hop)
    freqs = np.fft.rfftfreq(FRAME, 1.0 / sr)

    cent, flat, med = [], [], []
    for i in range(nf):
        seg = x[i * hop:i * hop + FRAME]
        if len(seg) < FRAME:
            seg = np.pad(seg, (0, FRAME - len(seg)))
        mag = np.abs(np.fft.rfft(seg * win)) + 1e-12
        s = mag.sum()
        cent.append(float((freqs * mag).sum() / s))
        # geometric over arithmetic mean
        flat.append(float(np.exp(np.log(mag).mean()) / mag.mean()))
        # frequency below which half the ENERGY sits, matching SpecPcile(0.5)
        c = np.cumsum(mag ** 2)
        med.append(float(freqs[np.searchsorted(c, c[-1] * 0.5)]))

    rms = float(np.sqrt((x ** 2).mean()))
    zcr = float((np.diff(np.signbit(x)) != 0).mean())
    return dict(centroid=float(np.mean(cent)), flatness=float(np.mean(flat)),
                median=float(np.mean(med)), rms=rms, zcr=zcr)


def rank_normalise(vals):
    """Percentile rank in [0,1]. Ties share the average rank."""
    a = np.asarray(vals, dtype=float)
    order = a.argsort()
    ranks = np.empty(len(a), dtype=float)
    ranks[order] = np.arange(len(a), dtype=float)
    # average ties so identical grains do not get arbitrary neighbours
    for v in np.unique(a):
        m = a == v
        if m.sum() > 1:
            ranks[m] = ranks[m].mean()
    return (ranks / max(1, len(a) - 1)).tolist()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--grains', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    files = sorted((f for f in os.listdir(a.grains) if f.endswith('.wav')),
                   key=lambda f: int(f[1:-4]))
    print(f'{len(files)} grains in {a.grains}', flush=True)

    raw, kept = [], []
    for i, f in enumerate(files):
        idx = int(f[1:-4])
        try:
            x, sr = read_grain(os.path.join(a.grains, f))
            raw.append(descriptors(x, sr))
            kept.append(idx)
        except Exception as e:
            print(f'  skip {f}: {e}')
        if (i + 1) % 500 == 0:
            print(f'  {i + 1}/{len(files)}', flush=True)

    keys = ['centroid', 'flatness', 'median', 'rms', 'zcr']
    norm = {k: rank_normalise([d[k] for d in raw]) for k in keys}

    doc = {
        '_comment': ('Per-grain descriptors, rank-normalised to [0,1] so the '
                     'space is uniformly populated and a fixed neighbourhood '
                     'radius behaves the same everywhere. Index is the grain '
                     'number, matching gNN.wav. Written by analyse_grains.py.'),
        '_keys': keys,
        'index': kept,
        'norm': {k: [round(v, 4) for v in norm[k]] for k in keys},
        'raw_ranges': {k: [round(min(d[k] for d in raw), 2),
                           round(max(d[k] for d in raw), 2)] for k in keys},
    }
    with open(a.out, 'w') as f:
        json.dump(doc, f)

    print(f'\n{len(kept)} analysed -> {a.out}')
    for k in keys:
        lo, hi = doc['raw_ranges'][k]
        print(f'  {k:9s} {lo:>12.2f} .. {hi:<12.2f}')


if __name__ == '__main__':
    main()
