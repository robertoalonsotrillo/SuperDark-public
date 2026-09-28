#!/usr/bin/env python3
"""Look for discontinuities INSIDE the grains themselves.

WHY THIS EXISTS
---------------
30 Aug: Roberto heard a constant "super short clipping" sound for hours. It
survived, in order: the MP3 encoder, the browser, Icecast, the SSH tunnel,
BlackHole, the capture path, the voice floor, a linear-to-cubic interpolation
change, a real doneAction repair that removed part of it, and a 7 kHz lowpass on
the master. Eight measurements of the LIVE SUM came back clean, because they all
compared a candidate click against a 10 ms local envelope, and a one-sample jump
does not register that way.

Concatenating 200 raw corpus grains, with no engine and no processing at all,
showed the thing the live-sum measurements could not:

    mean jump AT grain boundaries : 0.00000   (the 3 ms fades work)
    largest jump INSIDE a grain   : 0.8007
    mean jump elsewhere           : 0.02936

A 0.8 sample-to-sample step is an enormous discontinuity - 27x the local mean.
If those are scattered through the corpus, every grain that contains one carries
a click, and no amount of work on the playback engine can remove it. The fault
would be in the material, inherited at build time.

WHAT THIS DOES NOT ASSUME
-------------------------
A large sample-to-sample step is not automatically a defect. Real audio has hard
transients, and at 22050 Hz a genuine attack can step a long way in one sample.
So this reports the DISTRIBUTION and the location, and distinguishes two cases:

  isolated single-sample spikes    a value that leaves and returns - the
                                   signature of a decode error or a bad splice,
                                   and audible as a click
  sustained steep slopes           many large steps in a row - a loud transient,
                                   which is music

The difference is whether the step reverses immediately. That is what separates
"the corpus is damaged" from "the corpus is percussive", and it is the question
the live-sum measurements were never able to reach.

    python3 tools/audit_corpus_clicks.py --dir workdir_music/grains_lic_ev
"""
import argparse
import glob
import os
import re
import wave

import numpy as np


def load(path):
    with wave.open(path) as w:
        n, sw, ch = w.getnframes(), w.getsampwidth(), w.getnchannels()
        raw = w.readframes(n)
        sr = w.getframerate()
    dt = "<i4" if sw == 4 else "<i2"
    sc = 2 ** 31 if sw == 4 else 2 ** 15
    a = np.frombuffer(raw, dtype=dt).astype(np.float64) / sc
    return a.reshape(-1, ch).mean(axis=1), sr


def audit(d, thresh, limit):
    files = sorted(glob.glob(os.path.join(d, "*.wav")),
                   key=lambda p: int(re.match(r"g(\d+)\.wav$",
                                              os.path.basename(p)).group(1)))[:limit]
    if not files:
        return None
    spikes, slopes, total, worst, worstf = 0, 0, 0, 0.0, None
    hit_files = []
    for p in files:
        x, sr = load(p)
        d1 = np.diff(x)
        ad = np.abs(d1)
        total += len(ad)
        idx = np.where(ad > thresh)[0]
        if len(idx) == 0:
            continue
        n_spike = 0
        for i in idx:
            # a SPIKE reverses: the step back is comparable and opposite.
            # a SLOPE continues: the next step keeps the same sign.
            if i + 1 < len(d1) and np.sign(d1[i]) != np.sign(d1[i + 1]) \
               and abs(d1[i + 1]) > 0.5 * ad[i]:
                n_spike += 1
            else:
                slopes += 1
        spikes += n_spike
        if ad.max() > worst:
            worst, worstf = ad.max(), os.path.basename(p)
        if n_spike:
            hit_files.append((os.path.basename(p), n_spike))
    return dict(files=len(files), spikes=spikes, slopes=slopes, total=total,
                worst=worst, worstf=worstf, hits=hit_files)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", action="append", required=True)
    ap.add_argument("--thresh", type=float, default=0.25,
                    help="sample-to-sample step counted as large")
    ap.add_argument("--limit", type=int, default=100000)
    a = ap.parse_args()

    print(f"  step threshold {a.thresh}\n")
    for d in a.dir:
        r = audit(d, a.thresh, a.limit)
        if r is None:
            print(f"  {d}: no grains")
            continue
        pc_files = 100 * len({f for f, _ in r["hits"]}) / max(1, r["files"])
        print(f"  {os.path.basename(d)}")
        print(f"    {r['files']} grains, worst step {r['worst']:.3f} in {r['worstf']}")
        print(f"    REVERSING spikes (click-like): {r['spikes']:6}   "
              f"in {len({f for f,_ in r['hits']})} grains ({pc_files:.1f}% of the corpus)")
        print(f"    continuing slopes (transients): {r['slopes']:6}")
        if r["hits"]:
            worst5 = sorted(r["hits"], key=lambda t: -t[1])[:5]
            print(f"    worst offenders: " + ", ".join(f"{f}({n})" for f, n in worst5))
        print()
    print("  A reversing spike is a value that jumps and comes straight back:")
    print("  a decode error or a bad splice, and audible as a click. A continuing")
    print("  slope is an attack, and is music. If the spike count is high, the")
    print("  clicking is in the MATERIAL and no change to the playback engine")
    print("  can remove it.")


if __name__ == "__main__":
    main()
