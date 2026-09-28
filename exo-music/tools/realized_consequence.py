#!/usr/bin/env python3
"""Realized-consequence scoring: the judges' second reward signal.

P502 -- and this is the mechanism our judge population was missing:

  "this cannot be the only reward mechanism for the evaluations layer, because
  if that were the case, then evaluator agents and productive agents would be
  easily incentivized to collaborate in the direction of overfitting. A second
  reward signal is required, and it needs to come from outside the factory's
  input... This second metric scores REALIZED CONSEQUENCE: a judgment of whether
  a given verdict predicted real downstream outcomes. For example, a judge that
  flagged some anomalous behavior should be duly incentivized only if that
  anomalous behavior PRECEDED A TRUE REGRESSION or caused a real failure in the
  world of the factory."

P508: "the general producer class and the general evaluator class are not
permitted to collude... the realized-consequence metric sits outside the
factory's input entirely, fixed at the architect's Stackelberg move."

WHAT WAS WRONG WITH THE JUDGES AS BUILT
---------------------------------------
They score the factory against the charter's own metrics. That is exactly the
colluding arrangement P502 describes: the thing being judged and the judgement
share a vocabulary, so both can drift together and neither notices.

Realized consequence breaks the loop because a FAILURE IS NOT A METRIC. It is
something that happened. A judge is scored on whether its alarms preceded
actual regressions -- and that score is unavailable to the factory, cannot be
optimised against directly, and is fixed at the Stackelberg move rather than
negotiated in the charter.

WHAT COUNTS AS A REAL FAILURE HERE
----------------------------------
Not "a criterion was violated" -- that would reintroduce the collusion. These
are events with consequences for the factory as a running system, each of which
has actually happened and cost this project time:

  silence_run     >= 3 consecutive windows under the amplitude floor. The
                  collapse guard exists for this; three windows is ~35 s of
                  nothing, which is audible as a fault rather than as rest.
  clipping        the master limiter catching. Masqueraded as an aesthetic
                  property for seven consecutive wrong diagnoses.
  vocab_collapse  distinct behaviours over 50 windows falling below half the
                  running median. This is what the audibility score did:
                  nine machines to four.
  amp_decay       median amplitude over 50 windows falling below half its
                  previous 50. Pre-registered as H2 for the long run.
  stall           no new window for a long gap in factory time -- the factory
                  stopped producing while still alive.

SPARSITY IS EXPECTED AND IS THE POINT
-------------------------------------
P502: "this reward mechanism is not only sparse but shrinking over time. To
create enough of this kind of scoring to be useful, we need to actually farm and
manufacture it, which we do by inducing a level of adversarial activity." A
healthy factory produces few failures, so a judge population trained only on
observed failures learns almost nothing. That is the argument for the chaos
monkey, which is the next piece and is not built yet.

    python3 tools/realized_consequence.py --log <windows.log>
"""
import argparse
import collections
import os
import re

import numpy as np

import judges as J


AMP_FLOOR = 0.004


def find_clock_jumps(path, threshold=60.0):
    """Windows across which the factory's clock jumped: the machine slept.

    This is a real failure in the strongest sense this module asks for -- an
    event with consequences, not a metric violation -- and it is the one that
    actually happened. On 28 Aug the shadow's clock jumped 20,309 s between
    window 100 and window 105 (laptop slept ~01:55, woke 07:33:56, confirmed in
    pmset). sclang's scheduler came back 5.6 hours behind, flooded scsynth, and
    the server spent the next 7.75 hours DROPPING commands: 77,491 `command FIFO
    full`. Every charter metric read healthy throughout.

    That is precisely P502's argument for a reward signal outside the factory's
    own vocabulary. No judge scoring the charter's metrics could have caught it,
    because by those metrics nothing was wrong.

    It matters twice. As a failure the judges can be scored against, and as a
    CONTAMINATION MARKER: windows after a jump were produced on a server that
    was dropping commands, so a run containing one must be analysed in two
    pieces, or not at all.
    """
    jumps = {}
    prev_t = None
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("CLOCKJUMP"):
                    # the factory reports these itself as of 28 Aug
                    try:
                        parts = line.split()[1].split(",")
                        jumps[int(parts[0])] = float(parts[1])
                    except (ValueError, IndexError):
                        pass
                    continue
                p = line.split(",")
                if len(p) < 3:
                    continue
                try:
                    t, w = float(p[0]), int(p[1])
                except ValueError:
                    continue
                if prev_t is not None and (t - prev_t) > threshold:
                    jumps[w] = t - prev_t
                prev_t = t
    except OSError:
        pass
    return jumps


