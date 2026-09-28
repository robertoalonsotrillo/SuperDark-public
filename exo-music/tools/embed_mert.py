#!/usr/bin/env python3
"""
MERT embedding front end for evaluator rung E2.

Why this exists: claim 100/101. E1's four temporal floors never fire on any real
output (zero penalty on 31 of 39 renders, and on 100% of Archon renders), so
among genuine music E1 reduces to E0's three time-averaged spectral scalars,
which run 14 showed prefer a featureless wash to every piece the system has made.
E1 is a guard, not a measure. Discrimination has to come from somewhere else.

MERT-v1-95M, 20K hours of music at 24 kHz (model card, verified 2026-08-20;
the 330M checkpoint is 160K hours but is CC BY-NC 4.0 and slower on CPU).
Output is 13 hidden states of 768 dims at 75 Hz.

The model card is explicit that "features extracted by different layers could
have various performance depending on tasks", so this script emits ALL layers
and the layer choice is made empirically by calibrate_e2.py against the same
degenerate references E0 and E1 were calibrated on. Picking a layer by intuition
is exactly the move that produced E1's inert floors.

Usage:  embed_mert.py <wav> [<wav> ...]   -> npz of {path: (13, 768)}
"""
import os
import sys
import warnings

import numpy as np
import torch
from scipy.io import wavfile
from scipy.signal import resample_poly

warnings.filterwarnings("ignore")

MODEL = "m-a-p/MERT-v1-95M"
SR = 24000
CHUNK = SR * 5          # the model's pre-train context is 5 s
MIN_CHUNK = SR // 2


def load_audio(path):
    """Mono, float32, resampled to 24 kHz."""
    rate, data = wavfile.read(path)
    x = data.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.issubdtype(data.dtype, np.integer):
        x = x / float(np.iinfo(data.dtype).max)
    if rate != SR:
        from math import gcd
        g = gcd(int(rate), SR)
        x = resample_poly(x, SR // g, rate // g)
    peak = np.abs(x).max()
    if peak > 0:
        x = x / peak          # level is not the object of study
    return x.astype(np.float32)


def embed(path, model, proc):
    """Mean over 5 s chunks of the per-layer time-averaged hidden states."""
    x = load_audio(path)
    # Reference pieces run to 49 minutes; embedding all of Sun.wav is 589 chunks
    # and hours of CPU for a descriptor that stabilises in a couple of minutes.
    limit = float(os.environ.get("MERT_LIMIT_S", "0"))
    if limit > 0:
        x = x[: int(limit * SR)]
    chunks = [x[i:i + CHUNK] for i in range(0, len(x), CHUNK)]
    chunks = [c for c in chunks if len(c) >= MIN_CHUNK]
    if not chunks:
        return None
    acc = []
    for c in chunks:
        inputs = proc(c, sampling_rate=SR, return_tensors="pt")
        with torch.no_grad():
            out = model(**inputs, output_hidden_states=True)
        h = torch.stack(out.hidden_states).squeeze()      # (13, T, 768)
        acc.append(h.mean(dim=-2).numpy())                # (13, 768)
    return np.mean(acc, axis=0)


def main():
    from transformers import AutoModel, Wav2Vec2FeatureExtractor
    model = AutoModel.from_pretrained(MODEL, trust_remote_code=True).eval()
    proc = Wav2Vec2FeatureExtractor.from_pretrained(MODEL, trust_remote_code=True)

    out = {}
    for path in sys.argv[1:]:
        vec = embed(path, model, proc)
        if vec is None:
            print(f"skip (too short) {path}", file=sys.stderr)
            continue
        out[path] = vec
        print(f"embedded {path} {vec.shape}", file=sys.stderr)
    dest = os.environ.get("MERT_OUT", "/tmp/mert_embeddings.npz")
    np.savez_compressed(dest, **out)
    print(dest)


if __name__ == "__main__":
    main()
