#!/usr/bin/env python3
"""Grains as EVENTS, analysed the way Archon analyses them.

THREE THINGS THE EARLIER CORPORA GOT WRONG
------------------------------------------
docs/05-archon.md, describing the system these machines come from:

    "Analysis detects ONSETS AND OFFSETS in live input and extracts SEVEN
     descriptors per event: onset time, offset time, spectral centroid,
     rolloff, flatness, RMS, pitch."

1. GRAIN LENGTH. Ours were 0.5 s. At that length a slice of a full band mix
   already contains its own rhythm, key and instrumentation, so the SOURCE
   composes and the machine can only rearrange it. Roberto: "rapid concatenative
   transitions, like a broken radio... the machines are not generating musical
   behaviours." Correct: at 0.5 s they cannot. Short grains put the machine's
   \\dur pattern in charge of the perceived rhythm, which is the regime Archon
   was written for.

2. ONSET ALIGNMENT. build_grains.py cut "at random offsets rather than
   onset-aligned" -- its own comment. Every grain began mid-note, so no machine
   could articulate anything, because there was no attack to place. Archon's
   grains are bounded by onset and offset: a grain IS an event.

3. PITCH. Archon analyses seven descriptors. Ours had five, and the factory's
   path used four (centroid, flatness, median, zcr) -- no rolloff, and NO PITCH.
   The machines ask for \\mainpitch and \\avgrolloff and receive them from the
   live analysis, but grain SELECTION has always been pitch-blind. You cannot
   assemble harmonically coherent material along axes that do not include pitch.
   That is the direct cause of "nothing harmonic or tonal".

This cuts short grains snapped to detected onsets, and analyses all seven.
Provenance and adjacency from build_grains_seq.py are kept, so continuity still
works and consecutive grains still reconstruct the source when asked to.

Pitch is autocorrelation over the grain, valid from roughly 80 Hz upward at
60 ms. Grains where it fails are marked 0.0 and are simply unpitched, which is
honest: a cymbal has no pitch and should not be given one.

There is also a TRANSIENT GATE, which rejects whole source tracks carrying
impulsive damage. It now has two shapes -- a spike gate (default, on) and a
floor gate (calibrated, off) -- and the long comment inside main() records the
measurement that decided which is which. Read it before changing either. The
thresholds live in RUN_MEDIAN_THRESH below and are per-layer, because one
number cannot serve three grain lengths.
"""
import argparse
import json
import os
import random
import subprocess
import wave

import numpy as np

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from audit_grain_transients import grain_score

SR = 22050

# ---------------------------------------------------------------------------
# THE TRANSIENT GATE'S THRESHOLDS, ONE PER LAYER GEOMETRY
#
# Derived 1 Sept 2026 by tools/transient_median_null.py: the 99th percentile of
# the RUN MEDIAN of grain_score() over 2,500 licence-clean tracks (seed
# 20260902), with the seven ids .lab/notes/BISECTION.md names, 450 "Antique Phonograph
# Music Program" transfers and 516 genre_top == "Old-Time / Historic" excluded
# on PROVENANCE and never on score.
#
#     layer   grain   run   M*     bootstrap 95% CI    held-out false rejection
#     ev      60 ms    24    25.5  [ 20.5,  33.3]      1.84%  (23 of 1250)
#     mid     400 ms   12    61.8  [ 49.3,  73.7]      1.04%  (13 of 1250)
#     macro   2 s       8   101.3  [ 86.6, 129.4]      1.20%  (15 of 1250)
#
# THESE ARE NOT ON BY DEFAULT. Read the block above main()'s gate before turning
# them on: the run median was measured against the live rule and did not win.
#
# NEVER ONE NUMBER FOR THREE GEOMETRIES. grain_score()'s median window is 15 ms,
# so a 60 ms grain gives the anomaly ratio ~4 chances to be large and a 2 s grain
# ~133; the three nulls are three distributions and 40 sits at a different
# percentile of each. An unknown geometry raises rather than borrowing the
# nearest number, because borrowing is exactly the error being corrected.
#
# Measured at SR = 22050. grain_score()'s env_ms and med_ms are in milliseconds
# but its output is a ratio of sample-domain envelopes, so a sample-rate change
# invalidates the table. Re-run transient_median_null.py if SR moves.
# ---------------------------------------------------------------------------
RUN_MEDIAN_THRESH = {0.06: 25.5, 0.40: 61.8, 2.00: 101.3}


