#!/usr/bin/env python3
"""M-D: how long the dominant partial holds, on isolated macro.

READ docs/measurements/2026-09-15_partial_hold_prereg.md FIRST. It was written
before this file and it fixes what would make the measure wrong.

WHY NOT ANOTHER SPECTRAL SIMILARITY STATISTIC
Four have saturated here and they share one shape: normalised band vector,
pairwise frame comparison, average. M-A, this morning, ranked a literal loop as
more varied than 600 unrelated FMA clips. The family is closed.

WHAT THIS DOES INSTEAD
Tracks the dominant spectral peak frame by frame and asks how long it stays put.
A HOLD is a maximal run of consecutive frames whose peak stays within a
tolerance in cents of the run's starting peak, above the audibility floor.
Held-tone duration, on a layer whose job is to hold tones.

THE CONTROL ARM IS THE POINT
A measure of held tones that cannot find a held tone in a synthesised sine is
not a measure. M-A had no arm that could prove the instrument detected the thing
it was looking for at all. `calibrate` refuses to report the factory unless the
sustained control yields one hold covering at least MIN_CONTROL_COVER of its
duration.

    python3 tools/partial_hold.py control
    python3 tools/partial_hold.py calibrate --sustained S.wav --loop L.wav \\
        --diverse D.wav --factory F.wav --out cal.json
    python3 tools/partial_hold.py score --audio F.wav
"""
import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

# --- fixed by the pre-registration -----------------------------------------
HOP_S = 0.046               # ~46 ms
TOL_CENTS = 50.0            # +/- a quarter tone from the run's starting peak
FLOOR_DB = -60.0            # audibility floor; below this a frame is silence
MIN_HZ, MAX_HZ = 60.0, 8000.0
MIN_SCORED = 200            # frames per arm
MIN_CONTROL_COVER = 0.90    # the sustained control must be one hold, 90%+
SEPARATION_K = 3.0
LONG_HOLD_S = 1.0           # "inside a long hold" threshold for the coverage stat


def read_audio(path, sr=22050):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
        out = t.name
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                        "-i", path, "-ac", "1", "-ar", str(sr),
                        "-c:a", "pcm_s16le", out],
                       check=True, capture_output=True)
        with wave.open(out) as w:
            raw = w.readframes(w.getnframes())
        return np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0, sr
    finally:
        try:
            os.unlink(out)
        except OSError:
            pass


def peak_track(x, sr):
    """Dominant spectral peak per frame, with parabolic interpolation.

    Returns (hz, db) arrays. hz is nan where the frame is below the floor or
    has no peak in band -- nan breaks a hold, which is correct: silence is not
    a sustained tone.
    """
    hop = max(1, int(HOP_S * sr))
    n_fft = 1 << int(math.ceil(math.log2(hop * 4)))
    win = np.hanning(n_fft).astype(np.float32)
    freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
    lo = int(np.searchsorted(freqs, MIN_HZ))
    hi = int(np.searchsorted(freqs, MAX_HZ))
    hz, db = [], []
    for s in range(0, len(x) - n_fft, hop):
        seg = x[s:s + n_fft] * win
        rms = float(np.sqrt(np.mean(seg * seg)) + 1e-12)
        level = 20.0 * math.log10(rms)
        db.append(level)
        if level < FLOOR_DB:
            hz.append(np.nan)
            continue
        mag = np.abs(np.fft.rfft(seg))
        band = mag[lo:hi]
        if band.size < 3:
            hz.append(np.nan)
            continue
        k = int(np.argmax(band)) + lo
        if k <= 0 or k >= len(mag) - 1:
            hz.append(float(freqs[k]))
            continue
        # parabolic interpolation, so a steady tone does not jitter between bins
        a, b, c = mag[k - 1], mag[k], mag[k + 1]
        denom = (a - 2 * b + c)
        delta = 0.5 * (a - c) / denom if abs(denom) > 1e-12 else 0.0
        hz.append(float(freqs[k] + delta * (freqs[1] - freqs[0])))
    return np.asarray(hz), np.asarray(db)


def holds(hz):
    """Maximal runs staying within TOL_CENTS of the run's starting peak."""
    out = []
    start = None
    ref = None
    for i, f in enumerate(hz):
        if not np.isfinite(f) or f <= 0:
            if start is not None:
                out.append(i - start)
                start, ref = None, None
            continue
        if start is None:
            start, ref = i, f
            continue
        cents = 1200.0 * math.log2(f / ref)
        if abs(cents) > TOL_CENTS:
            out.append(i - start)
            start, ref = i, f
    if start is not None:
        out.append(len(hz) - start)
    return np.asarray(out, dtype=float) * HOP_S


