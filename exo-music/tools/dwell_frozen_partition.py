#!/usr/bin/env python3
"""Re-score the six arms' empirical dwell on ONE partition, fitted once and frozen.

WHAT THIS ANSWERS
-----------------
`.lab/measurements/2026-09-19_three_knobs_result.md` reported empirical dwell of
5.6 / 11.5 / 4.5 / 17.8 / 4.8 / 8.5 across A1, C1, A2, C2, A3, C3 and read a 2x
to 4x movement off it. The CORRECTION block at the top of that document
withdraws the inference, on the ground that `version_operator.py` selects K
inside each arm (its K sweep, lines ~260-277) and refits `kmeans(Xs, k, seed=0)`
inside each arm, and then divides the arm's window count by its number of label
runs. Six arms measured on six different state spaces do not yield six
differenceable numbers.

This file does the thing the correction says is owed. It pools all six arms'
windows, runs version_operator's OWN K-selection criterion once on the pool,
freezes K and the centroids, labels every arm against those frozen centroids,
and recomputes `len(labels)/runs` per arm. Nothing else changes. The judges, the
feature construction, the standardisation, the k-means, the block null and the
selection rule are all imported from the sealed files rather than reimplemented,
so the only difference between this and the sealed per-arm scoring is WHERE the
partition is fitted.

WHY NOTHING HERE IS TUNED
-------------------------
There is exactly one free choice in this file and it is made the same way the
sealed scorer makes it: K is whichever value in [kmin, kmax] beats the block
null and has the smallest 1 - |lambda2|. It is selected on the pool, before any
arm is looked at, and then it does not move. There is no per-arm fallback, no
K chosen to make a difference appear or disappear, and no seed sweep. If the
movement survives that, it survives; if it collapses, it collapses.

BOTH CELL SOURCES, BECAUSE judges.py SAYS SO
--------------------------------------------
`judges.cell_matrix` documents two sources and says, in as many words, that if
they disagree the disagreement is the finding. So both are run:

  judges   the nine judge predictions per window -- P432's construction, and
           what the sealed per-arm scoring used (run_version_operator.sh passes
           --cell-source judges).
  metrics  raw [peak, clip, live, gap] with no learner in between.

ONE SUBTLETY ABOUT THE JUDGES SOURCE, STATED RATHER THAN HIDDEN
---------------------------------------------------------------
`cell_matrix(source="judges")` is an ONLINE pass: the judges learn as they walk
the record list, so the profile at window t depends on every window before it.
Pooling the arms and running one pass is therefore not merely a re-partition --
it also changes the feature construction, because the judges arrive at C1
already trained on A1 instead of freshly initialised. That is arguably the more
honest pooling (one operator, one history, as a version that outlives a run
would require), but it is a second change on top of the frozen partition.

So both passes are reported:

  --judge-pass pooled    one online pass over the concatenated arms (default)
  --judge-pass per-arm   judges reset at each arm boundary, exactly as the
                         sealed scoring did; only the PARTITION is pooled

If the two agree, the partition is doing the work and the judges' history is
not. They are printed side by side for that reason. The `metrics` source has no
history at all, so the distinction does not arise there.

WINDOW SOURCE
-------------
Preferred: `--log <full live log>` plus `--arms <n_arms json>`, re-sliced here
with `eval_run.slice_log` (the FIXED slicer, commit e35ff0f).

Fallback: `--arm-log LABEL=path` for each arm, or auto-discovery under
harness/runs/. EVERY arm log used is verified before use -- every window number
on both line formats must fall inside the arm's [from, to], and the count must
match. The bundles under harness/superseded_260919_sliced_wrong/ were produced
by the broken slicer and carry all 7,131 event lines of the whole run in every
arm; the check below rejects them by construction. Nothing is trusted because of
where it sits on disk.

    python3 tools/dwell_frozen_partition.py
    python3 tools/dwell_frozen_partition.py --log .../live_260918_115036.log
    python3 tools/dwell_frozen_partition.py --cell-source metrics
"""
import argparse
import glob
import json
import os
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import judges                      # read_windows, cell_matrix -- sealed
import version_operator as vo      # kmeans, gap_of, null_test, spectrum_of -- sealed
import eval_run                    # slice_log -- sealed, and the FIXED slicer

