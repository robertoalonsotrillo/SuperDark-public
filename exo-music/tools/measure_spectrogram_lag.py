#!/usr/bin/env python3
"""How far ahead of the sound does the picture run? Measure it, do not guess it.

The panel's spectrogram is computed at the splitter, BEFORE the MP3 encoder.
A listener hears the same audio after encoding, after Icecast's burst, and after
their own client buffer. So the image leads the sound, and the panel holds it
back by a fixed LAG_S to compensate. That constant was picked as "about fifteen
seconds" from the Icecast burst size, which is a guess dressed as a number.

This measures it. Capture the DELIVERED stream, compute its energy envelope at
the same hop the splitter uses, and cross-correlate against the energy envelope
of the published spectrogram. The lag that maximises the correlation is the true
offset between what the page draws and what the visitor hears.

    python3 tools/measure_spectrogram_lag.py --seconds 90
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request
import wave

import numpy as np

STATE = "https://stream.robertoalonsotrillo.com/state.json"
STREAM = "https://stream.robertoalonsotrillo.com/superdark.mp3"


def fetch_state():
    with urllib.request.urlopen(STATE + "?x=%d" % time.time(), timeout=20) as r:
        return json.load(r)


def capture(seconds, path):
    """Record the delivered stream, and return the wall-clock time at which the
    FIRST sample was received. That timestamp is the anchor for everything."""
    p = subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", STREAM,
         "-t", str(seconds), "-ac", "1", "-ar", "16000",
         "-c:a", "pcm_s16le", "-y", path])
    t0 = time.time()
    p.wait()
    return t0


def envelope(path, hop):
    with wave.open(path) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float)
    n = int(sr * hop)
    m = len(x) // n
    if m < 10:
        return None, sr
    e = np.abs(x[:m * n].reshape(m, n)).mean(axis=1)
    return e, sr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=90)
    a = ap.parse_args()

    before = fetch_state()
    sp0 = before.get("spectrogram")
    if not sp0:
        raise SystemExit("  no spectrogram in the published state")
    hop = sp0.get("hop", 0.18)

    print(f"\n  capturing {a.seconds:.0f}s of the delivered stream...")
    wav = "/tmp/lagcap.wav"
    t_start = capture(a.seconds, wav)
    after = fetch_state()
    sp = after.get("spectrogram")
    print(f"  captured; newest spectrogram column written at t={sp['t']:.1f}")

    env, sr = envelope(wav, hop)
    if env is None:
        raise SystemExit("  capture too short")
    # The delivered audio's envelope, in wall clock: sample i is at
    # t_start + i*hop (plus whatever ffmpeg's own startup cost, which is small
    # and shows up as part of the lag being measured).
    print(f"  {len(env)} audio frames at {hop}s")

    raw = np.frombuffer(base64.b64decode(sp["b64"]), dtype=np.uint8)
    grid = raw.reshape(sp["cols"], sp["bins"]).astype(float)
    # Broadband energy per column, the spectrogram's own envelope.
    senv = grid.mean(axis=1)
    # Column j was written at sp["t"] - (cols-1-j)*hop.
    scol_t = sp["t"] - (sp["cols"] - 1 - np.arange(sp["cols"])) * hop

    # Resample the spectrogram envelope onto the audio frames' timeline.
    aud_t = t_start + np.arange(len(env)) * hop
    keep = (aud_t >= scol_t[0]) & (aud_t <= scol_t[-1])
    if keep.sum() < 30:
        raise SystemExit("  the two records do not overlap in time; "
                         "capture for longer or check the clocks")
    aud_t, env = aud_t[keep], env[keep]

    def z(v):
        v = v - v.mean()
        s = v.std()
        return v / s if s > 1e-9 else v

    best = (None, -2)
    print()
    print(f"  {'lag (s)':>9} {'correlation':>12}")
    for lag in np.arange(-5, 40.001, 0.5):
        # A positive lag means the PICTURE leads: audio heard at time t
        # corresponds to a spectrogram column written at t - lag.
        s_at = np.interp(aud_t - lag, scol_t, senv)
        c = float(np.corrcoef(z(env), z(s_at))[0, 1])
        if c > best[1]:
            best = (float(lag), c)
        if abs(lag % 5) < 1e-6:
            print(f"  {lag:9.1f} {c:12.3f}")
    print()
    print(f"  BEST: the picture leads the sound by {best[0]:.1f} s "
          f"(correlation {best[1]:.3f})")
    if best[1] < 0.3:
        print("  Correlation is weak. Either the factory was near-silent for the")
        print("  capture, or the two are not measuring the same thing -- do not")
        print("  set a constant from this.")
    else:
        print(f"  Set LAG_S to {best[0]:.0f} in player.html.")
    os.unlink(wav)
    return 0


if __name__ == "__main__":
    sys.exit(main())
