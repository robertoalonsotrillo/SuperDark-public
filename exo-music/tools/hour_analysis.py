#!/usr/bin/env python3
"""An hour of the delivered stream, read for FRAGMENTATION AND VARIABILITY.

WHY AN HOUR AND NOT TWO MINUTES. Every measurement in this project so far has
been taken over one to three minutes, and every one of them has been consistent
with a factory that is doing the same thing forever. Roberto, 3 Sept: "I dare
you to record a 1h spectrogram and look at the predominant behaviours
(fragmentation at different levels) and variability." A short window cannot
distinguish a factory that varies on a ten-minute timescale from one that does
not vary at all, and the whole claim of the three-slot architecture is about
timescales longer than a window.

WHAT IT MEASURES, and each is a question the ear has already asked:

  FRAGMENTATION AT THREE LEVELS. Sounding-run and gap lengths, bucketed at the
  three grain scales (0.06 / 0.35 / 0.8 s) so "fragmentary" becomes a number per
  layer instead of a verdict. A factory whose runs pile up below 0.35 s is
  fragmentary however its slots are configured.

  HELD PITCH. How long the dominant partial stays within half a semitone. This
  is the melodic claim and it has failed every test so far: 0.03 s median, zero
  runs above half a second.

  VARIABILITY ACROSS THE HOUR. The same statistics computed per minute, then the
  spread of those. A factory that produces identical minutes for sixty minutes
  is not varying, whatever any single minute looks like. This is the measurement
  the short captures could not make.

  SPECTRAL OCCUPANCY over time, as a picture. Sixty minutes at one column per
  second, log frequency, so drift into a band or out of one is visible.

    python3 tools/hour_analysis.py /tmp/hour/hour.mp3 --png /tmp/hour/hour.png
"""
import argparse
import os
import subprocess
import sys

import numpy as np

SR = 22050
GRAIN = (0.06, 0.35, 0.80)


def decode(path):
    raw = path + ".f32"
    if not os.path.exists(raw) or os.path.getmtime(raw) < os.path.getmtime(path):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path,
                        "-ac", "1", "-ar", str(SR), "-f", "f32le", raw],
                       check=True)
    return np.fromfile(raw, dtype="<f4")


def runs_of(mask, hop):
    d = np.diff(np.concatenate(([0], mask.view(np.int8), [0])))
    return (np.where(d == -1)[0] - np.where(d == 1)[0]) * hop


