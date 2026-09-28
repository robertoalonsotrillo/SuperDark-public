#!/usr/bin/env python3
"""
Produce events.csv from a driving input, in Archon's Behavior.receiver order.

Replaces the SuperCollider NRT descriptor pass of run 06. Same seven quantities,
computed directly, which removes a round trip through /tmp/an/descriptors.wav and
makes the onset threshold a visible parameter instead of a buried default.

Column order is read from BehaviorTrimmed.sc:452 `receiver`, which appends
args[1..7] as onset, offset, cent, rolloff, flat, rms, pitch. Getting this wrong
is silent: every value still parses, and the behaviour model simply reads
rolloff as centroid for the rest of the run.

Rolloff matches Archon's `SpecPcile.kr(chain, 0.5)`, which is the median
frequency and NOT the conventional 85% rolloff. Pitch is emitted as a note name
because render.scd calls `.asSymbol` on it, and "unpitched" where the frame
carries no stable partial.

Usage:  analyse_input.py <wav> <out.csv> [duration_s] [threshold]
"""
import csv
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

FRAME, HOP = 2048, 512
NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def note_name(freq):
    if freq <= 0:
        return "unpitched"
    midi = 69 + 12 * np.log2(freq / 440.0)
    if not np.isfinite(midi) or midi < 12 or midi > 120:
        return "unpitched"
    m = int(round(midi))
    return f"{NOTES[m % 12]}{m // 12 - 1}"


