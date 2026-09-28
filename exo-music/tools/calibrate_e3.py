#!/usr/bin/env python3
"""
Calibrate E3 against real music, the degenerate attacks, and our own renders.

Reuses embeddings already computed (renders in /tmp/mert_embeddings.npz,
reference music in /tmp/mert_reference.npz) so MERT runs once, not once per file.

Reference pieces are scored LEAVE-ONE-OUT: a reference may not match itself, or
it scores 1.0 by construction, which is exactly the circularity that made E2
unable to ask whether the machine beats the human (claim 119).

The three questions this has to answer:
  1. does real music outrank the attacks?
  2. does m07 (post-fix) outrank m01 (broken) and the voice baseline?
  3. does anything score high for the wrong reason?

Usage:  calibrate_e3.py
"""
import os

import numpy as np

sys_path = os.path.dirname(os.path.abspath(__file__))
import sys
sys.path.insert(0, sys_path)
from score_e3 import traversal, LAYER  # noqa: E402

RENDERS = "/tmp/mert_embeddings.npz"
REFS = "/tmp/mert_reference.npz"
DEGENERATE = ["shaped-noise", "sine-3khz", "am-noise", "source-inharmonic",
              "seed-noise", "seed-impulse", "sciarrino"]


def cos(a, b):
    return float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b)))


def main():
    refs = dict(np.load(REFS).items())
    rend = dict(np.load(RENDERS).items())

    extra = {
        "m07 (post-fix, music)":
            "exo-music/workdir_music/renders/m07.wav",
        "m01 (broken, music)":
            "exo-music/workdir_music/renders/m01.wav",
    }

    rows = []

    # reference music, leave-one-out
    for name, vec in refs.items():
        others = {k: v for k, v in refs.items() if k != name}
        m = max(cos(vec[LAYER], v[LAYER]) for v in others.values())
        t, d = traversal(name)
        rows.append(("REFERENCE", os.path.basename(name), m, t, d))

    # our renders and the attacks
    for path, vec in rend.items():
        base = os.path.basename(path)
        kind = "ATTACK" if any(x in base for x in DEGENERATE) else "RENDER"
        m = max(cos(vec[LAYER], v[LAYER]) for v in refs.values())
        t, d = traversal(path)
        rows.append((kind, base, m, t, d))

    # the two music-corpus renders, embedded on the fly
    for label, path in extra.items():
        if not os.path.exists(path):
            continue
        from score_e3 import musicality
        m, _ = musicality(path, refs)
        t, d = traversal(path)
        rows.append(("NEW", label, m, t, d))

    from score_e3 import MUS_LO, MUS_HI

    def score(m, t, wm=0.5, wt=0.5):
        mn = float(np.clip((m - MUS_LO) / (MUS_HI - MUS_LO), 0.0, 1.0))
        return 100.0 * (wm * mn + wt * t), mn

    print(f"{'kind':<11}{'file':<42}{'cos':>7}{'mus':>7}{'trav':>7}{'E3':>8}")
    out = []
    for kind, name, m, t, d in rows:
        s, mn = score(m, t)
        out.append((s, kind, name, m, mn, t, d))
    for s, kind, name, m, mn, t, d in sorted(out, reverse=True):
        print(f"{kind:<11}{name[:41]:<42}{m:>7.3f}{mn:>7.3f}{t:>7.3f}{s:>8.1f}")

    def band(k):
        v = [s for s, kind, *_ in out if kind == k]
        return (min(v), max(v)) if v else (0, 0)

    print()
    for k in ("REFERENCE", "NEW", "RENDER", "ATTACK"):
        lo, hi = band(k)
        print(f"  {k:<11} {lo:6.1f} .. {hi:6.1f}")
    ref_lo = band("REFERENCE")[0]
    atk_hi = band("ATTACK")[1]
    print(f"\n  separation, worst real music minus best attack: {ref_lo - atk_hi:+.1f}")


if __name__ == "__main__":
    main()
