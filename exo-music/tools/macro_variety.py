#!/usr/bin/env python3
"""M-A and M-B from docs/measurements/2026-09-15_macro_measure_prereg.md.

READ THE PRE-REGISTRATION FIRST. It was written before this file existed, it
states what would make the measure wrong, and it records that clean isolation by
voice count was tried and refused (macro is alone in 1.7% of windows, longest
run 44 s, against a MIN_SCORED of 200).

M-A  macro-band within-span variation, from audio.
     Band-pass to 220-3600 Hz, the macro band and the only layer with filter
     bands. Inside each 90 s span take 0.5 s frames, log-band spectra, CENTRE
     before normalising, and report the mean pairwise DISTANCE between frames.
     High means the band changes within a span; low means it does not.

     Centring is not a detail. The un-centred form of this computation is the
     measure that scored 140 unrelated FMA tracks as more repetitive than the
     factory, because a cosine between non-negative log-band vectors converges
     to 1 for any music.

     THE CONTAMINATION IS STATED AND IT CUTS ONE WAY. Micro and mid also put
     energy in 220-3600 Hz and they are seven times more numerous, so this
     weights toward macro instead of isolating it. Foreign variation can only
     push M-A UP. A low reading is therefore strong and a high reading is weak.

THE LOG'S FIELD ORDER, because getting it wrong cost a corrected table on the
first day: `VOICES win,macro,mid,micro` and `SLOT win,layer,machine,n`. Macro is
the FIRST count, not the last. Read the wlog call in live_factory.scd before
trusting any memory of this.

M-B  macro source-hold, from the window log, no audio.
     How many windows one machine holds a macro slot, and how many distinct
     machines appear inside a 90 s span. Descriptive only: there is no external
     arm for it, so it carries veto power and never promotion power.

    python3 tools/macro_variety.py calibrate --loop L.wav --diverse D.wav --factory F.wav
    python3 tools/macro_variety.py score --audio F.wav
    python3 tools/macro_variety.py hold  --log /Volumes/FMA/superdark/renders/live_...log
"""
import argparse
import collections
import json
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

# --- fixed by the pre-registration; changing one is a change to the measure ---
BAND_LO_HZ = 220.0          # policy macro_cut_lo
BAND_HI_HZ = 3600.0         # policy macro_cut_hi
SPAN_S = 90.0               # policy voice_span_macro
FRAME_S = 0.5               # as in sonic_variety
N_BANDS = 32
MIN_SCORED = 200            # the guard that exists because 8 frames once
                            # put the factory above a literal loop
SEPARATION_K = 3.0          # LOOP vs DIVERSE must separate by 3 sd or the
                            # measure is declared saturated


