#!/usr/bin/env python3
"""Fire the kernel, offline, on synthetic runs. Does the constitutional core work?

WHY THIS EXISTS. kernel.json has been armed since 1 Sept and has never fired. An
armed guard that has never acted is untested: we do not know whether the
condition can be reached, whether decide() agrees with score_charter about what
is failing, or whether the thing would stop the right process. Arming something
and never exercising it is how a safety mechanism becomes decoration -- which is
the fault this project has already found in m6 and m7.

WHAT IT DOES. It manufactures two runs that genuinely violate the charter,
scores them with the REAL scorer against the REAL charter, and puts the result
through the REAL decide(). Nothing is stubbed except the last step: the factory
is not stopped, because the point is to test the decision, not to lose a run.

WHAT IT DELIBERATELY DOES NOT DO. It does not touch the live factory, the live
logs, or kernel.json. It writes synthetic logs to /tmp and reads the charter
read-only. A rehearsal that could take the factory down would be a worse thing
than the untested guard it is meant to check.

    python3 tools/rehearse_kernel.py
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC                                    # noqa: E402
import kernel_guard as KG                                     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")


def synth_log(path, n=140, healthy=True):
    """A window log that either satisfies the charter or violates it plainly.

    The unhealthy variant is not subtle: near-silent, clipping, one machine
    only, centroid far out of band. A kernel that will not fire on this would
    not fire on anything.
    """
    with open(path, "w") as f:
        for w in range(1, n + 1):
            if healthy:
                peak, clip = 0.06, 0.0
                cent, live = 1200.0, 4
                mach = f"m{w % 22}"
                lam = 0.20 + (w % 7) * 0.01
            else:
                peak, clip = 0.0005, 0.35      # silent AND clipping
                cent, live = 60.0, 1           # far below the band, one voice
                mach = "stuck"                 # no vocabulary at all
                lam = 0.20
            f.write(f"{w*11.7:.2f},{w},{mach},runtime,0.5,{cent},0.003,16,"
                    f"{live},{live},{live},0.5,14,"
                    f"0.2|0.3|0.4|0.5|0.6|0.7,571,11\n")
            f.write(f"OPERATOR {w},{1-lam:.4f},{lam:.4f},120,{mach},9000\n")
            f.write(f"MASTER {w},{peak},{clip}\n")


def main():
    argparse.ArgumentParser().parse_args()
    ch = json.load(open(os.path.join(MUT, "charter.json")))
    kern = json.load(open(os.path.join(MUT, "kernel.json")))
    tol = ch["departures"]["tolerated_failing_metrics"]
    never = ch["departures"]["never_tolerated"]

    print()
    print(f"  charter edition {ch['edition']}, kernel edition {kern['edition']}, "
          f"armed={kern.get('armed')}")
    print(f"  tolerance {tol} failing metrics; never tolerated: {never}")
    print()

    cases = [
        ("two HEALTHY runs", [True, True]),
        ("one bad, one healthy", [False, True]),
        ("two BAD runs", [False, False]),
    ]
    for name, states in cases:
        runs = []
        for i, ok in enumerate(states):
            p = f"/tmp/rehearse_{i}.log"
            synth_log(p, healthy=ok)
            n, rows, failed, und = SC.evaluate(p, ch)
            runs.append((n, p, set(failed)))
        fire, reason, detail = KG.decide(runs, ch, kern)
        marks = "/".join("healthy" if s else "BAD" for s in states)
        print(f"  {name:24} [{marks}]")
        for n, p, f in runs:
            print(f"      {n:4d} windows, failing: {sorted(f) or 'none'}")
        print(f"      -> kernel fires: {'YES' if fire else 'no'}   ({reason})")
        print()

    print("  WHAT A FIRING WOULD DO, from kernel.json:")
    print(f"    {kern.get('_what_arming_does', '')[:300]}")
    print()
    print("  The factory was NOT stopped. This exercised decide() against the")
    print("  real charter on manufactured evidence; the last step is the only")
    print("  one not rehearsed, and it is a SIGTERM to caffeinate and sclang.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
