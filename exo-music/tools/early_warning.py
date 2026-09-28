#!/usr/bin/env python3
"""The early-warning joint-rise statistic, as pre-registered on 18 September.

    .lab/measurements/2026-09-18_early_warning_veto_prereg.md

Critical slowing down is variance AND autocorrelation rising together. Either
alone indicates nothing. So the statistic is a conjunction, and the conjunction
is enforced by a MIN: at scale w, over a window series x,

    r_var = variance(last w) / variance(first w)
    r_ac  = ac1(last w) - ac1(first w)
    JR(w) = min( log(r_var), r_ac / s_ac )

and the arm's statistic is JR = max over w in {30, 90, 240}. A large variance
ratio with flat autocorrelation scores low, and so does the reverse. `s_ac` is
the null's standard deviation of `r_ac`, which is what makes the two components
comparable before the min is taken.

THE BOUND COMES FROM A NULL, NEVER FROM AN OBSERVED VALUE. That is the
discipline m7, m4's old ceiling and the 0.9 drift threshold each broke, and the
reason all three were withdrawn. The null here is a circular block bootstrap of
the arm's own series, block length 30, 2,000 replicates, bound at the 99th
percentile. A plain shuffle would be wrong: it destroys the autocorrelation
whose CHANGE is half the statistic, so the null would be trivially beaten and
the bound would mean nothing. The block bootstrap destroys the early-to-late
trend and keeps the short-range structure, which is the null the alternative is
actually tested against.

This file computes and reports. It does not act, and it writes nothing into
harness/measures.json. Calibration lives in tools/test_early_warning.py and,
per the registry's own rule, must pass before this can enter as a veto.

    python3 tools/early_warning.py --log <windows.log>
    python3 tools/early_warning.py --log <cand.log> --champion <champ.log>
    python3 tools/early_warning.py --log <windows.log> --json out.json
"""
import argparse
import json
import sys

import numpy as np

# Fixed by the pre-registration. Changing any of these makes the numbers
# incommensurable with anything scored before the change.
SCALES = (30, 90, 240)
BLOCK = 30
REPLICATES = 2000
PERCENTILE = 99.0

# The bound is a bootstrap quantile, so it moves a little with the draw. A gate
# that gives a different verdict on re-run is not a gate, so the seed is fixed
# and recorded in the output rather than left to the clock.
SEED = 20260918

SERIES = ("master_peak", "spectral_gap")


# ---------------------------------------------------------------- input

def read(path):
    """The window log's two line formats, as parsed in score_charter.read().

    `MASTER  win, peak, clip` and `OPERATOR  win, gap, lambda2, ...` are
    keyword-then-CSV; the event rows are bare CSV with no whitespace at all.
    Only the first two are needed here.

    The OPERATOR field index is the corrected one: p[0] is the window, p[1] is
    the GAP, p[2] is lambda2. m7 read p[2] for its entire life and scored
    lambda2 under the gap's name; see the note in score_charter.read().
    """
    mp, gap = [], []
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                mp.append(float(p[1]))
            except (ValueError, IndexError):
                pass
        elif line.startswith("OPERATOR"):
            p = line.split()[1].split(",")
            try:
                gap.append(float(p[1]))
            except (ValueError, IndexError):
                pass
    return {"master_peak": np.array(mp, float),
            "spectral_gap": np.array(gap, float)}


# ---------------------------------------------------------------- statistic

def ac1(x):
    """Lag-1 autocorrelation. Zero for a constant series, by convention."""
    d = x - x.mean()
    den = float(np.dot(d, d))
    if den <= 0.0:
        return 0.0
    return float(np.dot(d[:-1], d[1:]) / den)


def components(x, w):
    """(log r_var, r_ac) at scale w, or None if the scale does not apply.

    The early and late blocks must not overlap, so a scale needs n >= 2w. The
    pre-registration does not say what to do when it does not, and overlapping
    blocks would share data between the two sides of a ratio built to compare
    them, so the scale is dropped instead.
    """
    n = len(x)
    if n < 2 * w:
        return None
    early, late = x[:w], x[-w:]
    v_e, v_l = float(np.var(early)), float(np.var(late))
    if v_e <= 0.0 or v_l <= 0.0:
        # A flat block makes the ratio undefined rather than large. Dropping
        # the scale is the conservative move for a veto: it cannot invent a
        # rise out of a degenerate denominator.
        return None
    return float(np.log(v_l / v_e)), ac1(late) - ac1(early)


def circular_block_bootstrap(x, rng, block=BLOCK):
    """Resample by whole blocks, wrapping at the end of the series.

    Short-range structure survives inside a block; the early-to-late ordering
    does not survive at all, which is exactly the null of "no trend".
    """
    n = len(x)
    nb = int(np.ceil(n / block))
    starts = rng.integers(0, n, size=nb)
    idx = (starts[:, None] + np.arange(block)[None, :]) % n
    return x[idx.ravel()[:n]]


