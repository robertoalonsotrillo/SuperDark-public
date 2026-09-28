#!/usr/bin/env python3
"""Suspend m7 and bump the charter to edition 3.

P518: "Every change to the input is a new charter, and every new charter is a new
version of the factory." So this archives edition 2 before writing edition 3, and
records who did it and why, exactly as review_proposals.py does when the FACTORY's
proposal is adopted. The difference is only in who initiated it.

WHY SUSPEND RATHER THAN DELETE
The finding is worth more than the metric. Deleting m7 would erase the evidence
that a bound was once written from an observed run instead of from a null, which
is the mistake this project has now made three times (m6 pinned by policy, the
0.9 drift threshold, m7). The entry stays, unscoreable, carrying its own autopsy.

WHY SUSPEND RATHER THAN RE-PRICE
Re-pricing assumes the statistic is sound and only the numbers are stale. It is
not sound: the interquartile range of a cumulative estimator that persists across
runs falls with accumulated history no matter what the factory does. There is no
value of the bound that fixes that. See .lab/notes/M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md.

    python3 tools/suspend_m7.py --by "Roberto Alonso Trillo"
"""
import argparse
import datetime
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")
CHARTER = os.path.join(MUT, "charter.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--by", default="Roberto Alonso Trillo")
    a = ap.parse_args()

    ch = json.load(open(CHARTER))
    old = ch["edition"]
    m = ch["metrics"].get("m7_spectral_gap_settles")
    if m is None:
        raise SystemExit("  no m7 in this charter")
    if m.get("suspended"):
        raise SystemExit(f"  m7 is already suspended (edition {old})")

    arch = os.path.join(MUT, f"charter_edition_{old}.json")
    if not os.path.exists(arch):
        shutil.copy2(CHARTER, arch)

    m["suspended"] = {
        "since_edition": old + 1,
        "by": a.by,
        "when": datetime.date.today().isoformat(),
        "reason": (
            "The statistic measures the operator's age, not the factory's "
            "coherence. TransferOperator accumulates transition counts with no "
            "decay, and saveMemory persists those counts into memory.json so "
            "they span every run the factory has ever done. A cumulative "
            "estimator converges, so the interquartile range of its lambda2 "
            "falls with accumulated history whatever the factory does. "
            "Confirmed on a live restart: the operator reported 137 cells while "
            "the run had played 4 distinct machines."),
        "evidence": ".lab/notes/M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md",
        "why_not_repriced": (
            "No value of the bound repairs a statistic that decays with age. "
            "Widening it would buy a pass now and fail again later, which is "
            "how m6 stayed decorative for ten runs."),
        "replacement_requires": (
            "A second operator with exponential forgetting, observing the same "
            "cells and steering nothing, logging both lambda2 and its "
            "observation count; the bound then derived from a shuffled null over "
            "the cell sequence rather than from a run that happened to pass. The "
            "forgetting operator exists (TransferOperator halflife argument, "
            "tested) but is not yet wired into the factory, so no data exists to "
            "derive a bound from."),
    }
    m["_scoring"] = ("Reported SUSPENDED, which counts as undecided. It is not "
                     "counted as a departure, because a metric that cannot be "
                     "measured cannot be failed.")

    ch["edition"] = old + 1
    ch["authored"] = datetime.date.today().isoformat()
    ch.setdefault("_lineage", []).append({
        "edition": old + 1, "from": old, "by": a.by,
        "when": datetime.datetime.now().isoformat(timespec="seconds"),
        "change": "suspended m7_spectral_gap_settles",
        "initiated_by": "architect",
    })
    json.dump(ch, open(CHARTER, "w"), indent=2)
    print(f"  charter edition {old} -> {old + 1}")
    print(f"  previous archived as charter_edition_{old}.json")
    print("  m7_spectral_gap_settles is now SUSPENDED, not failing")
    print("  P518: this is a new version of the factory.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
