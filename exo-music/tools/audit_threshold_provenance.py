#!/usr/bin/env python3
"""Where did each charter bound come from, and has it ever discriminated?

WHY THIS EXISTS
Two findings on the night of 16-17 September were the same finding twice:

  - `clicks_per_second` has closed a question three times and has NO BOUND at
    all. A number with no threshold cannot pass or fail, only be read
    favourably.
  - `m1_audible_when_driving` has a carefully derived bound and has returned
    exactly 0.0000 in 3,555 opportunities, so its discrimination is simulated
    rather than observed.

Both are failures of PROVENANCE rather than of arithmetic, and neither was
visible from the charter's face. The charter reports pass or fail; it does not
report how much evidence stands behind the line it is judging against.

So this asks three questions of every metric, and answers them from the files
rather than from memory:

  1. Is there a bound at all, and is it two-sided?
  2. What is the bound's stated derivation, and does it name an n?
  3. Across the available runs, has the metric ever taken a value that would
     have failed -- or come close?

A metric that has never approached its bound is not thereby broken. m3 spent
weeks pinned against its bound and was right. But "never approached" and "cannot
approach" look identical from the outside, and the difference is the whole
question, so it is worth printing.

  python3 tools/audit_threshold_provenance.py
  python3 tools/audit_threshold_provenance.py --runs 20
"""
import argparse
import glob
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import score_charter as SC                                   # noqa: E402


def derivation_n(spec):
    """Pull an evidence size out of the derivation prose, if it states one.

    Deliberately conservative: it reports what the text SAYS, and reports
    'unstated' rather than inferring. A derivation that does not name its
    sample size is itself the finding.
    """
    blob = " ".join(str(v) for k, v in spec.items() if k.startswith("_"))
    if not blob.strip():
        return None, "no derivation recorded"
    # COUNT THE REFERENCE POINTS, DO NOT GUESS FROM THE FIRST MATCH.
    #
    # The first version matched "6h run" and reported "one run" for seven
    # metrics, which read as though most of the charter rested on a single
    # session. It does not. The derivations cite the 6 h run AND gap_r1 -- two
    # runs -- and m5_not_converging spans "the 15-run ablation or the 6 h run",
    # which is sixteen. The tool manufactured a finding out of its own regex.
    # Second false alarm this audit produced; both were caught by reading the
    # derivations the tool was summarising.
    refs = []
    if re.search(r"\d+\s*h\s+run", blob):
        refs.append("a multi-hour run")
    if "gap_r1" in blob:
        refs.append("gap_r1")
    m = re.search(r"(\d+)-run ablation", blob)
    if m:
        refs.append(f"a {m.group(1)}-run ablation")
    for pat, unit in ((r"(\d[\d,]{2,})\s+driving windows", "driving windows"),
                      (r"(\d[\d,]{2,})\s+windows", "windows"),
                      (r"(\d[\d,]{2,})\s+events", "events")):
        mm = re.search(pat, blob)
        if mm:
            refs.append(f"{mm.group(1)} {unit}")
    if not refs:
        return None, blob[:110]
    return " + ".join(refs), blob[:110]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=12)
    a = ap.parse_args()

    ch = json.load(open(os.path.join(EM, "workdir_music/mutable/charter.json")))
    logs = sorted(glob.glob(os.path.join(
        EM, "workdir_music/renders/live_2609*.log")))[-a.runs:]

    # collect every metric's value across the runs
    seen = {}
    scored_runs = 0
    for p in logs:
        try:
            n, rows, failed, und = SC.evaluate(p, ch)
        except Exception:                                    # noqa: BLE001
            continue
        if n < 100:
            continue
        scored_runs += 1
        for r in rows:
            k = r[0] if isinstance(r, (list, tuple)) else None
            v = r[2] if isinstance(r, (list, tuple)) and len(r) > 2 else None
            if k and isinstance(v, (int, float)):
                seen.setdefault(k, []).append(float(v))

    print(f"\n  charter edition {ch['edition']}, "
          f"{scored_runs} runs of >= 100 windows\n")
    print(f"  {'metric':<26}{'bound':<18}{'derivation n':<22}"
          f"{'observed':<20}headroom")
    print("  " + "-" * 104)

    concerns, deliberates = [], []
    for k, spec in ch["metrics"].items():
        if k.startswith("_"):
            continue
        lo, hi = spec.get("acceptable", [None, None])
        two_sided = lo is not None and hi is not None
        bound = (f"[{lo}, {hi}]" if two_sided
                 else f"[{lo}, -]" if lo is not None
                 else f"[-, {hi}]" if hi is not None
                 else "NONE")
        nstr, _why = derivation_n(spec)
        v = seen.get(k, [])
        if v:
            arr = np.array(v)
            obs = f"{arr.min():.4g}..{arr.max():.4g}"
            # how close did it get to whichever bound it could violate
            head = "-"
            if hi is not None and np.isfinite(hi):
                head = f"{100*arr.max()/hi:.0f}% of upper"
                if arr.max() == 0:
                    head = "NEVER NON-ZERO"
            elif lo is not None and np.isfinite(lo) and lo != 0:
                head = f"{100*arr.min()/lo:.0f}% of lower"
        else:
            obs, head = "(not scored)", "-"

        print(f"  {k:<26}{bound:<18}{(nstr or 'UNSTATED'):<22}{obs:<20}{head}")

        # UNBOUNDED BY DESIGN IS NOT A DEFECT, and the first version of this
        # tool called it one. m9_turnover's entry says "DESCRIPTIVE ON PURPOSE.
        # An upper bound near 0.8 is available from the data and is refused: it
        # would rest on one listener's judgement of two runs, it would be fitted
        # to a distribution that contains the failure". That is the charter
        # declining to set a line it cannot justify, which is the behaviour this
        # audit exists to encourage. Flagging it as a concern inverted the
        # finding. m1_not_silent is the same: demoted to description in edition
        # 4 because it counted a compositional choice as a fault.
        deliberate = any(("DESCRIPTIVE ON PURPOSE" in str(v)) or
                         ("Demoted to a DESCRIPTION" in str(v))
                         for kk, v in spec.items() if kk.startswith("_"))
        if bound == "NONE" and not deliberate:
            concerns.append((k, "no bound, and no note saying that is deliberate"))
        elif bound == "NONE":
            deliberates.append((k, "unbounded ON PURPOSE, with the refusal reasoned"))
        if nstr is None:
            concerns.append((k, "derivation names no evidence at all"))
        elif nstr.count("+") == 0 and "ablation" not in nstr:
            concerns.append((k, f"a single reference point: {nstr}"))
        if v and hi is not None and np.isfinite(hi) and np.array(v).max() == 0:
            concerns.append((k, "has never taken a non-zero value"))

    print()
    if deliberates:
        print("  DELIBERATELY DESCRIPTIVE -- the charter refusing a line it cannot justify:")
        for k, why in deliberates:
            print(f"    {k:<26} {why}")
        print()
    if concerns:
        print("  CONCERNS, one line each:")
        for k, why in concerns:
            print(f"    {k:<26} {why}")
    else:
        print("  no concerns")

    print("\n  Not in the charter at all, yet quoted as verdicts:")
    print("    clicks_per_second          no bound anywhere; closed a question")
    print("                               three times (31 Aug, 1 Sept, bisection)")
    print("    transient threshold        #22, never pre-registered")
    print()


if __name__ == "__main__":
    main()
