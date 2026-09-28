#!/usr/bin/env python3
"""A population of online judges. They predict, they learn, they NEVER steer.

WHAT THE PAPER ASKS FOR (5.3)
  - evaluations that are online and continuous
  - a population with REQUISITE VARIETY: a surplus of mean-based (no-regret)
    learners alongside swap-based (no-swap-regret) ones. Ashby's law: the
    controller needs at least the variety of what it controls.
  - a grading signal that sits OUTSIDE the loop the evaluator judges, so the
    evaluation layer cannot settle into a shared overfit with what it supervises.

WHAT THIS FACTORY HAD: nothing. No judge_weight, no verdicts, one scorer run by
the architect against a written charter. The public panel said "requisite variety
of judges: failing", which flattered it; the truth was "none".

THE DESIGN CONSTRAINT THAT SHAPES EVERYTHING BELOW
Three self-generated criteria have become convergence engines here: E3 (rho
-0.861 against blind ranking), the audibility score (vocabulary 9 machines -> 4),
and the transfer operator (narrowing monotonically with its weight). score_charter
refuses to emit a total for the same reason. So:

    THESE JUDGES DO NOT STEER. Nothing they emit is read by the factory.
    They observe the window log and write verdicts to a file.

That is not timidity, it is the precondition for the fourth principle. A judge
that steers what it also predicts has manufactured its own evidence, and its
realized-consequence score would be meaningless. Kept at zero influence, the
signal grading them sits outside their loop BY CONSTRUCTION rather than by
arrangement.

THE TASK, chosen so the grading signal is external and non-gameable
Each judge sees window t and predicts whether window t+1 will be ANOMALOUS.
Anomaly is fixed here, in advance:

    anomalous(t) = master_peak(t) < 0.004        (the level m1 counts as silent)
                   OR clip_p99(t) > 0.02         (the level m3 counts as clipping)

Both thresholds are the charter's own, so the judges are not inventing a target.
The outcome is produced by the factory without reference to any prediction, which
is what makes it a realized consequence and not a self-fulfilment.

VARIETY, CONCRETELY
Two learning rules over the same expert basis:
  - HEDGE, minimising EXTERNAL regret: competes with the best single expert in
    hindsight. Mean-based.
  - BLUM-MANSOUR, minimising SWAP regret: one Hedge instance per expert, playing
    the stationary distribution of the induced chain. Converges to correlated
    equilibrium. This is the family the paper (and LATTICE) identifies as unable
    to take score-lowering moves, so it is present but deliberately NOT alone.
and three feature views (level, texture, identity), so judges differ in what they
can see as well as how they learn. Nine judges, six of them mean-based, which is
the surplus Ashby's law asks for.

    python3 tools/judges.py --log <windows.log>          # offline, with control
    python3 tools/judges.py --watch                      # live, tailing
"""
import argparse
import glob
import json
import math
import os
import random
import sys
import time

import numpy as np

SILENT = 0.004      # m1's threshold
CLIP = 0.02         # m3's threshold
OUT = "/Volumes/FMA/superdark/renders/judges.jsonl"


# --------------------------------------------------------------- the window log

def read_windows(path):
    """One record per window: level, clipping, voices, machine, operator state."""
    peak, clip, live, mach, gap = {}, {}, {}, {}, {}
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                peak[int(p[0])] = float(p[1]); clip[int(p[0])] = float(p[2])
            except (ValueError, IndexError):
                pass
        elif line.startswith("OPERATOR"):
            p = line.split()[1].split(",")
            try:
                gap[int(p[0])] = float(p[2])
            except (ValueError, IndexError):
                pass
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                try:
                    live[int(p[1])] = int(p[9]); mach[int(p[1])] = p[2]
                except (ValueError, IndexError):
                    pass
    ws = sorted(set(peak) & set(live))
    return [{"w": w, "peak": peak[w], "clip": clip.get(w, 0.0),
             "live": live[w], "mach": mach.get(w, "?"),
             "gap": gap.get(w, 0.0)} for w in ws]


