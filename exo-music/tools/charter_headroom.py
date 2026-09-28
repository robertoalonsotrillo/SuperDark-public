#!/usr/bin/env python3
"""For metrics that never fail: are they unreachable, or is the factory comfortable?

WHY THE DISTINCTION DECIDES SOMETHING
Three of the charter's eight metrics did not depart on any of ten runs. That is
reported as "not currently a constraint", which is true and unhelpful, because
it covers two situations with opposite implications:

  UNREACHABLE BY CONSTRUCTION   another file already guarantees the bound.
                                policy.json pins voice count between voices_min
                                and voices_max, so a metric on median voice
                                count cannot fail while those settings hold. It
                                is not testing the factory; it is restating a
                                setting. As a charter metric it is decorative,
                                and P518's "acceptable probability states"
                                cannot be expressed by a quantity with no
                                probability of departing.

  COMFORTABLE                   the bound is genuinely reachable and the factory
                                has simply stayed inside it. That is a metric
                                doing its job quietly, and it should be kept.

The remedy differs. A decorative metric should be replaced or dropped, and
saying so costs nothing. A comfortable one should be left exactly as it is --
and tightening it so that it "bites" is the theatre kernel.json forbids.

Reports observed range against the bound, and against any policy setting that
already constrains the same quantity. Proposes no bound.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="+", required=True)
    ap.add_argument("--charter", required=True)
    ap.add_argument("--policy", required=True)
    ap.add_argument("--min-windows", type=int, default=100)
    a = ap.parse_args()

    ch = json.load(open(a.charter))
    pol = json.load(open(a.policy))

    seen = {}
    for p in sorted(a.logs, key=os.path.getmtime):
        try:
            n, rows, _, _ = SC.evaluate(p, ch)
        except Exception:
            continue
        if n < a.min_windows:
            continue
        for k, norm, v, lo, hi, verdict in rows:
            if v is None:
                continue
            seen.setdefault(k, []).append(v)

    # quantities that another file already pins
    pinned = {
        "m6_texture": ("policy.json voices_min..voices_max",
                       float(pol.get("voices_min", 0)), float(pol.get("voices_max", 0))),
    }

    print()
    print(f"  {'metric':26} {'bound':>18} {'observed':>20} {'headroom':>10}   reading")
    print("  " + "-" * 100)
    for k, spec in ch["metrics"].items():
        if k.startswith("_") or k not in seen:
            continue
        lo, hi = spec["acceptable"]
        v = np.array(seen[k], float)
        span = hi - lo
        # how close did it ever get to a bound, as a fraction of the range
        head = min((v.min() - lo), (hi - v.max())) / max(span, 1e-9)

        note = ""
        if k in pinned:
            src, plo, phi = pinned[k]
            if plo >= lo and phi <= hi:
                note = (f"DECORATIVE: {src} = [{plo:g},{phi:g}] already sits "
                        f"inside [{lo:g},{hi:g}]; cannot depart while that holds")
        if not note:
            if head > 0.30:
                note = "comfortable: reachable, factory well inside"
            elif head > 0.0:
                note = "close to a bound: would bite on a modest change"
            else:
                note = "departs somewhere; not in this group"
        print(f"  {k:26} [{lo:7.3f},{hi:8.3f}] "
              f"[{v.min():8.3f},{v.max():8.3f}] {head:9.2f}   {note}")

    print()
    print("  headroom = closest approach to either bound, as a fraction of the")
    print("  bound's own width. Small means the metric nearly bit.")
    print()
    print("  A DECORATIVE metric is not a calibration error and must not be fixed")
    print("  by moving its bound. It is a metric whose value another file")
    print("  determines, so it can never carry information about the factory.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
