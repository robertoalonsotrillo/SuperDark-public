#!/usr/bin/env python3
"""Tier two: judges of judges. The recursion the paper asks for, one level up.

WHAT THE PAPER ASKS (5.3, third principle)
"evaluations must be recursive -- and massively so. Every individual evaluator
can be, and will be, incorrect, just as it can overfit to its own reward
structure." Beer: any viable system is built from smaller viable systems, each
sensing, deciding and rewarding within its own scope. So the factory should have
evaluations of evaluations, stacking to some arbitrary depth.

WHAT TIER ONE ALREADY DOES, AND WHY IT IS NOT RECURSION
judges.py scores each tier-one judge on whether the anomaly it flagged actually
followed. That is a scoring RULE applied from outside -- useful, and it is the
fourth principle, but it does not learn and it is not an evaluator. Calling it
recursion would be the same overstatement as calling one scorer "a population".

WHAT THIS DOES
A second population predicts, for each tier-one judge, whether that judge is
about to be RIGHT. Its features are tier one's own behaviour: what the judge
just predicted, how confident it was, how the population is spread, and whether
it was correct recently. Its outcome is observable without reference to its own
prediction -- tier one either was right or was not -- so the grading signal sits
outside tier two's loop for exactly the reason it sits outside tier one's:
NEITHER TIER STEERS ANYTHING.

WHAT IT IS FOR, CONCRETELY
A tier-two judge that reliably predicts when a tier-one judge is about to be
wrong is detecting something the first tier cannot see about itself. That is the
whole argument for recursion, and it is testable: if tier two cannot beat the
base rate of tier-one correctness, the second level is decoration and should be
reported as such rather than counted as a principle satisfied.

THE SAME NEGATIVE CONTROL. Permute the outcomes and tier two must lose its
skill. A recursion that "works" on shuffled data is a harness fooling itself one
level further from the evidence, which is harder to notice, not easier.

    python3 tools/judges_tier2.py --log <windows.log>
"""
import argparse
import glob
import json
import os
import random
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import judges as T1                                    # noqa: E402

SUMMARY = "/Volumes/FMA/superdark/renders/judges_tier2.json"


def tier1_trace(records, shuffle_labels=False, seed=7):
    """Re-run tier one, keeping every per-window prediction.

    Deliberately re-running rather than reading judges.jsonl: the trace has to
    correspond exactly to the window sequence tier two is about to learn on, and
    a file written by an earlier process against an earlier log would not.
    """
    ys = [T1.anomalous(r) for r in records]
    if shuffle_labels:
        rng = random.Random(seed)
        ys = ys[:]
        rng.shuffle(ys)
    js = T1.population()
    hist, trace = [], []
    for t in range(len(records) - 1):
        y = ys[t + 1]
        row = {}
        for j in js:
            ps = [f(hist) for _, f in j["ex"]]
            p = j["algo"].predict(ps)
            row[j["name"]] = p
            j["algo"].update(ps, y)
        trace.append({"w": records[t]["w"], "preds": row, "outcome": y})
        hist.append((records[t], y))
    return trace, [j["name"] for j in js]


def t2_experts():
    """Predictors of "this judge is about to be right".

    Crude on purpose, as in tier one: the learner's job is to weight them, and a
    basis of strong models would hide whether the weighting does anything.
    """
    return [
        ("constant", lambda c: 0.6),
        ("base_rate", lambda c: c["base"]),
        # A judge that was right last time tends to be right again if the series
        # is locally predictable; if it is not, this expert loses weight.
        ("was_right", lambda c: 0.75 if c["prev_right"] else 0.45),
        # Confidence: a judge saying 0.9 or 0.1 is committing; one saying 0.5 is
        # not. Commitment near the extremes is usually better calibrated.
        ("committed", lambda c: 0.72 if abs(c["p"] - 0.5) > 0.25 else 0.5),
        # When the population agrees, any one of them is likelier to be right;
        # disagreement is the paper's early-warning signal, used here as a
        # FEATURE rather than as an alarm.
        ("consensus", lambda c: 0.72 if c["spread"] < 0.04 else 0.45),
    ]


def run_tier2(trace, names):
    ex = t2_experts()
    out = {}
    for nm in names:
        # One mean-based and one swap-based learner per tier-one judge, keeping
        # the variety requirement at this level too.
        out[nm] = {
            "hedge": T1.Hedge(len(ex), 0.3),
            "swap": T1.SwapRegret(len(ex), 0.3),
            "loss_h": 0.0, "loss_s": 0.0, "n": 0, "right": 0,
            "prev_right": True, "best_expert": np.zeros(len(ex)),
        }
    for t, row in enumerate(trace):
        spread = float(np.std(list(row["preds"].values())))
        for nm, p in row["preds"].items():
            s = out[nm]
            # "Right" means the judge's side of 0.5 matched what happened.
            right = 1 if ((p >= 0.5) == (row["outcome"] == 1)) else 0
            base = (s["right"] / s["n"]) if s["n"] > 20 else 0.6
            ctx = {"p": p, "spread": spread, "prev_right": s["prev_right"],
                   "base": base}
            ps = [f(ctx) for _, f in ex]
            ph = s["hedge"].predict(ps)
            pw = s["swap"].predict(ps)
            s["loss_h"] += (ph - right) ** 2
            s["loss_s"] += (pw - right) ** 2
            s["best_expert"] += np.array([(q - right) ** 2 for q in ps])
            s["hedge"].update(ps, right)
            s["swap"].update(ps, right)
            s["n"] += 1
            s["right"] += right
            s["prev_right"] = bool(right)
    res = []
    for nm, s in out.items():
        n = max(s["n"], 1)
        acc = s["right"] / n                      # how often tier one was right
        base_brier = acc * (1 - acc)              # predicting the base rate
        res.append({
            "judges": nm,
            "tier1_accuracy": acc,
            "base_brier": base_brier,
            "hedge_brier": s["loss_h"] / n,
            "swap_brier": s["loss_s"] / n,
            "best_expert_brier": float(s["best_expert"].min()) / n,
            "gain": base_brier - min(s["loss_h"], s["loss_s"]) / n,
        })
    return res


