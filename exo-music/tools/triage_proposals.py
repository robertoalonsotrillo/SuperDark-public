#!/usr/bin/env python3
"""What the factory has asked for, and what answering it would cost.

P271: a factory that cannot participate in its own charter-writing is an exercise
in Class 1 or 2 automation. It has participated 94 times and been answered none.
But adoption is the architect's act, and the answer is not obviously "yes": the
coverage proposals each mint a NEW METRIC, so adopting them all would leave a
charter of 98 entries, which is not a charter.

This does not decide anything. It measures three things the decision needs:

  1  how much the proposals actually differ from each other
  2  whether the factory still reaches the regions it asked to have anchored --
     because a holdout nobody can reach is a bound that fails by construction,
     which is the m7 mistake in a new costume
  3  what a NULL reaches, so any adopted threshold says what it discriminates
     rather than restating one run

    python3 tools/triage_proposals.py
"""
import glob
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")


def load():
    props, dec = [], {}
    p = os.path.join(MUT, "charter_proposals.jsonl")
    for i, line in enumerate(open(p)):
        if line.strip():
            try:
                d = json.loads(line); d["_n"] = i; props.append(d)
            except json.JSONDecodeError:
                pass
    q = os.path.join(MUT, "charter_decisions.jsonl")
    if os.path.exists(q):
        for line in open(q):
            if line.strip():
                d = json.loads(line); dec[d["proposal"]] = d
    return props, dec


def trajectory(log):
    """Where the factory actually went, from the descriptor vector in each
    window line (field 13, pipe-separated)."""
    out = []
    for line in open(log, errors="replace"):
        p = line.strip().split(",")
        if len(p) > 13 and p[3] in ("runtime", "class") and "|" in p[13]:
            try:
                out.append([float(x) for x in p[13].split("|")])
            except ValueError:
                pass
    return np.array(out) if out else None


def main():
    props, dec = load()
    cov = [p for p in props if p.get("kind", "coverage_holdout") == "coverage_holdout"]
    vr = [p for p in props if p.get("kind") == "voice_range"]
    print()
    print(f"  {len(props)} proposals, {len(dec)} decided")
    print(f"    {len(cov)} coverage_holdout  (norm n2_varied)")
    print(f"    {len(vr)} voice_range       (norm n3_coherent)")

    # ---- the voice_range four ------------------------------------------------
    print()
    print("  VOICE RANGE — these ask to widen ONE existing bound, m6_texture [2,5]")
    for p in sorted(vr, key=lambda x: x.get("voices", 0)):
        print(f"    #{p['_n']:<3} window {p.get('proposed_at'):>5}  "
              f"{p.get('voices')} concurrent voices")
    if vr:
        widest = max(vr, key=lambda x: x.get("voices", 0))
        print(f"    -> adopting #{widest['_n']} alone widens m6 to "
              f"[2, {widest['voices']}] and SUBSUMES the other three.")
        print(f"       The other three are then redundant, not wrong: refusing "
              f"them records that they were seen.")

    # ---- the coverage ninety -------------------------------------------------
    C = np.array([p["centre"] for p in cov if p.get("centre")])
    print()
    print(f"  COVERAGE — {len(C)} anchored regions in {C.shape[1]}-dimensional "
          f"descriptor space")
    d = np.sqrt(((C[:, None, :] - C[None, :, :]) ** 2).sum(-1))
    iu = np.triu_indices(len(C), 1)
    print(f"    pairwise distance between them: median {np.median(d[iu]):.3f}, "
          f"min {d[iu].min():.3f}")
    print(f"    novelty as claimed: {min(p['novelty'] for p in cov):.3f} to "
          f"{max(p['novelty'] for p in cov):.3f}")
    print(f"    ADOPTING ALL would make the charter "
          f"{len(C) + 8} entries. That is not a charter.")

    # Does the factory still reach them? A holdout it cannot reach is a bound
    # that fails by construction -- exactly the m7 fault in a new costume.
    logs = sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                  key=os.path.getmtime)[-3:]
    print()
    print("  DO THE ANCHORS STILL GET REACHED?")
    rng = np.random.default_rng(5)
    for lg in logs:
        T = trajectory(lg)
        if T is None or len(T) < 100:
            continue
        k = min(C.shape[1], T.shape[1])
        dist = np.sqrt(((C[:, None, :k] - T[None, :, :k]) ** 2).sum(-1))
        nearest = dist.min(axis=1)
        # A "reach" is coming within the median spacing between anchors: closer
        # than that and you are unambiguously in that region rather than a
        # neighbouring one.
        tol = float(np.median(d[iu]))
        reached = (nearest <= tol).mean()
        _ = reached  # reported below, alongside the tolerance sweep
        # NULL: a trajectory of the same length drawn from the run's own
        # marginal, which keeps the descriptor distribution but destroys the
        # path. This is what "reaching regions" looks like with no navigation.
        idx = rng.integers(0, len(T), size=(len(T), k))
        Tn = np.stack([T[idx[:, j], j] for j in range(k)], axis=1)
        dn = np.sqrt(((C[:, None, :k] - Tn[None, :, :k]) ** 2).sum(-1))
        reached_null = (dn.min(axis=1) <= tol).mean()
        print(f"    {os.path.basename(lg):28} {len(T):5d} windows")
        # SWEEP THE TOLERANCE. At the median anchor spacing everything reaches
        # everything, real and shuffled alike, so a metric there would be
        # vacuous -- m6's fault in a new costume. The only radius worth a bound
        # is one where the factory's actual PATH beats its own marginal. If no
        # such radius exists, then coverage is not measurable this way and the
        # honest answer is to refuse the proposals rather than mint a metric
        # that cannot fail.
        print(f"      {'radius':>8} {'reached':>9} {'null':>9}   separation")
        best = (0.0, 0.0)
        for tolf in (1.0, 0.6, 0.4, 0.25, 0.15, 0.10, 0.06, 0.03):
            t = tol * tolf
            r = (nearest <= t).mean()
            rn = (dn.min(axis=1) <= t).mean()
            sep = r - rn
            if sep > best[1]:
                best = (t, sep)
            bar = "#" * int(max(0, sep) * 40)
            print(f"      {t:8.3f} {100*r:8.1f}% {100*rn:8.1f}%   {bar}")
        print(f"      best separation {100*best[1]:.1f} points at radius {best[0]:.3f}")
        if best[1] < 0.05:
            print("      -> NO radius separates the factory's path from its own")
            print("         marginal. Coverage is not measurable this way, and a")
            print("         metric built on it could not fail. REFUSE the")
            print("         proposals and say why.")

    print()
    print("  WHAT THIS SUGGESTS, for the architect to accept or reject:")
    print("    - adopt ONE consolidated coverage metric over all "
          f"{len(C)} anchors, not {len(C)} of them;")
    print("      its bound stated as a fraction that must still be reached, and")
    print("      derived from the null above rather than from a passing run")
    print("    - adopt the widest voice_range proposal; refuse the other three")
    print("      as subsumed, with that as the recorded reason")
    print("    - fix the proposer: its novelty test measures against the run's")
    print("      own history, so it never saturates and a factory that runs")
    print("      forever proposes forever. Novelty should be measured against")
    print("      what is ALREADY ANCHORED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