def main():
    path, out = sys.argv[1], sys.argv[2]
    dur = float(sys.argv[3]) if len(sys.argv) > 3 else 60.0
    thresh = float(sys.argv[4]) if len(sys.argv) > 4 else 0.01

    sr, data = wavfile.read(path)
    x = data.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.issubdtype(data.dtype, np.integer):
        x = x / float(np.iinfo(data.dtype).max)
    if sr != 44100:
        from math import gcd
        g = gcd(int(sr), 44100)
        x = resample_poly(x, 44100 // g, sr // g)
        sr = 44100
    x = x[: int(dur * sr)]

    win = np.hanning(FRAME)
    freqs = np.fft.rfftfreq(FRAME, 1 / sr)
    times, amps, cents, rolls, flats, pitches = [], [], [], [], [], []

    for i in range(0, len(x) - FRAME, HOP):
        seg = x[i:i + FRAME] * win
        rms = float(np.sqrt((seg ** 2).mean()))
        spec = np.abs(np.fft.rfft(seg)) + 1e-12
        total = spec.sum()
        cent = float((freqs * spec).sum() / total)
        # SpecPcile 0.5: the frequency below which half the energy lies
        cum = np.cumsum(spec)
        roll = float(freqs[int(np.searchsorted(cum, total * 0.5))])
        flat = float(np.exp(np.log(spec).mean()) / (spec.mean()))
        peak_bin = int(np.argmax(spec))
        f0 = float(freqs[peak_bin]) if spec[peak_bin] > spec.mean() * 8 else 0.0
        times.append(i / sr)
        amps.append(rms)
        cents.append(cent)
        rolls.append(roll)
        flats.append(flat)
        pitches.append(f0)

    amps = np.array(amps)
    peak = amps.max()
    live = amps > (peak * thresh)

    # Amplitude gating assumes the input falls silent between events. That holds
    # for the voice recording this pipeline was built on (0.3% silent, but with
    # gaps at the gate) and fails completely on continuous music: corelli.wav is
    # 5.2% silent and yields THREE events in 60 s, one of them 18.5 seconds long.
    #
    # Archon's own analysis has this assumption baked in, which is why the
    # project has been driven by voice. Since the stated aim is to engage any
    # musical style from any input, the detector has to work on material that
    # never stops. Spectral flux with an adaptive median threshold is the
    # standard answer (Dixon, 2006, "Onset detection revisited").
    if len(events_from_flux := []) == 0 and live.mean() > 0.90:
        spec_prev = None
        flux = []
        for i in range(0, len(x) - FRAME, HOP):
            seg = x[i:i + FRAME] * win
            spec = np.abs(np.fft.rfft(seg))
            if spec_prev is not None:
                # half-wave rectified: only increases in energy count as onsets
                flux.append(float(np.maximum(spec - spec_prev, 0).sum()))
            else:
                flux.append(0.0)
            spec_prev = spec
        flux = np.array(flux)
        if flux.max() > 0:
            flux = flux / flux.max()
        # adaptive threshold: local median over ~0.5 s plus a fixed margin
        w = max(3, int(0.5 * sr / HOP))
        pad = np.pad(flux, (w // 2, w // 2), mode="edge")
        local = np.array([np.median(pad[i:i + w]) for i in range(len(flux))])
        onset = (flux > local + thresh) & (flux > np.roll(flux, 1)) \
                & (flux > np.roll(flux, -1))
        idx = np.flatnonzero(onset)
        # each event runs from its onset to the next
        live = np.zeros(len(flux), dtype=bool)
        events_flux = [(idx[k], idx[k + 1]) for k in range(len(idx) - 1)
                       if idx[k + 1] - idx[k] >= 2]
        print(f"  continuous input detected ({live.size and (amps > peak*thresh).mean():.0%} "
              f"above gate): switched to spectral flux, {len(events_flux)} onsets")
        rows = []
        for a, b in events_flux:
            sl = slice(a, b)
            f0s = [f for f in pitches[a:b] if f > 0]
            rows.append([
                round(times[a], 6), round(times[b - 1], 6),
                round(float(np.mean(cents[sl])), 4),
                round(float(np.mean(rolls[sl])), 4),
                round(float(np.mean(flats[sl])), 6),
                round(float(np.mean(amps[sl])), 6),
                note_name(float(np.median(f0s)) if f0s else 0.0),
            ])
        with open(out, "w", newline="") as fh:
            csv.writer(fh).writerows(rows)
        pitched = sum(1 for r in rows if r[6] != "unpitched")
        span = rows[-1][1] - rows[0][0] if rows else 0
        print(f"{len(rows)} events over {span:.1f}s "
              f"({len(rows)/max(span,1e-9):.1f}/s), "
              f"{pitched} pitched ({pitched/max(len(rows),1):.0%})")
        print(f"  mean event {np.mean([r[1]-r[0] for r in rows])*1000:.0f} ms")
        return

    # Pair rising and falling edges. Run 06's pairing assumed the signal starts
    # below threshold; if it does not, every pair fails and all events are
    # discarded silently. Opening the state as "inside an event" avoids that.
    events, start = [], (0 if live[0] else None)
    for k in range(1, len(live)):
        if live[k] and not live[k - 1]:
            start = k
        elif not live[k] and live[k - 1] and start is not None:
            if k - start >= 2:
                events.append((start, k))
            start = None
    if start is not None and len(live) - start >= 2:
        events.append((start, len(live)))

    rows = []
    for a, b in events:
        sl = slice(a, b)
        f0s = [f for f in pitches[a:b] if f > 0]
        rows.append([
            round(times[a], 6), round(times[b - 1], 6),
            round(float(np.mean(cents[sl])), 4),
            round(float(np.mean(rolls[sl])), 4),
            round(float(np.mean(flats[sl])), 6),
            round(float(np.mean(amps[sl])), 6),
            note_name(float(np.median(f0s)) if f0s else 0.0),
        ])

    with open(out, "w", newline="") as fh:
        csv.writer(fh).writerows(rows)

    pitched = sum(1 for r in rows if r[6] != "unpitched")
    span = rows[-1][1] - rows[0][0] if rows else 0
    print(f"{len(rows)} events over {span:.1f}s "
          f"({len(rows)/max(span,1e-9):.1f}/s), "
          f"{pitched} pitched ({pitched/max(len(rows),1):.0%}), "
          f"threshold {thresh}")
    print(f"  mean event {np.mean([r[1]-r[0] for r in rows])*1000:.0f} ms, "
          f"coverage {sum(r[1]-r[0] for r in rows)/max(span,1e-9):.0%}")


if __name__ == "__main__":
    main()