def show(tag, res):
    print(f"\n  === {tag} ===")
    print(f"  {'watches':22} {'t1 acc':>7} {'base':>8} {'hedge':>8} "
          f"{'swap':>8} {'gain':>8}")
    for r in sorted(res, key=lambda x: -x["gain"]):
        print(f"  {r['judges']:22} {r['tier1_accuracy']:7.3f} "
              f"{r['base_brier']:8.4f} {r['hedge_brier']:8.4f} "
              f"{r['swap_brier']:8.4f} {r['gain']:+8.4f}")
    print(f"  best gain {max(r['gain'] for r in res):+.4f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=None)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--watch", action="store_true",
                    help="recompute on a slow loop and keep the summary current")
    ap.add_argument("--interval", type=float, default=1800.0)
    a = ap.parse_args()

    if a.watch:
        # Half-hourly, not five-minutely like tier one. This re-runs the whole
        # first tier twice (once live, once permuted) before it can learn
        # anything, so it costs minutes on a long log. Nothing it measures moves
        # faster than that anyway: it is watching judges accumulate a track
        # record, which is a slow quantity by nature.
        while True:
            try:
                lg = sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                            key=os.path.getmtime)[-1]
                rs = T1.read_windows(lg)
                # 1200 WINDOWS, NOT 300. A second tier is looking for structure
                # in how often the FIRST tier is right, and tier one is right
                # about 85% of the time, so the quantity being predicted is
                # rare-ish and needs a long run to estimate. Measured: on a
                # 2,532-window log the gain is +0.0035 and passes its control;
                # on a 130-window log it is +0.0002 and fails. The short answer
                # is not a finding, it is noise -- and because this loop
                # overwrites the summary each cycle, one short run was enough to
                # replace a real result with a spurious one on the public page.
                # Refusing to publish is the correct behaviour when the sample
                # cannot support a verdict.
                if len(rs) >= 1200:
                    tr, nm = tier1_trace(rs)
                    rl = run_tier2(tr, nm)
                    tc, _ = tier1_trace(rs, shuffle_labels=True)
                    cl = run_tier2(tc, nm)
                    gg = max(r["gain"] for r in rl)
                    gcc = max(r["gain"] for r in cl)
                    tmp = SUMMARY + ".tmp"
                    json.dump({
                        "generated": time.time(), "log": os.path.basename(lg),
                        "windows": len(rs), "tier2_population": len(rl) * 2,
                        "best_gain": gg, "control_gain": gcc,
                        "passes_control": bool(gg > 0.002 and gcc <= 0.002),
                        "informative": bool(gg > 0.002),
                        "mean_tier1_accuracy": sum(r["tier1_accuracy"]
                                                   for r in rl) / len(rl),
                        "per_judge": sorted(rl, key=lambda x: -x["gain"])[:5],
                    }, open(tmp, "w"), indent=1)
                    os.replace(tmp, SUMMARY)
                    print(f"  {time.strftime('%H:%M:%S')}  {len(rs)} windows, "
                          f"gain {gg:+.4f}, control {gcc:+.4f}", flush=True)
            except Exception as e:
                print(f"  {type(e).__name__}: {e}", flush=True)
            time.sleep(a.interval)
    log = a.log or sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                          key=os.path.getmtime)[-1]
    recs = T1.read_windows(log)
    print(f"\n  {os.path.basename(log)}: {len(recs)} windows")
    if len(recs) < 300:
        raise SystemExit("  too short for a second tier")

    tr, names = tier1_trace(recs)
    real = run_tier2(tr, names)
    show("TIER TWO on live outcomes", real)

    trc, _ = tier1_trace(recs, shuffle_labels=True)
    ctrl = run_tier2(trc, names)
    show("NEGATIVE CONTROL (outcomes permuted)", ctrl)

    g, gc = (max(r["gain"] for r in real), max(r["gain"] for r in ctrl))
    print()
    if g > 0.002 and gc <= 0.002:
        verdict = ("RECURSION EARNS ITS PLACE: tier two anticipates when a tier-one "
                   "judge is about to be wrong, and finds nothing in noise.")
    elif gc > 0.002:
        verdict = ("FAILS ITS CONTROL: tier two finds skill in permuted outcomes. "
                   "The second level is an artefact of the harness. Do not report "
                   "recursion as satisfied.")
    else:
        verdict = ("NO SKILL: tier two cannot beat the base rate of tier-one "
                   "correctness. The level exists but is decoration, and should "
                   "be reported as present-and-uninformative, not as a principle "
                   "satisfied.")
    print("  " + verdict)

    if a.write:
        json.dump({
            "generated": time.time(), "log": os.path.basename(log),
            "windows": len(recs), "tier2_population": len(real) * 2,
            "best_gain": g, "control_gain": gc,
            "passes_control": bool(g > 0.002 and gc <= 0.002),
            "informative": bool(g > 0.002),
            "verdict": verdict,
            "per_judge": sorted(real, key=lambda x: -x["gain"])[:5],
        }, open(SUMMARY, "w"), indent=1)
        print(f"  wrote {SUMMARY}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
