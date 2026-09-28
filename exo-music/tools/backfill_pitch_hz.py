#!/usr/bin/env python3
"""Add the raw_hz column to a corpus that was built before it existed.

WHY NOT REBUILD. build_grains_onset now writes raw_hz, but every corpus on disk
predates it, and rebuilding from the FMA source is hours of work to recover a
number that can be measured from the grains already sitting there. The grains are
the same files; the pitch of a file does not depend on when it was written.

WHY IT IMPORTS pitch_of RATHER THAN REIMPLEMENTING IT. The normalised `pitch`
column in descriptors.json is a RANK over whatever pitch_of returned at build
time. If this tool computed Hz a different way, raw_hz and norm.pitch would
describe the same grains through two different estimators, and any check that
compared them would find a disagreement that means nothing. Importing the
function is the only way the two columns stay commensurable.

WHAT IT VERIFIES. After writing, it ranks the new Hz values and compares that
ranking against the stored norm.pitch. They should agree closely; where they do
not, the corpus was built with a different version of the analysis and the file
says so instead of quietly carrying two incompatible pitch columns.

    python3 tools/backfill_pitch_hz.py workdir_music/grains_play_ev
    python3 tools/backfill_pitch_hz.py workdir_music/grains_*_ev --write
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_grains_onset import pitch_of                       # noqa: E402

try:
    import soundfile as sf
except ImportError:
    sf = None


def read_mono(path):
    if sf is not None:
        x, sr = sf.read(path, always_2d=True)
        return x.mean(axis=1), sr
    import wave
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        n = w.getnframes()
        raw = w.readframes(n)
        ch = w.getnchannels()
        wid = w.getsampwidth()
        dt = {1: np.int8, 2: np.int16, 4: np.int32}.get(wid)
        if dt is None:
            raise RuntimeError(f"unsupported sample width {wid}")
        a = np.frombuffer(raw, dtype=dt).astype(np.float64)
        a = a / float(np.iinfo(dt).max)
        if ch > 1:
            a = a.reshape(-1, ch).mean(axis=1)
        return a, sr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--write", action="store_true",
                    help="without this, measure and report but change nothing")
    a = ap.parse_args()

    for d in a.dirs:
        dp = os.path.join(d, "descriptors.json")
        if not os.path.exists(dp):
            print(f"  {d}: no descriptors.json, skipped")
            continue
        desc = json.load(open(dp))
        n = len(desc.get("index", []))
        if "raw_hz" in desc:
            print(f"  {d}: already has raw_hz ({len(desc['raw_hz']['pitch'])} values)")
            continue

        hz = []
        for i in range(n):
            w = os.path.join(d, f"g{i:02d}.wav")
            if not os.path.exists(w):
                hz.append(0.0)
                continue
            try:
                mono, sr = read_mono(w)
                # the SAME bounded window build_grains_onset uses, so the
                # estimator sees exactly what it saw at build time
                p, clar = pitch_of(mono[: int(0.2 * sr)], sr)
            except Exception:
                p = 0.0
            hz.append(float(p))

        arr = np.array(hz)
        pitched = int((arr > 0).sum())
        # AGREEMENT, COMPUTED CAREFULLY, because the first version was not.
        #
        # It filtered the new values to pitched grains and compared them against
        # the stored column at those indices -- but the stored column is a rank
        # over ALL grains, unpitched ones included, and argsort gives tied zeros
        # arbitrary distinct ranks. Any grain whose pitched-status changed
        # between the two analyses then contributed pure noise, and the result
        # looked like disagreement about pitch when it was disagreement about
        # which grains have one.
        #
        # So: restrict to grains the OLD analysis also called pitched, and count
        # the status changes separately. norm.pitch is a rank over the whole
        # corpus, and the unpitched grains occupy its bottom `k` ranks, so a
        # grain is old-pitched if its rank sits above that block.
        stored = desc.get("norm", {}).get("pitch")
        agree, flipped = None, None
        if stored is not None and len(stored) == n and pitched > 8:
            s = np.array(stored, dtype=float)
            old_pitched = s > ((n - pitched) / float(n))
            both = (arr > 0) & old_pitched
            flipped = int(((arr > 0) != old_pitched).sum())
            if both.sum() > 8 and s[both].std() > 0:
                r1 = np.argsort(np.argsort(arr[both]))
                r2 = np.argsort(np.argsort(s[both]))
                agree = float(np.corrcoef(r1, r2)[0, 1])

        print(f"  {d}")
        print(f"      {pitched} of {n} grains pitched ({100*pitched/max(1,n):.0f}%)")
        if pitched:
            v = np.sort(arr[arr > 0])
            print(f"      Hz  min {v[0]:.1f}  median {v[len(v)//2]:.1f}  max {v[-1]:.1f}")
            print(f"      spans {np.log2(v[-1]/max(v[0],1e-9)):.1f} octaves")
        if flipped is not None:
            print(f"      pitched-status changed on {flipped} grains "
                  f"({100*flipped/max(1,n):.1f}%)")
        if agree is not None:
            flag = "" if agree > 0.95 else "   <-- DISAGREES with the stored rank column"
            print(f"      rank agreement on grains pitched in BOTH  {agree:+.3f}{flag}")

        if a.write:
            desc["raw_hz"] = {"pitch": [round(float(x), 2) for x in arr]}
            desc["_raw_hz_note"] = (
                "Backfilled by tools/backfill_pitch_hz.py using the same pitch_of "
                "as build_grains_onset. norm.pitch is a rank and its ratios are "
                "meaningless; this column is Hz and its ratios are intervals.")
            json.dump(desc, open(dp, "w"))
            print(f"      written")
        else:
            print(f"      (dry run; pass --write to store it)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
