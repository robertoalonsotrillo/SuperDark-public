#!/usr/bin/env python3
"""Measure the DELIVERED level from outside the factory, and check the log against it.

WHY THIS EXISTS. Every level number this project has is `Amplitude.kr` on the
output bus, written to the log by the same process that made the sound. m2_level,
m1_not_silent and m1_audible_when_driving all read it. So the factory reports its
own loudness to itself, and when the BufRateScale change left machine amplitudes
uncalibrated, every metric said the factory was healthy while it played into a
multiplier at zero. rehearse_kernel_real.py then showed the kernel would not fire
on a factory 40 dB down. Nothing in the apparatus can currently tell us where the
live factory actually sits on that scale.

WHAT MAKES THIS EXTERNAL. It pulls the public Icecast mount over the network --
through the FIFO, the encoder, the lowpass, MP3, Icecast, the Hetzner relay and
TLS -- and decodes what a listener would hear. No factory code runs in this
measurement. The number comes back from the far end of the delivery path.

WHAT IT REPORTS.
  1. EBU R128 integrated loudness, loudness range and true peak of the delivered
     stream. LUFS is the external reference: it is defined against full scale,
     not against this factory's habits, so it cannot drift with the criteria.
  2. Per-window peak on the factory's own 11.7 s grid, aligned to the log by
     cross-correlation over candidate lags. The lag it finds is a check in
     itself: the panel assumes 22 s, and if the correlation peaks somewhere else
     that assumption is wrong.
  3. The relationship between delivered peak and logged peak. If they are
     proportional, the log is honest about level up to a constant and that
     constant is the thing we have never measured. If they are uncorrelated, the
     log is not tracking what leaves the building and three charter metrics are
     reading an instrument that is not connected to anything.

WHAT IT CANNOT SETTLE. A high correlation does not make m1_audible_when_driving
useful; it only shows the log is not lying. The metric could still be near-vacuous
for the separate reason that it compares a quantity to itself. That question is
downstream of this one and needs the constant this tool measures.

    python3 tools/level_probe.py --seconds 420
    python3 tools/level_probe.py --seconds 420 --log /Volumes/FMA/.../live_x.log
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys

import numpy as np

URL = "https://stream.robertoalonsotrillo.com/superdark.mp3"
RENDERS = "/Volumes/FMA/superdark/renders"
WINDOW = 11.7
SR = 44100


def capture(url, seconds):
    """Decode the delivered stream to mono float32, and read R128 off the same pass."""
    cmd = ["ffmpeg", "-hide_banner", "-nostdin",
           "-i", url, "-t", str(seconds),
           "-af", "ebur128=peak=true", "-ac", "1", "-ar", str(SR),
           "-f", "f32le", "-"]
    started = dt.datetime.now()
    p = subprocess.run(cmd, capture_output=True)
    x = np.frombuffer(p.stdout, dtype="<f4")
    return started, x, p.stderr.decode("utf-8", "replace")


def parse_r128(err):
    """Pull the Summary block out of ffmpeg's ebur128 report."""
    out = {}
    tail = err.split("Summary:")[-1] if "Summary:" in err else ""
    for key, pat in (("lufs", r"I:\s*(-?[\d.]+|-inf) LUFS"),
                     ("lra", r"LRA:\s*(-?[\d.]+|-inf) LU"),
                     ("peak_dbfs", r"Peak:\s*(-?[\d.]+|-inf) dBFS")):
        m = re.search(pat, tail)
        if m:
            out[key] = float("-inf") if m.group(1) == "-inf" else float(m.group(1))
    return out


def stream_windows(x, offset_s):
    """Peak per WINDOW-second window, starting offset_s into the capture."""
    n = int(WINDOW * SR)
    start = int(offset_s * SR)
    body = x[start:]
    k = len(body) // n
    if k < 3:
        return np.array([])
    return np.abs(body[:k * n].reshape(k, n)).max(axis=1)


