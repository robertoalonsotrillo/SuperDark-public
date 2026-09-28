#!/usr/bin/env python3
"""ONE coverage metric over all 89 anchors, at the pre-registered tight radius.

Implements `.lab/measurements/2026-09-18_coverage_metric_prereg.md`. Nothing
here decides anything: the pre-registration adopts this metric as DESCRIPTIVE
and leaves the bound UNSET until four stated conditions hold. This file computes
and reports. It contains no threshold, no pass, no fail, and adding one is the
specific failure the pre-registration forbids.

WHAT IS MEASURED
  Fraction of the 89 `coverage_holdout` anchors whose ball of radius r contains
  at least one window of the arm. An anchor is a section CENTRE in the frozen
  6-dimensional descriptor basis ["pc0".."pc4", "pitch"]; a window's position is
  the `target` vector the drift walk held for that window, logged as field 13
  (pipe-separated) of each window line. Same space, same basis, no rescaling.

THE RADIUS RULE, TAKEN AS FIXED
  r = 0.12 * (median nearest-neighbour spacing among the anchors), recomputed
  from the anchor set on every run. Stated as a ratio, never as a number, so it
  keeps asking the same question if the anchor set grows denser.

  READ THE PROVENANCE BLOCK THIS PRINTS. The pre-registration says this rule
  "evaluates to approximately 0.09" on the 18 September anchor set. It does not:
  it evaluates to about 0.037. The 0.09 in both the pre-registration and
  `.lab/notes/COVERAGE_PROPOSALS_REFUSED.md` is 0.12 x the median PAIRWISE distance
  (0.7526), which is the tolerance `tools/triage_proposals.py` actually swept.
  The two spacings differ by a factor of 2.5 and the rule as written does not
  reproduce the radius the pre-registered table was measured at. This tool
  computes the rule AS WRITTEN and reports the discrepancy rather than quietly
  switching to whichever spacing reproduces the published number. Which one the
  charter meant is an architect's decision, not this file's.

THE NULL, COMPUTED EVERY TIME
  Condition 4 of the pre-registration: the per-arm shuffled null is recomputed
  alongside, so the metric always reports its own separation and a saturation is
  visible the moment it happens.

  The null is a PER-DIMENSION shuffle: each descriptor column is permuted
  independently. That keeps every marginal exactly and destroys the path and the
  coupling between dimensions, which is what "a trajectory with no navigation"
  means in `COVERAGE_PROPOSALS_REFUSED.md`.

  A whole-row permutation of window ORDER is not a null for this statistic. The
  metric is a set membership question over the point cloud, so reordering the
  rows returns the same number, bit for bit, every time. This tool computes that
  degenerate null too and prints it, because a null that silently equals the
  measurement is worse than no null, and the only defence is to show it equal on
  purpose.

    python3 tools/coverage_metric.py --log path/to/arm_windows.log
    python3 tools/coverage_metric.py --log ... --json out.json
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ANCHORS = os.path.join(ROOT, "workdir_music", "mutable", "charter_proposals.jsonl")

# The stipulation, recorded as one. Section "Radius rule, fixed now".
RADIUS_RATIO = 0.12
NORM = "n2_varied"


# ---------------------------------------------------------------- the anchors

def load_anchors(path=ANCHORS):
    """The `coverage_holdout` proposals, as an (n, d) array of centres.

    Written by live_factory.scd at the novelty block (~line 1453): one JSON
    object per line, appended, so a crash mid-write costs one proposal and not
    the file. Read it the same way.
    """
    C, skipped = [], 0
    with open(path, errors="replace") as fh:
        for line in fh:
            if not line.strip():
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                skipped += 1
                continue
            if d.get("kind") != "coverage_holdout":
                continue
            c = d.get("centre")
            if isinstance(c, list) and c and all(isinstance(v, (int, float)) for v in c):
                C.append([float(v) for v in c])
            else:
                skipped += 1
    if not C:
        raise SystemExit(f"no coverage_holdout anchors with a centre in {path}")
    widths = {len(c) for c in C}
    if len(widths) != 1:
        # a mixed-width anchor set is two geometries in one file; refuse rather
        # than truncate, which is how a metric starts measuring nothing
        raise SystemExit(f"anchor centres of mixed width {sorted(widths)} in {path}")
    return np.asarray(C, dtype=float), skipped


# ---------------------------------------------------------------- the trajectory

def load_windows(log, dim):
    """Where the arm actually went, one row per window.

    Field 13 of the window line, pipe-separated, written at live_factory.scd
    ~3521 as `target.round(0.01)`. Rows are kept only when field 3 marks a real
    window verdict (`runtime` or `class`) and the vector is present, which is
    the same filter `tools/triage_proposals.py` uses.
    """
    rows, held, malformed = [], 0, 0
    with open(log, errors="replace") as fh:
        for line in fh:
            p = line.rstrip("\n").split(",")
            if len(p) <= 13 or p[3] not in ("runtime", "class"):
                continue
            if "|" not in p[13]:
                # "-" is written when the walk had no target yet; a window with
                # no position cannot be placed in the space and is COUNTED
                # rather than dropped silently
                held += 1
                continue
            try:
                v = [float(x) for x in p[13].split("|")]
            except ValueError:
                malformed += 1
                continue
            if len(v) != dim:
                malformed += 1
                continue
            rows.append(v)
    return (np.asarray(rows, dtype=float) if rows else np.empty((0, dim))), held, malformed


# ---------------------------------------------------------------- the radius

def spacings(C):
    """Median nearest-neighbour and median pairwise distance among the anchors."""
    D = np.sqrt(((C[:, None, :] - C[None, :, :]) ** 2).sum(-1))
    iu = np.triu_indices(len(C), 1)
    nn = D.copy()
    np.fill_diagonal(nn, np.inf)
    return float(np.median(nn.min(axis=1))), float(np.median(D[iu]))


def radius(C):
    """r = 0.12 * median nearest-neighbour spacing. The rule, as written."""
    nn, _ = spacings(C)
    return RADIUS_RATIO * nn


# ---------------------------------------------------------------- the statistic

def coverage(C, W, r):
    """Fraction of anchors with at least one window inside the ball of radius r.

    Chunked over anchors so a 7,000-window arm against 89 anchors does not
    allocate the full cross-product at 8 bytes a cell for no reason.
    """
    if len(W) == 0:
        return 0.0
    hit = np.zeros(len(C), dtype=bool)
    step = max(1, int(2_000_000 // max(1, len(W))))
    for i in range(0, len(C), step):
        blk = C[i:i + step]
        d2 = ((blk[:, None, :] - W[None, :, :]) ** 2).sum(-1)
        hit[i:i + step] = d2.min(axis=1) <= r * r
    return float(hit.mean())


def shuffled_null(C, W, r, reps, seed):
    """Per-dimension independent permutation. Marginals kept, path destroyed."""
    rng = np.random.default_rng(seed)
    vals = []
    for _ in range(reps):
        S = np.empty_like(W)
        for j in range(W.shape[1]):
            S[:, j] = rng.permutation(W[:, j])
        vals.append(coverage(C, S, r))
    return vals


def order_permutation_null(C, W, r, seed):
    """Whole-row reordering. Degenerate on purpose; see the module docstring."""
    rng = np.random.default_rng(seed)
    return coverage(C, W[rng.permutation(len(W))], r)


# ---------------------------------------------------------------- report

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--log", required=True, help="arm_windows.log of the arm")
    ap.add_argument("--anchors", default=ANCHORS)
    ap.add_argument("--json", dest="json_out", default=None)
    ap.add_argument("--null-reps", type=int, default=32)
    ap.add_argument("--seed", type=int, default=5)
    a = ap.parse_args(argv)

    C, skipped = load_anchors(a.anchors)
    nn, pw = spacings(C)
    r = RADIUS_RATIO * nn
    r_pairwise = RADIUS_RATIO * pw

    W, held, malformed = load_windows(a.log, C.shape[1])

    print()
    print("  COVERAGE (one metric, all anchors) -- prereg 2026-09-18, norm "
          f"{NORM}")
    print(f"    anchors      {len(C)} coverage_holdout centres, {C.shape[1]}-dim"
          + (f"  ({skipped} unusable lines skipped)" if skipped else ""))
    print(f"    arm          {os.path.basename(os.path.dirname(os.path.abspath(a.log)))}"
          f"  {len(W)} windows with a position"
          + (f", {held} with none" if held else "")
          + (f", {malformed} malformed" if malformed else ""))

    print()
    print("  RADIUS")
    print(f"    median nearest-neighbour spacing  {nn:.4f}")
    print(f"    r = {RADIUS_RATIO} x that          = {r:.4f}   <- the rule as written")
    print(f"    median pairwise distance          {pw:.4f}")
    print(f"    {RADIUS_RATIO} x that                       = {r_pairwise:.4f}   "
          f"<- reproduces the 0.09 of the prereg table")
    if not (0.07 <= r <= 0.11):
        print(f"    !! the prereg says this rule gives about 0.09. It gives "
              f"{r:.4f}.")
        print("       The published 0.09 is the PAIRWISE figure above. Not "
              "silently swapped;")
        print("       reported. See the provenance note in this file's "
              "docstring.")

    if len(W) < 2:
        print()
        print("  NOT COMPUTED: fewer than two positioned windows in this log.")
        return 1

    fac = coverage(C, W, r)
    nulls = shuffled_null(C, W, r, a.null_reps, a.seed)
    nmean = float(np.mean(nulls))
    ordnull = order_permutation_null(C, W, r, a.seed)

    # the same three figures at the radius the prereg's own table was measured
    # at, so the discrepancy above can be judged instead of argued about
    fac_p = coverage(C, W, r_pairwise)
    nulls_p = shuffled_null(C, W, r_pairwise, a.null_reps, a.seed)
    nmean_p = float(np.mean(nulls_p))

    print()
    print(f"  AT r = {r:.4f}  (the pre-registered rule)")
    print(f"    factory        {100 * fac:6.1f}%   "
          f"({int(round(fac * len(C)))} of {len(C)} anchors reached)")
    print(f"    shuffled null  {100 * nmean:6.1f}%   "
          f"(mean of {a.null_reps}; sd {100 * np.std(nulls):.1f}, "
          f"min {100 * min(nulls):.1f}, max {100 * max(nulls):.1f})")
    print(f"    separation     {100 * (fac - nmean):+6.1f} points")

    print()
    print(f"  AT r = {r_pairwise:.4f}  (NOT the rule; the radius the prereg table used)")
    print(f"    factory        {100 * fac_p:6.1f}%")
    print(f"    shuffled null  {100 * nmean_p:6.1f}%   "
          f"(sd {100 * np.std(nulls_p):.1f})")
    print(f"    separation     {100 * (fac_p - nmean_p):+6.1f} points")

    print()
    print("  DEGENERACY CHECK")
    print(f"    window-ORDER permutation at r = {r:.4f}: {100 * ordnull:6.1f}%  "
          f"(factory {100 * fac:.1f}%)")
    print("    These are equal by construction. Coverage is a question about a "
          "point")
    print("    cloud, so reordering the rows cannot change it. The null that "
          "means")
    print("    something is the per-dimension shuffle above.")

    print()
    print("  STATUS: DESCRIPTIVE. BOUND UNSET.")
    print("    No pass, no fail. The pre-registration sets four conditions "
          "before a")
    print("    floor may be stated (six unseen arms of 800+ windows, the spread "
          "characterised,")
    print("    floor only, null alongside) and none of them is this tool's to "
          "declare met.")
    print()

    out = {
        "metric": "coverage_holdout_consolidated",
        "norm": NORM,
        "prereg": ".lab/measurements/2026-09-18_coverage_metric_prereg.md",
        "status": "descriptive",
        "bound": None,
        "log": os.path.abspath(a.log),
        "n_anchors": int(len(C)),
        "dim": int(C.shape[1]),
        "n_windows": int(len(W)),
        "n_windows_without_position": int(held),
        "n_windows_malformed": int(malformed),
        "radius_ratio": RADIUS_RATIO,
        "median_nn_spacing": nn,
        "median_pairwise_distance": pw,
        "r": r,
        "factory": fac,
        "null_mean": nmean,
        "null_sd": float(np.std(nulls)),
        "null_min": float(min(nulls)),
        "null_max": float(max(nulls)),
        "null_reps": int(a.null_reps),
        "seed": int(a.seed),
        "separation": fac - nmean,
        "order_permutation_null": ordnull,
        "diagnostic_pairwise_radius": {
            "r": r_pairwise,
            "factory": fac_p,
            "null_mean": nmean_p,
            "separation": fac_p - nmean_p,
            "note": "0.12 x median PAIRWISE distance; not the pre-registered "
                    "rule, but the radius the prereg's own table was measured "
                    "at",
        },
    }
    if a.json_out:
        with open(a.json_out, "w") as fh:
            json.dump(out, fh, indent=2)
        print(f"  wrote {a.json_out}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
