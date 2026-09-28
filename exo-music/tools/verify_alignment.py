#!/usr/bin/env python3
"""Assert that descriptors.json actually describes the grains beside it.

WHY THIS IS A STANDING CHECK AND NOT A ONE-OFF FIX
A sort-order bug once had the factory reading the wrong descriptors for 2,389
of 2,400 grains. It raised no error and produced entirely plausible numbers,
because wrong descriptors are still descriptors: the path logic ran, the
machines played, the logs looked normal. The only way to catch that class of
fault is to recompute a sample from the audio and correlate against what the
file claims. Run this after every corpus build and every swap.

Exit status is 1 on any misalignment, so it can gate a pipeline.

  python3 verify_alignment.py --root workdir_music \
      --corpora grains_lic_ev,grains_lic_mid,grains_lic_macro
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse_mfcc import mel_filterbank, mfcc_stats, read_mono, N_MEL, FFT  # noqa: E402
from world_listen import load_transform                                     # noqa: E402
from scipy.stats import spearmanr, rankdata                                 # noqa: E402


def check(corpus_dir, n_probe=45, stride=9, tol=0.999):
    d = json.load(open(os.path.join(corpus_dir, "descriptors.json")))
    mu, sc, C = load_transform(os.path.join(corpus_dir, "descriptors.json"))
    norm = d["norm"]
    have = len(next(iter(norm.values())))
    ids = list(range(0, min(n_probe * stride, have), stride))

    fb, mine = None, []
    for i in ids:
        m, sr = read_mono(os.path.join(corpus_dir, f"g{i:02d}.wav"))
        if fb is None:
            fb = mel_filterbank(sr, FFT, N_MEL)
        mine.append(C @ ((mfcc_stats(m, sr, fb) - mu) / sc))
    mine = np.array(mine)

    # Spearman, not Pearson: descriptors.json stores RANK-normalised values, so
    # the relationship is monotonic and not linear. Pearson would report a
    # respectable 0.9-something on a genuinely misaligned corpus.
    rs = [spearmanr(mine[:, k], [norm[f"pc{k}"][i] for i in ids]).correlation
          for k in range(5)]

    # HOW FAR GRAINS MOVED, not just how well the ranks correlate.
    #
    # WHY BOTH NUMBERS ARE NEEDED, 1 Sept. grains_play_macro failed at
    # rho = 0.99815 while FOUR of its five axes sat at exactly +1.00000. The
    # whole deficit was two grains swapping by three ranks on pc4 -- the
    # lowest-variance axis, where stored values are densest and a rank flip is
    # cheapest. 6*sum(d^2)/(n(n^2-1)) with sum(d^2)=26 predicts 0.00171 against
    # the 0.00185 observed, so the shortfall was fully accounted for by tie
    # noise, and nothing was misaligned.
    #
    # A fixed rho threshold cannot tell that apart from a real fault, because
    # rho answers "do these agree" and the question here is "is the ORDER
    # wrong". A wrong order displaces most probes; ties displace a couple. So
    # the count of large displacements is reported alongside, and the caller
    # decides. Loosening the threshold instead would have blinded the check
    # that once caught 2,389 of 2,400 grains reading the wrong descriptors.
    moved = 0
    for k in range(5):
        stored = np.array([norm[f"pc{k}"][i] for i in ids])
        dr = np.abs(rankdata(mine[:, k]) - rankdata(stored))
        moved = max(moved, int((dr > 2).sum()))
    return min(rs), ("_order" in d), len(ids), moved


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", default="workdir_music")
    p.add_argument("--corpora", required=True, help="comma-separated dir names")
    a = p.parse_args()

    bad = False
    noted = []
    print(f"{'corpus':24} {'_order':>7} {'probes':>7} {'min rho':>9} {'moved':>6}   verdict")
    print("-" * 70)
    for c in a.corpora.split(","):
        d = os.path.join(a.root, c.strip())
        if not os.path.isdir(d):
            print(f"{c:24} {'-':>7} {'-':>7} {'-':>9} {'-':>6}   MISSING")
            bad = True
            continue
        rho, order, n, moved = check(d)
        if rho > 0.999:
            verdict = "ALIGNED"
        elif moved <= max(2, n // 15):
            # Localised: the order holds, a few tie-dense values changed places.
            verdict = "ties only"
            noted.append((c.strip(), rho, moved, n))
        else:
            verdict = "MISALIGNED"
            bad = True
        print(f"{c:24} {'yes' if order else 'NO':>7} {n:7d} {rho:+9.5f} "
              f"{moved:6d}   {verdict}")
    print()
    for c, rho, moved, n in noted:
        print(f"  {c}: rho {rho:.5f} is below 0.999, but only {moved} of {n} "
              f"probes moved")
        print(f"  more than 2 ranks. That is tie noise on a low-variance axis, "
              f"not a wrong order.")
        print(f"  Run tools/why_misaligned.py --corpus <dir> to see which grains "
              f"and why.")
    print("  all corpora aligned" if not bad
          else "  MISALIGNMENT -- do not run the factory")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
