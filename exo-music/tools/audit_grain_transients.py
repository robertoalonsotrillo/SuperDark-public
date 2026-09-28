#!/usr/bin/env python3
"""Rank every grain in a corpus by locally-anomalous transient content.

REPLACES audit_corpus_clicks.py, WHICH WAS WRONG. That tool's "reversing spike"
test fired on any high-frequency content, so it could not tell a hi-hat from a
click and its clean verdicts meant nothing. It is the reason the corpus was
cleared while the sound was audible.

This uses the detector from bisect_report.py: high-pass, short envelope, divide
by a RUNNING MEDIAN of that envelope. A grain that is uniformly bright scores
near 1. A grain with a step discontinuity in it scores in the hundreds.

The bisection ladder is what pointed here. R1 played ONE grain repeatedly and
scored 0.00 events/s; R2 changed nothing but WHICH grains play and scored 7.14
with a worst-case ratio of 394. The filter, the summing and the master chain
each added nothing. So the events are carried by particular grains, and this
finds them.

  python3 audit_grain_transients.py --dir workdir_music/grains_lic_ev
  python3 audit_grain_transients.py --dir ... --list-worst 40 --out bad.txt
"""
import argparse
import glob
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bisect_report import read_wav                      # noqa: E402

from scipy.signal import butter, sosfiltfilt            # noqa: E402
from scipy.ndimage import median_filter                 # noqa: E402


def grain_score(x, sr, hp_hz=6000.0, env_ms=0.3, med_ms=15.0):
    """Worst local anomaly in one grain, plus where it sits.

    Windows are shorter than in bisect_report because a grain is 60 ms and a
    50 ms median window would span most of it, leaving nothing to be anomalous
    against. med_ms=15 keeps roughly four windows per grain.

    Also returns the position of the worst event as a FRACTION of the grain, so
    a fault at the edges (a fade that is too short, a boundary artefact) is
    distinguishable from one in the middle (damage in the source material).
    """
    if len(x) < 64:
        return 0.0, 0.0, 0.0
    sos = butter(4, min(hp_hz, sr / 2 * 0.95) / (sr / 2), btype="highpass", output="sos")
    hp = sosfiltfilt(sos, x)
    k = max(1, int(sr * env_ms / 1000))
    env = np.convolve(np.abs(hp), np.ones(k) / k, mode="same")
    m = max(3, int(sr * med_ms / 1000) | 1)
    floor = median_filter(env, size=m, mode="nearest")
    ratio = env / np.maximum(floor, 1e-6 + 0.02 * np.median(env))
    i = int(np.argmax(ratio))
    # largest single-sample jump, as a sanity cross-check on the ratio
    step = float(np.abs(np.diff(x)).max()) if len(x) > 1 else 0.0
    return float(ratio[i]), i / len(x), step


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    p.add_argument("--list-worst", type=int, default=20)
    p.add_argument("--thresh", type=float, default=40.0,
                   help="ratio above which a grain is called damaged")
    p.add_argument("--out", help="write the damaged grain indices here")
    a = p.parse_args()

    files = sorted(glob.glob(os.path.join(a.dir, "g*.wav")))
    if not files:
        print(f"no grains in {a.dir}", file=sys.stderr)
        return 1

    rows = []
    for f in files:
        x, sr, _ = read_wav(f)
        r, pos, step = grain_score(x, sr)
        rows.append((r, pos, step, os.path.basename(f)))

    rs = np.array([r[0] for r in rows])
    bad = [r for r in rows if r[0] > a.thresh]
    rows.sort(reverse=True)

    print(f"\n{os.path.basename(a.dir)}: {len(files)} grains")
    print(f"  ratio   median {np.median(rs):7.1f}   p90 {np.percentile(rs, 90):7.1f}"
          f"   p99 {np.percentile(rs, 99):7.1f}   max {rs.max():7.1f}")
    print(f"  over {a.thresh:.0f}: {len(bad)} grains "
          f"({100 * len(bad) / len(files):.2f}%)")

    print(f"\n  worst {a.list_worst}:")
    print(f"    {'grain':10} {'ratio':>8} {'at':>6} {'max step':>9}")
    for r, pos, step, name in rows[:a.list_worst]:
        print(f"    {name:10} {r:8.1f} {pos:6.2f} {step:9.4f}")

    # WHERE in the grain. If the worst events cluster at the edges the fault is
    # the build (fade length, onset snapping); if they are spread through the
    # middle the fault is in the source audio and no fade will fix it.
    if bad:
        pos = np.array([b[1] for b in bad])
        edge = np.count_nonzero((pos < 0.08) | (pos > 0.92))
        print(f"\n  of the {len(bad)} damaged grains, {edge} "
              f"({100 * edge / len(bad):.0f}%) have their worst event in the "
              f"outer 8% -- {'EDGE, so the build' if edge > len(bad) * 0.5 else 'INTERIOR, so the source material'}")

    if a.out and bad:
        with open(a.out, "w") as fh:
            for b in sorted(bad, key=lambda z: z[3]):
                fh.write(f"{b[3]}\t{b[0]:.1f}\t{b[1]:.3f}\n")
        print(f"\n  wrote {len(bad)} to {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
