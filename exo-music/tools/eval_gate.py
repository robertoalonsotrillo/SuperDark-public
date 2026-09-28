#!/usr/bin/env python3
"""The verdict. Deterministic: same comparison, same policy version, same answer.

The gate does three things in order and stops at the first that says no.

  1  hard invariants   absolute; no measurement waives one
  2  veto              any measure with veto power that got worse blocks
  3  promotion         a measure that still HOLDS promotion power must show a win

Step 3 is where this project has been cheating. Every measure here has been
visible to every change made after it was built, so promoting on one is
promoting on a seen task. harness/measures.json gives each measure a budget of
three adjudications and then takes its promotion power away. The gate reads
that and will refuse a promotion argued from a spent measure.

While margins are UNSET the gate runs in shadow: it computes everything, writes
the decision, and returns 3 with verdict "margins_unset". It promotes nothing.
Changes still ship on my judgement. The difference is that the bundle says so.

Exit: 0 promote, 1 rig broke, 3 anything else.
"""
import argparse
import datetime as dt
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
HARNESS = os.path.join(EM, "harness")


def load(path):
    with open(path) as fh:
        return json.load(fh)


def decide(comp, pol, ctx):
    notes, blocked = [], []

    # --- 0. the comparison itself has to be sound ---------------------------
    for p in comp.get("problems", []):
        blocked.append(f"comparison: {p}")
    if not comp.get("paired", False):
        blocked.append(
            "comparison: both arms read the same log. That is one run measured "
            "twice, not two runs compared.")

    # --- 1. hard invariants --------------------------------------------------
    # Each is a real tool; eval_invariants.py is the thin wiring that calls them.
    # An unverified invariant blocks exactly as a failed one does. A gate that
    # treats "could not check" as "fine" is the same failure as a panel that
    # shows green because its source is gone.
    inv = ctx["invariants"]
    failed = [k for k, v in inv.items() if v["pass"] is False]
    unverified = [k for k, v in inv.items() if v["pass"] is None]
    for k in failed:
        blocked.append(f"invariant {k}: {inv[k]['observed']}")
    if unverified:
        blocked.append(
            f"hard invariants unverified ({len(unverified)} of {len(inv)}): "
            + ", ".join(unverified))

    # --- 2. veto -------------------------------------------------------------
    vetoes = []
    for key, m in comp["measures"].items():
        if not m.get("veto"):
            continue
        if m.get("candidate_status") not in ("ok", None):
            vetoes.append(f"{key}: candidate arm {m.get('candidate_status')}")
        # A champion that produced no number is not a veto, it is an absent
        # reference: the measure could not judge this pair at all. 19 Sept, A3
        # vs C3: champion NO AUDIO, candidate ok, and the gate returned
        # MARGINS_UNSET as if sonic_variety had looked and found nothing wrong.
        # Treated as blocked, worded as what it is.
        elif m.get("champion_status") not in ("ok", None):
            blocked.append(f"unjudged: {key}: champion arm "
                           f"{m.get('champion_status')}, no reference to compare against")
    for v in vetoes:
        blocked.append("veto: " + v)

    # --- 3. promotion --------------------------------------------------------
    can_promote = [k for k, m in comp["measures"].items() if m.get("promote")]
    wins = []
    for key in can_promote:
        m = comp["measures"][key]
        if m.get("delta"):
            wins.append({"measure": key, "delta": m["delta"]})
    if not can_promote:
        notes.append(
            "No measure in this comparison holds promotion power. Everything is "
            "spent, veto-only or retired. A change can be blocked today and "
            "cannot be justified. Pre-register a new measure, or record that "
            "the change shipped on the ear.")

    margins_unset = pol["margins"]["status"] == "UNSET"

    if blocked:
        verdict, why = "blocked", blocked[0]
    elif margins_unset:
        verdict = "margins_unset"
        why = ("The gate ran and promotes nothing. Margins are not set, so "
               "'clearly better' has no number behind it yet. Five paired "
               "comparisons in shadow, then set them from that data.")
    elif not wins:
        verdict, why = "retain", ("No reason to switch was found, and a tie "
                                  "keeps the champion.")
    else:
        verdict, why = "promote", f"win on {', '.join(w['measure'] for w in wins)}"

    return {"verdict": verdict, "why": why, "blocked": blocked,
            "notes": notes, "invariants": inv, "wins": wins,
            "measures_with_promotion_power": can_promote}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--comparison", required=True)
    ap.add_argument("--policy", required=True)
    ap.add_argument("--skip", default="",
                    help="invariant keys to skip; each is recorded as SKIPPED "
                         "and still blocks, because 'could not check' is not "
                         "'fine'")
    args = ap.parse_args()

    path = args.comparison
    if os.path.isdir(path):
        path = os.path.join(path, "comparison.json")
    if not os.path.isfile(path):
        print(f"no comparison at {path}", file=sys.stderr)
        return 1
    comp = load(path)

    pid, _, pver = args.policy.partition("@")
    pol_path = os.path.join(HARNESS, f"release_policy.v{pver or 1}.json")
    if not os.path.isfile(pol_path):
        print(f"no policy at {pol_path}", file=sys.stderr)
        return 1
    pol = load(pol_path)
    if pol["id"] != pid:
        print(f"policy id mismatch: asked {pid}, file says {pol['id']}",
              file=sys.stderr)
        return 1

    sys.path.insert(0, HERE)
    import eval_invariants
    dest = os.path.dirname(path)
    try:
        inv = eval_invariants.evaluate(dest, pol_path,
                                       skip=tuple(x for x in args.skip.split(",") if x))
    except Exception as e:                    # the rig broke, not the factory
        print(f"invariant checks could not run: {type(e).__name__}: {e}",
              file=sys.stderr)
        return 1

    d = decide(comp, pol, {"invariants": inv})
    d.update({"t": time.time(),
              "iso": dt.datetime.now().isoformat(timespec="seconds"),
              "event": "gate", "comparison": comp["comparison_id"],
              "policy": f"{pol['id']}@{pol['version']}"})

    with open(os.path.join(dest, "decisions.jsonl"), "a") as fh:
        fh.write(json.dumps(d, sort_keys=True) + "\n")
    with open(os.path.join(dest, "invariants.json"), "w") as fh:
        json.dump(d["invariants"], fh, indent=1, sort_keys=True)

    print("invariants:")
    for k, v in d["invariants"].items():
        mark = {True: "ok  ", False: "FAIL", None: "----"}[v["pass"]]
        print(f"  {mark}  {k:24s} {v['observed']}")
    print()
    print(f"VERDICT  {d['verdict'].upper()}")
    print(f"         {d['why']}")
    if d["blocked"]:
        print("\nblocked by:")
        for b in d["blocked"]:
            print(f"  - {b}")
    if d["notes"]:
        print("\nnotes:")
        for n in d["notes"]:
            print(f"  - {n}")
    print(f"\nmeasures with promotion power: "
          f"{', '.join(d['measures_with_promotion_power']) or 'none'}")
    print(f"\n{dest}/decisions.jsonl")
    print("\nThe gate produces a verdict. A person ships it. A person may hold a")
    print("promotion for any reason, including the ear, and may not patch the")
    print("candidate and ship it anyway: only checkpointed states ship.")

    return 0 if d["verdict"] == "promote" else 3


if __name__ == "__main__":
    sys.exit(main())
