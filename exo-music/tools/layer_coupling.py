#!/usr/bin/env python3
"""Do the three timescales sound together, or independently? The measure that
has to exist before any nesting is built (.lab/notes/NESTING_THE_THREE_TIMESCALES.md,
"What must be measured before anything is built").

INPUT. A window log. The VOICES line is `VOICES win,macro,mid,micro`: live
voice count per layer, one row per window (11.7 s). Three integer series.

STATISTICS, pairwise (macro-mid, macro-micro, mid-micro):
  r(lag)   Pearson correlation at lags -L..+L windows (positive lag: the first
           series leads). Reported as the max |r| over lags and the lag it sits
           at.
  MI       mutual information at lag 0 between the two series after each is
           quantised to {0, 1, 2+} voices (rest / one / more), in bits.
  P(rest)  P(second silent | first silent) against P(second silent): the
           quantity the ear asked about on 19 Sept. Ratio 1 = independent.

NULL. Circular block bootstrap of the SECOND series in each pair: blocks of
BLOCK windows (default 20, above macro's dwell of 6-16) are resampled with
replacement into a series of the same length, so within-layer structure
(runs, rests, dwell) survives and only the alignment between layers is
destroyed. N draws; the 95th percentile of each statistic under the null is
the bar, and p is the share of draws at or above the observed value.

WHAT IT IS FOR. Today's factory shares `target` across layers (correlated in
colour) and has no cross-layer term in any rest decision (independent in
density). The expected reading is near-null coupling. If it is not, the
shared target is already coupling density through material and the nesting
design changes before it starts. Either way this is the uncoupled BASELINE
that a coupling mechanism at K > 0 is later measured against.

    python3 tools/layer_coupling.py workdir_music/renders/live_260919_141610.log
    python3 tools/layer_coupling.py LOG --from 0 --to 853      # one arm
    python3 tools/layer_coupling.py --calibrate                # synthetic check
"""
import argparse
import math
import re
import sys

import numpy as np

LAYERS = ["macro", "mid", "micro"]


def read_voices(path, w0=None, w1=None):
    rows = []
    for line in open(path, errors="ignore"):
        m = re.match(r"VOICES (\d+),(\d+),(\d+),(\d+)", line)
        if m:
            w = int(m.group(1))
            if (w0 is None or w >= w0) and (w1 is None or w <= w1):
                rows.append([int(m.group(i)) for i in (2, 3, 4)])
    return np.array(rows, dtype=float)


def xcorr_max(a, b, maxlag):
    best, blag = 0.0, 0
    n = len(a)
    for lag in range(-maxlag, maxlag + 1):
        if lag >= 0:
            x, y = a[: n - lag], b[lag:]
        else:
            x, y = a[-lag:], b[: n + lag]
        if x.std() < 1e-9 or y.std() < 1e-9:
            continue
        r = float(np.corrcoef(x, y)[0, 1])
        if abs(r) > abs(best):
            best, blag = r, lag
    return best, blag


def quantise(v):
    return np.minimum(v, 2).astype(int)   # 0 rest, 1 one voice, 2 two or more


def mutual_info(a, b):
    qa, qb = quantise(a), quantise(b)
    n = len(qa)
    joint = np.zeros((3, 3))
    for x, y in zip(qa, qb):
        joint[x, y] += 1
    joint /= n
    pa, pb = joint.sum(1), joint.sum(0)
    mi = 0.0
    for i in range(3):
        for j in range(3):
            if joint[i, j] > 0:
                mi += joint[i, j] * math.log2(joint[i, j] / (pa[i] * pb[j]))
    return mi


def rest_ratio(a, b):
    """P(b silent | a silent) / P(b silent). 1 = independent, >1 = rests align."""
    ra, rb = a == 0, b == 0
    if ra.sum() == 0 or rb.mean() == 0:
        return float("nan")
    return float(rb[ra].mean() / rb.mean())


def block_bootstrap(b, block, rng):
    n = len(b)
    out = np.empty(n)
    i = 0
    while i < n:
        s = int(rng.integers(0, n))
        k = min(block, n - i)
        idx = (np.arange(s, s + k)) % n
        out[i:i + k] = b[idx]
        i += k
    return out


