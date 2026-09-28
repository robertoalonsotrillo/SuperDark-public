#!/usr/bin/env python3
"""Recompute the base Archon descriptors for a corpus whose audio has changed.

WHY THIS EXISTS SEPARATELY FROM THE BUILDER
build_grains_onset.py computes the eight descriptors while it cuts the grains,
so there was no way to recompute them for grains that already exist. After
resampling to 44100 they must be recomputed, because three of the eight are in
Hz (centroid, rolloff, median) and one is a rate-dependent count (zcr).
Carrying the 22050 values across would produce a corpus whose descriptors
describe audio that is no longer there, which is precisely the failure
verify_alignment.py was written to catch after it went unnoticed for weeks.

Grain ORDER is taken from the numeric index in the filename, not from a
directory listing. Lexicographic ordering puts g100 before g11 and once had the
factory reading the wrong descriptors for 2,389 of 2,400 grains, with no error
and entirely plausible numbers.

analyse_mfcc.py is then run over the result to add the PCA columns; it edits
descriptors.json in place and needs this file to exist first.

  python3 redescribe_corpus.py --dir workdir_music/grains_44_ev
"""
import argparse
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_grains_onset import analyse, KEYS  # noqa: E402


def read_stereo(path):
    import wave
    with wave.open(path, "rb") as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        raw = w.readframes(n)
    a = np.frombuffer(raw, "<i4").astype(np.float64) / 2 ** 31
    return a.reshape(-1, ch), sr


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    a = p.parse_args()

    files = glob.glob(os.path.join(a.dir, "g*.wav"))
    if not files:
        print(f"  no grains in {a.dir}", file=sys.stderr)
        return 1
    idx = lambda f: int("".join(c for c in os.path.basename(f) if c.isdigit()))  # noqa: E731
    files.sort(key=idx)

    desc, sr0 = [], None
    for f in files:
        x, sr = read_stereo(f)
        sr0 = sr0 or sr
        desc.append(analyse(x.mean(axis=1), sr))
    D = np.array(desc)

    # rank-normalise, the same convention every other builder uses
    norm = np.zeros_like(D)
    for j in range(D.shape[1]):
        norm[D[:, j].argsort(), j] = np.linspace(0, 1, len(D))

    json.dump({
        "_comment": "Base Archon descriptors RECOMPUTED after resampling. "
                    "Three of these are in Hz and one is a rate-dependent "
                    "count, so they cannot be carried across a rate change.",
        "_order": "numeric grain index from the filename, not lexicographic",
        "_keys": KEYS,
        "index": list(range(len(files))),
        "norm": {k: norm[:, j].round(5).tolist() for j, k in enumerate(KEYS)},
        "raw_ranges": {k: [float(D[:, j].min()), float(D[:, j].max())]
                       for j, k in enumerate(KEYS)},
    }, open(os.path.join(a.dir, "descriptors.json"), "w"))

    pitched = int((D[:, KEYS.index("pitch")] > 0).sum())
    print(f"  {len(files)} grains re-described at {sr0} Hz -> {a.dir}")
    print(f"    {100 * pitched / len(files):.1f}% pitched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