def read_log(path):
    """(wall-clock of each window, logged master peak). Window time comes from the
    event lines' elapsed seconds; the wall-clock origin comes from the filename."""
    m = re.search(r"live_(\d{6})_(\d{6})", os.path.basename(path))
    if not m:
        return None, {}, {}
    origin = dt.datetime.strptime("20" + m.group(1) + m.group(2), "%Y%m%d%H%M%S")
    elapsed, peaks = {}, {}
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            f = line.split()[1].split(",")
            try:
                peaks[int(f[0])] = float(f[1])
            except (ValueError, IndexError):
                pass
        elif not line.startswith(("OPERATOR", "FADEOP", "REQUEST", "#")):
            f = line.strip().split(",")
            if len(f) > 3:
                try:
                    w = int(f[1])
                    elapsed.setdefault(w, float(f[0]))
                except (ValueError, IndexError):
                    pass
    return origin, elapsed, peaks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=int, default=420)
    ap.add_argument("--url", default=URL)
    ap.add_argument("--log", default=None)
    ap.add_argument("--json", default=None)
    a = ap.parse_args()

    logs = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")), key=os.path.getmtime)
    logpath = a.log or (logs[-1] if logs else None)
    if not logpath:
        print("  no live log found", file=sys.stderr)
        return 2

    print()
    print(f"  capturing {a.seconds}s from {a.url}")
    print(f"  comparing against {os.path.basename(logpath)}")
    print()
    t0, x, err = capture(a.url, a.seconds)
    if x.size < SR * 10:
        print(f"  capture failed or too short ({x.size} samples)", file=sys.stderr)
        print(err[-800:], file=sys.stderr)
        return 2

    r128 = parse_r128(err)
    got = x.size / SR
    silent = float(np.mean(np.abs(x.reshape(-1, SR)[:int(got)]).max(axis=1) < 10 ** (-60 / 20)))

    print("  DELIVERED STREAM, measured at the far end of the path")
    print(f"    captured                {got:.1f} s")
    print(f"    integrated loudness     {r128.get('lufs', float('nan')):.1f} LUFS")
    print(f"    loudness range          {r128.get('lra', float('nan')):.1f} LU")
    print(f"    true peak               {r128.get('peak_dbfs', float('nan')):.1f} dBFS")
    print(f"    sample peak             {20*np.log10(max(np.abs(x).max(), 1e-12)):.1f} dBFS")
    print(f"    seconds under -60 dBFS  {100*silent:.1f}%")
    print()

    origin, elapsed, peaks = read_log(logpath)
    common = sorted(set(elapsed) & set(peaks))
    if origin is None or len(common) < 5:
        print("  log has too few scoreable windows to align against")
        return 0

    # Wall-clock of each logged window, and the capture's offset into that clock.
    wall = {w: origin + dt.timedelta(seconds=elapsed[w]) for w in common}
    base = (t0 - origin).total_seconds()

    # Search the lag: how far behind the log does the delivered stream run?
    best = None
    for lag in np.arange(0.0, 60.0, 0.5):
        sw = stream_windows(x, 0.0)
        if sw.size < 4:
            break
        # Window k of the capture covers log-clock [base+k*W-lag, +W)
        pairs = []
        for k, v in enumerate(sw):
            tc = base + k * WINDOW - lag
            w = min(common, key=lambda q: abs(elapsed[q] - tc))
            if abs(elapsed[w] - tc) <= WINDOW / 2:
                pairs.append((peaks[w], float(v)))
        if len(pairs) < 6:
            continue
        A = np.array(pairs)
        if A[:, 0].std() < 1e-9 or A[:, 1].std() < 1e-12:
            continue
        r = float(np.corrcoef(A[:, 0], A[:, 1])[0, 1])
        if best is None or r > best[0]:
            best = (r, float(lag), A)

    if best is None:
        print("  ALIGNMENT FAILED. No lag produced enough overlapping windows.")
        print("  Either the capture and the log do not overlap in wall-clock, or")
        print("  one of the two series is constant.")
        return 0

    r, lag, A = best
    logged, delivered = A[:, 0], A[:, 1]
    ratio = delivered / np.maximum(logged, 1e-12)
    print("  LOGGED PEAK vs DELIVERED PEAK, on the factory's window grid")
    print(f"    windows compared        {len(A)}")
    print(f"    best lag                {lag:.1f} s   (the panel assumes 22 s)")
    print(f"    Pearson r               {r:+.3f}")
    print(f"    median logged peak      {np.median(logged):.5f}")
    print(f"    median delivered peak   {np.median(delivered):.5f}")
    print(f"    median ratio            {np.median(ratio):.3f}  "
          f"({20*np.log10(max(np.median(ratio),1e-12)):+.1f} dB)")
    print(f"    ratio IQR               {np.percentile(ratio,25):.3f} to "
          f"{np.percentile(ratio,75):.3f}")
    print()
    print("  READING IT")
    if r > 0.8:
        print("    The log tracks the delivered stream. The median ratio is the")
        print("    constant nobody had measured; a bound for a restored silence")
        print("    metric can be carried across it.")
    elif r > 0.4:
        print("    Partial tracking. Some of the delivered variation is not in the")
        print("    log. Encoder buffering and the lowpass account for some of it;")
        print("    the rest is unexplained and should be before any bound is set.")
    else:
        print("    The log does NOT track what leaves the building. m2_level,")
        print("    m1_not_silent and m1_audible_when_driving are then reading an")
        print("    instrument disconnected from the delivered signal, and the")
        print("    charter's audibility norm is unmeasured rather than merely")
        print("    shallow. This would be a larger finding than the depth hole.")
    print()
    print("  CAVEAT. One capture, one factory state. The ratio is a snapshot; it")
    print("  becomes a calibration only after it repeats across separate runs.")

    if a.json:
        json.dump({"captured_s": got, **r128, "silent_frac": silent,
                   "lag_s": lag, "r": r, "n": len(A),
                   "median_ratio": float(np.median(ratio)),
                   "median_logged": float(np.median(logged)),
                   "median_delivered": float(np.median(delivered)),
                   "log": os.path.basename(logpath),
                   "at": t0.isoformat()}, open(a.json, "w"), indent=2)
        print(f"\n  wrote {a.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
