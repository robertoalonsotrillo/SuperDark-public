#!/usr/bin/env python3
"""
E3: perceptual similarity to real music, plus density traversal.

Why the rungs below it failed.
  E0  three time-averaged spectral scalars. Run 14: shaped noise 54.68 against
      the best musical output 32.05. The proxy fails before optimisation exists.
  E1  E0 plus four one-sided temporal FLOORS. Claim 100: the floors never fire on
      real output (zero penalty on 31 of 39 renders, 100% of Archon renders), so
      among genuine music E1 ranks exactly as E0 does. It is a guard, not a
      measure. Claim 121: because sparsity is a floor, a render that is 92%
      silent passes perfectly, which is how a 26% pattern failure went unseen by
      four evaluators and was caught by a composer in one listen.
  E2  MERT cosine to a single reference. Discriminates (claim 116) but the
      reference was a VOICE recording scored by a MUSIC model, and its own rank
      is 1.0 by construction (claim 119).

E3 fixes all three: no stipulated spectral targets anywhere, a music reference
set instead of one voice file, and a structural term that is two-sided in the
way the brief actually asks for.

TWO DESIGN DECISIONS, STATED BECAUSE BOTH ARE WHERE E1 WENT WRONG.

1. Nearest reference, not the centroid. The reference set is multi-modal:
   corelli sits at mean density 0.82, Sun at 0.05. Their centroid is a target no
   real music occupies, and inventing an unoccupied target is exactly how E1's
   flatness target of 0.15 came to penalise the very recording it was meant to
   represent (measured 0.2158, run 26). Distance to the NEAREST reference lets
   several aesthetics count as musical without forcing output to their average.

2. The traversal term encodes ROBERTO'S COMMISSION and is labelled as such:
   "we still need silence but it should be generated non-linearly, we should be
   able to move from continuous sound to silence to fragmentary intersections."
   It is NOT a universal property of music. Sun and Moon are legitimate music
   with span 0.52 and two regimes, and they score poorly on it. That is correct
   and intended. The failure mode of E1 was forgetting which of its numbers were
   stipulated; this one is stipulated and says so.

Usage:  score_e3.py <wav> [--refs refs.npz]   -> JSON on stdout
Env:    E3_REFS   path to the reference embedding npz (default /tmp/mert_reference.npz)
        E3_WM     musicality weight (default 0.5)
        E3_WT     traversal weight  (default 0.5)
"""
import json
import os
import sys
import warnings

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

warnings.filterwarnings("ignore")

MODEL = "m-a-p/MERT-v1-95M"
SR = 24000
CHUNK = SR * 5
LAYER = 0            # chosen empirically in run 27: layers 0-7 separate, 8-12 do not
FRAME, HOP = 2048, 512
WIN_S, WIN_HOP_S = 1.0, 0.25
SPARSE, DENSE = 0.25, 0.60
FLICKER_S = 0.25     # runs shorter than this are twitch, not composed silence
# Cosine band measured across references, renders and attacks, not stipulated:
# attacks bottom out near 0.79 and real music tops out near 0.96, so the useful
# range is narrow. The first version normalised over 0.60-0.95 and saturated
# most of the corpus at 1.000, hiding every distinction among musical material.
MUS_LO, MUS_HI = 0.79, 0.96


