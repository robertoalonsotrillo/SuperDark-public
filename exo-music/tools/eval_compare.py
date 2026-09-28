#!/usr/bin/env python3
"""The only place a difference is computed.

Roles are named flags, never positional. Swapping the order of two run
directories would flip the sign of every delta and the output would still read
as a perfectly sensible result, which is how a comparison lies without anything
looking broken.

Writes a comparison JSON to stdout and to harness/runs/<cmp-id>/comparison.json.
"""
import argparse
import datetime as dt
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
RUNS = os.path.join(EM, "harness", "runs")


def load(d, name):
    with open(os.path.join(d, name)) as fh:
        return json.load(fh)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidate", required=True)
    ap.add_argument("--champion", required=True)
    args = ap.parse_args()

    cand_m, champ_m = load(args.candidate, "manifest.json"), load(args.champion, "manifest.json")
    cand_r, champ_r = load(args.candidate, "results.json"), load(args.champion, "results.json")

    problems = []
    if cand_m["policy"] != champ_m["policy"]:
        problems.append(
            f"policy differs: {cand_m['policy']} vs {champ_m['policy']}. "
            "Two arms judged under different policies are not comparable.")
    if cand_m["checkpoint"] == champ_m["checkpoint"]:
        problems.append(
            "both arms name the same checkpoint. This is a comparison of a "
            "state with itself.")
    if cand_m["arm"] == champ_m["arm"]:
        problems.append(
            f"both arms are labelled '{cand_m['arm']}'. Check the flags; the "
            "sign of every delta below depends on which is which.")

    per = {}
    for key in sorted(set(cand_r) | set(champ_r)):
        a, b = cand_r.get(key, {}), champ_r.get(key, {})
        rec = {"candidate": a.get("value"), "champion": b.get("value"),
               "candidate_status": a.get("status"), "champion_status": b.get("status"),
               "promote": a.get("promote", False), "veto": a.get("veto", False)}
        if a.get("scorer_sha256") != b.get("scorer_sha256"):
            rec["_scorer_differs"] = (
                "The two arms were scored by different text of the same "
                "measure. The delta is not attributable to the factory.")
            problems.append(f"{key}: scorer hash differs between arms")
        if a.get("status") == "ok" and b.get("status") == "ok" \
                and isinstance(a.get("value"), dict) and isinstance(b.get("value"), dict):
            delta = {}
            for k in sorted(set(a["value"]) & set(b["value"])):
                av, bv = a["value"][k], b["value"][k]
                if isinstance(av, (int, float)) and isinstance(bv, (int, float)):
                    delta[k] = round(av - bv, 6)
            rec["delta"] = delta or None
        else:
            rec["delta"] = None
            rec["_no_delta"] = "one or both arms did not produce a number"
        per[key] = rec

    # ---- PAIRING: DISJOINT WINDOWS, NOT DIFFERENT FILENAMES ------------------
    #
    # Read from arm_windows.log and NOT from the manifest. The manifest's
    # `windows` field recorded the whole log's range regardless of slicing until
    # it was fixed on 16 Sept, so bundles written before that claim a scope three
    # times wider than they scored. arm_windows.log is what the measures actually
    # read, so it is the only honest answer to "which windows is this number
    # about" -- and it is present in every bundle, including the old ones.
    def scored_span(run_dir):
        p = os.path.join(run_dir, "arm_windows.log")
        if not os.path.isfile(p):
            return None
        lo = hi = None
        with open(p, errors="replace") as fh:
            for line in fh:
                if not line.startswith("VOICES"):
                    continue
                try:
                    w = int(line.split()[1].split(",")[0])
                except (IndexError, ValueError):
                    continue
                lo = w if lo is None else min(lo, w)
                hi = w if hi is None else max(hi, w)
        return None if lo is None else [lo, hi]

    cand_span, champ_span = scored_span(args.candidate), scored_span(args.champion)
    if cand_span is None or champ_span is None:
        paired = cand_m["log"] != champ_m["log"]
        why_paired = ("no arm_windows.log in one or both bundles, so the scored "
                      "ranges are unknown; fell back to comparing log filenames")
    elif cand_span[1] < champ_span[0] or champ_span[1] < cand_span[0]:
        paired = True
        why_paired = (f"disjoint windows: champion {champ_span}, "
                      f"candidate {cand_span}")
    else:
        paired = False
        why_paired = (f"OVERLAPPING windows: champion {champ_span}, "
                      f"candidate {cand_span}. Windows scored by both arms "
                      f"appear on both sides of every delta.")

    cmp_id = "cmp_" + dt.datetime.now().strftime("%y%m%d_%H%M%S")
    out = {
        "comparison_id": cmp_id,
        "created": time.time(),
        "created_iso": dt.datetime.now().isoformat(timespec="seconds"),
        "candidate_run": os.path.basename(args.candidate),
        "champion_run": os.path.basename(args.champion),
        "candidate_checkpoint": cand_m["checkpoint"],
        "champion_checkpoint": champ_m["checkpoint"],
        "policy": cand_m["policy"],
        "paired": paired,
        "_paired": why_paired,
        "_paired_rule": (
            "Two arms are paired when they scored DISJOINT sets of windows. "
            "Filename inequality was the old test and it was wrong: slice_log() "
            "exists so that a hot-reloaded comparison CAN share one log, "
            "because the change is a policy value needing no restart -- and a "
            "restart would move the trace and the corpus alongside the knob, "
            "breaking one_change_at_a_time. One part of the rig enabled what "
            "another rejected. Decided 16 Sept by Roberto: disjoint ranges "
            "count as paired. Overlap of even one window does not."),
        "candidate_windows": cand_span,
        "champion_windows": champ_span,
        "problems": problems,
        "measures": per,
    }

    dest = os.path.join(RUNS, cmp_id)
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, "comparison.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)

    print(json.dumps(out, indent=1, sort_keys=True))
    print(f"\n{dest}/comparison.json", file=sys.stderr)
    if problems:
        print(f"{len(problems)} problem(s) recorded in the comparison; the gate "
              f"will read them.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
