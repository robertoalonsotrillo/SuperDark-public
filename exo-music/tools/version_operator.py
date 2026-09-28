#!/usr/bin/env python3
"""The transfer operator over judge-score cells: P432's version detector.

WHAT THIS CORRECTS
------------------
P430-432: "Versioning... can be realized vividly with the mathematical principle
of the transfer operator... partition the factory's observable behavior into
cells (PROFILES OF JUDGE SCORES ACROSS THE CHARTER'S METRICS, say), keep a
running histogram of the effects of recent outputs on those cells, and then
count how often behavior in one cell leads to behavior in another... the
operator's spectral gap... giving us A READOUT OF WHETHER VERSIONING IS
HAPPENING AT ALL. If near-invariant regions are cleanly partitioned and well
defined (a wide spectral gap), then a given version is durable and well defined.
A small spectral gap suggests that versions are bleeding into each other, or
that a given version is provisional or transitional."

We built the operator over MACHINE IDENTITIES (gap ~0.34) and later over SECTION
IDENTITIES (gap 0.19). Right machinery, wrong state space: those measure which
behaviour follows which, when the paper asks which EVALUATIVE PROFILE follows
which. That is why the operator has read as a behaviour diagnostic rather than
a version detector -- it is one.

So a version is not an object to build. A version IS an almost-invariant set of
this operator, and the spectrum says whether versioning occurs at all.

WHICH GAP, AND THE DEFECT THIS FILE CARRIED UNTIL 7 SEPT
--------------------------------------------------------
The quotation above is right about the substance and this file printed the wrong
arithmetic under it. `gap_of` returns 1 - |lambda2|, the ordinary spectral gap,
which governs MIXING SPEED: wide means the chain forgets its starting cell within
a few steps, and that is versions bleeding into each other. Nearly-invariant sets
produce the opposite -- lambda2 -> 1, slow mixing, a NARROW 1 - |lambda2|.

The gap that is genuinely wide when versions are durable is the drop AFTER the
m-th eigenvalue, where m is the number of metastable sets: lambda_1..lambda_m sit
near 1 and there is a fall to lambda_{m+1}. That is the standard
Markov-state-model reading (Deuflhard & Schuette, PCCA+), and on it P432 is
correct as written. The paper does not need changing; what this file REPORTS
does.

The internal evidence that the two readings were being mixed: the K sweep below
has always selected the SMALLEST 1 - |lambda2| among the K that beat the null --
selecting for metastability -- while the summary underneath announced that a wide
gap was the good outcome. And m7's charter note records "P227 stable failure is a
gap frozen wide", which contradicts P432 under the lambda2 reading and agrees
with it under the m-gap reading.

So this now reports m, the drop after m, and a dwell time, with 1 - |lambda2|
retained only to keep the earlier machine- and section-identity figures
comparable. The threshold that decides m comes from the block-shuffled null and
is fixed before the spectrum is inspected.

WHY THE NULL IS NOT OPTIONAL
----------------------------
A sparse count matrix with smoothing produces eigenvalues that look like
structure and are not. The section-level estimate was 165 transitions over a
115x115 matrix -- 1.1% occupancy -- and only survived because it was tested
against a shuffled null (p = 0.037). Every gap reported here is tested the same
way, and a gap that does not beat its null is reported as absent.

THE PER-ARM K SWEEP IS NOT A PER-ARM RESULT (19 Sept 2026)
----------------------------------------------------------
Everything above describes ONE sequence of cells. The moment this file is used
to compare two arms it acquires a defect that the text above does not mention
and that the numbers it produced did not survive.

main() selects K inside whatever matrix it is handed and refits kmeans inside
it, then divides that arm's window count by its number of label runs and prints
the quotient as `empirical dwell`. Six arms scored this way are six different
state spaces, so their six dwell figures are not differences of anything.

Measured, on the six arms of harness/n_arms_260918_115004.json:

    per-arm refit   5.6  11.5   4.5  17.8   4.8   8.5      K = 10 5 10 4 10 7
    ONE partition   6.1   7.1   5.5   5.1   4.8   5.4      K = 10 throughout

    Pearson(1/K, per-arm dwell) = 0.987

The 2x-4x movement that the three-knob result read off the first row is the K
sweep. Pinning K removes nearly all of it. tools/dwell_frozen_partition.py
established this by fitting one partition across the pool; this file now carries
the same capability so an arm can be scored against a partition that was fitted
BEFORE it ran:

    --fit-partition <out.json>   fit K, centroids and the standardisation on the
                                 given cell matrices and freeze them to a file.
                                 CALIBRATION. Do this once, on arms you are not
                                 going to read a difference off.
    --partition <in.json>        label this arm against that frozen partition and
                                 report. No refit, no K re-selection.
    neither                      unchanged arithmetic, and now a warning saying
                                 the number is not comparable across arms.

WHY THE SCALER TRAVELS WITH THE CENTROIDS. The partition is not the centroids
alone. main() drops constant criteria and then z-scores what is left using THAT
matrix's own mean and standard deviation. A second arm has a different mean and
a different spread, so labelling it against stored centroids after re-deriving
the scaler from itself would silently rescale the space under the centroids and
give a partition that is frozen in name only. The frozen file therefore carries
the keep-mask, the mean and the scale, and labelling uses them and never the new
arm's own.

    python3 tools/judges.py --log <windows.log> --cells cells.npy
    python3 tools/version_operator.py --cells cells.npy
    python3 tools/version_operator.py --cells a.npy b.npy ... \
            --cell-source judges --fit-partition frozen.json
    python3 tools/version_operator.py --cells a.npy \
            --cell-source judges --partition frozen.json
"""
import argparse
import datetime
import hashlib
import json
import os
import sys

