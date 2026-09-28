#!/usr/bin/env python3
"""How far a render sits from the corpus it is made of: a proxy for charter
norm n5_new_in_kind (edition 8, 27 Sept 2026).

WHY. n5 says the vocabulary should grow in kind, not only in colour. Roberto's
listening of the twelve rung 2 renders (27 Sept) is the only judgement of it so
far. For the factory to PROPOSE anything about its own sources (B8 rung 3) it
needs its own reading of n5, and that reading is only worth using if it agrees
with the ear. This tool is that reading; calibrate it against the ear before it
steers anything.

WHAT. Frames of 2048 (hop 1024), only those above -60 dBFS. Per frame: log2
spectral centroid, spectral flatness, peakiness (share of power in the 8
strongest bins) and harmonicity (the highest normalised autocorrelation at a
period between 1 and 20 ms). A file is summarised by the median of each. The
corpus is summarised the same way over a sample of its grains; the distance is
the RMS of the render's robust z-scores (median / MAD) against the corpus.
No learned parameters.

  python3 tools/kind_distance.py FILE.wav [...] [--corpus DIR] [--n 300]
  python3 tools/kind_distance.py --selftest
"""
import argparse, glob, json, os, random, sys
import numpy as np
import scipy.io.wavfile as wavfile

FR, HOP, FLOOR_DB = 2048, 1024, -60.0
FEATS = ["log2_centroid", "flatness", "peakiness", "harmonicity"]


def load(path):
    sr, x = wavfile.read(path)
    x = x.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    peak = {np.dtype("int16"): 32768.0, np.dtype("int32"): 2147483648.0}
    kind = wavfile.read(path)[1].dtype
    x = x / peak.get(kind, 1.0)
    return sr, x


def frame_feats(sr, x):
    if len(x) < FR:
        x = np.pad(x, (0, FR - len(x)))
    win = np.hanning(FR)
    f = np.fft.rfftfreq(FR, 1 / sr)
    lo, hi = int(sr / 1000), int(sr / 50)
    out = []
    for i in range(0, len(x) - FR + 1, HOP):
        s = x[i:i + FR]
        rms = np.sqrt(np.mean(s ** 2)) + 1e-12
        if 20 * np.log10(rms) < FLOOR_DB:
            continue
        p = np.abs(np.fft.rfft(s * win)) ** 2 + 1e-18
        cen = (f * p).sum() / p.sum()
        flat = np.exp(np.mean(np.log(p))) / np.mean(p)
        peak = np.sort(p)[-8:].sum() / p.sum()
        ac = np.fft.irfft(np.abs(np.fft.rfft(s, 2 * FR)) ** 2)[:FR]
        harm = float(np.max(ac[lo:hi]) / ac[0]) if ac[0] > 0 else 0.0
        out.append([np.log2(max(cen, 20.0)), flat, peak, harm])
    return np.array(out)


def summarise(path):
    sr, x = load(path)
    F = frame_feats(sr, x)
    if len(F) == 0:
        return None
    return np.median(F, axis=0)


def corpus_stats(corpus, n, seed=0):
    files = sorted(glob.glob(os.path.join(corpus, "g*.wav")))
    random.Random(seed).shuffle(files)
    rows = [r for r in (summarise(p) for p in files[:n]) if r is not None]
    A = np.array(rows)
    med = np.median(A, axis=0)
    mad = np.median(np.abs(A - med), axis=0) * 1.4826 + 1e-9
    return med, mad, len(A)


def baseline(corpus, n, path):
    """Corpus stats cached in `path`, so the live admission check does not
    re-read 300 grains every time; rebuilt if absent."""
    if path and os.path.exists(path):
        d = json.load(open(path))
        return np.array(d["median"]), np.array(d["mad"]), d["n"]
    med, mad, n2 = corpus_stats(corpus, n)
    if path:
        json.dump({"median": med.tolist(), "mad": mad.tolist(), "n": n2,
                   "corpus": os.path.abspath(corpus), "feats": FEATS}, open(path, "w"))
    return med, mad, n2


def pitch_structure(z):
    """harmonicity z + peakiness z. Chosen 27 Sept AFTER reading Roberto's
    twelve verdicts (it separated them 6/6), so it is a hypothesis about what
    the ear calls new in kind, to be tested on renders he has not judged."""
    return float(z[3] + z[2])


def distance(v, med, mad):
    z = (v - med) / mad
    return float(np.sqrt(np.mean(z ** 2))), z


def selftest():
    sr = 44100
    t = np.arange(sr * 2) / sr
    rng = np.random.default_rng(0)
    noise = rng.normal(0, 0.1, len(t))
    sine = 0.1 * np.sin(2 * np.pi * 220 * t)
    fn, fs = frame_feats(sr, noise), frame_feats(sr, sine)
    ok = (np.median(fs[:, 3]) > 0.9 > np.median(fn[:, 3])
          and np.median(fs[:, 1]) < np.median(fn[:, 1])
          and np.median(fs[:, 2]) > np.median(fn[:, 2]))
    silent = frame_feats(sr, np.zeros(sr))
    ok = ok and len(silent) == 0
    print("selftest", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--corpus", default=os.path.join(os.path.dirname(__file__), "..", "workdir_music", "grains_play_mid"))
    ap.add_argument("--n", type=int, default=300)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--baseline", default=None, help="cache of corpus stats (JSON)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(selftest())
    med, mad, n = baseline(a.corpus, a.n, a.baseline)
    res = {}
    for p in a.files:
        v = summarise(p)
        if v is None:
            res[os.path.basename(p)] = None
            continue
        d, z = distance(v, med, mad)
        res[os.path.basename(p)] = {"kind": round(d, 3), "pitch": round(pitch_structure(z), 3),
                                    "z": dict(zip(FEATS, [round(float(q), 2) for q in z]))}
    if a.json:
        print(json.dumps({"corpus_n": n, "results": res}))
    else:
        print(f"corpus: {n} grains")
        for k, r in res.items():
            print(f"{k:55} " + ("silent" if r is None else f"kind {r['kind']:6.2f}  pitch {r['pitch']:+6.2f}  " + "  ".join(f"{f[:5]} {r['z'][f]:+6.2f}" for f in FEATS)))


if __name__ == "__main__":
    main()