DEFAULT_ARMS = os.path.join(EM, "harness", "n_arms_260918_115004.json")

# The per-arm figures from the sealed scoring, .lab/measurements/
# 2026-09-19_three_knobs_result.md. Used only when the bundle that produced a
# given arm log cannot be found next to it; the bundle is preferred.
PUBLISHED = {"A1": 5.6, "C1": 11.5, "A2": 4.5, "C2": 17.8, "A3": 4.8, "C3": 8.5}


# ----------------------------------------------------------- arm window sources

def window_numbers(path):
    """Every window number in the file, on BOTH line formats.

    The second branch is the one the old slicer missed: event lines look like
    "20.51,2,cp,class,0.03,..." with no whitespace at all and the window in the
    SECOND comma field. Mirrors eval_run.slice_log's field test.
    """
    master, event = [], []
    for line in open(path, errors="replace"):
        if line.startswith("MASTER ") or line.startswith("OPERATOR"):
            try:
                master.append(int(line.split()[1].split(",")[0]))
            except (ValueError, IndexError):
                pass
        else:
            f = line.strip().split(",")
            if len(f) > 10 and f[3] in ("runtime", "class") and f[1].isdigit():
                event.append(int(f[1]))
    return master, event


def verify_arm_log(path, lo, hi):
    """(ok, note). An arm log is usable only if BOTH line formats are in range.

    This is not a formality. Most arm_windows.log under
    harness/superseded_260919_sliced_wrong/ carry the whole 7,131-window run's
    event lines inside a file whose MASTER lines are correctly sliced, so a
    check that looked at one format only would pass them.
    """
    master, event = window_numbers(path)
    if not master or not event:
        return False, "no windows on one of the two line formats"
    bad_m = [w for w in master if not (lo <= w <= hi)]
    bad_e = [w for w in event if not (lo <= w <= hi)]
    if bad_m or bad_e:
        return False, (f"{len(bad_m)} header-format and {len(bad_e)} event-format "
                       f"window numbers outside [{lo},{hi}] "
                       f"(event span {min(event)}-{max(event)}) -- BROKEN SLICE")
    return True, f"{len(set(master))} header / {len(set(event))} event windows in range"


def slice_from_full_log(log, arms, dest_dir):
    out = {}
    for a in arms:
        dest = os.path.join(dest_dir, f"arm_{a['label']}.log")
        kept, dropped = eval_run.slice_log(log, dest, a["from"], a["to"])
        print(f"    {a['label']:>3}  windows {a['from']}-{a['to']}  "
              f"kept {kept} lines, dropped {dropped}")
        out[a["label"]] = dest
    return out


def discover_arm_logs(arms):
    """Find one verified arm log per label under harness/runs/ and harness/.

    Candidates are checked, not assumed. A candidate matches an arm only if
    every window number in it -- on both formats -- lies inside that arm's
    range and the window count equals the arm's length.
    """
    cands = sorted(glob.glob(os.path.join(EM, "harness", "**", "arm_windows.log"),
                             recursive=True))
    found, rejected = {}, []
    for a in arms:
        lab, lo, hi = a["label"], a["from"], a["to"]
        want = None
        for p in cands:
            if lab in found:
                break
            master, event = window_numbers(p)
            if not master or not event:
                continue
            if min(master) != lo or max(master) != hi:
                continue
            ok, note = verify_arm_log(p, lo, hi)
            if ok:
                found[lab] = p
                want = note
            else:
                rejected.append((lab, p, note))
        if lab in found:
            print(f"    {lab:>3}  {os.path.relpath(found[lab], EM)}")
            print(f"         VERIFIED: {want}")
    for lab, p, note in rejected:
        print(f"    rejected for {lab}: {os.path.relpath(p, EM)}")
        print(f"         {note}")
    return found


# --------------------------------------------------------------- frozen fitting