def score_audio(path, label):
    x, sr = read_audio(path)
    hz, db = peak_track(x, sr)
    sounding = int(np.isfinite(hz).sum())
    h = holds(hz)
    if h.size == 0 or sounding < MIN_SCORED:
        return {"arm": label, "frames": int(len(hz)), "sounding": sounding,
                "holds": int(h.size),
                "status": "UNDERPOWERED" if sounding < MIN_SCORED else "NO HOLDS"}
    total = float(h.sum())
    return {
        "arm": label,
        "frames": int(len(hz)),
        "sounding": sounding,
        "sounding_frac": round(sounding / max(len(hz), 1), 4),
        "holds": int(h.size),
        "median_s": round(float(np.median(h)), 4),
        "mean_s": round(float(h.mean()), 4),
        "sd_s": round(float(h.std(ddof=1)) if h.size > 1 else 0.0, 4),
        "p95_s": round(float(np.percentile(h, 95)), 4),
        "max_s": round(float(h.max()), 4),
        "long_hold_cover": round(float(h[h >= LONG_HOLD_S].sum() / max(total, 1e-9)), 4),
        "status": "ok",
    }


def synth_sustained(path, seconds=30.0, hz=330.0, sr=22050):
    t = np.arange(int(seconds * sr)) / sr
    # a bare sine is an unfairly easy target; give it three harmonics and a
    # slow amplitude envelope, which is what a held instrumental tone looks like
    x = (0.6 * np.sin(2 * np.pi * hz * t)
         + 0.25 * np.sin(2 * np.pi * 2 * hz * t)
         + 0.1 * np.sin(2 * np.pi * 3 * hz * t))
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.3 * t)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    return path


def cmd_control(args):
    path = args.out or os.path.join(tempfile.gettempdir(), "ph_sustained.wav")
    synth_sustained(path, seconds=args.seconds)
    r = score_audio(path, "SUSTAINED")
    print(json.dumps(r, indent=1, sort_keys=True))
    if r.get("status") != "ok":
        print("\nINSTRUMENT INVALID: the control did not even score.")
        return 1
    cover = r["max_s"] / args.seconds
    print(f"\nlongest hold {r['max_s']:.2f}s of {args.seconds:.0f}s "
          f"= {100*cover:.1f}% coverage (need {100*MIN_CONTROL_COVER:.0f}%)")
    if cover < MIN_CONTROL_COVER:
        print("INSTRUMENT INVALID. A measure of held tones that cannot find a")
        print("held tone in a synthesised one is not a measure. Per the")
        print("pre-registration, no factory number may be read.")
        return 1
    print("control passes; the tracker can see a held tone")
    return 0


