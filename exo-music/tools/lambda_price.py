#!/usr/bin/env python3
"""λ: what a constraint costs the factory, priced in novelty forgone.

THE IDEA, in one line: a constraint's price is the novelty the factory gives up
by obeying it, per window, at its current operating point.

WHY NOT THE TEXTBOOK λ. A shadow price is normally the derivative of an
objective with respect to relaxing a constraint. This factory has no objective by
construction -- score_charter refuses to emit a total, because three
self-generated scalars became convergence engines -- so there is no gradient to
take. The paper still asks for a price: "the marginal worth of that constraint at
the factory's current operating point... a speculative price posted by the
factory". This supplies one in the only currency the factory has.

WHY NOVELTY IS THE CURRENCY. Novelty failed as a BOUND: measured as coverage of
descriptor space it is vacuous at a loose radius and perverse at a middling one,
where a shuffled trajectory beats the factory because a diffuse walk covers more
ground than one that lingers. But at a TIGHT radius the factory beats its own
null decisively (20.2% against 2.2%), because it genuinely occupies regions. So
the measurement is good and the FORM was wrong. Here novelty does no bounding at
all -- it is the unit in which prices are quoted.

WHAT CAN BE PRICED. Only constraints that CLAMP A CHOICE, because only those
exclude candidates the factory would otherwise have taken:

    priceable      voices_min/max (m6), self_ingest_weight, master_gain,
                   the transient gate on admission
    NOT priceable  m2_level, m3_no_clipping, m8_in_band,
                   m1_audible_when_driving -- these describe an OUTCOME. They
                   forbid nothing, so there is no excluded candidate set, so λ
                   is UNDEFINED and must be reported as undefined rather than as
                   zero. Zero means "this constraint is free"; undefined means
                   "this is not the kind of thing that has a price". Conflating
                   them is how a metric becomes decorative.

λ IS NOT AN OBJECTIVE. Nothing in selection reads it. It is a report the factory
posts and the architect reads, which is why it is safe where E3, the audibility
score and the transfer operator were not. If a future version ever feeds λ back
into selection, that is the moment this becomes the fourth convergence engine.

FIRST PRICE: the voice clamp, because it is the constraint the factory has
actually complained about -- four voice_range proposals asking for densities of
5, 6, 7 and 8 against a bound of [2,5].

    python3 tools/lambda_price.py
"""
import argparse
import glob
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")

# The radius at which occupying a region means something. Established
# empirically: at 0.09 the factory reaches 20.2% of anchored regions against a
# null of 2.2%; at 0.226 the null wins 96.6% to 73.0%. This is the regime where
# "how new is this" has an answer that is about the factory rather than about
# the geometry of a large ball.
TIGHT = 0.09


def read_run(path):
    """Per window: the machine, the voice count, and where in descriptor space
    the factory was."""
    W = []
    for line in open(path, errors="replace"):
        p = line.strip().split(",")
        if len(p) > 13 and p[3] in ("runtime", "class") and "|" in p[13]:
            try:
                W.append({"w": int(p[1]), "mach": p[2], "amp": float(p[4]),
                          "live": int(p[9]),
                          "vec": np.array([float(x) for x in p[13].split("|")])})
            except (ValueError, IndexError):
                pass
    return W


def novelty_of(vec, history):
    """Distance to the nearest place the factory has already been, capped at the
    tight radius. Beyond that radius the number stops meaning "new" and starts
    meaning "far", which is a different claim."""
    if not len(history):
        return TIGHT
    d = np.sqrt(((history - vec) ** 2).sum(axis=1)).min()
    return float(min(d, TIGHT))


def price_voice_clamp(W, lo, hi):
    """λ for the voice clamp.

    The factory's DESIRED voice count is not logged -- only the count after the
    clamp. So the excluded set is estimated from behaviour at the boundary: a
    window sitting exactly at the clamp is a window that may have wanted more
    (or fewer), and the clamp bound there. This is a lower bound on the true
    price, and it is labelled as such rather than presented as the price.

    Each binding window is weighted by the novelty of where the factory was when
    it bound: being clamped in familiar territory costs less than being clamped
    somewhere new, because the constraint is denying less.
    """
    hist = np.zeros((0, len(W[0]["vec"]))) if W else None
    bind_lo = bind_hi = 0
    nov_at_bind = []
    nov_all = []
    for r in W:
        n = novelty_of(r["vec"], hist)
        nov_all.append(n)
        if r["live"] <= lo:
            bind_lo += 1; nov_at_bind.append(n)
        elif r["live"] >= hi:
            bind_hi += 1; nov_at_bind.append(n)
        hist = np.vstack([hist, r["vec"]])
    n_w = len(W)
    return {
        "windows": n_w,
        "at_lower_clamp": bind_lo,
        "at_upper_clamp": bind_hi,
        "binding_rate": (bind_lo + bind_hi) / max(n_w, 1),
        # λ in novelty-per-window: how much new ground, on average per window,
        # the factory was standing on when the clamp bound it.
        "lambda": float(np.sum(nov_at_bind) / max(n_w, 1)),
        "mean_novelty_overall": float(np.mean(nov_all)) if nov_all else 0.0,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=None)
    a = ap.parse_args()
    logs = ([a.log] if a.log else
            sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                   key=os.path.getmtime)[-6:])
    pol = json.load(open(os.path.join(MUT, "policy.json")))
    ch = json.load(open(os.path.join(MUT, "charter.json")))
    lo = int(pol.get("voices_min", 1)); hi = int(pol.get("voices_max", 8))
    m6 = ch["metrics"]["m6_texture"]["acceptable"]

    print()
    print(f"  policy clamp voices [{lo}, {hi}]   charter m6_texture {m6}")
    print(f"  novelty measured at the tight radius {TIGHT}")
    print()
    print(f"  {'run':30} {'windows':>8} {'binds':>7} {'rate':>7} {'lambda':>9}")
    print("  " + "-" * 68)
    rows = []
    for lg in logs:
        W = read_run(lg)
        if len(W) < 100:
            continue
        r = price_voice_clamp(W, lo, hi)
        rows.append(r)
        print(f"  {os.path.basename(lg):30} {r['windows']:8d} "
              f"{r['at_lower_clamp'] + r['at_upper_clamp']:7d} "
              f"{100*r['binding_rate']:6.1f}% {r['lambda']:9.5f}")
    if not rows:
        raise SystemExit("  no run long enough to price")

    lam = float(np.mean([r["lambda"] for r in rows]))
    nov = float(np.mean([r["mean_novelty_overall"] for r in rows]))
    print()
    print(f"  λ(voice clamp) = {lam:.5f} novelty per window")
    print(f"  for scale, mean novelty per window overall = {nov:.5f}")
    print(f"  so the clamp costs about {100*lam/max(nov,1e-9):.1f}% of the "
          f"novelty the factory generates")
    print()
    if lam < 0.002:
        print("  READ: the clamp is nearly free. The four voice_range proposals")
        print("  were asking for something of little worth at this operating")
        print("  point, and widening m6 to [2,8] cost the charter nothing.")
    elif lam < 0.02:
        print("  READ: the clamp has a modest price. It binds, and where it")
        print("  binds the factory is not in especially new territory.")
    else:
        print("  READ: the clamp is expensive. It binds often and in novel")
        print("  regions, so the factory's four proposals were reporting a real")
        print("  constraint on its work rather than a preference.")
    print()
    print("  This is a LOWER BOUND: the desired voice count is not logged, so")
    print("  only windows sitting AT the clamp are counted as bound. Logging the")
    print("  pre-clamp value would give the true price and is the obvious next")
    print("  step if this number is ever used for anything.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
