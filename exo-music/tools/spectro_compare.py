#!/usr/bin/env python3
"""Comparative spectrogram for two renders of the SAME score.

WHY THIS IS A FAIR COMPARISON AND NOT TWO PICTURES SIDE BY SIDE
bisect_render.scd renders from a fixed Score: the same grains, in the same
order, at the same times, with the same envelopes. The only variable between
the two files is the corpus sample rate. So the two renders are time-aligned
and their DIFFERENCE is meaningful, which is not true of two arbitrary
recordings of a live factory. That is the whole reason the ladder is rendered
offline rather than captured from the stream.

THE LINE THAT MATTERS
The corpus is 22050 Hz, so by the sampling theorem the material contains
nothing above 11.025 kHz. That line is drawn on every panel. Energy above it
was manufactured by the playback chain, and the question is how much and where.

PANELS
  1,2  spectrograms, identical colour scale, so they can be read against
       each other rather than each against its own auto-scale
  3    difference in dB. Red is energy the 22 kHz corpus has that the 44 kHz
       one does not, i.e. what interpolation ADDED.
  4    mean spectrum, both overlaid, log frequency. The shelf above 11 kHz is
       the imaging; if it is absent this hypothesis is wrong.
  5    the loudest transient, time domain, both traces overlaid, so a click can
       be seen as a waveform rather than inferred from a statistic.
"""
import argparse
import os
import sys

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt                                    # noqa: E402
from matplotlib.gridspec import GridSpec                           # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bisect_report import read_wav                                 # noqa: E402

CORPUS_NYQ = 11025.0


def spectrogram(x, sr, n=2048, hop=512):
    frames = 1 + (len(x) - n) // hop
    w = np.hanning(n)
    S = np.empty((n // 2 + 1, frames))
    for i in range(frames):
        S[:, i] = np.abs(np.fft.rfft(x[i * hop:i * hop + n] * w))
    f = np.fft.rfftfreq(n, 1 / sr)
    t = np.arange(frames) * hop / sr
    return 20 * np.log10(S + 1e-10), f, t


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--a", required=True, help="22050-corpus render")
    p.add_argument("--b", required=True, help="44100-corpus render")
    p.add_argument("--label-a", default="corpus 22050 (as shipped)")
    p.add_argument("--label-b", default="corpus 44100 (pre-resampled)")
    p.add_argument("--out", required=True)
    a = p.parse_args()

    xa, sra, _ = read_wav(a.a)
    xb, srb, _ = read_wav(a.b)
    n = min(len(xa), len(xb))
    xa, xb = xa[:n], xb[:n]

    Sa, f, t = spectrogram(xa, sra)
    Sb, _, _ = spectrogram(xb, srb)
    D = Sa - Sb

    fig = plt.figure(figsize=(15, 15))
    gs = GridSpec(5, 1, height_ratios=[1, 1, 1, 0.85, 0.7], hspace=0.42)
    vmin, vmax = -110, -20

    for i, (S, lab) in enumerate(((Sa, a.label_a), (Sb, a.label_b))):
        ax = fig.add_subplot(gs[i])
        im = ax.pcolormesh(t, f / 1000, S, vmin=vmin, vmax=vmax,
                           shading="auto", cmap="magma")
        ax.axhline(CORPUS_NYQ / 1000, color="cyan", lw=1.2, ls="--")
        ax.text(0.4, CORPUS_NYQ / 1000 + 0.4, "11.025 kHz — corpus Nyquist; "
                "nothing above this came from the music",
                color="cyan", fontsize=8)
        ax.set_ylabel("kHz"); ax.set_title(lab, fontsize=11, loc="left")
        ax.set_ylim(0, sra / 2000)
        fig.colorbar(im, ax=ax, pad=0.01, label="dB")

    ax = fig.add_subplot(gs[2])
    m = np.abs(D).max() * 0.6 or 1
    im = ax.pcolormesh(t, f / 1000, D, vmin=-m, vmax=m, shading="auto", cmap="RdBu_r")
    ax.axhline(CORPUS_NYQ / 1000, color="k", lw=1.2, ls="--")
    ax.set_ylabel("kHz"); ax.set_ylim(0, sra / 2000)
    ax.set_title("difference: 22050 minus 44100.  RED = energy interpolation ADDED",
                 fontsize=11, loc="left")
    fig.colorbar(im, ax=ax, pad=0.01, label="dB")

    # mean spectrum
    ax = fig.add_subplot(gs[3])
    for S, lab, c in ((Sa, a.label_a, "crimson"), (Sb, a.label_b, "navy")):
        lin = 10 ** (S / 20)
        ax.semilogx(f[1:], 20 * np.log10(lin[1:].mean(axis=1) + 1e-10),
                    label=lab, color=c, lw=1.3)
    ax.axvline(CORPUS_NYQ, color="k", ls="--", lw=1.2)
    ax.text(CORPUS_NYQ * 1.04, ax.get_ylim()[0] + 4, "11.025 kHz", fontsize=9)
    ax.set_xlabel("Hz"); ax.set_ylabel("dB"); ax.legend(fontsize=9)
    ax.set_title("mean spectrum — the shelf above 11 kHz is the imaging",
                 fontsize=11, loc="left")
    ax.grid(alpha=0.3, which="both")

    # loudest transient, time domain
    ax = fig.add_subplot(gs[4])
    hp = xa - np.convolve(xa, np.ones(64) / 64, mode="same")   # crude HF emphasis
    c = int(np.argmax(np.abs(hp)))
    lo, hi = max(0, c - 400), min(n, c + 400)
    tt = (np.arange(lo, hi) - c) / sra * 1000
    ax.plot(tt, xa[lo:hi], color="crimson", lw=1.0, label=a.label_a)
    ax.plot(tt, xb[lo:hi], color="navy", lw=1.0, alpha=0.8, label=a.label_b)
    ax.set_xlabel("ms around the loudest transient"); ax.set_ylabel("amplitude")
    ax.legend(fontsize=9); ax.grid(alpha=0.3)
    ax.set_title("the loudest transient, waveform", fontsize=11, loc="left")

    fig.suptitle("Same score, same grains, same code. Only the corpus sample rate differs.",
                 fontsize=13, y=0.995)
    fig.savefig(a.out, dpi=110, bbox_inches="tight")

    # numbers to go with the picture
    def band(x, sr):
        S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        fr = np.fft.rfftfreq(len(x), 1 / sr)
        return float(S[fr > CORPUS_NYQ].sum() / max(S.sum(), 1e-30))
    print(f"  wrote {a.out}")
    print(f"  energy above 11.025 kHz, fraction of total:")
    print(f"    {a.label_a:32} {band(xa, sra):.3e}")
    print(f"    {a.label_b:32} {band(xb, srb):.3e}")
    r = band(xa, sra) / max(band(xb, srb), 1e-30)
    print(f"    ratio {r:.1f}x  ({10*np.log10(r):.1f} dB more above the corpus Nyquist)")


if __name__ == "__main__":
    main()