import numpy as np

PARTITION_SCHEMA = "version_operator/frozen-partition/1"


def kmeans(X, k, seed=0, iters=80):
    """Plain Lloyd's. No sklearn dependency; the data is 2k x 8."""
    rng = np.random.default_rng(seed)
    C = X[rng.choice(len(X), k, replace=False)].copy()
    lab = np.zeros(len(X), dtype=int)
    for _ in range(iters):
        d = ((X[:, None, :] - C[None, :, :]) ** 2).sum(-1)
        new = d.argmin(1)
        if (new == lab).all():
            break
        lab = new
        for j in range(k):
            m = lab == j
            if m.any():
                C[j] = X[m].mean(0)
            else:
                C[j] = X[rng.integers(len(X))]
    return lab, C


def spectrum_of(seq, k, smooth=1e-3):
    """|eigenvalues| of the row-stochastic transition matrix, descending."""
    C = np.zeros((k, k))
    for a, b in zip(seq, seq[1:]):
        C[a, b] += 1
    R = C + smooth
    R /= R.sum(1, keepdims=True)
    return np.sort(np.abs(np.linalg.eigvals(R.T)))[::-1], C


def gap_of(seq, k, smooth=1e-3):
    """1 - |lambda2|. RETAINED, AND IT IS NOT THE VERSIONING FIGURE.

    THE DEFECT THIS FILE CARRIED. P430-432 quotes above: "if near-invariant
    regions are cleanly partitioned and well defined (a WIDE spectral gap), then
    a given version is durable". The substance is right and the arithmetic
    printed underneath it was the wrong quantity.

    1 - |lambda2| is the ordinary spectral gap and it governs MIXING SPEED. Wide
    means the chain forgets its starting cell in a few steps, which is versions
    bleeding into each other -- the opposite of what the sentence claims. Narrow,
    lambda2 -> 1, is slow mixing, and slow mixing is exactly what a state space
    that decomposes into nearly-invariant sets produces.

    The gap that IS wide when versions are durable is the one AFTER the m-th
    eigenvalue, where m is the number of metastable sets: lambda_1..lambda_m sit
    near 1 and there is a drop to lambda_{m+1}. That is the standard
    Markov-state-model construction (Deuflhard & Schuette, PCCA+), and under it
    P432 reads correctly. So the paper does not need rewriting; this file needs
    to report m, the drop after it, and a dwell time, instead of 1 - |lambda2|.

    Corroboration from inside the charter: m7's note records "P227 stable failure
    is a gap frozen wide". Under the 1 - |lambda2| reading P227 and P432
    contradict each other. Under the m-gap reading they do not.

    Kept because the nulls and the K sweep are calibrated on it, and because the
    figures already quoted elsewhere -- machine identities 0.34, section
    identities 0.19 -- are this quantity and stay comparable.
    """
    ev, C = spectrum_of(seq, k, smooth)
    return float(1 - ev[1]), C


def versions_of(ev, theta):
    """(m, drop after m, dwell in windows) from a spectrum.

    m counts eigenvalues at or above theta. theta is NOT chosen by eye: it comes
    from the null in main(), as the 95th percentile of |lambda2| under a block
    shuffle, so an eigenvalue only counts as a version if a shuffled sequence of
    the same cells would not have produced it.

    The drop reported is ev[m-1] - ev[m], the separation between the last
    eigenvalue that counts as a version and the first that does not. THAT is the
    figure P432 means by a wide gap.

    Dwell is -1/ln|lambda2| in windows: the expected residence time in a
    metastable set. It is finite and meaningful only when lambda2 < 1.
    """
    m = int((ev >= theta).sum())
    m = max(1, min(m, len(ev) - 1))
    drop = float(ev[m - 1] - ev[m])
    lam2 = float(ev[1])
    dwell = float("inf") if lam2 >= 1 else float(-1.0 / np.log(max(1e-12, lam2)))
    return m, drop, dwell


