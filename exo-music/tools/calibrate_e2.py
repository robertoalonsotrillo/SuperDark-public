#!/usr/bin/env python3
"""
Choose E2's layer empirically, and test whether it discriminates where E1 cannot.

The question E1 failed (claims 100, 101): does the measure separate real music
from degenerate signals *and* rank real music sensibly, or does it only reject
the attacks it was built against?

Method. Each render is labelled by hand into three sets:
  REFERENCE  the human recording the corpus was cut from, the quality benchmark
  MUSIC      Archon output
  DEGENERATE the calibration attacks: shaped noise, sine, AM noise, noise seeds

For each of MERT's 13 layers, score every file by cosine similarity to the
REFERENCE embedding, then measure separation as

    margin = min(score over MUSIC) - max(score over DEGENERATE)

A positive margin means every piece of real music outranks every degenerate
signal on that layer. This is the property E1 has only through floors that no
real render ever approaches, and E0 does not have at all (run 14: shaped noise
54.68 against best musical output 32.05).

The layer with the largest margin wins. Reporting all 13 keeps the choice honest
and lets a reader see how much the result depends on it.

Usage:  calibrate_e2.py /tmp/mert_embeddings.npz
"""
import sys

import numpy as np

REFERENCE_KEY = "D-gen00-seed-recording"

DEGENERATE = [
    "shaped-noise", "sine-3khz", "am-noise", "source-inharmonic",
    "B-gen00-seed-noise", "B-gen00-seed-impulse-noise",
    # The two sciarrino renders belong here, on Roberto's own listening and on
    # claim 49: "sciarrino unregistered is silent, the other one is just random
    # sinetones", 13.5% of frames above 10% of peak and a median frame RMS of
    # 0.000000. They are early pipeline failures, not music. Classifying them as
    # MUSIC in the first pass of this script inverted the result: they were the
    # only two files putting min(MUSIC) below max(DEGENERATE), and they made
    # every layer's margin negative. Recorded because the fix flips the finding.
    "sciarrino-registered", "sciarrino-unregistered",
]
# Excluded from both sets: loop generations that decayed toward silence
# (D-gen01/02/03/06, B-gen01/03/06) are neither clean music nor clean attacks,
# and the near-dead ones are exactly the ambiguous middle this test is not about.
EXCLUDE = ["gen01", "gen02", "gen03", "gen06", "playback-24events", "grain-example"]


def label(name):
    if REFERENCE_KEY in name:
        return "REFERENCE"
    if any(d in name for d in DEGENERATE):
        return "DEGENERATE"
    if any(e in name for e in EXCLUDE):
        return "EXCLUDE"
    return "MUSIC"


def cosine(a, b):
    return float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b)))


def main():
    data = np.load(sys.argv[1])
    items = [(p, data[p]) for p in data.files]
    labelled = [(p, v, label(p.split("/")[-1])) for p, v in items]

    ref = [v for _, v, l in labelled if l == "REFERENCE"]
    if not ref:
        sys.exit("no reference embedding found")
    ref = ref[0]

    music = [(p, v) for p, v, l in labelled if l == "MUSIC"]
    degen = [(p, v) for p, v, l in labelled if l == "DEGENERATE"]
    print(f"reference 1   music {len(music)}   degenerate {len(degen)}   "
          f"excluded {sum(1 for _,_,l in labelled if l=='EXCLUDE')}\n")

    print(f"{'layer':>5} {'min(music)':>11} {'max(degen)':>11} {'margin':>9}")
    best, best_margin = None, -9e9
    for layer in range(ref.shape[0]):
        m = [cosine(v[layer], ref[layer]) for _, v in music]
        d = [cosine(v[layer], ref[layer]) for _, v in degen]
        margin = min(m) - max(d)
        flag = ""
        if margin > best_margin:
            best, best_margin, flag = layer, margin, ""
        print(f"{layer:>5} {min(m):>11.4f} {max(d):>11.4f} {margin:>9.4f}"
              f"{'  <-- separates' if margin > 0 else ''}")

    print(f"\nbest layer {best}, margin {best_margin:.4f}")
    print("positive margin means every musical render outranks every degenerate one\n")

    print("per-file cosine to the human recording, best layer:")
    rows = sorted(((cosine(v[best], ref[best]), p.split("/")[-1], l)
                   for p, v, l in labelled if l != "EXCLUDE"), reverse=True)
    for s, n, l in rows:
        print(f"  {s:>7.4f}  {l:<11} {n[:46]}")


if __name__ == "__main__":
    main()
