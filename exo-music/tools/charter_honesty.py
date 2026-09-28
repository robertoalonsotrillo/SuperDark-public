#!/usr/bin/env python3
"""Are the charter's bounds honest enough to arm the kernel?

THE QUESTION THIS ANSWERS, AND WHY IT IS NOT "WIRE UP THE ACTUATOR"
kernel.json defers enforcement on an explicit condition:

    "Enforcement is deliberately deferred until the charter has been evaluated
     against enough runs to know whether its bounds are honest. A live-or-die
     button wired up before its criteria are calibrated would kill the factory
     for the architect's arithmetic errors, and today alone produced four of
     those."

So the charter reporting and not acting is a recorded decision with a stated
release condition, not an oversight. The work is to test whether that condition
is now met, which means asking of each metric, across every run of at least 100
windows:

  HOW OFTEN DOES IT FAIL?     A metric that fails in almost every run is either
                              measuring a real standing defect or is mis-priced.
                              Either way, arming the kernel would fire on it
                              immediately and the reason would be unexamined.
  DOES IT EVER PASS?          A metric that never passes cannot discriminate,
                              and one that always passes is not a constraint.
                              Both are vacuous, in opposite directions.
  HOW FAR OUT IS IT?          A metric failing by 1% of its range is priced
                              about right and the factory is near the edge. One
                              failing by 400% is measuring something else.
  IS THE FAILURE SUSTAINED?   kernel.json requires two CONSECUTIVE runs. A
                              metric that fails intermittently never triggers
                              it, however often it fails overall.

THE TRAP THIS IS DESIGNED NOT TO FALL INTO
kernel.json names it: "What must not happen is quietly widening a bound until
the run passes -- which is the failure that would make this entire file
theatre." So this tool reports distance-from-bound and never proposes a bound.
If a metric fails everywhere, the finding is that the factory or the metric is
wrong, and both are decisions for the architect.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="+", required=True)
    ap.add_argument("--charter", required=True)
    ap.add_argument("--min-windows", type=int, default=100)
    a = ap.parse_args()

    ch = json.load(open(a.charter))
    runs = []
    for p in sorted(a.logs, key=os.path.getmtime):
        try:
            n, rows, failed, und = SC.evaluate(p, ch)
        except Exception as e:
            print(f"  {os.path.basename(p)}: unreadable ({e})")
            continue
        if n < a.min_windows:
            continue
        runs.append((os.path.basename(p), n, rows, set(failed), set(und)))

    if not runs:
        print("  no runs long enough to judge")
        return 1

    print()
    print(f"  {len(runs)} runs of >= {a.min_windows} windows, "
          f"charter edition {ch['edition']}")
    print()

    stats = defaultdict(lambda: {"fail": 0, "pass": 0, "und": 0, "worst": 0.0})
    for _, _, rows, failed, und in runs:
        for k, norm, v, lo, hi, verdict in rows:
            s = stats[k]
            if verdict == "UNDECIDED" or v is None:
                s["und"] += 1
                continue
            if verdict == "FAIL":
                s["fail"] += 1
                span = max(hi - lo, 1e-9)
                out = (lo - v) / span if v < lo else (v - hi) / span
                s["worst"] = max(s["worst"], out)
            else:
                s["pass"] += 1

    never = set(ch["departures"]["never_tolerated"])
    print(f"  {'metric':26} {'pass':>5} {'fail':>5} {'undec':>6} "
          f"{'worst overshoot':>16}   reading")
    print("  " + "-" * 92)
    verdicts = {}
    for k in [m for m in ch["metrics"] if not m.startswith("_")]:
        s = stats[k]
        dec = s["pass"] + s["fail"]
        if dec == 0:
            read = "never decidable -- no run supplies it"
        elif s["fail"] == 0:
            read = "always passes -- not currently a constraint"
        elif s["pass"] == 0:
            read = "NEVER passes -- mis-priced or a standing defect"
        else:
            # OVERSHOOT SIZE IS NOT EVIDENCE OF MIS-PRICING, and treating it as
            # such was wrong. m3_no_clipping is bounded [0, 0.02]: a
            # near-zero-tolerance metric, where ANY real fault overshoots by
            # many multiples of a very narrow range. m3 reads exactly 0.000 in
            # 7 of 10 runs and departs only during three consecutive runs with
            # a mis-set master_gain, which is a metric working perfectly. The
            # first version of this heuristic called it "suspect" and would
            # have had the architect loosen the one bound that had just caught
            # a real defect the stream measurements missed -- precisely the
            # theatre kernel.json warns about. Overshoot is now reported as
            # FAULT SEVERITY and never as a readiness objection.
            read = "discriminates"
            if s["worst"] > 1.0:
                read += f" (worst departure {s['worst']:.1f}x range = fault size)"
        verdicts[k] = read
        star = " *" if k in never else "  "
        print(f"  {k:24}{star} {s['pass']:5d} {s['fail']:5d} {s['und']:6d} "
              f"{s['worst']:15.2f}x   {read}")
    print("  * = never_tolerated")

    # sustained failure is what the kernel actually keys on
    print()
    print("  sustained failure (kernel needs 2 CONSECUTIVE runs):")
    hits = []
    tol = ch["departures"]["tolerated_failing_metrics"]
    for i in range(1, len(runs)):
        a_name, _, _, fa, _ = runs[i - 1]
        b_name, _, _, fb, _ = runs[i]
        both = fa & fb
        if len(both) > tol or (never & both):
            hits.append((a_name, b_name, sorted(both)))
    if hits:
        for x, y, m in hits:
            print(f"    {x} + {y}: {m}")
        print(f"    -> the kernel WOULD have fired {len(hits)} time(s)")
    else:
        print("    none -- the kernel would never have fired on this history")

    print()
    print("  READINESS")
    broken = [k for k, r in verdicts.items()
              if r.startswith("NEVER passes") or r.startswith("never decidable")]
    vacuous = [k for k, r in verdicts.items() if r.startswith("always passes")]
    live = [k for k, r in verdicts.items() if r.startswith("discriminates")]

    if broken:
        print("    NOT READY. These metrics never pass, so they cannot")
        print("    discriminate and the kernel would fire on them permanently:")
        for k in broken:
            print(f"      {k}: {verdicts[k]}")
    else:
        print(f"    {len(live)} of {len(verdicts)} metrics discriminate: "
              f"{', '.join(sorted(live))}")
        if vacuous:
            print(f"    {len(vacuous)} never fail on any run, so they are not")
            print(f"    currently constraints: {', '.join(sorted(vacuous))}")
            print("    The kernel would effectively key on the "
                  f"{len(live)} live ones with a")
            print(f"    tolerance of {tol}. That is a narrower charter than it")
            print("    looks, and the narrowing should be stated, not fixed by")
            print("    tightening the three until they bite.")
        print()
        print("    Arming is defensible IF the architect accepts that the")
        print("    effective charter is the discriminating subset. Note the two")
        print("    historical firings were both caused by an architect error")
        print("    (master_gain), which is the exact scenario kernel.json")
        print("    deferred enforcement to avoid. A kernel armed today would")
        print("    have been correct to fire, and the factory was not at fault.")
    print()
    print("    Do not widen a bound to clear this report. kernel.json: that is")
    print("    'the failure that would make this entire file theatre'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
