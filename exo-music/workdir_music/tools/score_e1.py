#!/usr/bin/env python3
"""
E1: the spectral score plus a time axis.

E0 (score.py) averages three spectral features across every frame, so twenty
seconds of continuous wash and twenty seconds containing one event produce the
same description. Run 14 measured what that costs: shaped noise 54.68 against
best musical output 32.05.

E1 keeps E0's three terms unchanged and adds four temporal ones. Design targets
come from the symbolic temporal descriptors in Lerch et al. (2025) Table 1
(p. 99:15), given audio analogues:

    Empty Bars                        -> silence ratio
    Total Used Notes                  -> onset rate
    Average Inter-onset Interval      -> IOI mean
    Note Length Histogram / Transition-> IOI coefficient of variation
    Rhythmic Similarity between       -> novelty-curve variance over a
      Measures                           self-similarity matrix

The last is the one the survey says does not exist: "specific metrics to measure
these higher-level features have not yet been proposed" (p. 99:14), of form and
repetition. Table 2 (p. 99:17) contains no audio structural metric at all; only
ViSQOL touches a time-frequency representation (p. 99:16).

E1 is a strict extension of E0, so the two are comparable rung to rung.

Usage:  score_e1.py <wavfile>
"""
import sys, json, wave
import numpy as np

SPECTRAL_TARGET = {"centroid": 3000.0, "flatness": 0.15, "rolloff": 2000.0}

# Temporal targets. Chosen to describe music with events in it: a few events per
# second, irregular but not random spacing, spectral change, and sectional
# contrast. Fixed before any optimisation, like the spectral target.
# Derived, not stipulated. A first version of this file guessed these four
# numbers and the result was worse than useless: Archon scored temporal distance
# 4.20 against shaped noise's 2.72, because the guesses penalised exactly what
# made the music music. Targets now come from a reference recording, which is
# what the survey says music evaluation requires: "the existence of a reference
# signal is usually deemed necessary for music" (Lerch et al. 2025, p. 99:5).
REFERENCE = "/tmp/an/rec_seed.wav"

FRAME, HOP = 2048, 1024


def load(path):
    w = wave.open(path)
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    d = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float64)
    if ch > 1:
        d = d.reshape(-1, ch).mean(axis=1)
    return d / 32768.0, sr


def spectrogram(x, sr):
    win = np.hanning(FRAME)
    frames = [x[i:i + FRAME] * win for i in range(0, len(x) - FRAME, HOP)]
    if not frames:
        return None, None
    S = np.abs(np.fft.rfft(np.array(frames), axis=1)) + 1e-12
    f = np.fft.rfftfreq(FRAME, 1 / sr)
    return S, f


def spectral_terms(S, f):
    """E0, unchanged: averaged over frames carrying energy."""
    energy = S.sum(axis=1)
    live = energy > (energy.max() * 1e-4)
    if live.sum() == 0:
        return None
    Sl = S[live]
    tot = Sl.sum(axis=1)
    centroid = float(((f * Sl).sum(axis=1) / tot).mean())
    flatness = float((np.exp(np.log(Sl).mean(axis=1)) / Sl.mean(axis=1)).mean())
    cs = np.cumsum(Sl, axis=1)
    roll = float(np.mean([f[np.searchsorted(c, 0.5 * c[-1])] for c in cs]))
    return {"centroid": centroid, "flatness": flatness, "rolloff": roll}


def temporal_terms(x, S, sr):
    """Envelope statistics. No onset detection: two attempts at onset-based
    features failed (see notes/runs/2026-08-19-16-e1). The detector reported
    1.20 onsets/s for shaped noise, which has none, and 1.35/s for a render
    containing 98 grain patterns. Envelope statistics separate the same cases
    by two orders of magnitude and need no peak picking."""
    fr = int(sr * 0.02)
    env = np.array([np.sqrt((x[i:i + fr] ** 2).mean()) for i in range(0, len(x) - fr, fr)])
    env = env[env > 0]
    if len(env) < 10:
        return {"log_env_var": 0.0, "dyn_range": 1.0, "sparsity": 0.0}
    p90, p10 = np.percentile(env, 90), np.percentile(env, 10)

    # Pitched fraction, by normalised autocorrelation per frame. This mirrors
    # Archon's own percpitch descriptor, which Behavior already consumes: the
    # system reasons in pitched-versus-unpitched terms, so the evaluator should
    # too. Noise is unpitched by construction, so this is hard to satisfy
    # without producing something tonal.
    lo, hi = int(sr / 2000), int(sr / 50)          # 50 Hz to 2 kHz
    pitched, live, fl = 0, 0, 2048
    for i in range(0, len(x) - fl, fl):
        seg = x[i:i + fl]
        if np.sqrt((seg ** 2).mean()) < 1e-4:
            continue
        live += 1
        seg = seg - seg.mean()
        ac = np.correlate(seg, seg, mode="full")[fl - 1:]
        ac = ac / (ac[0] + 1e-12)
        if hi < len(ac) and ac[lo:hi].max() > 0.5:
            pitched += 1

    return {
        "log_env_var": float(np.log10(env + 1e-9).var()),
        "dyn_range": float(p90 / max(p10, 1e-9)),
        "sparsity": float(1.0 - (env > env.max() * 0.1).mean()),
        "pitched_ratio": float(pitched / live) if live else 0.0,
    }


# Floors, not targets. Archon is MORE dynamic than the reference recording, so a
# distance-to-target framing penalised it for the very property that
# distinguishes it from a wash. These are one-sided: exceeding them costs
# nothing, falling below them costs.
# The reference recording is 63.2% pitched (run 06, hasFreq). The floor sits near
# half of that: the system must produce some tonal material, and is not rewarded
# for producing only tonal material.
FLOORS = {"log_env_var": 0.08, "dyn_range": 5.0, "sparsity": 0.15, "pitched_ratio": 0.30}


def temporal_penalty(tp):
    pen, per = 0.0, {}
    for k, floor in FLOORS.items():
        v = tp[k]
        short = max(0.0, floor - v) / floor
        per[k] = {"value": round(v, 4), "floor": floor, "shortfall": round(short, 4)}
        pen += short
    return pen, per


def main():
    path = sys.argv[1]
    x, sr = load(path)
    if float(np.abs(x).max()) == 0.0:
        print(json.dumps({"error": "SILENT", "file": path, "score": None})); sys.exit(2)

    S, f = spectrogram(x, sr)
    if S is None:
        print(json.dumps({"error": "TOO_SHORT", "file": path, "score": None})); sys.exit(2)

    sp = spectral_terms(S, f)
    if sp is None:
        print(json.dumps({"error": "NO_VOICED_FRAMES", "file": path, "score": None})); sys.exit(2)
    tp = temporal_terms(x, S, sr)
    tdist, tper = temporal_penalty(tp)

    per, sdist = {}, 0.0
    for k, t in SPECTRAL_TARGET.items():
        d = abs(sp[k] - t) / t
        per[k] = {"value": round(sp[k], 4), "target": t, "norm_dist": round(d, 4)}
        sdist += d
    per.update(tper)

    print(json.dumps({
        "file": path,
        "rung": "E1",
        "score": round(100.0 / (1.0 + sdist + tdist), 3),
        "score_E0_part": round(100.0 / (1.0 + sdist), 3),
        "spectral_distance": round(sdist, 4),
        "temporal_penalty": round(tdist, 4),
        "features": per,
    }, indent=2))


if __name__ == "__main__":
    main()
