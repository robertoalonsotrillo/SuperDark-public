#!/usr/bin/env python3
"""Measure every rung of the bisection ladder on ONE consistent instrument.

WHY A NEW DETECTOR
------------------
Ten measurements of the live sum came back clean while the sound was plainly
audible. Every one of them shared a blind spot:

  * the clip meter sampled Peak with A2K at control rate, 1 sample in 64;
  * the discontinuity tests compared against a 10 ms envelope, which is two
    orders of magnitude longer than the event being looked for;
  * audit_corpus_clicks.py's "reversing spike" test fired on any high-frequency
    content at all, so it could not distinguish a cymbal from a click, and
    its verdicts were therefore worthless in both directions.

A click is not "high-frequency energy". A click is high-frequency energy that
is LOCALLY ANOMALOUS -- far above the high-frequency background immediately
around it. So the detector here high-passes, takes a short envelope, and
divides by a running median of that envelope over 50 ms. A continuously bright
signal has ratio ~1 everywhere and scores zero, however bright it is. A 20-
sample transient against a quiet background scores enormous. That normalisation
is the whole point, and it is what the earlier detector lacked.

WHAT EACH NUMBER IS FOR
-----------------------
  peak/rms       gain staging, and whether the rung produced audio at all
  pinned         samples at full scale -- hard clipping in the file itself
  clicks/s       the transient rate, the thing being hunted
  worst ratio    how far above local background the worst transient sits
  hf frac        energy above 8 kHz, reported ONLY as context for clicks/s,
                 never as evidence on its own
  dc drift       mean offset, to test the doneAction:0 risk (a PlayBuf past
                 its end holding its last sample would step DC once per grain)

READ THE LADDER, NOT THE ROW. A single rung's clicks/s means little. The
question is where the number JUMPS, because each rung adds exactly one thing.
"""
import argparse
import glob
import os
import subprocess
import sys
import wave

import numpy as np

try:
    from scipy.signal import butter, sosfiltfilt, resample_poly
    from scipy.ndimage import median_filter
except ImportError:
    print("needs scipy: pip3 install scipy --break-system-packages", file=sys.stderr)
    raise


# ---------------------------------------------------------------- reading ---
def read_wav(path):
    """Return (mono float64 in [-1,1], sr, nchan). Handles int16/24/32."""
    with wave.open(path, "rb") as w:
        sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, "<i2").astype(np.float64) / 2 ** 15
    elif sw == 4:
        a = np.frombuffer(raw, "<i4").astype(np.float64) / 2 ** 31
    elif sw == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        v = (b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16))
        v[v >= 1 << 23] -= 1 << 24                      # sign-extend 24-bit
        a = v.astype(np.float64) / 2 ** 23
    else:
        raise ValueError(f"{path}: {sw*8}-bit not handled")
    a = a.reshape(-1, ch) if ch > 1 else a.reshape(-1, 1)
    return a.mean(axis=1), sr, ch


# --------------------------------------------------------------- measures ---
def click_stats(x, sr, hp_hz=8000.0, env_ms=0.5, med_ms=50.0, thresh=8.0):
    """Locally-anomalous transients per second.

    Normalising by a RUNNING MEDIAN of the high-passed envelope is what makes
    this a click detector rather than a brightness meter. Median, not mean, so
    that the clicks themselves do not raise the floor that is meant to expose
    them.
    """
    if len(x) < sr // 10:
        return 0.0, 0.0
    sos = butter(4, hp_hz / (sr / 2), btype="highpass", output="sos")
    hp = sosfiltfilt(sos, x)
    k = max(1, int(sr * env_ms / 1000))
    env = np.convolve(np.abs(hp), np.ones(k) / k, mode="same")
    m = max(3, int(sr * med_ms / 1000) | 1)
    floor = median_filter(env, size=m, mode="nearest")
    # a global floor stops division blowing up in true digital silence
    ratio = env / np.maximum(floor, 1e-6 + 0.02 * np.median(env))
    hot = ratio > thresh
    # count CONTIGUOUS regions, so one click is one event, not forty samples
    events = int(np.count_nonzero(hot[1:] & ~hot[:-1])) + int(hot[0])
    return events / (len(x) / sr), float(ratio.max())


def hf_fraction(x, sr, split=8000.0):
    S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / sr)
    tot = S.sum()
    return float(S[fr >= split].sum() / tot) if tot > 0 else 0.0