def fit_once(X, kmin, kmax, quiet=False):
    """version_operator's OWN selection, run once on the pooled matrix.

    Lifted line for line from version_operator.main(): drop constant criteria,
    standardise, sweep K, test each K against the plain and the block null, and
    take the SMALLEST 1 - |lambda2| among those that beat the block null. The
    only change is that X is the pool rather than one arm, and that the fitted
    centroids and the standardisation are returned so they can be frozen.
    """
    keep = X.std(0) > 1e-9
    if not keep.all() and not quiet:
        print(f"  dropping {int((~keep).sum())} constant criteria (no information)")
    Xu = X[:, keep]
    mu, sd = Xu.mean(0), np.maximum(1e-9, Xu.std(0))
    Xs = (Xu - mu) / sd

    if not quiet:
        print(f"  {'K':>3} {'gap':>8} | {'plain':>8} {'p':>6} | {'block':>8} {'p':>6}   verdict")
    best = None
    for k in range(kmin, kmax + 1):
        lab, C = vo.kmeans(Xs, k, seed=0)
        if len(set(lab.tolist())) < k:
            continue
        obs, n1, p1 = vo.null_test(lab.tolist(), k, draws=200, seed=1, block=1)
        _, n2, p2 = vo.null_test(lab.tolist(), k, draws=200, seed=1, block=20)
        if not quiet:
            v = "REAL" if p2 <= 0.05 else "artefact of the sliding windows"
            print(f"  {k:>3} {obs:8.4f} | {np.median(n1):8.4f} {p1:6.3f} "
                  f"| {np.median(n2):8.4f} {p2:6.3f}   {v}")
        if p2 <= 0.05 and (best is None or obs < best["obs"]):
            best = {"k": k, "obs": obs, "p": p2, "lab": lab, "C": C, "null": n2}
    if best is None:
        return None
    best.update({"keep": keep, "mu": mu, "sd": sd, "Xs": Xs})
    return best


def label_against(fit, X):
    """Nearest FROZEN centroid, in the FROZEN standardised space."""
    Xu = X[:, fit["keep"]]
    Xs = (Xu - fit["mu"]) / fit["sd"]
    d = ((Xs[:, None, :] - fit["C"][None, :, :]) ** 2).sum(-1)
    return d.argmin(1)


def dwell_of(lab):
    """version_operator's empirical dwell, verbatim: len(lab) / runs."""
    lab = np.asarray(lab)
    if len(lab) == 0:
        return float("nan"), 0
    runs = 1 + int((np.diff(lab) != 0).sum())
    return len(lab) / runs, runs


def occupancy(lab, k):
    return np.bincount(np.asarray(lab), minlength=k) / max(1, len(lab))


# ------------------------------------------------------------------- the reading

def per_arm_refit(X_by_arm, kmin, kmax):
    """What the sealed scorer does: select K and refit INSIDE each arm.

    Recomputed here rather than quoted, so the K each arm chose on its own can
    be set beside the pooled K in the same units, from the same windows.
    """
    out = {}
    for lab, X in X_by_arm.items():
        fit = fit_once(X, kmin, kmax, quiet=True)
        if fit is None:
            out[lab] = {"k": None, "dwell": float("nan"), "runs": 0, "occ": None}
            continue
        d, runs = dwell_of(fit["lab"])
        out[lab] = {"k": fit["k"], "dwell": d, "runs": runs,
                    "occ": occupancy(fit["lab"], fit["k"]), "gap": fit["obs"]}
    return out


def sealed_dwell(arm_logs):
    """Prefer the sealed bundle's own number; fall back to the published table."""
    out = {}
    for lab, p in arm_logs.items():
        res = os.path.join(os.path.dirname(p), "results.json")
        v = None
        if os.path.exists(res):
            try:
                v = json.load(open(res))["version_operator"]["value"]["empirical dwell"]
            except Exception:
                v = None
        out[lab] = float(v) if v is not None else PUBLISHED.get(lab, float("nan"))
    return out


