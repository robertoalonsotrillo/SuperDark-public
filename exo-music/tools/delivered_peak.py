#!/usr/bin/env python3
"""The peak of the signal a LISTENER receives, which m3_no_clipping cannot see.

THE HOLE THIS EXISTS TO FILL. Measured over the hour of 3 Sept 17:41-18:42, the
delivered stream peaked at 1.043 -- above full scale -- while m3_no_clipping
reported 0.0 in every one of 410 windows. Both are correct and that is the
problem. The limiter holds the SAMPLE peak at its ceiling and m3 measures that
signal; the MP3 encoder then reconstructs a waveform whose INTERSAMPLE peaks
exceed the samples it was handed, and nothing in the factory looks at the result.

m3 is the NEVER-TOLERATED clause. It is the one that stopped the factory on
2 Sept. A never-tolerated bound that is blind on the side the listener is
actually on is a hole in the governance layer.

This measures the delivered mount and writes the result where the charter's
scorer can read it. It does not itself constitute a metric: adopting it as one
is a governance act and belongs in charter_proposals.jsonl, not in a tool.

    python3 tools/delivered_peak.py --seconds 120
    python3 tools/delivered_peak.py --file /tmp/hour/hour.mp3
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time

import numpy as np

URL = "https://stream.robertoalonsotrillo.com/superdark.mp3"
OUT = "/tmp/superdark_delivered_peak.json"


def decode(path, sr=44100):
    raw = tempfile.mktemp(suffix=".f32")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path,
                    "-ac", "1", "-ar", str(sr), "-f", "f32le", raw], check=True)
    x = np.fromfile(raw, dtype="<f4")
    try:
        os.unlink(raw)
    except OSError:
        pass
    return x


def true_peak(x, sr=44100, up=4):
    """Sample peak understates what a converter reconstructs between samples.

    4x oversampling is the ITU-R BS.1770 minimum for a true-peak reading. It is
    approximate -- a proper meter uses a longer filter -- and it is far closer to
    what a listener's DAC produces than the sample maximum, which is the whole
    point: the factory has been reading the sample maximum and calling it peak.

    BLOCKWISE, because an hour is 162 million samples and one FFT of that at 4x
    is several GB of complex128. Overlapping blocks so a peak landing on a
    boundary is not missed by the window either side of it.
    """
    n = len(x)
    if n < 64:
        return float(np.abs(x).max() if n else 0.0)
    B, OV = 1 << 16, 1 << 10
    best = 0.0
    for s in range(0, n, B - OV):
        seg = x[s:s + B]
        if len(seg) < 64:
            break
        X = np.fft.rfft(seg)
        Y = np.zeros(len(X) * up, dtype=complex)
        Y[:len(X)] = X * up
        y = np.fft.irfft(Y, n=len(seg) * up)
        m = float(np.abs(y).max())
        if m > best:
            best = m
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=int, default=120)
    ap.add_argument("--file", default=None, help="measure a capture instead")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    if a.file:
        path, took = a.file, None
    else:
        path = tempfile.mktemp(suffix=".mp3")
        t0 = time.time()
        subprocess.run(["curl", "-s", "--max-time", str(a.seconds + 10),
                        "-o", path, URL], check=False)
        took = time.time() - t0
    if not os.path.exists(path) or os.path.getsize(path) < 10000:
        print("  no audio captured", file=sys.stderr)
        return 2

    x = decode(path)
    sp = float(np.abs(x).max())
    tp = true_peak(x)
    rms = float(x.std())
    over = int((np.abs(x) >= 0.999).sum())

    def db(v):
        return 20 * np.log10(v) if v > 0 else -999

    print()
    print(f"  {len(x) / 44100:.0f} s of the delivered stream"
          + (f", captured in {took:.0f} s" if took else f" from {os.path.basename(path)}"))
    print(f"    sample peak  {sp:6.3f}   {db(sp):+6.2f} dBFS")
    print(f"    TRUE peak    {tp:6.3f}   {db(tp):+6.2f} dBTP   (4x oversampled)")
    print(f"    rms          {rms:6.4f}   {db(rms):+6.2f} dBFS")
    print(f"    samples at or above full scale: {over}")
    print()
    if tp > 1.0:
        print("    OVER FULL SCALE. A converter reconstructing this will clip,")
        print("    and m3_no_clipping cannot see it because it reads the signal")
        print("    BEFORE the encoder. Lower master_ceiling until this sits")
        print("    below 1.0; each 1 dB of ceiling buys about 1 dB here.")
    else:
        print("    Below full scale. This is the side of the encoder the")
        print("    listener is on, and it is the reading that was missing.")

    rec = {"t": time.time(), "seconds": len(x) / 44100,
           "sample_peak": round(sp, 4), "true_peak": round(tp, 4),
           "true_peak_dbtp": round(db(tp), 2), "rms": round(rms, 5),
           "over_full_scale": over, "source": os.path.basename(path)}
    json.dump(rec, open(a.out, "w"), indent=2)
    print(f"\n    written to {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