def null_test(seq, k, draws=400, seed=0, block=1):
    """block=1 is a plain shuffle. block>1 is a BLOCK shuffle.

    THE PLAIN SHUFFLE IS TOO WEAK HERE AND WOULD REPORT AN ARTEFACT AS A
    FINDING. Two of the criteria are computed over sliding histories --
    c_monotony over the last 20 windows, c_flatness over the last 15 -- so
    consecutive profiles overlap BY CONSTRUCTION and are necessarily similar.
    Any smoothed signal beats a full shuffle trivially. Measured: observed gaps
    of 0.03-0.27 against a shuffled null of 0.93-0.97, p = 0.000 at every K,
    which is what an artefact looks like when tested against the wrong null.

    A block shuffle of ~the longest criterion history preserves the local
    autocorrelation the sliding windows create and destroys only the ordering
    ABOVE that scale. Structure that survives it is structure the sliding
    windows did not manufacture.
    """
    rng = np.random.default_rng(seed)
    obs, _ = gap_of(seq, k)
    s = np.array(seq)
    null = []
    for _ in range(draws):
        if block <= 1:
            t = s.copy(); rng.shuffle(t)
        else:
            nb = int(np.ceil(len(s) / block))
            blocks = [s[i * block:(i + 1) * block] for i in range(nb)]
            rng.shuffle(blocks)
            t = np.concatenate(blocks)
        null.append(gap_of(t, k)[0])
    null = np.array(null)
    return obs, null, float((null <= obs).mean())


def age_curve(lab, k, steps=12):
    """lambda2, m and dwell over PREFIXES of the sequence, against transitions seen.

    WHY THIS IS NOT OPTIONAL, and the project has already paid for it once. m7 does
    not measure the factory's coherence; it measures the OPERATOR'S AGE. The
    operator accumulates transition counts with no decay and saveMemory persists
    them across every run, so a cumulative estimator converges and m7's
    interquartile range shrinks with history no matter what the factory does. The
    metric was suspended for exactly that.

    Versioning has the same shape and cannot dodge it the same way, because
    persistence across runs is what a version IS. A version that cannot outlive a
    run is not a version. So the age has to be controlled rather than avoided.

    A single lambda2 is uninterpretable without knowing how much history produced
    it: a sparse count matrix is smoothed toward uniform, which DEPRESSES lambda2,
    so an early estimate looks like fast mixing whatever the truth. Reporting the
    curve makes that visible, and it says which comparisons are legitimate --
    two runs may be compared only at matched transition counts, never as two
    scalars.

    READ IT LIKE THIS. A curve that has flattened means the estimate has
    converged and the value is a property of the sequence. A curve still climbing
    at the end means the answer is still a function of how much has been seen,
    and no number from it should be quoted.
    """
    out = []
    n = len(lab)
    for i in range(1, steps + 1):
        cut = max(k * 8, int(n * i / steps))
        if cut > n:
            break
        seq = lab[:cut].tolist()
        ev, C = spectrum_of(seq, k)
        nnz = int((C > 0).sum())
        lam2 = float(ev[1])
        dwell = float("inf") if lam2 >= 1 else float(-1.0 / np.log(max(1e-12, lam2)))
        out.append((cut, int(C.sum()), nnz, lam2, dwell))
    return out


NOT_COMPARABLE = (
    "per-arm refit -- NOT COMPARABLE ACROSS ARMS "
    "(K is selected inside this arm; see --partition)")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_cells(paths):
    """Stack one or more cell matrices, keeping a record of what went in.

    Several matrices are only ever stacked for --fit-partition: pooling arms is
    how a partition gets fitted before any one arm is read off it. Scoring still
    takes exactly one.
    """
    mats, info = [], []
    for p in paths:
        X = np.load(p)
        if X.ndim != 2:
            raise SystemExit(f"  {p}: expected a 2-D cell matrix, got shape {X.shape}")
        mats.append(X)
        info.append({"path": os.path.relpath(p), "sha256": sha256_file(p),
                     "rows": int(X.shape[0]), "cols": int(X.shape[1])})
    cols = {i["cols"] for i in info}
    if len(cols) > 1:
        raise SystemExit(f"  cell matrices disagree on criterion count: {sorted(cols)}. "
                         f"They cannot be pooled into one partition.")
    return np.vstack(mats), info