def cmd_calibrate(args):
    sustained = args.sustained or synth_sustained(
        os.path.join(tempfile.gettempdir(), "ph_sustained.wav"))
    arms = {}
    print("scoring SUSTAINED (control) ...", flush=True)
    arms["SUSTAINED"] = score_audio(sustained, "SUSTAINED")
    ctrl = arms["SUSTAINED"]
    ok_ctrl = (ctrl.get("status") == "ok"
               and ctrl.get("max_s", 0) / 30.0 >= MIN_CONTROL_COVER)
    if not ok_ctrl:
        print("\nINSTRUMENT INVALID: control failed. Stopping before any other")
        print("arm is read, per the pre-registration.")
        print(json.dumps(ctrl, indent=1, sort_keys=True))
        return 1
    print(f"  control ok: longest hold {ctrl['max_s']:.2f}s\n")

    for label, path in (("LOOP", args.loop), ("DIVERSE", args.diverse),
                        ("FACTORY", args.factory)):
        if not path:
            continue
        print(f"scoring {label} ...", flush=True)
        arms[label] = score_audio(path, label)

    print()
    print(f"{'arm':11s} {'holds':>7s} {'median_s':>9s} {'p95_s':>8s} "
          f"{'max_s':>8s} {'>1s cover':>10s}  status")
    for label in ("SUSTAINED", "LOOP", "DIVERSE", "FACTORY"):
        r = arms.get(label)
        if not r:
            continue
        print(f"{label:11s} {r.get('holds',0):>7d} {r.get('median_s',0):>9.4f} "
              f"{r.get('p95_s',0):>8.3f} {r.get('max_s',0):>8.3f} "
              f"{r.get('long_hold_cover',0):>10.3f}  {r['status']}")

    verdict = {}
    if "LOOP" in arms and "DIVERSE" in arms and \
            arms["LOOP"].get("status") == "ok" and arms["DIVERSE"].get("status") == "ok":
        gap = arms["DIVERSE"]["median_s"] - arms["LOOP"]["median_s"]
        pooled = math.sqrt((arms["LOOP"]["sd_s"] ** 2 +
                            arms["DIVERSE"]["sd_s"] ** 2) / 2.0) or 1e-9
        d = gap / pooled
        verdict = {"loop_to_diverse_gap_s": round(gap, 4),
                   "pooled_sd": round(pooled, 4),
                   "separation_sd": round(d, 2),
                   "separated": bool(abs(d) >= SEPARATION_K)}
        print(f"\nLOOP -> DIVERSE median gap {gap:+.4f}s, separation {d:+.2f} sd "
              f"(need {SEPARATION_K})")
        if not verdict["separated"]:
            print("SATURATED. Retire it in harness/measures.json and quote no")
            print("factory number from it. That would be the fifth.")
        elif "FACTORY" in arms and arms["FACTORY"].get("status") == "ok":
            f = arms["FACTORY"]["median_s"]
            dv = arms["DIVERSE"]["median_s"]
            short_by = (dv - f) / pooled
            verdict["factory_below_diverse_sd"] = round(short_by, 2)
            verdict["complaint_supported"] = bool(short_by >= SEPARATION_K)
            print(f"\nFACTORY median hold {f:.4f}s against DIVERSE {dv:.4f}s: "
                  f"{short_by:+.2f} sd")
            print("COMPLAINT SUPPORTED: macro does not hold tones."
                  if verdict["complaint_supported"] else
                  "The complaint is NOT about held tones on this instrument.\n"
                  "Write that up as such. The ear has been right three times\n"
                  "here where the instruments were not.")

    out = {"measure": "M-D partial_hold",
           "prereg": "docs/measurements/2026-09-15_partial_hold_prereg.md",
           "hop_s": HOP_S, "tol_cents": TOL_CENTS, "floor_db": FLOOR_DB,
           "arms": arms, "verdict": verdict}
    if args.out:
        with open(args.out, "w") as fh:
            json.dump(out, fh, indent=1, sort_keys=True)
        print(f"\n{args.out}")
    return 0


def permutation_test(h_a, h_b, n=2000, seed=20260916):
    """Difference in long_hold_cover between two arms, against a label null.

    M-D died on a pooled sd. Hold durations run from one frame to nearly ten
    seconds, so the sd is dominated by the tail and a 2x difference in medians
    normalised to 0.17 sd -- the rule could not have detected anything.

    long_hold_cover is a ratio of summed durations, so the honest null is to
    pool both arms' holds, reshuffle which arm each belongs to, and recompute.
    No distributional assumption, and the heavy tail is carried identically in
    the null and the observation.

    Returns observed difference, p (two-tailed), and the null's spread.
    """
    rng = np.random.default_rng(seed)

    def cover(h):
        tot = h.sum()
        return float(h[h >= LONG_HOLD_S].sum() / tot) if tot > 0 else 0.0

    obs = cover(h_a) - cover(h_b)
    pool = np.concatenate([h_a, h_b])
    n_a = len(h_a)
    diffs = np.empty(n)
    for i in range(n):
        rng.shuffle(pool)
        diffs[i] = cover(pool[:n_a]) - cover(pool[n_a:])
    p = float((np.abs(diffs) >= abs(obs)).mean())
    return {"observed_diff": round(obs, 5),
            "p_two_tailed": round(p, 5),
            "null_mean": round(float(diffs.mean()), 5),
            "null_p2_5": round(float(np.percentile(diffs, 2.5)), 5),
            "null_p97_5": round(float(np.percentile(diffs, 97.5)), 5),
            "draws": n,
            "cover_a": round(cover(h_a), 5),
            "cover_b": round(cover(h_b), 5)}


def holds_of(path):
    x, sr = read_audio(path)
    hz, _ = peak_track(x, sr)
    return holds(hz), int(np.isfinite(hz).sum()), int(len(hz))