def frag(x, sr=SR):
    """Sounding runs and gaps, and how they distribute across the grain scales."""
    H = int(sr * 0.02)
    env = np.sqrt((x[:len(x) // H * H].reshape(-1, H) ** 2).mean(1))
    mx = np.percentile(env, 99.5)
    quiet = env < mx * 0.05
    g, s = runs_of(quiet, 0.02), runs_of(~quiet, 0.02)
    return env, s, g


def held_pitch(x, sr=SR):
    N, H = 1024, 256
    n = (len(x) - N) // H
    if n < 4:
        return np.array([0.0])
    idx = np.arange(N)[None, :] + H * np.arange(n)[:, None]
    S = np.abs(np.fft.rfft(x[idx] * np.hanning(N), axis=1))
    f = np.fft.rfftfreq(N, 1 / sr)
    lo, hi = np.searchsorted(f, 80), np.searchsorted(f, 2100)
    pk = lo + S[:, lo:hi].argmax(1)
    f0, amp = f[pk], S[np.arange(n), pk]
    live = amp > np.percentile(amp, 25)
    out, cur = [], 1
    for i in range(1, n):
        # half a semitone: the threshold below which a listener hears one note
        if live[i] and live[i - 1] and abs(np.log2(f0[i] / max(f0[i - 1], 1))) < 0.043:
            cur += 1
        else:
            if cur > 1:
                out.append(cur * H / sr)
            cur = 1
    return np.array(out) if out else np.array([0.0])


def bucket(runs):
    """Which grain scale does the material sit at? The layer names are the point."""
    b = [(runs < GRAIN[1]).sum(), ((runs >= GRAIN[1]) & (runs < GRAIN[2])).sum(),
         ((runs >= GRAIN[2]) & (runs < 4.0)).sum(), (runs >= 4.0).sum()]
    t = max(1, sum(b))
    return [100 * v / t for v in b]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("audio")
    ap.add_argument("--png", default=None)
    a = ap.parse_args()

    x = decode(a.audio)
    dur = len(x) / SR
    print()
    print(f"  {dur / 60:.1f} minutes of the delivered stream")
    print(f"  rms {x.std():.5f} ({20 * np.log10(x.std() + 1e-12):.1f} dBFS)  "
          f"peak {np.abs(x).max():.3f}")

    env, s, g = frag(x)
    hp = held_pitch(x)
    print()
    print("  FRAGMENTATION, whole hour")
    print(f"    sounding runs n={len(s):6}  median {np.median(s):.2f}s  "
          f"p90 {np.percentile(s, 90):.2f}s  max {s.max():.2f}s")
    print(f"    gaps          n={len(g):6}  median {np.median(g):.2f}s  "
          f"p90 {np.percentile(g, 90):.2f}s  max {g.max():.2f}s")
    bs = bucket(s)
    print(f"    runs by scale:  <0.35s {bs[0]:5.1f}%   0.35-0.8s {bs[1]:5.1f}%   "
          f"0.8-4s {bs[2]:5.1f}%   >4s {bs[3]:5.1f}%")
    print()
    print("  HELD PITCH, whole hour")
    print(f"    stable runs n={len(hp):6}  median {np.median(hp):.2f}s  "
          f"p90 {np.percentile(hp, 90):.2f}s  max {hp.max():.2f}s")
    for t in (0.5, 1.0, 2.0, 4.0):
        sel = hp >= t
        print(f"      >= {t}s : {sel.sum():5} runs, "
              f"{100 * hp[sel].sum() / max(hp.sum(), 1e-9):5.1f}% of sounding time")

    # ---- VARIABILITY: the same statistics minute by minute -----------------
    print()
    print("  VARIABILITY ACROSS THE HOUR (per minute)")
    mins = int(dur // 60)
    rows = []
    for m in range(mins):
        seg = x[m * 60 * SR:(m + 1) * 60 * SR]
        e, ss, gg = frag(seg)
        h = held_pitch(seg)
        rows.append((float(np.sqrt((seg ** 2).mean())),
                     float(np.median(ss)) if len(ss) else 0.0,
                     float((e < np.percentile(e, 99.5) * 0.05).mean()),
                     float(np.median(h)) if len(h) else 0.0,
                     float(h.max()) if len(h) else 0.0))
    R = np.array(rows)
    names = ["rms", "median run s", "quiet frac", "median held s", "max held s"]
    print(f"    {'':16}{'min':>9}{'median':>9}{'max':>9}{'CV':>8}")
    for i, nm in enumerate(names):
        c = R[:, i]
        cv = c.std() / max(abs(c.mean()), 1e-9)
        print(f"    {nm:16}{c.min():9.3f}{np.median(c):9.3f}{c.max():9.3f}{cv:8.2f}")
    print()
    print("    CV is the coefficient of variation across the sixty minutes. Near")
    print("    zero means every minute is the same minute -- which is the thing a")
    print("    two-minute capture can never tell you, and the thing the three-slot")
    print("    architecture claims to have fixed.")

    if a.png:
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt
            N, H = 2048, SR  # one column per second
            n = (len(x) - N) // H
            idx = np.arange(N)[None, :] + H * np.arange(n)[:, None]
            S = np.abs(np.fft.rfft(x[idx] * np.hanning(N), axis=1)).T
            f = np.fft.rfftfreq(N, 1 / SR)
            keep = (f > 40) & (f < 10000)
            D = 20 * np.log10(S[keep] + 1e-8)
            fig, ax = plt.subplots(figsize=(20, 6), dpi=110)
            ax.imshow(D, aspect="auto", origin="lower", cmap="magma",
                      extent=[0, n / 60, 0, keep.sum()],
                      vmin=np.percentile(D, 40), vmax=np.percentile(D, 99.7))
            yt = [50, 100, 200, 400, 800, 1600, 3200, 6400]
            fk = f[keep]
            ax.set_yticks([np.searchsorted(fk, v) for v in yt])
            ax.set_yticklabels([str(v) for v in yt])
            ax.set_xlabel("minutes"); ax.set_ylabel("Hz")
            ax.set_title(f"SuperDark, {dur/60:.0f} minutes of the delivered stream, "
                         f"1 column per second")
            fig.tight_layout(); fig.savefig(a.png)
            print(f"\n  spectrogram written to {a.png}")
        except Exception as e:
            print(f"\n  no png ({e})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