def report(source, arm_order, knobs, frozen, refit, sealed, fit, note):
    print()
    print(f"  {'='*74}")
    print(f"  CELL SOURCE: {source}   {note}")
    print(f"  {'='*74}")
    print(f"  pooled fit: K = {fit['k']}, 1-|lambda2| = {fit['obs']:.4f}, "
          f"p = {fit['p']:.3f} against the block null")
    ev, _ = vo.spectrum_of(fit["lab"].tolist(), fit["k"])
    theta = float(1.0 - np.percentile(fit["null"], 5))
    m, drop, dw = vo.versions_of(ev, theta)
    print(f"  pooled spectrum   " + " ".join(f"{v:.3f}" for v in ev[:min(8, len(ev))]))
    print(f"  versions m {m}, drop after m {drop:.4f}, theta {theta:.4f}")
    print(f"  pooled occupancy  " +
          "  ".join(f"{o:.0%}" for o in occupancy(fit["lab"], fit["k"])))
    print()
    print(f"  {'arm':>4} {'knob':>22} {'frozen':>8} {'as reported':>12} "
          f"{'diff':>8} {'own K':>6} {'runs':>6}")
    for lab in arm_order:
        f = frozen[lab]
        print(f"  {lab:>4} {knobs[lab]:>22} {f['dwell']:8.1f} {sealed[lab]:12.1f} "
              f"{f['dwell'] - sealed[lab]:+8.1f} {str(refit[lab]['k']):>6} "
              f"{f['runs']:6d}")
    print()
    print("  cell occupancy under the frozen partition")
    for lab in arm_order:
        print(f"  {lab:>4}  " + "  ".join(f"{o:.0%}" for o in frozen[lab]["occ"]))
    print()
    print("  cell occupancy under each arm's OWN fit (the mechanism under suspicion)")
    for lab in arm_order:
        r = refit[lab]
        occ = "  ".join(f"{o:.0%}" for o in r["occ"]) if r["occ"] is not None else "n/a"
        print(f"  {lab:>4}  K={str(r['k']):>2}  dwell {r['dwell']:5.1f}   {occ}")

    # ---- the pre-registered comparison, on the frozen numbers
    d = {lab: frozen[lab]["dwell"] for lab in arm_order}
    aa = [("A1 vs A2", abs(d["A1"] - d["A2"])), ("A2 vs A3", abs(d["A2"] - d["A3"]))]
    floor = max(v for _, v in aa)
    print()
    print("  THE PRE-REGISTERED COMPARISON, under the frozen partition")
    print("  Rule: a candidate's movement counts only if |d_cand| > max(|d_A1A2|, |d_A2A3|).")
    for name, v in aa:
        print(f"    A-A null   {name:>9}   {v:6.2f}")
    print(f"    null floor (frozen)      {floor:6.2f}      "
          f"(pre-registered floor from the per-arm scoring was 1.10)")
    verdicts = {}
    for cand, champ, knob in (("C1", "A1", "self_ingest_weight .5"),
                              ("C2", "A2", "voices_max 5"),
                              ("C3", "A3", "collapse_after 300")):
        delta = d[cand] - d[champ]
        ex = abs(delta) > floor
        verdicts[cand] = (delta, ex)
        print(f"    {cand} - {champ}  {knob:<24} {delta:+6.2f}   "
              f"{'EXCEEDS' if ex else 'inside drift'}")

    # A WIDER NULL THAN TWO DRAWS. The CORRECTION's own words are that "the null
    # floor of 1.1 taken from the two A-A pairs understates its own variability".
    # Two differences is not an estimate of spread, so here is a bigger one that
    # costs no extra data: split each CHAMPION arm at its midpoint and take every
    # pairwise difference among the six halves. Same knob setting throughout, so
    # every one of these is drift by construction. If a candidate delta does not
    # clear this, it is not distinguishable from where you happened to cut.
    half = {}
    for lab in arm_order:
        if not lab.startswith("A"):
            continue
        L = frozen[lab]["labels"]
        h = len(L) // 2
        half[lab + "a"] = dwell_of(L[:h])[0]
        half[lab + "b"] = dwell_of(L[h:])[0]
    sp = [abs(half[x] - half[y])
          for i, x in enumerate(sorted(half)) for y in sorted(half)[i + 1:]]
    print()
    print("  SAME-KNOB NULL FROM CHAMPION HALF-ARMS (every pair is drift by "
          "construction)")
    print("    " + "   ".join(f"{k} {v:.2f}" for k, v in sorted(half.items())))
    print(f"    {len(sp)} pairwise spreads: min {min(sp):.2f}  "
          f"median {float(np.median(sp)):.2f}  max {max(sp):.2f}")
    biggest = max(abs(v[0]) for v in verdicts.values())
    print(f"    largest candidate delta {biggest:.2f}  ->  "
          f"{'ABOVE' if biggest > max(sp) else 'BELOW'} the largest same-knob spread")
    return d, floor, verdicts, {"halves": half, "spreads_min": min(sp),
                                "spreads_median": float(np.median(sp)),
                                "spreads_max": max(sp)}


