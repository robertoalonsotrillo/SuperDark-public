#!/usr/bin/env python3
"""The kernel's actuator. DRY RUN BY DEFAULT: it decides, and does not act.

WHAT THIS IS
kernel.json declares a scrapping condition and then records that nothing
invokes it:

    "As of edition 1 nothing invokes this. score_charter.py REPORTS scrapping
     conditions; it does not act on them. Enforcement is deliberately deferred
     until the charter has been evaluated against enough runs to know whether
     its bounds are honest."

That evaluation has now been done (charter_honesty.py, charter_headroom.py, ten
runs of >= 100 windows). Seven of eight metrics are live; one, m6_texture, is
decorative because policy.json's voices_min..voices_max already sits inside its
bound. The kernel would have fired twice in the recorded history, both times on
a mis-set master_gain, and both times CORRECTLY: m3 read 0.205 against a bound
of 0.02 and the charter calls clipping "not an aesthetic departure, it is a
broken transport".

That last point deserves stating plainly, because kernel.json's deferral treats
it as the danger to avoid: a kernel firing on an ARCHITECT's error is not a
false positive. The factory was clipping. It should have stopped. A kernel that
fires only on the factory's own errors would assume the architect cannot be
wrong, which is a strange assumption for the party that moves first (P285).

DRY RUN IS THE POINT OF THIS VERSION
It journals what it WOULD have done and touches nothing. That gives a record of
the button's judgement before the button has power, which is the same reason
the charter was scored against history before being armed. --arm is required to
make it act, and even then what it does is bounded: it stops the factory and
writes a record. It never deletes, never edits the charter, never widens a
bound. P458: nothing here may be unrecoverable, and a stopped factory restarts
with a shell command.

WHAT IT KEYS ON
kernel.json: "Three or more charter metrics failing, or any never_tolerated
metric failing, sustained across two consecutive runs of at least 100 windows."
Two runs and not one, because "the 24 Aug ablation lost two runs to a squatted
UDP port and one to a starved buffer load, none of which was the factory's
doing. A single-run trigger would have scrapped a healthy factory three times
in one day."

  python3 kernel_guard.py                 # dry run, one pass
  python3 kernel_guard.py --watch 300     # dry run, every 5 minutes
  python3 kernel_guard.py --watch 300 --arm
"""
import argparse
import json
import glob
import os
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(ROOT, "workdir_music")


def completed_runs(min_windows):
    """Each live log is one run. Returns [(name, n, failed_set)] oldest first."""
    out = []
    ch = json.load(open(os.path.join(W, "mutable", "charter.json")))
    for p in sorted(glob.glob(os.path.join(W, "renders", "live_*.log")),
                    key=os.path.getmtime):
        try:
            n, rows, failed, und = SC.evaluate(p, ch)
        except Exception:
            continue
        if n < min_windows:
            continue
        out.append((os.path.basename(p), n, set(failed)))
    return out, ch


def decide(runs, ch, kern):
    """Would the kernel fire? Returns (fire, reason, detail)."""
    tol = ch["departures"]["tolerated_failing_metrics"]
    never = set(ch["departures"]["never_tolerated"])
    if len(runs) < 2:
        return False, "fewer than two runs of sufficient length", {}
    (na, _, fa), (nb, _, fb) = runs[-2], runs[-1]
    both = fa & fb
    hit_never = never & both
    if len(both) > tol or hit_never:
        why = []
        if hit_never:
            why.append(f"never-tolerated {sorted(hit_never)}")
        if len(both) > tol:
            why.append(f"{len(both)} metrics failing in both (tolerance {tol})")
        return True, "; ".join(why), {"runs": [na, nb], "sustained": sorted(both)}
    return False, (f"sustained failures {sorted(both) or 'none'} within tolerance "
                   f"{tol}"), {"runs": [na, nb], "sustained": sorted(both)}


def stop_factory():
    """Stop, do not destroy. P458: a hard world makes irreversible harm
    impossible, not all harm. The corpus, the pool and every log survive; the
    factory restarts with one command."""
    killed = []
    for pat in ("caffeinate", "MacOS/sclang"):
        for line in os.popen(f"pgrep -f '{pat}'").read().split():
            try:
                os.kill(int(line), signal.SIGTERM)
                killed.append(int(line))
            except (ProcessLookupError, ValueError, PermissionError):
                pass
    return killed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arm", action="store_true",
                    help="actually stop the factory; default is dry run")
    ap.add_argument("--watch", type=int, default=0, help="seconds between passes")
    ap.add_argument("--min-windows", type=int, default=100)
    ap.add_argument("--journal", default=os.path.join(W, "mutable", "kernel_journal.jsonl"))
    a = ap.parse_args()

    kern = json.load(open(os.path.join(W, "mutable", "kernel.json")))
    mode = "ARMED" if a.arm else "DRY RUN"
    print(f"  kernel guard, edition {kern['edition']}, {mode}")
    if not a.arm:
        print("  it will decide and journal. It will not stop anything.")

    while True:
        runs, ch = completed_runs(a.min_windows)
        fire, why, detail = decide(runs, ch, kern)
        rec = {"t": time.time(), "iso": time.strftime("%Y-%m-%dT%H:%M:%S"),
               "armed": bool(a.arm), "would_fire": bool(fire), "why": why,
               "charter_edition": ch["edition"], "kernel_edition": kern["edition"],
               "runs_considered": len(runs), **detail}
        acted = None
        if fire and a.arm:
            acted = stop_factory()
            rec["action"] = "factory stopped"
            rec["killed_pids"] = acted
        elif fire:
            rec["action"] = "none (dry run)"
        with open(a.journal, "a") as f:
            f.write(json.dumps(rec) + "\n")

        stamp = time.strftime("%H:%M:%S")
        if fire:
            print(f"  {stamp}  SCRAPPING CONDITION: {why}")
            print(f"            runs {detail.get('runs')}  "
                  f"sustained {detail.get('sustained')}")
            if a.arm:
                print(f"            FACTORY STOPPED (pids {acted}). This charter")
                print("            edition is declared unsatisfiable by this factory.")
                print("            Re-price it as a NEW EDITION or rebuild. Do not")
                print("            widen a bound to make this go away.")
                return 2
            print("            dry run: nothing stopped.")
        else:
            print(f"  {stamp}  ok -- {why}")

        if not a.watch:
            return 0
        time.sleep(a.watch)


if __name__ == "__main__":
    sys.exit(main())
