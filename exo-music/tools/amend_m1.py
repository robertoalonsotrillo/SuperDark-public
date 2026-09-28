#!/usr/bin/env python3
"""Charter edition 4: m1 stops judging the factory's silence and starts judging
whether sound comes out when the factory drives output.

WHAT WAS WRONG
m1_not_silent counted windows whose master peak fell below 0.004, unconditionally,
against a bound of 0.15. Measured 2 Sept on 2,532 windows: silence falls
monotonically with the SECTION AMPLITUDE the factory chooses --

    amp ~ 0        34.8% silent
    amp 1e-4       19.0%
    amp 2e-3        4.1%
    amp >= 1e-2     0.2%

-- and 47% of all windows carry an amplitude below 1e-4. So the metric was
largely counting how often the factory chose to be quiet. Roberto, asked whether
that is a fault or a description: "it is a description." The page already
promises listeners the states where the system veers into collapse, and a minute
of near-silence is one of them.

WHAT REPLACES IT
m1_audible_when_driving: of the windows where the factory is unambiguously
driving output (amp >= 1e-2, chosen where conditional silence reaches 0.2% and
stops being ambiguous), the fraction that are nonetheless silent. That is what
n1_audible actually means: when the factory tries to make sound, sound comes out.

WHERE THE BOUND COMES FROM -- a stated pathology, not this run
Level faults simulated against the same 861 driving windows:

    none (observed)   0.2%      gain -12 dB   1.2%
    gain  -6 dB       0.3%      gain -18 dB   4.5%
                                gain -24 dB  14.5%

Observed 0.23% +/- 0.32%, upper 99.9% bound 0.77%. The bound is 1.5%: above the
healthy rate's 99.9% ceiling, and low enough to catch a level collapse. It does
NOT try to catch a -12 dB drop, because m2_level already tests median level --
a division of labour, so neither metric has to do both jobs badly.

This is the correction the m7 write-up asked for: a bound derived from what it
must discriminate, rather than from what one run happened to do.

    python3 tools/amend_m1.py --by "Roberto Alonso Trillo"
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
    if "m1_audible_when_driving" in ch["metrics"]:
        raise SystemExit(f"  already amended (edition {old})")

    arch = os.path.join(MUT, f"charter_edition_{old}.json")
    if not os.path.exists(arch):
        shutil.copy2(CHARTER, arch)

    m1 = ch["metrics"]["m1_not_silent"]
    m1["descriptive"] = True
    m1["acceptable"] = [None, None]
    m1["_demoted"] = (
        f"Demoted to a DESCRIPTION in edition {old + 1}. It counted silence "
        f"unconditionally, and silence tracks the section amplitude the factory "
        f"chooses: 34.8% of windows are silent near amp 0, 0.2% at amp >= 1e-2, "
        f"and 47% of all windows sit below amp 1e-4. So it measured a "
        f"compositional habit, not a failure of n1_audible. It is still "
        f"reported, because the silence is part of the work, and it carries no "
        f"bound, because there is nothing here to pass or fail.")

    ch["metrics"]["m1_audible_when_driving"] = {
        "norm": "n1_audible",
        "test": ("fraction of windows that are silent (master peak < 0.004) "
                 "AMONG those where the factory is driving output "
                 "(section amplitude >= 0.01)"),
        "acceptable": [0.0, 0.015],
        "min_windows": 100,
        "_derivation": (
            "The bound states what it discriminates. Level faults simulated "
            "against 861 driving windows from the 8 h run of 2 Sept: observed "
            "0.2%, -6 dB 0.3%, -12 dB 1.2%, -18 dB 4.5%, -24 dB 14.5%. The "
            "observed rate is 0.23% +/- 0.32% with a 99.9% upper bound of 0.77%, "
            "so 1.5% sits above healthy noise and below a level collapse. It "
            "deliberately does NOT catch a -12 dB drop: m2_level tests median "
            "level and covers that, and a metric asked to do two jobs does both "
            "badly."),
        "_threshold_choice": (
            "amp >= 0.01 is where conditional silence reaches 0.2% and 'the "
            "factory is trying to sound' stops being ambiguous. It was measured, "
            "not chosen for roundness; the gradient below it is smooth, so any "
            "lower cut would blend intention with abstention."),
        "_untested": (
            "Derived from one 8 h run. The sensitivity table is arithmetic on "
            "that run's peaks, not an observation of a factory actually running "
            "12 dB down, so it predicts what a fault would look like rather than "
            "reporting what one did look like. Re-check when a genuine level "
            "fault next occurs."),
    }

    ch["edition"] = old + 1
    ch["authored"] = datetime.date.today().isoformat()
    ch.setdefault("_lineage", []).append({
        "edition": old + 1, "from": old, "by": a.by,
        "when": datetime.datetime.now().isoformat(timespec="seconds"),
        "change": ("m1_not_silent demoted to descriptive; "
                   "m1_audible_when_driving added"),
        "initiated_by": "architect",
    })
    json.dump(ch, open(CHARTER, "w"), indent=2)
    print(f"  charter edition {old} -> {old + 1}")
    print(f"  m1_not_silent            -> descriptive, no bound")
    print(f"  m1_audible_when_driving  -> [0, 0.015], derived from a fault model")
    print(f"  previous archived as charter_edition_{old}.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