def measure(path):
    x, sr, ch = read_wav(path)
    peak = float(np.abs(x).max())
    rms = float(np.sqrt((x ** 2).mean()))
    pinned = int(np.count_nonzero(np.abs(x) >= 0.9995))
    cps, worst = click_stats(x, sr)
    return {
        "file": os.path.basename(path), "sr": sr, "ch": ch,
        "sec": len(x) / sr, "peak": peak, "rms": rms,
        "peak_db": 20 * np.log10(peak) if peak > 0 else -np.inf,
        "rms_db": 20 * np.log10(rms) if rms > 0 else -np.inf,
        "pinned": pinned, "clicks_s": cps, "worst": worst,
        "hf": hf_fraction(x, sr), "dc": float(x.mean()),
    }


# --------------------------------------------------------------------- R0 ---
def build_r0(grain_dir, out, n=64, sr_out=44100, sec=20.0):
    """R0: the raw grains, concatenated, NO ENGINE AT ALL.

    No PlayBuf, no envelope, no filter, no server. If the sound is already here
    it is in the material and nothing in SuperCollider can be blamed. Grains are
    butted end to end with no crossfade deliberately: this is the WORST CASE for
    material discontinuity, so a clean R0 is a strong result.
    """
    files = sorted(glob.glob(os.path.join(grain_dir, "g*.wav")))[:n]
    if not files:
        return None
    # RESAMPLE PROPERLY. The first version used linear interpolation to get
    # from 22050 to 44100, which is an unfiltered upsample: it manufactures
    # exactly the locally-anomalous high-frequency transients this report
    # exists to count, and R0 duly scored 4.30 clicks/s of my own making.
    # resample_poly applies the anti-imaging filter. Measuring an artefact of
    # the measurement is how the previous ten tests went wrong.
    segs = []
    for f in files:
        a, sr, _ = read_wav(f)
        if sr != sr_out:
            g = np.gcd(int(sr), int(sr_out))
            a = resample_poly(a, sr_out // g, sr // g)
        segs.append(a)
    y = np.concatenate(segs)
    while len(y) < int(sec * sr_out):
        y = np.concatenate([y, y])
    y = y[: int(sec * sr_out)]
    q = np.clip(y * 2 ** 23, -2 ** 23, 2 ** 23 - 1).astype("<i4")
    b = q.view(np.uint8).reshape(-1, 4)[:, :3].tobytes()
    with wave.open(out, "wb") as w:
        w.setnchannels(1); w.setsampwidth(3); w.setframerate(sr_out)
        w.writeframes(b)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True, help="stream/bisect")
    p.add_argument("--grains", help="grain dir, to build R0")
    a = p.parse_args()

    if a.grains:
        r0 = os.path.join(a.dir, "R0_raw_grains.wav")
        if build_r0(a.grains, r0):
            print(f"  built R0 from {a.grains}")

    rows = [measure(f) for f in sorted(glob.glob(os.path.join(a.dir, "R*.wav")))]
    if not rows:
        print("NO RENDERS FOUND", file=sys.stderr)
        return 1

    print()
    print(f"{'rung':28} {'sec':>5} {'peak dB':>8} {'rms dB':>8} "
          f"{'pinned':>7} {'clicks/s':>9} {'worst':>7} {'hf':>6} {'dc':>9}")
    print("-" * 96)
    for r in rows:
        print(f"{r['file'][:-4]:28} {r['sec']:5.1f} {r['peak_db']:8.2f} "
              f"{r['rms_db']:8.2f} {r['pinned']:7d} {r['clicks_s']:9.2f} "
              f"{r['worst']:7.1f} {r['hf']:6.3f} {r['dc']:+9.2e}")

    # SILENCE GUARD. Two runs of this ladder produced full-length files of pure
    # silence and reported success, because a failed buffer alloc is not an
    # error. Never present a rung without asserting it contains audio.
    dead = [r["file"] for r in rows if r["rms"] < 1e-6]
    print()
    if dead:
        print(f"  SILENT, THEREFORE MEANINGLESS: {', '.join(dead)}")
    else:
        print("  all rungs contain audio")

    # where does it jump
    print()
    prev = None
    for r in rows:
        if prev is not None:
            d = r["clicks_s"] - prev["clicks_s"]
            if abs(d) > 0.5:
                print(f"  {prev['file'][:-4]} -> {r['file'][:-4]}: "
                      f"clicks/s {prev['clicks_s']:.2f} -> {r['clicks_s']:.2f} "
                      f"({d:+.2f})")
        prev = r
    return 0


if __name__ == "__main__":
    sys.exit(main())