def standardise(X):
    """The scaler main() has always used, returned instead of thrown away.

    Constant criteria carry no information and would let k-means split on noise,
    so they are dropped; what is left is z-scored. Both halves are part of the
    partition and both must travel with the centroids, or a second arm labelled
    against those centroids is labelled in a different space.
    """
    keep = X.std(0) > 1e-9
    Xu = X[:, keep]
    mean = Xu.mean(0)
    scale = np.maximum(1e-9, Xu.std(0))
    return keep, mean, scale, (Xu - mean) / scale


def sweep_and_select(Xs, kmin, kmax, quiet=False):
    """The K sweep and the selection rule, lifted out of main() unchanged.

    Returns (best, table). best is (k, obs, p_block, labels, block_null_gaps) or
    None. The arithmetic, the seeds and the draw counts are exactly what main()
    used before this function existed, so factoring it out moves no number.
    """
    if not quiet:
        print(f"  {'K':>3} {'gap':>8} | {'plain':>8} {'p':>6} "
              f"| {'block':>8} {'p':>6}   verdict")
    best, table = None, []
    for k in range(kmin, kmax + 1):
        lab, C = kmeans(Xs, k, seed=0)
        if len(set(lab.tolist())) < k:
            continue
        obs, n1, p1 = null_test(lab.tolist(), k, draws=200, seed=1, block=1)
        _, n2, p2 = null_test(lab.tolist(), k, draws=200, seed=1, block=20)
        v = "REAL" if p2 <= 0.05 else "artefact of the sliding windows"
        if not quiet:
            print(f"  {k:>3} {obs:8.4f} | {np.median(n1):8.4f} {p1:6.3f} "
                  f"| {np.median(n2):8.4f} {p2:6.3f}   {v}")
        table.append({"k": k, "gap": float(obs),
                      "plain_median": float(np.median(n1)), "p_plain": float(p1),
                      "block_median": float(np.median(n2)), "p_block": float(p2),
                      "verdict": v})
        # SMALLEST 1-|lambda2| AMONG THE K THAT BEAT THE NULL, and that choice is
        # deliberate now rather than incidental. It was already written this way
        # while the text underneath printed that a WIDE gap was the good outcome,
        # so the file selected for metastability and then congratulated itself on
        # the opposite. Small 1-|lambda2| is slow mixing is nearly-invariant sets,
        # which is the regime a version can exist in at all.
        if p2 <= 0.05 and (best is None or obs < best[1]):
            best = (k, obs, p2, lab, n2, C)
    return best, table


def theta_from_null(nullgaps):
    """THETA FROM THE NULL, NOT BY EYE.

    An eigenvalue counts as a version only if a block-shuffled sequence of the
    same cells would not have produced one that large. The null's lambda2 is
    1 - its gap, so the 95th percentile of null lambda2 is 1 - the 5th
    percentile of null gaps. Fixed before the spectrum is looked at; choosing it
    afterwards would let any spectrum yield any number of versions. When a
    partition is frozen this number is frozen with it, so a later arm is not
    silently judged against its own shuffles.
    """
    return float(1.0 - np.percentile(np.asarray(nullgaps), 5))