def anomalous(r):
    return 1 if (r["peak"] < SILENT or r["clip"] > CLIP) else 0


# ------------------------------------------------------------------- the experts

def experts(view):
    """Simple base predictors. Deliberately crude: the judges' job is to WEIGHT
    them online, and a basis of strong learners would hide whether the weighting
    is doing anything. Each returns P(anomaly next)."""
    if view == "level":
        return [
            ("constant_low", lambda h: 0.05),
            ("base_rate", lambda h: np.mean([a for _, a in h[-200:]]) if h else 0.2),
            ("persistence", lambda h: 0.75 if h and h[-1][1] else 0.10),
            ("quiet_now", lambda h: 0.6 if h and h[-1][0]["peak"] < 0.02 else 0.12),
        ]
    if view == "texture":
        return [
            ("constant_low", lambda h: 0.05),
            ("base_rate", lambda h: np.mean([a for _, a in h[-200:]]) if h else 0.2),
            ("few_voices", lambda h: 0.45 if h and h[-1][0]["live"] <= 2 else 0.12),
            ("many_voices", lambda h: 0.30 if h and h[-1][0]["live"] >= 7 else 0.15),
        ]
    return [
        ("constant_low", lambda h: 0.05),
        ("base_rate", lambda h: np.mean([a for _, a in h[-200:]]) if h else 0.2),
        ("bridge", lambda h: 0.35 if h and h[-1][0]["mach"].startswith("br") else 0.15),
        ("persistence", lambda h: 0.75 if h and h[-1][1] else 0.10),
    ]


def brier(p, y):
    return (p - y) ** 2


class Hedge:
    """External regret. Competes with the best single expert in hindsight."""
    kind = "mean-based"

    def __init__(self, n, eta=0.35):
        self.w = np.ones(n) / n
        self.eta = eta

    def predict(self, ps):
        return float(np.dot(self.w, ps))

    def update(self, ps, y):
        loss = np.array([brier(p, y) for p in ps])
        self.w *= np.exp(-self.eta * loss)
        self.w /= self.w.sum()


class SwapRegret:
    """Blum-Mansour: one Hedge per expert, play the induced chain's stationary
    distribution. Minimises SWAP regret, so it converges to a correlated
    equilibrium -- and, as the paper notes of LATTICE, it can only ever move
    toward the equilibrium of its current basis. It is here for variety, and
    outnumbered two to one for exactly that reason."""
    kind = "swap-based"

    def __init__(self, n, eta=0.35):
        self.n = n
        self.sub = [Hedge(n, eta) for _ in range(n)]
        self.q = np.ones(n) / n

    def _stationary(self):
        Q = np.array([s.w for s in self.sub])           # row i = distribution of sub i
        q = np.ones(self.n) / self.n
        for _ in range(60):                             # power iteration
            q = q @ Q
            s = q.sum()
            if s <= 0:
                return np.ones(self.n) / self.n
            q = q / s
        return q

    def predict(self, ps):
        self.q = self._stationary()
        return float(np.dot(self.q, ps))

    def update(self, ps, y):
        # Each sub-learner is updated in proportion to how much mass the
        # stationary distribution put on it; that weighting is what turns
        # external regret on each sub into swap regret overall.
        for i, s in enumerate(self.sub):
            loss = np.array([self.q[i] * brier(p, y) for p in ps])
            s.w *= np.exp(-s.eta * loss)
            s.w /= s.w.sum()


def population():
    """Nine judges: three views x three rules, with mean-based outnumbering
    swap-based two to one. The surplus is the point (Ashby)."""
    out = []
    for view in ("level", "texture", "identity"):
        ex = experts(view)
        out.append({"name": f"hedge_{view}_fast", "view": view,
                    "algo": Hedge(len(ex), 0.6), "ex": ex})
        out.append({"name": f"hedge_{view}_slow", "view": view,
                    "algo": Hedge(len(ex), 0.15), "ex": ex})
        out.append({"name": f"swap_{view}", "view": view,
                    "algo": SwapRegret(len(ex), 0.35), "ex": ex})
    return out


