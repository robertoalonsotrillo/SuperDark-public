#!/usr/bin/env python3
"""Click rate on a captured stream, without bisect_report's fragile reader.

bisect_report.read_wav infers channel count in a way that raises "cannot reshape
array of size N into shape (2)" on a file that is still being written, which is
exactly what a live stream capture is. The detector itself is fine; only the
loader is. This wraps the same click_stats with a loader that reads the header
and trims to whole frames.

    python3 tools/stream_click_rate.py /tmp/clicks_fifo.wav
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bisect_report import click_stats                       # noqa: E402


def load(path):
    with wave.open(path) as w:
        ch, sw, sr, n = (w.getnchannels(), w.getsampwidth(),
                         w.getframerate(), w.getnframes())
        raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 4:
        a = np.frombuffer(raw, dtype="<i4").astype(np.float32) / (2 ** 31)
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        a = (((b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)) << 8 >> 8)
             .astype(np.float32) / (2 ** 23))
    else:
        raise SystemExit(f"  unhandled sample width {sw}")
    # TRIM TO WHOLE FRAMES. A capture cut mid-frame leaves a partial sample and
    # the reshape fails on a file that is otherwise perfectly good.
    a = a[:len(a) // ch * ch].reshape(-1, ch)
    return a, sr


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    x, sr = load(sys.argv[1])
    mono = x.mean(1)
    print()
    print(f"  {os.path.basename(sys.argv[1])}   {len(x)/sr:.1f}s @ {sr} Hz, "
          f"{x.shape[1]}ch")
    print(f"  peak {np.abs(x).max():.3f}   rms {np.sqrt((x**2).mean()):.4f}")
    r = click_stats(mono, sr)
    if isinstance(r, dict):
        for k, v in r.items():
            print(f"  {k:22} {v}")
    else:
        print(f"  {r}")
    print()


if __name__ == "__main__":
    main()