def load(path, target_sr=None):
    rate, data = wavfile.read(path)
    x = data.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.issubdtype(data.dtype, np.integer):
        x = x / float(np.iinfo(data.dtype).max)
    if target_sr and rate != target_sr:
        from math import gcd
        g = gcd(int(rate), target_sr)
        x = resample_poly(x, target_sr // g, rate // g)
        rate = target_sr
    return rate, x


def musicality(path, refs):
    """Max cosine to any reference, in MERT layer 0. Nearest, not average."""
    from transformers import AutoModel, Wav2Vec2FeatureExtractor
    import torch
    model = AutoModel.from_pretrained(MODEL, trust_remote_code=True).eval()
    proc = Wav2Vec2FeatureExtractor.from_pretrained(MODEL, trust_remote_code=True)

    _, x = load(path, SR)
    peak = np.abs(x).max()
    if peak > 0:
        x = x / peak
    chunks = [x[i:i + CHUNK] for i in range(0, len(x), CHUNK)]
    chunks = [c for c in chunks if len(c) >= SR // 2]
    if not chunks:
        return 0.0, None
    acc = []
    for c in chunks:
        inp = proc(c.astype(np.float32), sampling_rate=SR, return_tensors="pt")
        with torch.no_grad():
            out = model(**inp, output_hidden_states=True)
        h = torch.stack(out.hidden_states).squeeze()
        acc.append(h.mean(dim=-2).numpy())
    vec = np.mean(acc, axis=0)[LAYER]

    best, who = -1.0, None
    for name, ref in refs.items():
        r = ref[LAYER]
        c = float(vec @ r / (np.linalg.norm(vec) * np.linalg.norm(r)))
        if c > best:
            best, who = c, os.path.basename(name)
    return best, who


def traversal(path):
    """Does the density curve move between regimes, and hold when it gets there?"""
    rate, x = load(path)
    frames = [x[i:i + FRAME] for i in range(0, max(1, len(x) - FRAME), HOP)]
    if len(frames) < 8:
        return 0.0, {}
    rms = np.array([np.sqrt((f ** 2).mean()) for f in frames])
    peak = np.abs(x).max() + 1e-12
    active = rms > peak * 0.05

    per_win = max(2, int(WIN_S * rate / HOP))
    step = max(1, int(WIN_HOP_S * rate / HOP))
    density = np.array([active[i:i + per_win].mean()
                        for i in range(0, max(1, len(active) - per_win), step)])
    if len(density) < 4:
        return 0.0, {}

    regime = np.where(density < SPARSE, 0, np.where(density > DENSE, 2, 1))
    runs, cur, n = [], regime[0], 1
    for r in regime[1:]:
        if r == cur:
            n += 1
        else:
            runs.append(n)
            cur, n = r, 1
    runs.append(n)
    median_run = float(np.median(runs)) * WIN_HOP_S

    span = float(density.max() - density.min())
    n_regimes = len(set(regime.tolist()))
    # held, not twitching. Full credit once runs reach FLICKER_S.
    hold = min(1.0, median_run / FLICKER_S)

    # OCCUPANCY, not just visits. The first version of this scored
    # sciarrino-unregistered at 77.5, a file Roberto describes as silent: 92%
    # silence with occasional blips still TOUCHES three regimes with held runs
    # and so scored as rich traversal. That is E1's sparsity floor all over
    # again, wearing a structural costume. Time spent in each regime is what the
    # brief asks for, so balance is measured with the entropy of occupancy and
    # a piece parked in one regime cannot score well however often it leaves.
    occupancy = np.array([(regime == k).mean() for k in range(3)])
    nz = occupancy[occupancy > 0]
    balance = float(-(nz * np.log2(nz)).sum() / np.log2(3))

    score = span * balance * hold
    detail = dict(span=round(span, 3), regimes=int(n_regimes),
                  balance=round(balance, 3),
                  occupancy=[round(float(o), 3) for o in occupancy],
                  median_run_s=round(median_run, 2), hold=round(hold, 3),
                  mean_density=round(float(density.mean()), 3))
    return float(np.clip(score, 0.0, 1.0)), detail


def main():
    path = sys.argv[1]
    refs_path = os.environ.get("E3_REFS", "/tmp/mert_reference.npz")
    wm = float(os.environ.get("E3_WM", 0.5))
    wt = float(os.environ.get("E3_WT", 0.5))

    refs = dict(np.load(refs_path).items())
    m, who = musicality(path, refs)
    t, detail = traversal(path)

    # musicality is a cosine; real music sits high and noise low, so rescale the
    # band that actually occurs rather than the full [-1, 1] the metric allows.
    m_norm = float(np.clip((m - MUS_LO) / (MUS_HI - MUS_LO), 0.0, 1.0))
    score = 100.0 * (wm * m_norm + wt * t)

    print(json.dumps({
        "file": path,
        "rung": "E3",
        "score": round(score, 3),
        "musicality": {"cosine": round(m, 4), "normalised": round(m_norm, 4),
                       "nearest_reference": who, "weight": wm},
        "traversal": {"value": round(t, 4), "weight": wt, **detail},
    }, indent=2))


if __name__ == "__main__":
    main()
