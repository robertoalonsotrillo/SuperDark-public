#!/usr/bin/env python3
"""Does the factory's output follow the world? The roadmap 2.3 acceptance test.

Two series in ONE space, both written by world_listen.py at 1 Hz:
  --world  the signal sent to the factory (the other factory's stream, or a room)
  --self   the factory's own delivered output, listened to the same way
Both are 5-dimensional positions in the corpus geometry plus rms.

THE STATISTIC. Per axis, the cross-correlation r(lag) between world and self
for lag in 0..MAXLAG seconds (world leads). Reported as the maximum |r| over
lags, per axis, and the mean over axes.

THE NULL. Circular shifts of the self series by a random offset drawn far from
zero (at least MAXLAG+60 s, at most len-MAXLAG-60 s), N times. Shifting keeps
every marginal and every autocorrelation of both series and destroys only
their alignment. This is the null the roadmap names: if the observed statistic
does not beat it, any resemblance between the two factories is what two runs
of the same corpus look like when nobody is listening to anybody.

THE DECISION RULE, fixed before the run (2026-09-20_factory_consumes_factory_prereg.md):
  treatment arm (world_pull > 0): observed mean |r| > 95th percentile of null
  control arm   (world_pull = 0): observed mean |r| NOT > 95th percentile
Both must hold. Treatment alone can be the relay's shared latency structure;
control alone says nothing.

Latency: the relay adds seconds between one factory's output and the other's
input; a window is 10-20 s; MAXLAG defaults to 60 s, which covers both.

    python3 tools/world_coupling.py --world /tmp/world_f1.csv --self /tmp/self_f2.csv
"""
import argparse
import sys

import numpy as np


def load(path):
    rows = []
    with open(path) as fh:
        for line in fh:
            p = line.strip().split(",")
            if len(p) < 7:
                continue
            try:
                rows.append([float(x) for x in p])
            except ValueError:
                continue
    a = np.array(rows)
    if a.shape[0] < 10:
        raise SystemExit(f"ABORT: {path} has {a.shape[0]} usable rows")
    return a[:, 0], a[:, 1:6], a[:, 6]


def align(tw, w, ts, s):
    """Resample both onto a common 1 Hz grid over their overlap by nearest row."""
    t0 = max(tw[0], ts[0]); t1 = min(tw[-1], ts[-1])
    if t1 - t0 < 120:
        raise SystemExit(f"ABORT: overlap is {t1 - t0:.0f} s; need at least 120")
    grid = np.arange(np.ceil(t0), np.floor(t1) + 1, 1.0)
    iw = np.searchsorted(tw, grid).clip(0, len(tw) - 1)
    is_ = np.searchsorted(ts, grid).clip(0, len(ts) - 1)
    return grid, w[iw], s[is_]


def xcorr_max(w, s, maxlag):
    """max |r| over lag 0..maxlag with world leading, per axis."""
    n, d = w.shape
    out = np.zeros(d)
    for j in range(d):
        best = 0.0
        for lag in range(0, maxlag + 1):
            a = w[: n - lag, j]; b = s[lag:, j]
            if a.std() < 1e-9 or b.std() < 1e-9:
                continue
            r = np.corrcoef(a, b)[0, 1]
            if abs(r) > abs(best):
                best = r
        out[j] = best
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--world", required=True)
    ap.add_argument("--self", dest="self_", required=True)
    ap.add_argument("--maxlag", type=int, default=60, help="seconds, world leads")
    ap.add_argument("--n-null", type=int, default=500)
    ap.add_argument("--seed", type=int, default=20260920)
    ap.add_argument("--rms-floor", type=float, default=1e-4,
                    help="seconds where either side is below this rms are dropped")
    ap.add_argument("--from", dest="t_from", type=float, default=None,
                    help="unix time; rows before this are dropped (one arm)")
    ap.add_argument("--to", dest="t_to", type=float, default=None,
                    help="unix time; rows after this are dropped (one arm)")
    a = ap.parse_args()

    tw, w, rw = load(a.world)
    ts, s, rs = load(a.self_)
    for lo_t, hi_t in [(a.t_from, a.t_to)]:
        if lo_t is not None:
            kw = tw >= lo_t; ks = ts >= lo_t
            tw, w, rw = tw[kw], w[kw], rw[kw]; ts, s, rs = ts[ks], s[ks], rs[ks]
        if hi_t is not None:
            kw = tw <= hi_t; ks = ts <= hi_t
            tw, w, rw = tw[kw], w[kw], rw[kw]; ts, s, rs = ts[ks], s[ks], rs[ks]
    grid, W, S = align(tw, w, ts, s)
    _, RW, RS = align(tw, rw[:, None], ts, rs[:, None])
    keep = (RW[:, 0] > a.rms_floor) & (RS[:, 0] > a.rms_floor)
    W, S = W[keep], S[keep]
    n = W.shape[0]
    if n < a.maxlag * 2 + 120:
        raise SystemExit(f"ABORT: {n} aligned non-silent seconds; need {a.maxlag * 2 + 120}")

    obs = xcorr_max(W, S, a.maxlag)
    rng = np.random.default_rng(a.seed)
    lo = a.maxlag + 60; hi = n - a.maxlag - 60
    null = np.zeros((a.n_null, W.shape[1]))
    for i in range(a.n_null):
        k = int(rng.integers(lo, hi))
        null[i] = xcorr_max(W, np.roll(S, k, axis=0), a.maxlag)
    obs_mean = float(np.mean(np.abs(obs)))
    null_mean = np.mean(np.abs(null), axis=1)
    p95 = float(np.percentile(null_mean, 95))
    p = float(np.mean(null_mean >= obs_mean))

    print(f"aligned seconds {n}   maxlag {a.maxlag} s   null draws {a.n_null}")
    print("per-axis max|r|  observed  " + "  ".join(f"{v:+.3f}" for v in obs))
    print("per-axis null p95          " + "  ".join(f"{v:.3f}" for v in np.percentile(np.abs(null), 95, axis=0)))
    print(f"mean |r|  observed {obs_mean:.4f}   null p95 {p95:.4f}   null median {np.median(null_mean):.4f}   p = {p:.3f}")
    verdict = "BEATS the circular-shift null" if obs_mean > p95 else "does NOT beat the null"
    print(f"VERDICT: {verdict}")
    return 0 if obs_mean > p95 else 1


if __name__ == "__main__":
    sys.exit(main())