def cmd_prime(args):
    """M-D': FACTORY vs DIVERSE on long_hold_cover, permutation null, p <= 0.01.

    Pre-registered in docs/measurements/2026-09-16_partial_hold_prime_prereg.md
    BEFORE the isolation run that feeds it. LOOP is deliberately absent: for a
    within-stretch duration statistic a loop of the factory is the factory.
    """
    ALPHA = 0.01
    sustained = args.sustained or synth_sustained(
        os.path.join(tempfile.gettempdir(), "ph_sustained.wav"))
    print("control ...", flush=True)
    ctrl = score_audio(sustained, "SUSTAINED")
    if ctrl.get("status") != "ok" or ctrl["max_s"] / 30.0 < MIN_CONTROL_COVER:
        print("INSTRUMENT INVALID: the control did not hold a synthesised tone.")
        print(json.dumps(ctrl, indent=1, sort_keys=True))
        return 1
    print(f"  ok, longest hold {ctrl['max_s']:.2f}s\n")

    print("DIVERSE ...", flush=True)
    hd, snd_d, tot_d = holds_of(args.diverse)
    print("FACTORY ...", flush=True)
    hf, snd_f, tot_f = holds_of(args.factory)
    if min(snd_d, snd_f) < MIN_SCORED:
        print(f"UNDERPOWERED: sounding frames {snd_f} / {snd_d}, need {MIN_SCORED}")
        return 1

    res = permutation_test(hf, hd, n=args.draws)
    supported = (res["observed_diff"] > 0) and (res["p_two_tailed"] <= ALPHA)

    out = {"measure": "M-D' long_hold_cover",
           "prereg": "docs/measurements/2026-09-16_partial_hold_prime_prereg.md",
           "alpha": ALPHA, "long_hold_s": LONG_HOLD_S,
           "control": ctrl,
           "factory": {"holds": int(len(hf)), "sounding_frac": round(snd_f/max(tot_f,1), 4)},
           "diverse": {"holds": int(len(hd)), "sounding_frac": round(snd_d/max(tot_d,1), 4)},
           "test": res,
           "verdict": ("complaint_supported" if supported
                       else "not_about_held_tones")}

    print()
    print(f"  FACTORY long_hold_cover  {res['cover_a']:.4f}  "
          f"(sounding {out['factory']['sounding_frac']:.3f})")
    print(f"  DIVERSE long_hold_cover  {res['cover_b']:.4f}  "
          f"(sounding {out['diverse']['sounding_frac']:.3f})")
    print(f"  difference               {res['observed_diff']:+.4f}")
    print(f"  permutation null         mean {res['null_mean']:+.4f}, "
          f"95% [{res['null_p2_5']:+.4f}, {res['null_p97_5']:+.4f}], "
          f"{res['draws']} draws")
    print(f"  p (two-tailed)           {res['p_two_tailed']:.4f}  "
          f"(need <= {ALPHA})")
    print()
    if supported:
        print("  COMPLAINT SUPPORTED. Macro holds single pitches far more than")
        print("  real music does. That is the drone, quantified, under a rule")
        print("  fixed before the data existed.")
    else:
        print("  NOT ABOUT HELD TONES on this instrument. Written up as such.")
        print("  It does not mean the ear was wrong; it means this measure does")
        print("  not see what the ear hears, and macro_has_no_harmony becomes")
        print("  the live lead.")
    if args.out:
        with open(args.out, "w") as fh:
            json.dump(out, fh, indent=1, sort_keys=True)
        print(f"\n{args.out}")
    return 0


def cmd_score(args):
    r = score_audio(args.audio, "FACTORY")
    print(json.dumps(r, indent=1, sort_keys=True))
    print("\nM-D_median_hold_s=%s" % r.get("median_s"))
    print("M-D_long_hold_cover=%s" % r.get("long_hold_cover"))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("control")
    c.add_argument("--seconds", type=float, default=30.0)
    c.add_argument("--out", default=None)
    c.set_defaults(fn=cmd_control)

    c = sub.add_parser("calibrate")
    c.add_argument("--sustained"); c.add_argument("--loop")
    c.add_argument("--diverse");   c.add_argument("--factory")
    c.add_argument("--out", default=None)
    c.set_defaults(fn=cmd_calibrate)

    c = sub.add_parser("prime")
    c.add_argument("--factory", required=True)
    c.add_argument("--diverse", required=True)
    c.add_argument("--sustained", default=None)
    c.add_argument("--draws", type=int, default=2000)
    c.add_argument("--out", default=None)
    c.set_defaults(fn=cmd_prime)

    c = sub.add_parser("score"); c.add_argument("--audio", required=True)
    c.set_defaults(fn=cmd_score)

    args = ap.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
