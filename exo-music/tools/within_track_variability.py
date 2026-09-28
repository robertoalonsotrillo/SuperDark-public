#!/usr/bin/env python3
"""Claim 182: is classical and experimental material actually more variable?

Roberto, 2026-08-21:

  "we should probably add extra classical music as that is where the greatest
   variability in content will be found (particularly experimental music), all
   the other genres are much more formulaic"

Plausible, and unmeasured. This project's record on unmeasured assumptions is
poor: the two-sided sparsity floor, E1's temporal floors, E3's traversal term
and the flatness target were each stipulated and each wrong, and five more
hypotheses died to measurement on 2026-08-21 alone.

The claim is about variability WITHIN a track, not across a genre. Two genres
can span the same range while every individual track in one of them holds
still. Archon grains a track and traverses the grains, so within-track
variability is the property that matters for the corpus.

Measured as: MERT-v1-95M layer 0, 1 s windows, mean cosine DISTANCE between
all pairs of windows inside each track. Layer 0 because run 27 chose it
empirically. High distance means the track goes somewhere.

  python3 within_track_variability.py --meta META --audio AUDIO \\
      --per-genre 200 --out variability.csv
"""
import argparse, ast, csv, os, random, subprocess, sys
import numpy as np

SR = 24000
WIN_S = 1.0


def load_audio(path, sr=SR, max_s=30.0):
    """Decode with ffmpeg to mono float32 at sr."""
    try:
        r = subprocess.run(
            ['ffmpeg', '-v', 'error', '-i', path, '-t', str(max_s),
             '-f', 'f32le', '-acodec', 'pcm_f32le', '-ac', '1',
             '-ar', str(sr), '-'],
            capture_output=True, timeout=60)
        x = np.frombuffer(r.stdout, dtype=np.float32)
        return x if len(x) > sr else None
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--picks', required=True)
    ap.add_argument('--audio', required=True)
    ap.add_argument('--per-genre', type=int, default=200)
    ap.add_argument('--out', required=True)
    ap.add_argument('--seed', type=int, default=20260821)
    a = ap.parse_args()

    import torch
    from transformers import AutoModel, Wav2Vec2FeatureExtractor

    # picks.csv is 'id,genre', built on the host where pandas is available.
    # The container image has torch and transformers but no pandas.
    picks = {}
    with open(a.picks) as f:
        r = csv.DictReader(f)
        for row in r:
            picks.setdefault(row['genre'], []).append(int(row['id']))
    print({g: len(v) for g, v in picks.items()}, flush=True)

    print('loading MERT', flush=True)
    model = AutoModel.from_pretrained('m-a-p/MERT-v1-95M',
                                      trust_remote_code=True).eval()
    fe = Wav2Vec2FeatureExtractor.from_pretrained('m-a-p/MERT-v1-95M',
                                                  trust_remote_code=True)

    rows = []
    for g, ids in picks.items():
        for tid in ids:
            p = os.path.join(a.audio, f'{tid // 1000:03d}', f'{tid:06d}.mp3')
            if not os.path.exists(p):
                continue
            x = load_audio(p)
            if x is None:
                continue
            # Chunked forward passes. One pass over the whole 30 s means
            # attention over ~2250 frames, which is quadratic and slower on
            # CPU than several short passes; one pass per 1 s window pays the
            # conv-encoder overhead thirty times. 5 s chunks sit between.
            CH = 5.0
            n = int(SR * CH)
            E = []
            with torch.no_grad():
                for c in range(len(x) // n):
                    seg = x[c * n:(c + 1) * n]
                    inp = fe(seg, sampling_rate=SR, return_tensors='pt')
                    H = model(**inp, output_hidden_states=True).hidden_states[0][0]
                    k = max(1, int(round(H.shape[0] / CH * WIN_S)))
                    nwc = H.shape[0] // k
                    if nwc:
                        E.append(H[:nwc * k].reshape(nwc, k, -1).mean(1).numpy())
            if not E:
                continue
            E = np.concatenate(E, 0)
            if len(E) < 4:
                continue
            E = E / (np.linalg.norm(E, axis=1, keepdims=True) + 1e-12)
            C = E @ E.T
            iu = np.triu_indices(len(E), 1)
            rows.append(dict(id=tid, genre=g, windows=len(E),
                             variability=float(1.0 - C[iu].mean())))
            if len(rows) % 25 == 0:
                print(f'    ... {len(rows)} tracks', flush=True)
        done = [r for r in rows if r['genre'] == g]
        if done:
            v = np.array([r['variability'] for r in done])
            print(f'  {g:18s} n={len(v):4d}  mean {v.mean():.4f}  sd {v.std():.4f}',
                  flush=True)

    with open(a.out, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['id', 'genre', 'windows', 'variability'])
        w.writeheader()
        w.writerows(rows)

    print('\n=== within-track variability by genre, high means the track moves')
    agg = {}
    for r in rows:
        agg.setdefault(r['genre'], []).append(r['variability'])
    for g, v in sorted(agg.items(), key=lambda kv: -np.mean(kv[1])):
        v = np.array(v)
        se = v.std(ddof=1) / np.sqrt(len(v)) if len(v) > 1 else float('nan')
        print(f'  {g:18s} n={len(v):4d}  {v.mean():.4f} +/- {se:.4f}')


if __name__ == '__main__':
    main()
