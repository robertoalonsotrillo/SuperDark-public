#!/usr/bin/env python3
"""Did the factory know what it was about to do?

THE ONE SIGNAL NOT AUTHORED BY THE ARCHITECT
Every measure in this project is mine: I chose it, and it is computed after the
fact. Exo's continual-release proposal names the exception and why it is worth
more than the others:

    Before starting a task, live or during a trial, Exo writes down what it
    expects... When the task ends, the evaluation rig writes what actually
    happened. The gap is the score.
    ... it arrives the moment the task ends, it needs no human label, and it's
    measured against clocks and bills the agent doesn't control.

The factory now writes, at the close of each window, a probability that the NEXT
window will be audible, formed from the audibility it has learned for whatever
sits in its slots:

    FORECAST <win>,<p_audible>,<live_voices>,<slots_filled>

The outcome is already in the log: MASTER's peak against 0.004, the same
threshold m1_not_silent uses. So this scores a prediction the factory made
against an outcome it did not choose.

HOW IT IS SCORED
Brier score, and the only number that means anything is the comparison against a
forecaster that always predicts the base rate. A forecast that cannot beat the
base rate is honest and uninformative, which is a result and not a failure:
judges.py reached exactly that verdict about its own ensemble and said so.

Plus a shuffled null. Pair each forecast with a RANDOM window's outcome, 2,000
times, and see where the real pairing falls. That catches the failure where a
forecast looks skilled only because audibility is autocorrelated.

NOTHING STEERS ON THIS, by design. Wiring it into selection would make it a
self-generated criterion, and runs 53-58 measured precisely that becoming a
convergence engine.

    python3 tools/reward_channel.py --log <window log>
    python3 tools/reward_channel.py --log <log> --out reward.json
"""
import argparse
import json
import os
import sys

import numpy as np

AUDIBLE_THRESHOLD = 0.004      # the same figure m1_not_silent thresholds
DRAWS = 2000
SEED = 20260916


def read(log):
    fc, peak = {}, {}
    with open(log, errors="replace") as fh:
        for line in fh:
            if line.startswith("FORECAST "):
                b = line.split(None, 1)[1].strip().split(",")
                try:
                    fc[int(b[0])] = (float(b[1]), int(b[2]), int(b[3]))
                except (ValueError, IndexError):
                    pass
            elif line.startswith("MASTER "):
                b = line.split(None, 1)[1].strip().split(",")
                try:
                    peak[int(b[0])] = float(b[1])
                except (ValueError, IndexError):
                    pass
    return fc, peak