def analyse(V, maxlag, block, n_null, seed):
    rng = np.random.default_rng(seed)
    pairs = [(0, 1), (0, 2), (1, 2)]
    res = {}
    for i, j in pairs:
        a, b = V[:, i], V[:, j]
        obs_r, obs_lag = xcorr_max(a, b, maxlag)
        obs_mi = mutual_info(a, b)
        obs_rr = rest_ratio(a, b)
        null_r, null_mi, null_rr = [], [], []
        for _ in range(n_null):
            bb = block_bootstrap(b, block, rng)
            null_r.append(abs(xcorr_max(a, bb, maxlag)[0]))
            null_mi.append(mutual_info(a, bb))
            null_rr.append(rest_ratio(a, bb))
        null_r, null_mi = np.array(null_r), np.array(null_mi)
        null_rr = np.array([x for x in null_rr if not math.isnan(x)])
        res[f"{LAYERS[i]}-{LAYERS[j]}"] = dict(
            r=obs_r, lag=obs_lag, r_p95=float(np.percentile(null_r, 95)),
            r_p=float(np.mean(null_r >= abs(obs_r))),
            mi=obs_mi, mi_p95=float(np.percentile(null_mi, 95)),
            mi_p=float(np.mean(null_mi >= obs_mi)),
            rest=obs_rr,
            rest_p95=float(np.percentile(null_rr, 95)) if len(null_rr) else float("nan"),
            rest_p=float(np.mean(null_rr >= obs_rr)) if len(null_rr) and not math.isnan(obs_rr) else float("nan"),
        )
    return res


def report(V, res, label):
    n = len(V)
    print(f"{label}: {n} windows   rest share  macro {np.mean(V[:,0]==0):.3f}  "
          f"mid {np.mean(V[:,1]==0):.3f}  micro {np.mean(V[:,2]==0):.3f}   "
          f"all three silent {np.mean((V==0).all(1)):.4f}")
    print(f"  {'pair':13s} {'max|r|':>7s} {'lag':>4s} {'null95':>7s} {'p':>6s}   "
          f"{'MI bits':>8s} {'null95':>7s} {'p':>6s}   {'rest ratio':>10s} {'null95':>7s} {'p':>6s}")
    for k, v in res.items():
        print(f"  {k:13s} {v['r']:+7.3f} {v['lag']:4d} {v['r_p95']:7.3f} {v['r_p']:6.3f}   "
              f"{v['mi']:8.4f} {v['mi_p95']:7.4f} {v['mi_p']:6.3f}   "
              f"{v['rest']:10.3f} {v['rest_p95']:7.3f} {v['rest_p']:6.3f}")


def calibrate(maxlag, block, n_null, seed):
    rng = np.random.default_rng(1)
    n = 2000
    def runs(p_rest, mean_len):
        v = np.zeros(n)
        i = 0
        state = 0
        while i < n:
            k = int(rng.geometric(1.0 / mean_len))
            v[i:i + k] = 0 if state == 0 else rng.integers(1, 4)
            i += k
            state = 0 if (state != 0 and rng.random() < p_rest) else 1
        return v
    ind = np.column_stack([runs(0.3, 10), runs(0.3, 6), runs(0.4, 4)])
    print("=== calibration: independent layers with their own run structure (expect null)")
    report(ind, analyse(ind, maxlag, block, n_null, seed), "independent")
    # coupled: micro rests when macro rests, with a 2-window lag
    cpl = ind.copy()
    for t in range(2, n):
        if cpl[t - 2, 0] == 0 and rng.random() < 0.7:
            cpl[t, 2] = 0
    print("=== calibration: micro follows macro's rests at lag 2 (expect macro-micro to beat null)")
    report(cpl, analyse(cpl, maxlag, block, n_null, seed), "coupled")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", nargs="?")
    ap.add_argument("--from", dest="w0", type=int, default=None)
    ap.add_argument("--to", dest="w1", type=int, default=None)
    ap.add_argument("--maxlag", type=int, default=16, help="windows; macro dwell is 6-16")
    ap.add_argument("--block", type=int, default=20, help="bootstrap block, windows")
    ap.add_argument("--n-null", type=int, default=300)
    ap.add_argument("--seed", type=int, default=20260922)
    ap.add_argument("--calibrate", action="store_true")
    a = ap.parse_args()
    if a.calibrate:
        calibrate(a.maxlag, a.block, a.n_null, a.seed)
        return 0
    if not a.log:
        ap.error("a log path or --calibrate")
    V = read_voices(a.log, a.w0, a.w1)
    if len(V) < 200:
        raise SystemExit(f"ABORT: {len(V)} windows; need at least 200")
    res = analyse(V, a.maxlag, a.block, a.n_null, a.seed)
    report(V, res, a.log.split("/")[-1] + (f"[{a.w0}:{a.w1}]" if a.w0 is not None or a.w1 is not None else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