def analyse(x, replicates=REPLICATES, seed=SEED, scales=SCALES):
    """JR for one series, with the bound its own null puts on it.

    s_ac is the null's standard deviation of r_ac, so the null has to be drawn
    before ANY JR can be formed -- including the null's own. Hence two passes
    over the same replicates: collect the raw components, derive s_ac per
    scale, then form JR for the replicates and for the observation with the
    identical normaliser.
    """
    n = len(x)
    usable = [w for w in scales if components(x, w) is not None]
    if not usable:
        return {"n": n, "usable_scales": [], "jr": None, "bound": None,
                "exceeds": None, "reason": "no scale applies to this series"}

    rng = np.random.default_rng(seed)
    raw = {w: np.empty((replicates, 2)) for w in usable}
    drawn = {w: np.zeros(replicates, bool) for w in usable}
    for b in range(replicates):
        xb = circular_block_bootstrap(x, rng)
        for w in usable:
            c = components(xb, w)
            if c is not None:
                raw[w][b] = c
                drawn[w][b] = True

    s_ac = {}
    for w in usable:
        r = raw[w][drawn[w], 1]
        s = float(np.std(r, ddof=1)) if r.size > 1 else 0.0
        # A null with no spread in r_ac cannot normalise anything; refusing to
        # divide is better than manufacturing an enormous ratio.
        s_ac[w] = s if s > 0.0 else float("nan")

    live = [w for w in usable if np.isfinite(s_ac[w])]
    if not live:
        return {"n": n, "usable_scales": usable, "jr": None, "bound": None,
                "exceeds": None, "reason": "null has no spread in r_ac"}

    null = np.full(replicates, -np.inf)
    for w in live:
        jr_w = np.minimum(raw[w][:, 0], raw[w][:, 1] / s_ac[w])
        jr_w = np.where(drawn[w], jr_w, -np.inf)
        null = np.maximum(null, jr_w)
    null = null[np.isfinite(null)]
    bound = float(np.percentile(null, PERCENTILE))

    per_scale, jr = {}, -np.inf
    for w in live:
        lv, ra = components(x, w)
        jr_w = min(lv, ra / s_ac[w])
        per_scale[w] = {"log_r_var": lv, "r_ac": ra, "s_ac": s_ac[w],
                        "r_ac_over_s_ac": ra / s_ac[w], "jr_w": jr_w}
        jr = max(jr, jr_w)

    return {"n": n, "usable_scales": live, "per_scale": per_scale,
            "jr": float(jr), "bound": bound, "exceeds": bool(jr > bound),
            "null_median": float(np.median(null)), "replicates": len(null),
            "argmax_scale": max(live, key=lambda w: per_scale[w]["jr_w"])}


def analyse_log(path, **kw):
    s = read(path)
    return {"log": path,
            "series": {k: analyse(s[k], **kw) for k in SERIES},
            "lengths": {k: int(len(s[k])) for k in SERIES}}


# ---------------------------------------------------------------- decision

def verdict(candidate, champion=None):
    """The rule, fixed in the pre-registration before any bound existed.

    cand <= bound                     -> pass
    cand >  bound and champ <= bound  -> VETO
    cand >  bound and champ >  bound  -> no veto, recorded warning: the factory
                                         is in the region under both arms, which
                                         is not attributable to the change.
    A veto on either series blocks.
    """
    out = {}
    for k in SERIES:
        c = candidate["series"][k]
        if c["jr"] is None:
            out[k] = "UNDECIDED"
        elif not c["exceeds"]:
            out[k] = "PASS"
        elif champion is None:
            out[k] = "EXCEEDS (no champion supplied; not a veto on its own)"
        else:
            h = champion["series"][k]
            if h["jr"] is None:
                out[k] = "UNDECIDED (champion series unscorable)"
            elif h["exceeds"]:
                out[k] = "WARNING"
            else:
                out[k] = "VETO"
    out["blocks"] = any(v == "VETO" for v in out.values())
    return out


# ---------------------------------------------------------------- report

def report(res, fh=sys.stdout):
    print(f"{res['log']}", file=fh)
    for k in SERIES:
        r = res["series"][k]
        if r["jr"] is None:
            print(f"  {k:<14} n={r['n']:<6} not scorable: {r['reason']}",
                  file=fh)
            continue
        flag = "EXCEEDS" if r["exceeds"] else "within"
        print(f"  {k:<14} n={r['n']:<6} JR={r['jr']:+.4f}  "
              f"bound(p{PERCENTILE:g})={r['bound']:+.4f}  {flag}"
              f"   [argmax w={r['argmax_scale']}]", file=fh)
        for w in r["usable_scales"]:
            d = r["per_scale"][w]
            print(f"      w={w:<4} log r_var={d['log_r_var']:+.4f}  "
                  f"r_ac={d['r_ac']:+.4f}  s_ac={d['s_ac']:.4f}  "
                  f"r_ac/s_ac={d['r_ac_over_s_ac']:+.4f}  "
                  f"JR(w)={d['jr_w']:+.4f}", file=fh)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--log", action="append", required=True,
                    help="window log; repeatable")
    ap.add_argument("--champion", default=None,
                    help="champion window log, to apply the paired rule")
    ap.add_argument("--json", default=None, help="write the full result here")
    ap.add_argument("--replicates", type=int, default=REPLICATES)
    ap.add_argument("--seed", type=int, default=SEED)
    a = ap.parse_args(argv)

    kw = dict(replicates=a.replicates, seed=a.seed)
    champ = analyse_log(a.champion, **kw) if a.champion else None
    if champ:
        print("champion:")
        report(champ)
        print()

    out = {"scales": list(SCALES), "block": BLOCK,
           "replicates": a.replicates, "percentile": PERCENTILE,
           "seed": a.seed, "champion": champ, "arms": []}
    blocks = False
    for p in a.log:
        res = analyse_log(p, **kw)
        report(res)
        v = verdict(res, champ)
        for k in SERIES:
            print(f"  -> {k:<14} {v[k]}")
        blocks = blocks or v["blocks"]
        res["verdict"] = v
        out["arms"].append(res)
        print()

    if a.json:
        with open(a.json, "w") as fh:
            json.dump(out, fh, indent=2)
        print(f"wrote {a.json}")
    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main())