def cell_matrix(records, source="judges", seed=7):
    """One row per window: the profile that version_operator partitions into cells.

    P432 asks for "profiles of judge scores across the charter's metrics", and
    version_operator.py's usage line has named `judges.py --cells` since it was
    written. THE FLAG DID NOT EXIST. The versioning readout has never been
    runnable end to end -- the same family as PatternGrammar unwired for a
    fortnight and the ingest daemon watching a directory the topology had left.
    A usage string is not an interface.

    TWO SOURCES, AND THE SECOND IS NOT OPTIONAL.

    `judges`  the vector of judge predictions at each window. This is P432's
              construction, literally.
    `metrics` the measured window features -- peak, clipping, voice count,
              operator gap -- with no learner in between.

    The metrics arm exists because the judges are the component shown not to
    work: nine of them plus nine tier-two learners, both tiers passing their
    negative controls, both steering nothing, the best beating chance by a margin
    that has never been comfortable. P484/P486 named operator cells the wrong
    state space BECAUSE the judges were no-swap-regret learners. Reading
    versioning through them puts a weak learner between the factory and the
    result, so the honest form is to run both and report both. If they disagree,
    the disagreement is the finding.
    """
    if source == "metrics":
        X = np.array([[r["peak"], r["clip"], float(r["live"]), r["gap"]]
                      for r in records], dtype=float)
        return X, ["peak", "clip", "live", "gap"]

    ys = [anomalous(r) for r in records]
    js = population()
    for j in js:
        j["loss"] = 0.0
        j["expert_loss"] = np.zeros(len(j["ex"]))
        j["flags"] = 0; j["hits"] = 0
    hist, rows = [], []
    names = [j["name"] for j in js]
    for t in range(len(records) - 1):
        y = ys[t + 1]
        prof = []
        for j in js:
            ps = [f(hist) for _, f in j["ex"]]
            p = j["algo"].predict(ps)
            prof.append(p)
            j["algo"].update(ps, y)
        rows.append(prof)
        hist.append((records[t], ys[t]))
    return np.array(rows, dtype=float), names


def run(records, shuffle_labels=False, seed=7, log_path=None):
    """One online pass. Judges see t, predict t+1, then learn from the outcome.

    shuffle_labels is the NEGATIVE CONTROL. With outcomes permuted, no judge can
    beat the base rate, and any apparent skill is the harness fooling itself.
    This project has shipped a detector that failed its own negative control
    (classify_transients.py, 0 defects on known-bad audio) and the lesson was to
    run the control BEFORE believing the measurement, not after.
    """
    ys = [anomalous(r) for r in records]
    if shuffle_labels:
        rng = random.Random(seed)
        ys = ys[:]; rng.shuffle(ys)

    js = population()
    hist, rows = [], []
    base_rate = float(np.mean(ys))
    for j in js:
        j["loss"] = 0.0
        j["expert_loss"] = np.zeros(len(j["ex"]))
        j["flags"] = 0; j["hits"] = 0

    fh = open(log_path, "a") if log_path else None
    for t in range(len(records) - 1):
        y = ys[t + 1]
        preds = {}
        for j in js:
            ps = [f(hist) for _, f in j["ex"]]
            p = j["algo"].predict(ps)
            preds[j["name"]] = p
            j["loss"] += brier(p, y)
            j["expert_loss"] += np.array([brier(q, y) for q in ps])
            # A "flag" is a verdict, and its realized consequence is whether the
            # thing it predicted actually happened.
            if p >= 0.5:
                j["flags"] += 1
                j["hits"] += y
            j["algo"].update(ps, y)
        # ENSEMBLE DISAGREEMENT: the paper's third early-warning signal, and the
        # one the panel has been reporting as unavailable because a single judge
        # configuration cannot produce it.
        vals = list(preds.values())
        if fh:
            fh.write(json.dumps({
                "t": time.time(), "window": records[t]["w"],
                "outcome_next": y,
                "disagreement": float(np.std(vals)),
                "mean_p": float(np.mean(vals)),
                "preds": {k: round(v, 4) for k, v in preds.items()},
            }) + "\n")
        rows.append(float(np.std(vals)))
        hist.append((records[t], y))
    if fh:
        fh.close()

    out = []
    for j in js:
        n = len(records) - 1
        best_expert = float(j["expert_loss"].min()) / n
        out.append({
            "name": j["name"], "kind": j["algo"].kind, "view": j["view"],
            "brier": j["loss"] / n,
            "regret_vs_best_expert": j["loss"] / n - best_expert,
            "flags": j["flags"],
            "precision": (j["hits"] / j["flags"]) if j["flags"] else None,
        })
    return {"n": len(records) - 1, "base_rate": base_rate,
            "base_brier": base_rate * (1 - base_rate),
            "judges": out, "disagreement_mean": float(np.mean(rows)) if rows else 0.0}