def write_partition(path, X, info, cell_source, kmin, kmax, self_sha):
    """Fit K, centroids and the scaler on the pooled matrix and freeze them.

    THIS IS THE CALIBRATION STEP AND IT IS THE ONLY PLACE K IS CHOSEN. Everything
    that a later arm needs in order to be labelled in the same space is written
    out: the keep-mask, the mean, the scale, the centroids in the standardised
    space, K, theta, and the selection criterion's own numbers so the choice can
    be audited rather than taken on trust. The inputs are hashed so a partition
    can never be quietly re-pointed at different logs.
    """
    print(f"  FITTING A PARTITION on {X.shape[0]} pooled rows "
          f"from {len(info)} cell matrix/matrices")
    for i in info:
        print(f"    {i['path']}  {i['rows']}x{i['cols']}  sha256 {i['sha256'][:12]}")
    keep, mean, scale, Xs = standardise(X)
    if not keep.all():
        print(f"  dropping {int((~keep).sum())} constant criteria (no information)")
    print()
    best, table = sweep_and_select(Xs, kmin, kmax)
    if best is None:
        raise SystemExit("\n  NO K BEATS THE BLOCK NULL ON THE POOLED MATRIX. "
                         "There is no partition to freeze.")
    k, obs, p, lab, nullgaps, C = best
    theta = theta_from_null(nullgaps)
    for row in table:
        row["selected"] = bool(row["k"] == k)

    body = {
        "schema": PARTITION_SCHEMA,
        "created_utc": datetime.datetime.now(datetime.timezone.utc)
                               .strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tool": {"path": "tools/version_operator.py", "sha256": self_sha},
        "cell_source": cell_source,
        "inputs": info,
        "inputs_sha256": hashlib.sha256(
            "".join(i["sha256"] for i in info).encode()).hexdigest(),
        "pooled_rows": int(X.shape[0]),
        "n_criteria_in": int(X.shape[1]),
        "standardisation": {
            "keep": [bool(v) for v in keep],
            "mean": [float(v) for v in mean],
            "scale": [float(v) for v in scale],
            "note": "z-score of the kept criteria, using the POOLED mean and "
                    "scale. A scored arm must be transformed with these and "
                    "never with its own, or the centroids move under it.",
        },
        "K": int(k),
        "centroids": [[float(v) for v in row] for row in C],
        "theta": theta,
        "selection": {
            "criterion": "smallest 1-|lambda2| among the K with p_block <= 0.05",
            "kmin": int(kmin), "kmax": int(kmax),
            "kmeans_seed": 0, "null_draws": 200, "null_seed": 1, "null_block": 20,
            "chosen_k": int(k), "chosen_gap": float(obs), "chosen_p_block": float(p),
            "theta_rule": "1 - 5th percentile of the block-null gaps at the chosen K",
            "block_null_gaps": [float(v) for v in nullgaps],
            "table": table,
        },
        "pooled_occupancy": [float(v) for v in
                             (np.bincount(lab, minlength=k) / len(lab))],
    }
    body["partition_id"] = hashlib.sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

    with open(path, "w") as fh:
        json.dump(body, fh, indent=1)

    ev, _ = spectrum_of(lab.tolist(), k)
    m, drop, dw = versions_of(ev, theta)
    print()
    print(f"  FROZEN: K={k}, 1-|lambda2|={obs:.4f}, p={p:.3f}, theta={theta:.4f}")
    print(f"    spectrum          " + " ".join(f"{v:.3f}" for v in ev[:min(8, len(ev))]))
    print(f"    versions m        {m}   drop after m {drop:.4f}")
    print(f"    pooled occupancy  " +
          "  ".join(f"{o:.0%}" for o in body["pooled_occupancy"]))
    print(f"    partition_id      {body['partition_id'][:16]}")
    print(f"    cell source       {cell_source}")
    print(f"  wrote {path}")
    print()
    print("  WHAT THIS IS AND IS NOT. A partition fitted on arms that were already")
    print("  run is a description of those arms, not a prior. It is a prior only")
    print("  for arms that run AFTER it is written. Fitting it on the very arms you")
    print("  then difference removes the K confound but not the circularity.")
    return body


def load_partition(path, X, cell_source):
    """Load a frozen partition and REFUSE if it does not fit this matrix.

    The two disagreements that would otherwise pass silently are the ones
    checked: a different number of criteria (metrics cells are 4 wide, judge
    cells are 9) and a different cell source (a 9-wide matrix from some other
    construction would pass a shape test and mean nothing). A missing
    --cell-source is also a refusal: an unverified match is not a match.
    """
    try:
        P = json.load(open(path))
    except Exception as e:
        raise SystemExit(f"  cannot read partition {path}: {e}")
    if P.get("schema") != PARTITION_SCHEMA:
        raise SystemExit(f"  REFUSING: {path} has schema {P.get('schema')!r}, "
                         f"this tool writes {PARTITION_SCHEMA!r}.")
    want_src = P.get("cell_source")
    if cell_source is None:
        raise SystemExit(
            f"  REFUSING: --partition needs --cell-source so the match can be\n"
            f"  CHECKED rather than assumed. {os.path.basename(path)} was fitted "
            f"on {want_src!r} cells.")
    if cell_source != want_src:
        raise SystemExit(
            f"  REFUSING: cell-source mismatch. The partition was fitted on "
            f"{want_src!r} cells\n  and this matrix was declared {cell_source!r}. "
            f"Labelling judge profiles against\n  centroids fitted on raw metrics "
            f"(or the reverse) produces a number with no\n  meaning and no way to "
            f"notice. Refit, or score with the matching cells.")
    if int(P["n_criteria_in"]) != int(X.shape[1]):
        raise SystemExit(
            f"  REFUSING: dimensionality mismatch. The partition was fitted on "
            f"{P['n_criteria_in']} criteria\n  and this matrix has {X.shape[1]}. "
            f"These are not the same feature space.")
    keep = np.array(P["standardisation"]["keep"], dtype=bool)
    if len(keep) != X.shape[1]:
        raise SystemExit(f"  REFUSING: the partition's keep-mask is {len(keep)} "
                         f"long and this matrix has {X.shape[1]} criteria.")
    return P


