#!/usr/bin/env python3
"""Can the click detector see a numerical blow-up? (#103)

THE UNRESOLVED NOTE THIS ANSWERS
`2026-09-16_numerical_blowups.md` says the blow-up finding "does not sit
comfortably beside the record from 1 September, which declared clicking solved at
1.01 clicks/s on the delivered stream. Either that measurement did not cover a
blow-up event, or the rate has changed, or the two are measuring different
things. Unresolved."

Three hypotheses, and the third is decidable without any archaeology: run the
detector, unchanged, against audio containing blow-ups of known shape and see
whether it counts them.

WHAT THE DETECTOR IS (bisect_report.click_stats, read from the source)
  highpass 8 kHz -> 0.5 ms envelope -> divide by a 50 ms running median ->
  flag where the ratio exceeds 8 -> count contiguous regions.

So it is a detector of LOCALLY ANOMALOUS HIGH-FREQUENCY energy. That is the
right instrument for a click, which is broadband by nature. Whether it is the
right instrument for a 13 ms band-limited excursion is exactly the question, and
the highpass is where the doubt lives.

INJECTION, NOT ARCHAEOLOGY. Bursts of known shape are added to real delivered
audio and the detector is run before and after. A burst it does not count is a
burst the 1 September measurement could not have counted either.

  python3 tools/test_click_detector_sees_blowups.py
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from bisect_report import click_stats                       # noqa: E402

SR = 44100
SEG = "/Volumes/FMA/superdark/segments"


def real_audio(seconds=30.0):
    """A stretch of genuinely delivered audio, so the floor is the real floor."""
    import wave
    files = sorted(f for f in os.listdir(SEG) if f.endswith(".wav"))
    if not files:
        return None, "no segments on the SSD"
    path = os.path.join(SEG, files[len(files) // 2])
    try:
        with wave.open(path) as w:
            ch, sw, sr, n = (w.getnchannels(), w.getsampwidth(),
                             w.getframerate(), w.getnframes())
            raw = w.readframes(min(n, int(sr * seconds)))
    except Exception as e:                                   # noqa: BLE001
        return None, f"{type(e).__name__}: {e}"
    if sw == 2:
        a = np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0
    elif sw == 4:
        a = np.frombuffer(raw, "<i4").astype(np.float64) / 2 ** 31
    else:
        return None, f"sample width {sw}"
    a = a[:len(a) // ch * ch].reshape(-1, ch).mean(1)
    return (a, os.path.basename(path)) if len(a) > sr else (None, "too short")


def synthetic_floor(seconds=30.0):
    """Fallback: pink-ish noise at the factory's measured level (m2 ~ 0.06)."""
    rng = np.random.default_rng(20260917)
    n = int(SR * seconds)
    w = rng.standard_normal(n)
    b = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1 / SR)
    b[1:] /= np.sqrt(f[1:])
    x = np.fft.irfft(b, n)
    return x / np.sqrt((x ** 2).mean()) * 0.06


def inject(x, kind, ms=13.0, n_bursts=10, amp=1.0):
    """Add n_bursts of `kind`, each `ms` long, at even spacing."""
    y = x.copy()
    k = int(SR * ms / 1000)
    rng = np.random.default_rng(7)
    step = len(x) // (n_bursts + 1)
    for i in range(1, n_bursts + 1):
        a = i * step
        if a + k >= len(y):
            break
        t = np.arange(k) / SR
        if kind == "broadband":
            b = rng.standard_normal(k)
            b /= np.abs(b).max()
        elif kind == "low_200hz":
            b = np.sin(2 * np.pi * 200 * t)
        elif kind == "mid_1khz":
            b = np.sin(2 * np.pi * 1000 * t)
        elif kind == "high_10khz":
            b = np.sin(2 * np.pi * 10000 * t)
        elif kind == "dc_step":
            b = np.ones(k)
        else:
            raise ValueError(kind)
        # a hard-edged burst, as a clipped excursion arrives
        y[a:a + k] = np.clip(b * amp, -1.0, 1.0)
    return y


def main():
    base, src = real_audio()
    if base is None:
        print(f"  (no delivered audio: {src}; using a synthetic floor)")
        base, src = synthetic_floor(), "synthetic pink noise at 0.06 rms"
    print(f"\n  floor: {src}, {len(base)/SR:.1f}s, "
          f"rms {np.sqrt((base**2).mean()):.4f}, peak {np.abs(base).max():.3f}")

    b_cps, b_worst = click_stats(base, SR)
    print(f"\n  BASELINE (no injection)   {b_cps:6.2f} clicks/s   worst ratio {b_worst:8.1f}")
    print("\n  Ten 13 ms full-scale bursts injected into that same audio:")
    print(f"  {'burst':<14}{'clicks/s':>10}{'delta':>9}{'worst':>11}   detected?")
    print("  " + "-" * 62)

    verdict = {}
    for kind in ("broadband", "high_10khz", "mid_1khz", "low_200hz", "dc_step"):
        y = inject(base, kind)
        cps, worst = click_stats(y, SR)
        d = cps - b_cps
        # ten bursts in ~30 s is ~0.33/s; call it detected if most are counted
        seen = d > 0.15
        verdict[kind] = seen
        print(f"  {kind:<14}{cps:>10.2f}{d:>+9.2f}{worst:>11.1f}   "
              f"{'yes' if seen else 'NO'}")

    print("\n  What this means for the 1 September record:")
    if all(verdict.values()):
        print("    The detector counts every burst shape tested, including a")
        print("    band-limited low-frequency one. So '1.01 clicks/s, clean'")
        print("    was NOT blind to blow-ups: either that audio contained none,")
        print("    or the rate genuinely changed. Hypothesis 3 is refuted.")
    elif not verdict["low_200hz"] and verdict["broadband"]:
        print("    The detector counts broadband bursts and MISSES low-frequency")
        print("    ones, because it high-passes at 8 kHz before looking. A")
        print("    blow-up whose energy sits below that is invisible to it.")
        print("    '1.01 clicks/s, clean' therefore says nothing about blow-ups,")
        print("    and the two measurements were never in conflict: they were")
        print("    measuring different things. Hypothesis 3 is CONFIRMED.")
    else:
        print("    Mixed: see the table. The detector's sensitivity depends on")
        print("    the burst's spectrum, so 'clean' is conditional on what the")
        print("    blow-ups actually contained.")
    print()


if __name__ == "__main__":
    main()