def find_failures(wins):
    """Events, not metric violations. Returns {window: [kinds]}."""
    fail = collections.defaultdict(list)
    n = len(wins)
    mp = np.array([w["mp"] for w in wins])
    clip = np.array([w["clip"] for w in wins])

    run = 0
    for i, v in enumerate(mp):
        run = run + 1 if v < AMP_FLOOR else 0
        if run == 3:
            fail[wins[i]["w"]].append("silence_run")

    for i, v in enumerate(clip):
        if v > 0.001:
            fail[wins[i]["w"]].append("clipping")

    # vocabulary collapse, on a trailing 50-window count of distinct behaviours
    counts = []
    for i in range(n):
        lo = max(0, i - 50)
        counts.append(len({w["mach"] for w in wins[lo:i + 1] if w["mach"]}))
    counts = np.array(counts, float)
    for i in range(100, n):
        med = np.median(counts[max(0, i - 200):i])
        if med > 4 and counts[i] < med * 0.5:
            fail[wins[i]["w"]].append("vocab_collapse")

    # amplitude decay: this 50 against the previous 50
    for i in range(100, n):
        a = np.median(mp[i - 50:i]); b = np.median(mp[i - 100:i - 50])
        if b > 0.01 and a < b * 0.5:
            fail[wins[i]["w"]].append("amp_decay")

    return fail


def score_judges(path, horizon=10):
    wins, js, prof, sur = J.judge_run(path)
    if len(wins) < 150:
        return None
    fail = find_failures(wins)
    jumps = find_clock_jumps(path)
    for w in jumps:
        fail[w].append("clock_jump")
    idx = {w["w"]: i for i, w in enumerate(wins)}
    failing = np.zeros(len(wins), bool)
    for w in fail:
        if w in idx:
            failing[idx[w]] = True

    # a window is "consequential" if a real failure occurs within `horizon`
    conseq = np.zeros(len(wins), bool)
    for i in range(len(wins)):
        if failing[i + 1:i + 1 + horizon].any():
            conseq[i] = True

    base = conseq.mean()
    out = []
    for k, j in enumerate(js):
        s = sur[:, k]
        thr = np.percentile(s, 90)          # a judge "flags" its own top decile
        flagged = s >= thr
        tp = int((flagged & conseq).sum())
        prec = tp / max(1, int(flagged.sum()))
        rec = tp / max(1, int(conseq.sum()))
        lift = prec / max(1e-9, base)
        out.append(dict(name=j.name, kind=j.kind, prec=prec, rec=rec, lift=lift,
                        surprise=j.verdict()))
    return wins, fail, base, out, jumps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", action="append", required=True)
    ap.add_argument("--horizon", type=int, default=10)
    a = ap.parse_args()

    for path in a.log:
        r = score_judges(path, a.horizon)
        print(f"\n  === {os.path.basename(path)} ===")
        if r is None:
            print("  too few windows"); continue
        wins, fail, base, rows, jumps = r

        if jumps:
            print()
            print("  !! THIS RUN CONTAINS A CLOCK JUMP. The machine slept.")
            for w in sorted(jumps):
                print(f"     window {w}: the clock advanced {jumps[w]:.0f}s "
                      f"({jumps[w]/3600:.1f} h) in one step")
            first = min(jumps)
            after = sum(1 for x in wins if x["w"] > first)
            print(f"     {after} of {len(wins)} windows ({after/len(wins):.0%}) come AFTER the")
            print( "     first jump. On waking, sclang's scheduler is behind by the")
            print( "     jump and floods scsynth catching up; the server then drops")
            print( "     commands. Those windows were produced by a degraded server")
            print( "     and should not be pooled with the ones before.")
            print()

        kinds = collections.Counter(k for v in fail.values() for k in v)
        print(f"  {len(wins)} windows, {len(fail)} windows carrying a real failure")
        for k, n in kinds.most_common():
            print(f"    {n:5}  {k}")
        if not fail:
            print("    none. P502: 'this reward mechanism is not only sparse but")
            print("    shrinking over time... we need to actually farm and")
            print("    manufacture it, which we do by inducing a level of")
            print("    adversarial activity.' With no failures there is no")
            print("    consequence to learn from and the judges are unscored.")
            continue

        print(f"  base rate: {base:.1%} of windows precede a failure within "
              f"{a.horizon} windows")
        print()
        print(f"  {'judge':10} {'kind':6} {'precision':>10} {'recall':>8} {'lift':>7}")
        for d in sorted(rows, key=lambda x: -x["lift"]):
            print(f"  {d['name']:10} {d['kind']:6} {d['prec']:10.3f} "
                  f"{d['rec']:8.3f} {d['lift']:7.2f}x")

        mean_l = np.mean([d["lift"] for d in rows if d["kind"] == "mean"])
        swap_l = np.mean([d["lift"] for d in rows if d["kind"] == "swap"])
        print()
        print(f"  mean-based lift {mean_l:.2f}x    swap-based lift {swap_l:.2f}x")
        print()
        print("  LIFT ABOVE 1 means a judge's alarms genuinely precede real")
        print("  regressions. Lift at 1 means it is flagging at random with")
        print("  respect to consequence, however confident it sounds -- which is")
        print("  the state E3 was in at rho = -0.861, and nothing in its own")
        print("  scoring could have told us.")


if __name__ == "__main__":
    main()