def show(tag, res):
    print(f"\n  === {tag} ===")
    print(f"  {res['n']} windows, anomaly base rate {res['base_rate']:.3f}, "
          f"always-predict-base-rate Brier {res['base_brier']:.4f}")
    print(f"  {'judge':22} {'kind':12} {'Brier':>8} {'vs base':>9} "
          f"{'regret':>8} {'flags':>7} {'prec':>6}")
    for j in sorted(res["judges"], key=lambda x: x["brier"]):
        d = res["base_brier"] - j["brier"]
        pr = "  n/a" if j["precision"] is None else f"{j['precision']:6.3f}"
        print(f"  {j['name']:22} {j['kind']:12} {j['brier']:8.4f} {d:+9.4f} "
              f"{j['regret_vs_best_expert']:8.4f} {j['flags']:7d} {pr}")
    print(f"  mean ensemble disagreement (sd of predictions): "
          f"{res['disagreement_mean']:.4f}")


SUMMARY = "/Volumes/FMA/superdark/renders/judges_summary.json"


def summarise(res, ctrl, log):
    """What the panel reads. Carries the control result with it, because a
    disagreement number without its control is a number nobody can weigh."""
    gain, gctrl = res_gain(res), res_gain(ctrl)
    best = min(res["judges"], key=lambda j: j["brier"])
    flagged = [j for j in res["judges"] if j["flags"] >= 20]
    return {
        "generated": time.time(),
        "log": os.path.basename(log),
        "windows": res["n"],
        "population": len(res["judges"]),
        "mean_based": sum(1 for j in res["judges"] if j["kind"] == "mean-based"),
        "swap_based": sum(1 for j in res["judges"] if j["kind"] == "swap-based"),
        "base_rate": res["base_rate"],
        "ensemble_disagreement": res["disagreement_mean"],
        "ensemble_disagreement_control": ctrl["disagreement_mean"],
        "best_judge": best["name"],
        "best_gain_over_base": gain,
        "control_gain": gctrl,
        "passes_control": bool(gain > 0.002 and gctrl <= 0.002),
        # REALIZED CONSEQUENCE, the paper's fourth principle: was a verdict
        # followed by the thing it predicted? Lift is precision divided by the
        # base rate, so 1.0 means the flag told you nothing.
        "realized": [{
            "judge": j["name"], "flags": j["flags"],
            "precision": j["precision"],
            "lift": (j["precision"] / res["base_rate"]) if j["precision"] else 0.0,
        } for j in sorted(flagged, key=lambda x: -(x["precision"] or 0))],
        "views_carrying_signal": sorted({
            j["view"] for j in res["judges"]
            if res["base_brier"] - j["brier"] > 0.005}),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=None)
    ap.add_argument("--write", action="store_true",
                    help="append per-window verdicts to judges.jsonl")
    ap.add_argument("--watch", action="store_true",
                    help="recompute on a loop and write judges_summary.json")
    ap.add_argument("--interval", type=float, default=300.0)
    ap.add_argument("--cells", default=None,
                    help="write the per-window profile matrix to this .npy, for "
                         "tools/version_operator.py")
    ap.add_argument("--cell-source", default="judges", choices=["judges", "metrics"],
                    help="judges = P432's construction; metrics = the measured "
                         "window features with no learner in between")
    a = ap.parse_args()

    if a.watch:
        # Recomputed from scratch each cycle rather than kept as a live daemon.
        # The whole pass over 2,500 windows takes a few seconds, and a stateless
        # recompute cannot drift from the log the way a long-lived accumulator
        # can. Five minutes is far finer than anything the judges measure.
        while True:
            try:
                log = sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                             key=os.path.getmtime)[-1]
                recs = read_windows(log)
                if len(recs) >= 200:
                    res = run(recs)
                    ctrl = run(recs, shuffle_labels=True)
                    s = summarise(res, ctrl, log)
                    tmp = SUMMARY + ".tmp"
                    json.dump(s, open(tmp, "w"), indent=1)
                    os.replace(tmp, SUMMARY)      # atomic for the reader
                    print(f"  {time.strftime('%H:%M:%S')}  {s['windows']} windows, "
                          f"gain {s['best_gain_over_base']:+.4f}, "
                          f"disagreement {s['ensemble_disagreement']:.4f}",
                          flush=True)
            except Exception as e:
                print(f"  {type(e).__name__}: {e}", flush=True)
            time.sleep(a.interval)
    log = a.log or sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                          key=os.path.getmtime)[-1]
    recs = read_windows(log)
    print(f"\n  {os.path.basename(log)}: {len(recs)} windows")
    if len(recs) < 200:
        raise SystemExit("  too short to judge")

    if a.cells:
        X, names = cell_matrix(recs, source=a.cell_source)
        np.save(a.cells, X)
        print(f"  wrote {X.shape[0]} x {X.shape[1]} {a.cell_source} profiles "
              f"-> {a.cells}")
        print(f"    columns: {', '.join(names)}")
        # A COLUMN THAT NEVER MOVES IS NOT A COORDINATE. version_operator drops
        # them, but say so here too: if most columns are constant the cells are
        # being built in far fewer dimensions than the count suggests, and the
        # spectrum that follows will be about those few.
        sd = X.std(0)
        dead = [n for n, s in zip(names, sd) if s <= 1e-9]
        if dead:
            print(f"    CONSTANT, carrying no information: {', '.join(dead)}")
        print(f"    per-column sd: " + "  ".join(f"{s:.4f}" for s in sd))
        return 0

    real = run(recs, log_path=OUT if a.write else None)
    show("LIVE OUTCOMES", real)
    ctrl = run(recs, shuffle_labels=True)
    show("NEGATIVE CONTROL (outcomes permuted)", ctrl)

    print()
    gain_real = res_gain(real)
    gain_ctrl = res_gain(ctrl)
    print(f"  best judge beats the base rate by {gain_real:+.4f} on live outcomes")
    print(f"  and by {gain_ctrl:+.4f} on permuted ones")
    if gain_real > 0.002 and gain_ctrl <= 0.002:
        print("  PASSES ITS CONTROL: skill on the live series, none on noise.")
    elif gain_ctrl > 0.002:
        print("  FAILS ITS CONTROL: the harness finds skill in permuted outcomes,")
        print("  so the apparent skill is an artefact. Do not deploy.")
    else:
        print("  NO SKILL: the judges do not beat the base rate. The population")
        print("  is honest but uninformative; the experts need better features")
        print("  before any verdict from it should carry weight.")
    return 0


def res_gain(res):
    return res["base_brier"] - min(j["brier"] for j in res["judges"])


if __name__ == "__main__":
    sys.exit(main())