def run_median_threshold(grain_sec, table=RUN_MEDIAN_THRESH, tol=1e-6):
    """M* for a grain length, or a refusal. Never the nearest neighbour."""
    for sec, m in table.items():
        if abs(sec - grain_sec) < tol:
            return m
    raise SystemExit(
        f"  no run-median threshold derived for a {grain_sec * 1000:.0f} ms "
        f"grain. Have {sorted(table)} seconds. A threshold from another geometry "
        f"is not transferable -- grain_score()'s 15 ms window gives a longer "
        f"grain more chances to look anomalous, so its null sits higher. Run "
        f"tools/transient_median_null.py --geometry at this length, or pass "
        f"--max-run-median explicitly and say where the number came from.")


def decode(path, sr=SR):
    try:
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le",
             "-acodec", "pcm_f32le", "-ac", "2", "-ar", str(sr), "-"],
            capture_output=True, timeout=120).stdout
    except Exception:
        return None
    a = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    return a.reshape(-1, 2) if len(a) > sr * 16 else None


def onsets(mono, sr, hop=256, n=1024):
    """Spectral-flux onset detection. Same method as analyse_temporal.py, so the
    regimes and the grains are segmented on the same definition of an event."""
    frames = 1 + (len(mono) - n) // hop
    if frames < 16:
        return np.array([])
    S = np.abs(np.fft.rfft(np.lib.stride_tricks.as_strided(
        mono, (frames, n), (mono.strides[0] * hop, mono.strides[0])) * np.hanning(n), axis=1))
    flux = np.maximum(np.diff(S, axis=0), 0).sum(axis=1)
    k = 9
    pad = np.pad(flux, (k // 2, k // 2), mode="edge")
    local = np.array([np.median(pad[i:i + k]) for i in range(len(flux))])
    thresh = local + 0.5 * np.std(flux)
    pk = [i for i in range(1, len(flux) - 1)
          if flux[i] > thresh[i] and flux[i] >= flux[i - 1] and flux[i] > flux[i + 1]]
    return np.array(pk) * hop


def pitch_of(mono, sr, fmin=80.0, fmax=2000.0):
    """Autocorrelation pitch with a clarity gate. Returns 0.0 when unpitched."""
    x = mono - mono.mean()
    if np.sqrt((x ** 2).mean()) < 1e-5:
        return 0.0, 0.0
    c = np.correlate(x, x, mode="full")[len(x) - 1:]
    if c[0] <= 0:
        return 0.0, 0.0
    lo, hi = int(sr / fmax), min(int(sr / fmin), len(c) - 1)
    if hi <= lo + 2:
        return 0.0, 0.0
    seg = c[lo:hi]
    i = int(np.argmax(seg))
    clarity = float(seg[i] / c[0])
    if clarity < 0.30:                      # not periodic enough to call pitched
        return 0.0, clarity
    return float(sr / (lo + i)), clarity


def analyse(mono, sr):
    S = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    fr = np.fft.rfftfreq(len(mono), 1 / sr)
    tot = max(1e-20, S.sum())
    c = np.cumsum(S) / tot
    cent = float((S * fr).sum() / tot)
    roll = float(fr[min(np.searchsorted(c, 0.85), len(fr) - 1)])     # Archon: rolloff
    med = float(fr[min(np.searchsorted(c, 0.5), len(fr) - 1)])
    flat = float(np.exp(np.log(S + 1e-20).mean()) / (S.mean() + 1e-20))
    rms = float(np.sqrt((mono ** 2).mean()))
    zcr = float(((mono[:-1] * mono[1:]) < 0).mean())
    # pitch on a bounded window: np.correlate is O(n^2), so a 2 s grain at
    # 44,100 samples costs ~2 billion operations and the macro build managed
    # 42 grains in six minutes. 0.2 s is ample for pitch down to 80 Hz.
    p, clar = pitch_of(mono[: int(0.2 * sr)], sr)
    return [cent, roll, flat, med, rms, zcr, p, clar]


KEYS = ["centroid", "rolloff", "flatness", "median", "rms", "zcr", "pitch", "clarity"]


def write_grain(path, a, sr, fade_ms=3.0):
    k = max(1, int(sr * fade_ms / 1000.0))
    if 2 * k >= len(a):
        k = max(1, len(a) // 6)
    ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, k))
    a = a.copy()
    a[:k] *= ramp[:, None]
    a[-k:] *= ramp[::-1][:, None]

    # ATTENUATE, DO NOT CLIP.
    #
    # This line used to be a bare np.clip to +/-1.0, and it put HARD CLIPPING
    # INTO THE CORPUS. Measured 30 Aug on the corpora it produced:
    #     grains_lic_macro  55,910 samples pinned at full scale, 19.2% of grains,
    #                       3,360 flat-topped runs of 3+ consecutive samples
    #     grains_lic_ev        371 samples pinned, 10.4% of grains
    #     grains_lic_mid       337 samples pinned,  4.0% of grains
    # Consecutive samples at exactly full scale cannot arise any other way.
    #
    # FMA is MP3, and MP3 decodes routinely exceed +/-1.0 on intersample peaks -
    # loud masters especially. Everything over the line was flattened instead of
    # scaled, so the distortion was baked into the material at build time and
    # was present in every note the factory ever played. It survived the codec,
    # the browser, Icecast, BlackHole, the voice floor, cubic interpolation, a
    # doneAction repair, a 7 kHz lowpass and a 12 dB gain cut, because none of
    # those touch the samples on disk. Roberto heard it as "clipping" for hours
    # while ten measurements of the PLAYBACK CHAIN came back clean.
    #
    # Scaling only when a grain is actually over-range keeps the relative
    # loudness of everything else intact, which matters: the audibility measures
    # and the admission score both read grain level, and per-grain normalisation
    # would silently flatten that distribution.
    peak = float(np.abs(a).max())
    if peak > 0.999:
        a = a * (0.999 / peak)
    q = np.clip(a * 2 ** 31, -2 ** 31, 2 ** 31 - 1).astype("<i4")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(4)
        w.setframerate(sr)
        w.writeframes(q.tobytes())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ids", required=True)
    p.add_argument("--audio", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--grain", type=float, default=0.06)
    p.add_argument("--per-track", type=int, default=24,
                   help="consecutive onset-aligned grains per track")
    p.add_argument("--tracks", type=int, default=100)
    p.add_argument("--seed", type=int, default=20260823)
    p.add_argument("--max-transient", type=float, default=40.0,
                   help="SPIKE GATE. Local-anomaly ratio above which a grain "
                        "counts as impulsive; with --transient-frac this "
                        "thresholds the k-th largest grain score in the run "
                        "(k = ceil(frac*n): 6 of 24, 3 of 12, 2 of 8). "
                        "0 disables. Hand-picked, but measured and still the "
                        "better of the two -- see the gate comment")
    p.add_argument("--transient-frac", type=float, default=0.25,
                   help="reject the whole track if this fraction of its run "
                        "is impulsive")
    p.add_argument("--max-run-median", type=float, default=0.0,
                   help="FLOOR GATE, OFF BY DEFAULT. Reject a track when the "
                        "MEDIAN grain score across its run exceeds this. "
                        "-1 looks M* up per geometry in RUN_MEDIAN_THRESH; "
                        "0 disables. Detects a uniformly raised run rather than "
                        "isolated spikes. It did NOT beat the spike gate at a "
                        "matched false-rejection rate -- read the gate comment "
                        "before switching it on")
    a = p.parse_args()

    # Resolved before a single file is decoded, so an unknown geometry fails in
    # the first second rather than after an hour of building.
    max_run_median = (run_median_threshold(a.grain) if a.max_run_median < 0
                      else a.max_run_median)
    if max_run_median > 0:
        print(f"  FLOOR GATE ON: rejecting tracks whose run median exceeds "
              f"{max_run_median:.1f}"
              + ("  (M* for this geometry)" if a.max_run_median < 0 else ""))
    if a.max_transient <= 0 and max_run_median <= 0:
        print("  NO TRANSIENT GATE. Shellac crackle and impulsive damage will "
              "enter the corpus.")

    ids = [int(x.strip()) for x in open(a.ids) if x.strip().isdigit()]
    rng = random.Random(a.seed)
    rng.shuffle(ids)
    os.makedirs(a.out, exist_ok=True)

    n = int(a.grain * SR)
    manifest, desc, made, used, pitched, rejected = [], [], 0, 0, 0, 0
    rej_spike, rej_floor = 0, 0

    for tid in ids:
        if used >= a.tracks:
            break
        path = os.path.join(a.audio, f"{tid // 1000:03d}", f"{tid:06d}.mp3")
        if not os.path.exists(path):
            continue
        x = decode(path)
        if x is None:
            continue
        mono = x.mean(axis=1)
        on = onsets(mono, SR)
        on = on[(on > SR) & (on < len(mono) - n - 1)]
        if len(on) < a.per_track:
            continue
        # a CONSECUTIVE stretch of onsets, so adjacency survives
        s0 = rng.randrange(0, len(on) - a.per_track)
        batch = []
        for s in range(a.per_track):
            st = int(on[s0 + s])
            seg = x[st: st + n]
            if len(seg) < n:
                break
            batch.append((s, st, seg, analyse(seg.mean(axis=1), SR)))

        # TRANSIENT GATE. Some FMA sources carry impulsive noise that is not
        # music and not a bug in this code: the worst offenders in the 30 Aug
        # corpus were "Antique Phonograph Music Program" transfers, i.e. 78rpm
        # SHELLAC SURFACE CRACKLE, plus a few glitch-electronic tracks. In a
        # 60 ms grain a shellac pop is most of the event, and the factory then
        # plays it several times a second. Roberto heard it for hours as
        # "super short clipping sounds", and it survived every test of the
        # playback chain because the playback chain was innocent.
        #
        # The check is REJECT-BY-TRACK, not by grain, because grains are cut as
        # consecutive runs and continuity is what fixed the radio effect.
        # Punching holes in a run to drop individual grains would trade one
        # artefact for a worse one.
        #
        # ------------------------------------------------------------------
        # TWO GATES, AND WHY THE DEFAULT DID NOT MOVE (measured 1 Sept 2026)
        # ------------------------------------------------------------------
        # tools/transient_null.py, calibrating the spike gate against a clean
        # null, closed with a recommendation: shellac "does not produce rare
        # extremes, it raises the whole run", so "a run-median statistic would
        # be the right one". THAT RECOMMENDATION WAS TESTED AND IT DOES NOT
        # HOLD. The evidence it rested on was one draw: one grain run per
        # damaged track, cut from a random start, and a clean p99 taken over
        # 600 tracks. Both are unstable. Re-drawn at 2,500 clean tracks and 60
        # independent runs per damaged track (tools/transient_median_null.py):
        #
        #   * the clean macro run-median p99 moved from 173.4 to 101.3 on a
        #     different draw of the SAME pool -- outside its own bootstrap
        #     interval, so the number was sampling noise as much as signal;
        #   * the damaged tracks are not uniformly elevated either. 122539 at
        #     ev has a run median of 18.6 with nine of twenty-four grains over
        #     40: at 60 ms, crackle IS a spike, because grains are onset-
        #     aligned and most of them land between the pops. The raised-floor
        #     picture is a macro-geometry phenomenon and was generalised from
        #     macro to all three layers.
        #
        # Both rules are order statistics of the same run -- the spike gate
        # thresholds the k-th largest score, the floor gate the median -- so
        # they can be put on one ROC. Held at a MATCHED false-rejection rate on
        # 1,250 held-out clean tracks, detection on 420 damaged runs:
        #
        #     matched FRR      ev              mid             macro
        #                   spike  floor    spike  floor    spike  floor
        #        1%         29.5%  20.2%     5.2%   8.3%     2.1%   1.9%
        #        2%         34.5%  21.7%    19.8%  29.5%    32.4%  32.6%
        #        5%         43.1%  27.1%    54.8%  38.3%    61.7%  62.1%
        #
        # The floor gate wins nothing at ev, wins at mid only in a narrow band,
        # and ties at macro. Sweeping EVERY order statistic of the run
        # (tools/transient_quantile_sweep.py) says the same: at 2% FRR the best
        # quantile is the 4th largest at ev (39.8%) and at mid (34.5%), and at
        # macro the column is flat from j=2 to j=8. The median is never the
        # peak. So the statistic was not the problem.
        #
        # WHAT IS ACTUALLY WRONG WITH THE LIVE GATE IS ITS OPERATING POINT, NOT
        # ITS STATISTIC. One threshold of 40 across three geometries costs
        # 1.9% of clean tracks at ev, 4.0% at mid and 5.4% at macro. That is a
        # choice of how much undamaged material to discard, made by accident.
        # Choose it, per layer, and the same statistic will do.
        #
        # The floor gate is implemented and calibrated because it is the right
        # instrument for a uniformly degraded source and nothing else here
        # detects one, but it is OFF unless asked for, because it lost the
        # comparison it was proposed to win. Setting it does not disable the
        # spike gate: they are different failure shapes and either may fire.
        #
        # SENSITIVITY IS A LOWER BOUND EVERYWHERE ABOVE. .lab/notes/BISECTION.md
        # counts thirteen damaged tracks and names seven; the other six were
        # never written down. Resampling runs sharpens the per-track estimate,
        # it does not turn seven tracks into a population.
        # ------------------------------------------------------------------
        if batch and (a.max_transient > 0 or max_run_median > 0):
            # scored once, read twice; grain_score() is the expensive part
            gs = [grain_score(seg.mean(axis=1), SR)[0] for _, _, seg, _ in batch]

            if a.max_transient > 0:
                hot = sum(1 for v in gs if v > a.max_transient)
                if hot >= a.transient_frac * len(batch):
                    rejected += 1
                    rej_spike += 1
                    continue

            if max_run_median > 0 and float(np.median(gs)) > max_run_median:
                rejected += 1
                rej_floor += 1
                continue

        for s, st, seg, d in batch:
            if d[6] > 0:
                pitched += 1
            write_grain(os.path.join(a.out, f"g{made:02d}.wav"), seg, SR)
            manifest.append({"i": made, "track": tid, "seq": s, "run": used,
                             "onset": int(st)})
            desc.append(d)
            made += 1
        used += 1
        if used % 20 == 0:
            print(f"  {used} tracks, {made} grains, {pitched} pitched, {rejected} rejected", flush=True)

    D = np.array(desc)
    norm = np.zeros_like(D)
    for j in range(D.shape[1]):
        norm[D[:, j].argsort(), j] = np.linspace(0, 1, len(D))

    json.dump({
        "_comment": "Onset-aligned event grains with Archon's seven descriptors "
                    "plus pitch clarity. Grain SELECTION can now use pitch, which "
                    "no earlier corpus allowed.",
        "_keys": KEYS,
        "index": list(range(made)),
        "norm": {k: norm[:, j].round(5).tolist() for j, k in enumerate(KEYS)},
        # PITCH IN Hz, NOT ONLY AS A RANK.
        #
        # `norm` is a rank transform: every column becomes a uniform 0..1, which
        # is right for a distance metric and destroys the one thing pitch is
        # good for. The RATIO between two pitches is an interval; the ratio
        # between two ranks is nothing at all. A shadow run built an interval
        # table from the normalised column and got [1.0] -- and had that column
        # been better conditioned it would have produced a table that was
        # non-degenerate and meaningless, which is the worse outcome.
        #
        # pitch_of() already returns Hz and marks unpitched grains 0.0. This
        # keeps that value, so anything downstream that needs an interval has a
        # source. It costs one array and changes no existing key.
        "raw_hz": {"pitch": [round(float(x), 2)
                             for x in D[:, KEYS.index("pitch")]]},
        "raw_ranges": {k: [float(D[:, j].min()), float(D[:, j].max())]
                       for j, k in enumerate(KEYS)},
    }, open(os.path.join(a.out, "descriptors.json"), "w"))

    json.dump({
        "_comment": "Provenance, adjacency and the source onset of every grain.",
        "grain_seconds": a.grain, "run_len": a.per_track,
        "tracks": used, "grains": made,
        "total_seconds": round(made * a.grain, 1),
        "pitched": pitched,
        "tracks_rejected_impulsive": rejected,
        # Which gate fired, and at what settings. Without this a rebuilt corpus
        # cannot be told apart from one built under different thresholds, and
        # every measurement taken on it is uninterpretable a month later.
        "transient_gate": {
            "max_transient": a.max_transient,
            "transient_frac": a.transient_frac,
            "max_run_median": max_run_median,
            "rejected_spike": rej_spike,
            "rejected_run_median": rej_floor,
        },
        "manifest": manifest,
    }, open(os.path.join(a.out, "manifest.json"), "w"))

    print(f"\n{made} grains from {used} tracks -> {a.out}")
    print(f"  {a.grain * 1000:.0f} ms each, onset-aligned, "
          f"{made * a.grain:.0f} s total, {100 * pitched / max(1, made):.0f}% pitched")
    print(f"  {rejected} tracks rejected by the transient gate")
    if a.max_transient > 0:
        print(f"      {rej_spike} as SPIKY   (ratio > {a.max_transient:.0f} on "
              f">= {100 * a.transient_frac:.0f}% of the run)")
    if max_run_median > 0:
        print(f"      {rej_floor} as RAISED  (run median > {max_run_median:.1f})")


if __name__ == "__main__":
    main()
