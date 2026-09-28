#!/usr/bin/env python3
"""Collect listener judgements WITHOUT showing the numbers, so m9 can get a bound.

WHY A BOUND CANNOT BE READ OFF THE DATA. m9_turnover was added descriptive and
unbounded on purpose. An upper bound near 0.8 is sitting in the runs on disk and
taking it would mean fitting to a distribution that CONTAINS the failure -- the
week when turnover drifted 0.736 to 0.950 and the listener called the result
"endless radio-like fragmentary shit". Fitting to that ratifies the drift as the
acceptable range. It is also one listener's judgement of two runs, which is
exactly how m7 and the 0.9 drift threshold were set, and both were withdrawn.

WHY BLIND. The architect knows what turnover is and roughly what each run scored.
A judgement made while looking at the number is a judgement of the number. This
plays a segment, asks one question, and does not print the metric until every
segment has been rated -- so the correlation, if there is one, is between the ear
and the measurement rather than between the ear and its own expectation.

WHAT IT PRODUCES. blind_listen.jsonl, one line per rating: segment, run, window
range, verdict. The bound is then set from the RANGE OF TURNOVER OVER RUNS RATED
ACCEPTABLE, and recorded as having been set that way. Several runs per verdict,
not one.

    python3 tools/blind_listen.py --build      # cut segments from recent runs
    python3 tools/blind_listen.py --rate       # listen and judge, numbers hidden
    python3 tools/blind_listen.py --report     # reveal, and propose a bound
"""
import argparse
import datetime
import glob
import json
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

RENDERS = "/Volumes/FMA/superdark/renders"
SEGMENTS = "/Volumes/FMA/superdark/segments"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable",
                   "blind_listen.jsonl")
PLAN = "/tmp/blind_listen_plan.json"


def turnover_of(path, lo=45, hi=10**9):
    """Same quantity score_charter computes, over a window range."""
    seq = []
    for line in open(path, errors="replace"):
        if line and line[0].isdigit():
            f = line.strip().split(",")
            if len(f) > 15 and f[3] in ("runtime", "class"):
                try:
                    w = int(f[1])
                except ValueError:
                    continue
                if lo <= w < hi:
                    seq.append(f[2])
    if len(seq) < 3:
        return None
    return round(sum(1 for a, b in zip(seq, seq[1:]) if a != b) / (len(seq) - 1), 4)


def cmd_build(n):
    """Pick runs spanning the turnover range, and note which segment file covers
    them. Segments are 600 s each and already on disk from the splitter."""
    rows = []
    for p in sorted(glob.glob(os.path.join(RENDERS, "live_*.log"))):
        t = turnover_of(p)
        if t is not None:
            rows.append({"run": os.path.basename(p), "turnover": t,
                         "windows": sum(1 for l in open(p, errors="replace")
                                        if l.startswith("MASTER "))})
    rows = [r for r in rows if r["windows"] >= 120]
    if len(rows) < 4:
        print("  too few scoreable runs", file=sys.stderr)
        return 2
    rows.sort(key=lambda r: r["turnover"])
    # spread across the observed range rather than sampling uniformly, so the
    # rating set contains both ends of the thing being tested
    idx = [int(round(i * (len(rows) - 1) / (n - 1))) for i in range(min(n, len(rows)))]
    plan = [rows[i] for i in sorted(set(idx))]
    random.shuffle(plan)                       # order carries no information
    for i, r in enumerate(plan):
        r["segment"] = i + 1
    json.dump(plan, open(PLAN, "w"), indent=2)
    print()
    print(f"  {len(plan)} segments planned, order randomised, numbers hidden.")
    print(f"  turnover range across them: {min(r['turnover'] for r in plan):.3f}"
          f" to {max(r['turnover'] for r in plan):.3f}")
    print(f"  written to {PLAN}")
    print()
    print("  Segments are the splitter's 600 s captures in")
    print(f"  {SEGMENTS} — play the one whose timestamp covers each run.")
    print("  Then: python3 tools/blind_listen.py --rate")
    return 0


def cmd_rate():
    if not os.path.exists(PLAN):
        print("  run --build first", file=sys.stderr)
        return 2
    plan = json.load(open(PLAN))
    done = set()
    if os.path.exists(OUT):
        for l in open(OUT):
            try:
                done.add(json.loads(l)["run"])
            except Exception:
                pass
    todo = [r for r in plan if r["run"] not in done]
    if not todo:
        print("  every planned segment already rated. --report to reveal.")
        return 0
    print()
    print("  For each run, listen to its capture, then answer.")
    print("  The metric is NOT shown. That is the point.")
    print("  verdict: (g)ood  (a)cceptable  (f)ragmentary  (s)kip")
    print()
    with open(OUT, "a") as f:
        for r in todo:
            print(f"  segment {r['segment']}  run {r['run']}  ({r['windows']} windows)")
            v = input("    verdict [g/a/f/s]: ").strip().lower()[:1]
            if v == "s" or v == "":
                continue
            if v not in "gaf":
                print("    not a verdict, skipped")
                continue
            note = input("    note (optional): ").strip()
            f.write(json.dumps({
                "run": r["run"], "segment": r["segment"], "verdict": v,
                "note": note, "by": "Roberto Alonso Trillo",
                "when": datetime.datetime.now().isoformat(timespec="seconds")}) + "\n")
            f.flush()
            print("    recorded")
    print("\n  --report to reveal the numbers.")
    return 0


def cmd_report():
    if not os.path.exists(OUT):
        print("  nothing rated yet", file=sys.stderr)
        return 2
    rows = [json.loads(l) for l in open(OUT)]
    for r in rows:
        r["turnover"] = turnover_of(os.path.join(RENDERS, r["run"]))
    rows = [r for r in rows if r["turnover"] is not None]
    if not rows:
        return 2
    print()
    print(f"  {len(rows)} ratings")
    print(f"  {'run':32} {'verdict':>9} {'turnover':>9}")
    print("  " + "-" * 54)
    for r in sorted(rows, key=lambda x: x["turnover"]):
        name = {"g": "good", "a": "acceptable", "f": "fragmentary"}[r["verdict"]]
        print(f"  {r['run'][:32]:32} {name:>9} {r['turnover']:9.3f}")

    ok = [r["turnover"] for r in rows if r["verdict"] in "ga"]
    bad = [r["turnover"] for r in rows if r["verdict"] == "f"]
    print()
    if len(ok) >= 3 and len(bad) >= 3:
        print(f"  acceptable  n={len(ok)}  turnover {min(ok):.3f} to {max(ok):.3f}")
        print(f"  fragmentary n={len(bad)}  turnover {min(bad):.3f} to {max(bad):.3f}")
        if max(ok) < min(bad):
            print(f"\n  SEPARATED. A bound anywhere in ({max(ok):.3f}, {min(bad):.3f})")
            print(f"  divides them. Record which runs it was set from.")
        else:
            print(f"\n  OVERLAPPING. The verdicts do not separate on turnover, so")
            print(f"  turnover is not what the ear is tracking, or not alone.")
            print(f"  Do NOT set a bound: that would be fitting to noise.")
    else:
        print(f"  acceptable n={len(ok)}, fragmentary n={len(bad)}")
        print(f"  NOT ENOUGH. Three of each at minimum before a bound is")
        print(f"  defensible -- fewer is one listener on two runs, which is how")
        print(f"  m7 and the 0.9 threshold were set and both were withdrawn.")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--rate", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("-n", type=int, default=8)
    a = ap.parse_args()
    if a.build:
        return cmd_build(a.n)
    if a.rate:
        return cmd_rate()
    if a.report:
        return cmd_report()
    print(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main())
