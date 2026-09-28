#!/usr/bin/env python3
"""Which grains make a corpus fail verify_alignment, and what is wrong with them.

verify_alignment reports one number per corpus: the minimum Spearman rho across
five principal axes over 45 probe grains, and refuses below 0.999. That is the
right shape for a GATE -- it caught the sort-order bug that had the factory
reading wrong descriptors for 2,389 of 2,400 grains -- but a single scalar says
nothing about whether the cause is a systematic reordering or two damaged files.

The distinction decides the repair. A reordering means the corpus must be
rebuilt. A handful of bad grains means those grains should be removed, and
rebuilding would only reintroduce them.

    python3 tools/why_misaligned.py --corpus workdir_music/grains_play_macro
"""
import argparse
import json
import os
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from analyse_mfcc import mel_filterbank, mfcc_stats, read_mono, N_MEL, FFT  # noqa: E402
from world_listen import load_transform                                     # noqa: E402
from scipy.stats import spearmanr, rankdata                                 # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--probes", type=int, default=45)
    ap.add_argument("--stride", type=int, default=9)
    a = ap.parse_args()

    D = a.corpus
    d = json.load(open(os.path.join(D, "descriptors.json")))
    mu, sc, C = load_transform(os.path.join(D, "descriptors.json"))
    norm = d["norm"]
    have = len(next(iter(norm.values())))
    ids = list(range(0, min(a.probes * a.stride, have), a.stride))

    fb, mine = None, []
    for i in ids:
        m, sr = read_mono(os.path.join(D, f"g{i:02d}.wav"))
        if fb is None:
            fb = mel_filterbank(sr, FFT, N_MEL)
        mine.append(C @ ((mfcc_stats(m, sr, fb) - mu) / sc))
    mine = np.array(mine)

    print()
    displaced = {}
    for k in range(5):
        stored = np.array([norm[f"pc{k}"][i] for i in ids])
        rho = spearmanr(mine[:, k], stored).correlation
        dr = rankdata(mine[:, k]) - rankdata(stored)
        worst = np.argsort(-np.abs(dr))[:4]
        print(f"  pc{k}  rho {rho:+.5f}   worst rank moves: "
              + ", ".join(f"g{ids[w]:02d}:{dr[w]:+.0f}" for w in worst))
        for w in np.where(np.abs(dr) > 2)[0]:
            displaced[ids[w]] = max(displaced.get(ids[w], 0), abs(dr[w]))

    # A SYSTEMATIC reordering displaces most probes. A few damaged files displace
    # a few. The ratio is the diagnosis, so it is printed rather than inferred.
    print()
    print(f"  {len(displaced)} of {len(ids)} probes displaced by more than 2 ranks")
    if len(displaced) > len(ids) // 3:
        print("  -> SYSTEMATIC. The corpus order and its descriptors disagree;")
        print("     rebuild. Removing grains will not fix an ordering fault.")
    else:
        print("  -> LOCAL. A small number of grains disagree with their")
        print("     descriptors; the corpus order is sound.")

    if displaced:
        print()
        print(f"  {'grain':7} {'moved':>6} {'frames':>8} {'sr':>7} {'sec':>6} "
              f"{'peak':>7}  note")
        for i in sorted(displaced, key=lambda x: -displaced[x]):
            p = os.path.join(D, f"g{i:02d}.wav")
            with wave.open(p) as w:
                n, srr, sw = w.getnframes(), w.getframerate(), w.getsampwidth()
                raw = np.frombuffer(w.readframes(n),
                                    dtype="<i4" if sw == 4 else "<i2")
            full = float(2 ** 31 - 1) if sw == 4 else float(2 ** 15 - 1)
            pk = np.abs(raw).max() / full if len(raw) else 0.0
            note = []
            if srr != 44100:
                note.append(f"SR {srr}")
            if pk < 1e-3:
                note.append("near-silent")
            if pk > 0.999:
                note.append("full-scale")
            print(f"  g{i:02d}    {displaced[i]:6.0f} {n:8d} {srr:7d} "
                  f"{n/srr:6.2f} {pk:7.4f}  {', '.join(note) or 'ordinary'}")
    print()


if __name__ == "__main__":
    sys.exit(main())