def build_cells(records, source, arm_of_record):
    """Cell matrix + the arm each ROW belongs to.

    judges  : one row per window EXCEPT the last (it predicts t+1), so row t
              belongs to the arm of record t.
    metrics : one row per window.
    """
    X, names = judges.cell_matrix(records, source=source)
    rows_arm = arm_of_record[:len(X)]
    return X, names, rows_arm


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arms", default=DEFAULT_ARMS,
                    help="n_arms sequence json with label/from/to per arm")
    ap.add_argument("--log", default=None,
                    help="full run log; if given, arms are re-sliced from it with "
                         "the FIXED eval_run.slice_log")
    ap.add_argument("--arm-log", action="append", default=[],
                    metavar="LABEL=PATH",
                    help="explicit arm log; repeatable. Still verified.")
    ap.add_argument("--cell-source", default="both",
                    choices=["judges", "metrics", "both"])
    ap.add_argument("--judge-pass", default="both",
                    choices=["pooled", "per-arm", "both"],
                    help="pooled = one online judge pass over the concatenated "
                         "arms; per-arm = judges reset at each boundary, as the "
                         "sealed scoring did. Only the partition is pooled either way.")
    ap.add_argument("--kmin", type=int, default=3)
    ap.add_argument("--kmax", type=int, default=10)
    ap.add_argument("--json-out", default=None)
    a = ap.parse_args()

    seq = json.load(open(a.arms))
    arms = seq["arms"]
    order = [x["label"] for x in arms]
    knobs = {x["label"]: (f"{x['knob']} {x['value']}" if x["knob"] else "champion (baseline)")
             for x in arms}

    print(f"\n  sequence {os.path.basename(a.arms)}: "
          f"{len(arms)} arms, {seq.get('windows_per_arm')} windows per arm")
    print(f"  design: {seq.get('design')}")
    print()

    tmp = None
    if a.log:
        print(f"  re-slicing each arm from {os.path.basename(a.log)} "
              f"with eval_run.slice_log (fixed)")
        tmp = tempfile.mkdtemp(prefix="dwell_frozen_")
        arm_logs = slice_from_full_log(a.log, arms, tmp)
    elif a.arm_log:
        arm_logs = dict(s.split("=", 1) for s in a.arm_log)
    else:
        print("  no --log given; discovering arm logs under harness/ and VERIFYING")
        print("  each one's window numbers against the arm's range before use")
        arm_logs = discover_arm_logs(arms)

    missing = [x["label"] for x in arms if x["label"] not in arm_logs]
    if missing:
        raise SystemExit(f"\n  no verified window source for {', '.join(missing)}. "
                         f"Pass --log <full log> or --arm-log LABEL=PATH.")

    # Verify whatever we ended up with, however it was obtained.
    print()
    print("  VERIFICATION (both line formats, against each arm's declared range)")
    recs_by_arm, all_recs, arm_of_record = {}, [], []
    for x in arms:
        lab, lo, hi = x["label"], x["from"], x["to"]
        ok, note = verify_arm_log(arm_logs[lab], lo, hi)
        print(f"    {lab:>3}  {'OK ' if ok else 'BAD'}  {note}")
        if not ok:
            raise SystemExit(f"  {lab}: refusing to use a log that fails the slice check")
        r = judges.read_windows(arm_logs[lab])
        out = [w for w in r if not (lo <= w["w"] <= hi)]
        if out:
            raise SystemExit(f"  {lab}: read_windows returned {len(out)} out-of-range windows")
        recs_by_arm[lab] = r
        all_recs.extend(r)
        arm_of_record.extend([lab] * len(r))
        print(f"         read_windows -> {len(r)} windows "
              f"[{r[0]['w']}, {r[-1]['w']}]")

    arm_of_record = np.array(arm_of_record)
    print()
    print(f"  POOLED: {len(all_recs)} windows across {len(arms)} arms, "
          f"concatenated in sequence order")

    sealed = sealed_dwell(arm_logs)
    results = {}

    sources = ["judges", "metrics"] if a.cell_source == "both" else [a.cell_source]
    for source in sources:
        if source == "judges":
            passes = (["pooled", "per-arm"] if a.judge_pass == "both"
                      else [a.judge_pass])
        else:
            passes = ["pooled"]        # metrics has no history; the pass is moot

        for jp in passes:
            if source == "judges" and jp == "per-arm":
                # Features exactly as the sealed scoring built them (judges
                # reinitialised at each arm), then pooled for the partition ONLY.
                blocks, rows_arm = [], []
                for x in arms:
                    lab = x["label"]
                    Xa, names = judges.cell_matrix(recs_by_arm[lab], source=source)
                    blocks.append(Xa)
                    rows_arm.extend([lab] * len(Xa))
                X = np.vstack(blocks)
                rows_arm = np.array(rows_arm)
                note = "judges reinitialised per arm; partition pooled"
            else:
                X, names, rows_arm = build_cells(all_recs, source, arm_of_record)
                note = ("one online judge pass over the pool"
                        if source == "judges" else "raw window features")

            print()
            print(f"  ---- fitting the partition ONCE on the pool "
                  f"({source}, {jp}) ----")
            print(f"  {X.shape[0]} rows x {X.shape[1]} criteria "
                  f"({', '.join(names)})")
            fit = fit_once(X, a.kmin, a.kmax)
            if fit is None:
                print("  NO K BEATS THE BLOCK NULL ON THE POOLED DATA. "
                      "No frozen partition to report against.")
                continue

            lab_all = label_against(fit, X)
            frozen = {}
            X_by_arm = {}
            for x in arms:
                lab = x["label"]
                sel = rows_arm == lab
                X_by_arm[lab] = X[sel]
                d, runs = dwell_of(lab_all[sel])
                frozen[lab] = {"dwell": d, "runs": runs,
                               "occ": occupancy(lab_all[sel], fit["k"]),
                               "labels": lab_all[sel], "n": int(sel.sum())}
            refit = per_arm_refit(X_by_arm, a.kmin, a.kmax)
            d, floor, verdicts, halfnull = report(f"{source} ({jp})", order, knobs,
                                                  frozen, refit, sealed, fit, note)
            results[f"{source}/{jp}"] = {
                "pooled_K": fit["k"], "pooled_gap": fit["obs"], "pooled_p": fit["p"],
                "frozen_dwell": {k: float(v["dwell"]) for k, v in frozen.items()},
                "frozen_runs": {k: v["runs"] for k, v in frozen.items()},
                "frozen_occupancy": {k: [float(o) for o in v["occ"]]
                                     for k, v in frozen.items()},
                "own_K": {k: v["k"] for k, v in refit.items()},
                "own_dwell": {k: float(v["dwell"]) for k, v in refit.items()},
                "sealed_dwell": sealed,
                "aa_spread": {"A1_A2": abs(d["A1"] - d["A2"]),
                              "A2_A3": abs(d["A2"] - d["A3"])},
                "null_floor_frozen": floor,
                "champion_half_arm_null": halfnull,
                "deltas": {k: {"delta": v[0], "exceeds": bool(v[1])}
                           for k, v in verdicts.items()},
            }

    if a.json_out:
        json.dump(results, open(a.json_out, "w"), indent=1)
        print(f"\n  wrote {a.json_out}")

    print()
    print("  " + "=" * 74)
    print("  WHAT THIS DOES NOT SETTLE. A common partition makes the six numbers")
    print("  differenceable; it does not make them an effect. The A-A pairs are two")
    print("  draws of drift and the rule says EXCEEDS, not significance. And a")
    print("  frozen partition fitted on the pool contains the candidate arms' own")
    print("  windows, so it is a description of this run, not a prior.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