def label_against(P, X):
    """Nearest FROZEN centroid, in the FROZEN standardised space.

    Note which mean and scale are used. They are the partition's, not this
    matrix's. That is the whole point: re-deriving them here would rescale the
    arm underneath the stored centroids and the partition would be frozen in
    name only.
    """
    keep = np.array(P["standardisation"]["keep"], dtype=bool)
    mean = np.array(P["standardisation"]["mean"], dtype=float)
    scale = np.array(P["standardisation"]["scale"], dtype=float)
    C = np.array(P["centroids"], dtype=float)
    Xs = (X[:, keep] - mean) / scale
    if Xs.shape[1] != C.shape[1]:
        raise SystemExit(f"  REFUSING: after the keep-mask this matrix is "
                         f"{Xs.shape[1]}-dimensional and the centroids are "
                         f"{C.shape[1]}-dimensional.")
    d = ((Xs[:, None, :] - C[None, :, :]) ** 2).sum(-1)
    return d.argmin(1)


def readout(lab, k, theta, mode, partition=None, gap=None, p=None):
    """The versioning readout, printed identically whichever mode produced it.

    The MODE is printed beside the dwell rather than in a header, because the
    number travels: eval_run keeps only the last 4,000 characters of stdout and
    a bundle read six months from now has to say on its face whether its dwell
    is comparable to the next bundle's.
    """
    lab = np.asarray(lab)
    ev, _ = spectrum_of(lab.tolist(), k)
    m, drop, dwell = versions_of(ev, theta)
    runs = 1 + int((np.diff(lab) != 0).sum())
    emp = len(lab) / runs
    occ = np.bincount(lab, minlength=k) / len(lab)

    print("  THE VERSIONING READOUT")
    print(f"    partition mode    {mode}")
    if partition is not None:
        print(f"    partition id      {partition['partition_id'][:16]}  "
              f"(K={partition['K']}, {partition['pooled_rows']} pooled rows, "
              f"source {partition['cell_source']})")
    print(f"    spectrum          " + " ".join(f"{v:.3f}" for v in ev[:min(8, len(ev))]))
    print(f"    theta from null   {theta:.4f}   (95th pct of shuffled |lambda2|)")
    print(f"    versions m        {m}      eigenvalues at or above theta")
    print(f"    drop after m      {drop:.4f}   <- THIS is P432's 'wide gap'")
    print(f"    dwell -1/ln|l2|   {dwell:.1f} windows = {dwell*11.2/60:.1f} min")
    print(f"    cell occupancy    " + "  ".join(f"{o:.0%}" for o in occ))
    suffix = ("" if partition is not None
              else f"   [{NOT_COMPARABLE}]")
    print(f"    empirical dwell   {emp:.1f} windows "
          f"({emp*11.2/60:.1f} min) over {runs} runs{suffix}")
    return {"mode": mode,
            "partition_id": partition["partition_id"] if partition else None,
            "partition_source": partition["cell_source"] if partition else None,
            "partition_path": partition.get("_path") if partition else None,
            "comparable_across_arms": partition is not None,
            "K": int(k), "theta": float(theta),
            "spectrum": [float(v) for v in ev],
            "versions_m": int(m), "drop_after_m": float(drop),
            "dwell_lambda2": float(dwell),
            "empirical dwell": round(float(emp), 4),
            "runs": int(runs), "windows": int(len(lab)),
            "cell_occupancy": [float(v) for v in occ],
            "gap_1_minus_lambda2": (float(gap) if gap is not None else None),
            "p_block": (float(p) if p is not None else None)}, m, drop, dwell, emp