def read_audio(path, target_sr=22050):
    """Mono float32 at target_sr. ffmpeg does the work; no resampler of ours."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        out = tmp.name
    try:
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path,
             "-ac", "1", "-ar", str(target_sr), "-c:a", "pcm_s16le", out],
            check=True, capture_output=True)
        with wave.open(out) as w:
            n = w.getnframes()
            raw = w.readframes(n)
        x = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
        return x, target_sr
    finally:
        try:
            os.unlink(out)
        except OSError:
            pass


def band_edges(sr, n_fft):
    """Log-spaced band edges inside the macro band only."""
    freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
    lo = max(BAND_LO_HZ, freqs[1])
    hi = min(BAND_HI_HZ, sr / 2.0 - 1.0)
    edges = np.geomspace(lo, hi, N_BANDS + 1)
    idx = [np.searchsorted(freqs, e) for e in edges]
    return [(idx[i], max(idx[i + 1], idx[i] + 1)) for i in range(N_BANDS)]


def frame_spectra(x, sr):
    hop = int(FRAME_S * sr)
    n_fft = 1 << int(math.ceil(math.log2(hop)))
    win = np.hanning(n_fft).astype(np.float32)
    edges = band_edges(sr, n_fft)
    out = []
    for s in range(0, len(x) - n_fft, hop):
        seg = x[s:s + n_fft] * win
        mag = np.abs(np.fft.rfft(seg))
        out.append([float(np.log1p(mag[a:b].sum())) for a, b in edges])
    return np.asarray(out, dtype=np.float64)


def span_variation(S, frames_per_span):
    """Mean pairwise distance between CENTRED, normalised frames, per span.

    Centring turns a cosine into a correlation. Without it this saturates, and
    it has saturated here before.
    """
    vals = []
    for s in range(0, len(S) - frames_per_span + 1, frames_per_span):
        B = S[s:s + frames_per_span]
        if B.shape[0] < 4:
            continue
        keep = B.sum(1) > 1e-6            # drop silent frames, not spans
        B = B[keep]
        if B.shape[0] < 4:
            continue
        B = B - B.mean(0, keepdims=True)
        nrm = np.linalg.norm(B, axis=1, keepdims=True)
        nrm[nrm < 1e-9] = 1.0
        B = B / nrm
        C = B @ B.T
        iu = np.triu_indices(len(B), 1)
        vals.append(float(1.0 - C[iu].mean()))   # distance, so high = varied
    return vals


def score_audio(path, label):
    x, sr = read_audio(path)
    S = frame_spectra(x, sr)
    fps = int(SPAN_S / FRAME_S)
    vals = span_variation(S, fps)
    if not vals:
        return {"arm": label, "spans": 0, "frames": int(len(S)),
                "status": "NO SPANS"}
    a = np.asarray(vals)
    return {"arm": label, "spans": len(vals), "frames": int(len(S)),
            "mean": round(float(a.mean()), 5),
            "sd": round(float(a.std(ddof=1)) if len(a) > 1 else 0.0, 5),
            "p05": round(float(np.percentile(a, 5)), 5),
            "p50": round(float(np.percentile(a, 50)), 5),
            "p95": round(float(np.percentile(a, 95)), 5),
            "status": "ok" if len(vals) * fps >= MIN_SCORED else "UNDERPOWERED"}


def cmd_calibrate(args):
    arms = {}
    for label, path in (("LOOP", args.loop), ("DIVERSE", args.diverse),
                        ("FACTORY", args.factory)):
        if not path:
            continue
        print(f"scoring {label} ...", flush=True)
        arms[label] = score_audio(path, label)

    print()
    print(f"{'arm':10s} {'spans':>6s} {'mean':>9s} {'sd':>9s} "
          f"{'p05':>9s} {'p95':>9s}  status")
    for label in ("LOOP", "DIVERSE", "FACTORY"):
        r = arms.get(label)
        if not r:
            continue
        print(f"{label:10s} {r['spans']:>6d} {r.get('mean', 0):>9.5f} "
              f"{r.get('sd', 0):>9.5f} {r.get('p05', 0):>9.5f} "
              f"{r.get('p95', 0):>9.5f}  {r['status']}")

    verdict = {"separated": None}
    if "LOOP" in arms and "DIVERSE" in arms and \
            arms["LOOP"].get("mean") is not None:
        gap = arms["DIVERSE"]["mean"] - arms["LOOP"]["mean"]
        pooled = math.sqrt((arms["LOOP"]["sd"] ** 2 +
                            arms["DIVERSE"]["sd"] ** 2) / 2.0) or 1e-9
        d = gap / pooled
        verdict = {"gap": round(gap, 5), "pooled_sd": round(pooled, 5),
                   "separation_sd": round(d, 2),
                   "separated": bool(d >= SEPARATION_K)}
        print()
        print(f"LOOP -> DIVERSE gap {gap:+.5f}, pooled sd {pooled:.5f}, "
              f"separation {d:.2f} sd (need {SEPARATION_K})")
        if not verdict["separated"]:
            print()
            print("SATURATED. The arms do not separate. Per the pre-registration")
            print("this measure is now retired in harness/measures.json and NO")
            print("factory number from it may be quoted. This is the fourth")
            print("spectral statistic to do this, and it was caught by the arms")
            print("again, which is the only reason it cost an afternoon.")
        elif "FACTORY" in arms:
            f = arms["FACTORY"]["mean"]
            lo, hi = arms["LOOP"]["mean"], arms["DIVERSE"]["mean"]
            pos = (f - lo) / (hi - lo) if hi != lo else float("nan")
            verdict["factory_position"] = round(pos, 4)
            print(f"\nfactory position on the loop-to-diverse axis: {pos:.4f}")
            print("0 is a literal loop, 1 is 140 unrelated tracks.")

    out = {"measure": "M-A macro_band_within_span",
           "prereg": "docs/measurements/2026-09-15_macro_measure_prereg.md",
           "band_hz": [BAND_LO_HZ, BAND_HI_HZ], "span_s": SPAN_S,
           "frame_s": FRAME_S, "n_bands": N_BANDS,
           "_contamination": "micro and mid also occupy this band and are 7x "
                             "more numerous, so foreign variation can only push "
                             "M-A up. A low reading is strong; a high one weak.",
           "arms": arms, "verdict": verdict}
    if args.out:
        with open(args.out, "w") as fh:
            json.dump(out, fh, indent=1, sort_keys=True)
        print(f"\n{args.out}")
    return 0


def cmd_score(args):
    r = score_audio(args.audio, "FACTORY")
    print(json.dumps(r, indent=1, sort_keys=True))
    print("\nM-A_mean=%s" % r.get("mean"))
    print("M-A_spans=%s" % r.get("spans"))
    return 0


def cmd_hold(args):
    """M-B: macro source-hold, from the log. Descriptive, never promoting."""
    cur = {}
    holds = []
    per_span = collections.defaultdict(set)
    win_s = args.window_s
    for line in open(args.log, errors="replace"):
        if not line.startswith("SLOT "):
            continue
        try:
            body = line.split(None, 1)[1].strip().split(",")
            win, layer, machine = int(float(body[0])), body[1], body[2]
        except (IndexError, ValueError):
            continue
        if layer != "macro":
            continue
        span = int(win * win_s // SPAN_S)
        per_span[span].add(machine)
        if cur.get("machine") == machine:
            cur["until"] = win
        else:
            if cur:
                holds.append(cur["until"] - cur["from"] + 1)
            cur = {"machine": machine, "from": win, "until": win}
    if cur:
        holds.append(cur["until"] - cur["from"] + 1)

    if not holds:
        print("no macro SLOT lines in this log")
        return 0
    h = np.asarray(holds)
    distinct = np.asarray([len(v) for v in per_span.values()])
    print(f"macro source-hold, {len(holds)} holds over {len(per_span)} spans "
          f"of {SPAN_S:.0f} s")
    print(f"  hold length, windows:  median {np.median(h):.1f}  "
          f"p95 {np.percentile(h, 95):.1f}  max {h.max()}")
    print(f"  hold length, seconds:  median {np.median(h)*win_s:.1f}  "
          f"max {h.max()*win_s:.1f}")
    print(f"  distinct machines per span: median {np.median(distinct):.1f}  "
          f"min {distinct.min()}  max {distinct.max()}")
    one = int((distinct == 1).sum())
    print(f"  spans with ONE machine throughout: {one} of {len(distinct)} "
          f"({100*one/len(distinct):.1f}%)")
    print()
    print("M-B_median_hold_s=%.1f" % (np.median(h) * win_s))
    print("M-B_single_machine_span_frac=%.4f" % (one / len(distinct)))
    print()
    print("DESCRIPTIVE ONLY. There is no loop arm and no diverse arm for a slot")
    print("log, so M-B has veto power and no promotion power, permanently.")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("calibrate")
    c.add_argument("--loop"); c.add_argument("--diverse"); c.add_argument("--factory")
    c.add_argument("--out", default=None)
    c.set_defaults(fn=cmd_calibrate)

    c = sub.add_parser("score"); c.add_argument("--audio", required=True)
    c.set_defaults(fn=cmd_score)

    c = sub.add_parser("hold"); c.add_argument("--log", required=True)
    c.add_argument("--window-s", type=float, default=11.0,
                   help="seconds per window; measure it, do not assume it")
    c.set_defaults(fn=cmd_hold)

    args = ap.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