def brier(p, y):
    return float(np.mean((np.asarray(p) - np.asarray(y)) ** 2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--out", default=None)
    ap.add_argument("--draws", type=int, default=DRAWS)
    args = ap.parse_args()

    fc, peak = read(args.log)
    wins = sorted(set(fc) & set(peak))
    if len(wins) < 50:
        print(f"  {len(wins)} paired windows: too few to score.")
        print("  The factory writes FORECAST only from the restart that brought")
        print("  the reward channel live; earlier runs have none.")
        return 1

    p = np.array([fc[w][0] for w in wins])
    # A peak above 2.0 is a numerical blow-up, not audio (see
    # docs/measurements/2026-09-16_numerical_blowups.md). Counting it as a
    # successful prediction of audibility would reward the factory for
    # exploding, so those windows are dropped and counted.
    raw = np.array([peak[w] for w in wins])
    ok = raw <= 2.0
    dropped = int((~ok).sum())
    p, raw, wins = p[ok], raw[ok], [w for w, k in zip(wins, ok) if k]
    y = (raw >= AUDIBLE_THRESHOLD).astype(float)

    base = float(y.mean())
    b_model = brier(p, y)
    b_base = brier(np.full_like(p, base), y)
    skill = b_base - b_model                       # positive = better than base

    # PERSISTENCE IS THE REAL BASELINE, and finding that out before any data
    # existed is why this was pre-registered.
    #
    # audib[m] is updated EVERY WINDOW, as an exponential moving average at rate
    # 0.25 of "was the last window heard". Slot machines persist across windows.
    # So a forecast built from audib is close to "the next window will be like
    # the last one", and audibility is autocorrelated, so beating the BASE RATE
    # is nearly free. The shuffled null does not catch this: it tests against no
    # relationship, and trivial persistence is a relationship.
    #
    # The question worth asking is whether the factory beats persistence. If it
    # does not, it knows nothing beyond "things stay the same", which is not a
    # model of its own consequences.
    # CALIBRATED persistence, not a hard 0/1 repeat. A forecaster that answers
    # 1.0 or 0.0 is savaged by Brier whenever it is wrong, so beating it proves
    # nothing -- the first version of this baseline did exactly that and the
    # self-check caught it: a generator built to be PURE persistence scored
    # +0.020 against it. The fair baseline is the conditional rate estimated
    # from the arm itself: P(audible | last was audible) and
    # P(audible | last was not).
    y_prev = np.concatenate([[y[0]], y[:-1]])
    m1, m0 = y_prev == 1, y_prev == 0
    p1 = float(y[m1].mean()) if m1.any() else base
    p0 = float(y[m0].mean()) if m0.any() else base
    p_persist = np.where(y_prev == 1, p1, p0)
    b_persist = brier(p_persist, y)
    skill_vs_persist = b_persist - b_model

    rng = np.random.default_rng(SEED)
    null = np.empty(args.draws)
    for i in range(args.draws):
        null[i] = b_base - brier(p, rng.permutation(y))
    p_val = float((null >= skill).mean())

    print()
    print(f"  THE REWARD CHANNEL   {os.path.basename(args.log)}")
    print(f"    paired windows      {len(wins)}"
          + (f"   ({dropped} dropped as blow-ups)" if dropped else ""))
    print(f"    base rate audible   {base:.4f}")
    print(f"    forecast mean       {p.mean():.4f}   sd {p.std():.4f}")
    print(f"    Brier, factory      {b_model:.5f}")
    print(f"    Brier, base rate    {b_base:.5f}")
    print(f"    Brier, persistence  {b_persist:.5f}   <- the baseline that matters")
    print(f"    skill vs base       {skill:+.5f}")
    print(f"    skill vs PERSISTENCE {skill_vs_persist:+.5f}")
    print(f"    shuffled null       mean {null.mean():+.5f}, "
          f"95th pct {np.percentile(null, 95):+.5f}")
    print(f"    p                   {p_val:.4f}")
    print()
    if p.std() < 1e-6:
        verdict = "CONSTANT: the factory predicts the same number every window"
        print("  CONSTANT FORECAST. The factory is not discriminating between")
        print("  windows at all, so the Brier score describes its base rate and")
        print("  nothing else. That is a broken forecast, not a calibrated one.")
    elif skill > 0 and p_val <= 0.05 and skill_vs_persist > 0:
        verdict = "SKILLED"
        print("  SKILLED. The factory beats the base rate, the shuffled null says")
        print("  the pairing matters, AND it beats persistence. It knows something")
        print("  about what it is about to do beyond 'the same as last time'.")
    elif skill > 0 and p_val <= 0.05:
        verdict = "PERSISTENCE ONLY"
        print("  PERSISTENCE ONLY. The factory beats the base rate and does NOT")
        print("  beat a forecaster that simply repeats the last window. audib[m]")
        print("  is an EMA at rate 0.25 updated every window, so the forecast is")
        print("  close to a lagged copy of the outcome. This is not a model of")
        print("  its own consequences; it is autocorrelation, and it may not be")
        print("  quoted as skill.")
    else:
        verdict = "NO SKILL"
        print("  NO SKILL. The factory does not anticipate its own audibility.")
        print("  Honest and uninformative, which is the same verdict judges.py")
        print("  reached about its own ensemble. It is a result: the machines")
        print("  have no useful model of their own consequences.")

    print()
    print("REWARD_skill=%.5f" % skill)
    print("REWARD_skill_vs_persistence=%.5f" % skill_vs_persist)
    print("REWARD_p=%.4f" % p_val)
    print("REWARD_base=%.4f" % base)

    if args.out:
        with open(args.out, "w") as fh:
            json.dump({"log": os.path.basename(args.log), "n": len(wins),
                       "dropped_blowups": dropped, "base_rate": base,
                       "brier_model": b_model, "brier_base": b_base,
                       "skill_vs_base": skill,
                       "brier_persistence": b_persist,
                       "skill_vs_persistence": skill_vs_persist,
                       "p": p_val, "verdict": verdict,
                       "forecast_mean": float(p.mean()),
                       "forecast_sd": float(p.std()),
                       "_nothing_steers_on_this": True}, fh, indent=1)
        print(f"\n{args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