def print_age_curve(lab, k):
    """The age control, unchanged, factored out so both modes can print it."""
    print()
    print("  AGE CONTROL: is this a property of the factory or of how much")
    print("  history the operator has eaten?")
    print()
    print(f"  {'windows':>9} {'transitions':>12} {'cells filled':>13} "
          f"{'|lambda2|':>10} {'dwell (w)':>11}")
    rows = age_curve(np.asarray(lab), k)
    for cut, tot, nnz, lam2, dwell in rows:
        print(f"  {cut:9d} {tot:12d} {nnz:13d} {lam2:10.4f} {dwell:11.1f}")
    if len(rows) >= 4:
        last4 = [r[3] for r in rows[-4:]]
        drift = max(last4) - min(last4)
        span = max(r[3] for r in rows) - min(r[3] for r in rows)
        print()
        print(f"  |lambda2| moves {span:.4f} over the whole curve and "
              f"{drift:.4f} across the last four points.")
        if drift < 0.02:
            print("  FLATTENED. The estimate has converged, so the value is a")
            print("  property of the sequence and may be quoted -- but only")
            print("  against another run at a MATCHED transition count.")
        else:
            print("  STILL MOVING. The answer is still a function of how much has")
            print("  been seen. Quoting a single figure from this would repeat the")
            print("  m7 mistake: reporting the operator's age as the factory's")
            print("  coherence. Collect more windows before reading it.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cells", required=True, nargs="+",
                    help="cell matrix (.npy). Several may be given ONLY with "
                         "--fit-partition, where they are pooled before fitting.")
    ap.add_argument("--age-curve", action="store_true",
                    help="report lambda2 against transitions seen, so two runs "
                         "can be compared at matched history instead of as scalars")
    ap.add_argument("--kmin", type=int, default=3)
    ap.add_argument("--kmax", type=int, default=10)
    ap.add_argument("--fit-partition", default=None, metavar="OUT.json",
                    help="CALIBRATION. Fit K, centroids and the standardisation "
                         "on the given cells and write them out. Fit this BEFORE "
                         "the arms you intend to difference.")
    ap.add_argument("--partition", default=None, metavar="IN.json",
                    help="Score against a frozen partition: label these windows "
                         "against its centroids and report, with no refit and no "
                         "K re-selection.")
    ap.add_argument("--cell-source", default=None, choices=["judges", "metrics"],
                    help="which construction produced these cells. Required with "
                         "--fit-partition and with --partition; ignored otherwise.")
    ap.add_argument("--json-out", default=None,
                    help="write the readout, including which mode produced it, "
                         "as json")
    a = ap.parse_args()

    self_sha = sha256_file(os.path.abspath(__file__))

    if a.fit_partition and a.partition:
        raise SystemExit("  --fit-partition and --partition are the two ends of "
                         "the same operation. Pick one.")
    if a.fit_partition and not a.cell_source:
        raise SystemExit("  --fit-partition needs --cell-source: a partition that "
                         "does not record\n  which construction it was fitted on "
                         "cannot refuse the wrong cells later.")
    if len(a.cells) > 1 and not a.fit_partition:
        raise SystemExit(f"  {len(a.cells)} cell matrices given without "
                         f"--fit-partition. Pooling arms is how a\n  partition is "
                         f"FITTED, not how one is scored; scoring takes one arm.")

    X, info = load_cells(a.cells)
    print(f"  {X.shape[0]} windows x {X.shape[1]} criteria")

    # ------------------------------------------------------------ calibration
    if a.fit_partition:
        write_partition(a.fit_partition, X, info, a.cell_source,
                        a.kmin, a.kmax, self_sha)
        return

    # ------------------------------------------- score against a frozen partition
    if a.partition:
        P = load_partition(a.partition, X, a.cell_source)
        P["_path"] = os.path.abspath(a.partition)
        lab = label_against(P, X)
        k = int(P["K"])
        print(f"  scoring against the FROZEN partition "
              f"{os.path.basename(a.partition)}")
        print(f"    K={k}, fitted on {P['pooled_rows']} rows from "
              f"{len(P['inputs'])} matrix/matrices, source {P['cell_source']}")
        print(f"    inputs_sha256 {P['inputs_sha256'][:16]}   "
              f"partition_id {P['partition_id'][:16]}")
        print(f"    NO refit and NO K re-selection happened here. The K sweep is "
              f"not run in\n    this mode by construction, which is the whole "
              f"reason the mode exists.")
        unseen = [c for c in range(k) if not (lab == c).any()]
        if unseen:
            print(f"    NOTE: cells {unseen} are never visited by this arm. That is "
                  f"information,\n    not an error -- it is what a frozen partition "
                  f"is for -- but the spectrum is\n    estimated on a matrix with "
                  f"empty rows held up only by the smoothing.")
        print()
        out, m, drop, dwell, emp = readout(lab, k, float(P["theta"]),
                                           "frozen-partition", partition=P)
        print()
        print("  This number is comparable with any other arm scored against")
        print(f"  partition_id {P['partition_id'][:16]}, and with nothing else.")
        if a.json_out:
            json.dump(out, open(a.json_out, "w"), indent=1)
            print(f"  wrote {a.json_out}")
        if a.age_curve:
            print_age_curve(lab, k)
        return

    # ---------------------------------------------- default: per-arm refit, as before
    print()
    print("  " + "!" * 72)
    print("  PER-ARM REFIT. K is selected inside THIS matrix and k-means is refitted")
    print("  inside it, so the dwell below describes this arm in a state space of")
    print("  its own. IT IS NOT COMPARABLE WITH ANOTHER ARM'S. Measured on the six")
    print("  arms of n_arms_260918_115004: per-arm refit gave 5.6 / 11.5 / 4.5 /")
    print("  17.8 / 4.8 / 8.5 with K = 10 / 5 / 10 / 4 / 10 / 7, and one partition")
    print("  across the same six gave 6.1 / 7.1 / 5.5 / 5.1 / 4.8 / 5.4. Pearson")
    print("  (1/K, dwell) = 0.987: the reported 2x-4x effect WAS the K sweep.")
    print("  To difference two arms, fit --fit-partition once and score both with")
    print("  --partition. See tools/dwell_frozen_partition.py.")
    print("  " + "!" * 72)

    keep, mean, scale, Xs = standardise(X)
    if not keep.all():
        print(f"  dropping {int((~keep).sum())} constant criteria (no information)")

    print()
    print("  Two nulls. The PLAIN shuffle destroys all order and is too weak here:")
    print("  c_monotony and c_flatness are computed over 20- and 15-window")
    print("  histories, so consecutive profiles overlap by construction. The BLOCK")
    print("  shuffle (blocks of 20) preserves that local autocorrelation and")
    print("  destroys only ordering above it. Only the block column is evidence.")
    print()
    best, table = sweep_and_select(Xs, a.kmin, a.kmax)

    print()
    if best is None:
        print("  NO K PRODUCES A GAP DISTINGUISHABLE FROM A SHUFFLED SEQUENCE.")
        print("  On P432's terms that means versioning is not happening in the")
        print("  factory's evaluative profile: there are no near-invariant regions")
        print("  to be a version OF. That is a result, not a failure of the method,")
        print("  and it is the same direction as the HMM (latent state worse than")
        print("  the marginal) and the judge population (no memory length worth")
        print("  disagreeing about).")
        if a.json_out:
            json.dump({"mode": "per-arm-refit", "comparable_across_arms": False,
                       "partition_id": None, "empirical dwell": None,
                       "status": "no K beats the block null"},
                      open(a.json_out, "w"), indent=1)
        return

    k, obs, p, lab, nullgaps, _C = best
    theta = theta_from_null(nullgaps)

    print(f"  BEST: K={k}, p={p:.3f} against the block null")
    print()
    out, m, drop, dwell, emp = readout(lab, k, theta, "per-arm-refit",
                                       gap=obs, p=p)
    if a.json_out:
        json.dump(out, open(a.json_out, "w"), indent=1)
        print(f"  wrote {a.json_out}")
    print()
    if m <= 1:
        print("  ONE VERSION. No eigenvalue but the trivial one clears the null, so")
        print("  the evaluative profile does not decompose into nearly-invariant")
        print("  regions. There is nothing for a version to BE. Same direction as")
        print("  the HMM result (latent state worse than the marginal) and the")
        print("  judge population, and it is a finding: the versioning strand would")
        print("  then rest on the AUTHORED half of P290 -- charter editions as acts")
        print("  of commitment -- and not on anything read off the wake.")
    else:
        print(f"  {m} VERSIONS, separated by {drop:.4f} and each held for about")
        print(f"  {dwell*11.2/60:.1f} minutes. The empirical dwell beside it is the check: if the")
        print("  two disagree badly the chain is not Markov at this cell size.")
    if a.age_curve:
        print_age_curve(lab, k)

    print()
    print("  WHAT IS NOT REPORTED HERE, AND WHY. 1 - |lambda2| is the ordinary")
    print(f"  spectral gap; for this run it is {obs:.4f}. It measures MIXING SPEED, so")
    print("  wide means the chain forgets quickly -- versions bleeding into each")
    print("  other, the opposite of the sentence it used to be printed under. It")
    print("  is kept only so the earlier figures stay comparable:")
    print("    machine identities   1-|l2| ~0.34")
    print("    section identities   1-|l2|  0.19   (p=0.037)")
    print(f"    judge-score cells    1-|l2|  {obs:.4f}   (p={p:.3f})")
    print()
    print(f"  MODE: {NOT_COMPARABLE}")
    print(f"  Dwell {emp:.1f} was measured on a K={k} partition fitted inside this "
          f"arm alone.")
    print("  Do not difference it against another arm's. Use --fit-partition once "
          "and")
    print("  --partition for every arm you intend to compare.")


if __name__ == "__main__":
    main()
