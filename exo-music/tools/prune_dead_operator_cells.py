#!/usr/bin/env python3
"""Move the operator's dead cells out of the live matrix, and keep them.

WHY THIS EXISTS
18 Sept 2026. The transfer operator in mutable/memory.json held 217 cells: 27
suffixed `@slow`, which the running factory observes, and 190 bare, which it
has not touched since the 15 Sept state-space change and never will again
(sampled live over 2m47s: 8 cells gained counts, all 8 `@slow`, zero bare).
The dead cells were 28,079 of 46,222 counts -- 61% of the operator's mass --
and sat in the matrix as a second closed class, pinning lambda2 at exactly 1.

    whole operator    n=217  gap 0.0000
    live only         n=27   gap 0.6124
    dead only         n=190  gap 0.3265

The operator STEERS selection at operator_weight 0.35, so this is a change to
the factory's behaviour and not only to a measurement. It is done once, by
hand, between comparisons, with the factory stopped. The half-life wired the
same day is so the next such change needs no hand.

WHAT IT REFUSES TO DO
  - run while the factory is up. memory.json is rewritten by the running
    factory; editing it underneath is a race and, inside a comparison, a second
    change.
  - delete anything. Dead cells move to `operator_archive_pre_20260915` in the
    same file. Nothing is lost; the live matrix stops describing a state space
    the factory left.
  - write without --apply. The default is a report.

    python3 tools/prune_dead_operator_cells.py            # report only
    python3 tools/prune_dead_operator_cells.py --apply    # do it, with a backup
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
MEM = os.path.join(EM, "workdir_music", "mutable", "memory.json")
ARCHIVE_KEY = "operator_archive_pre_20260915"


def is_dead(cell):
    """A cell with no '@' is from before operator_sees_macro appended one."""
    return "@" not in str(cell)


def spectrum(op, cells):
    cells = sorted(cells, key=str)
    idx = {c: i for i, c in enumerate(cells)}
    n = len(cells)
    if n < 3:
        return float("nan"), float("nan")
    M = np.full((n, n), 1.0 / n)
    for c in cells:
        r = np.zeros(n); tot = 0.0
        for b, v in op.get(c, {}).items():
            if b in idx:
                r[idx[b]] = v; tot += v
        if tot > 0:
            M[idx[c]] = r / tot
    ev = np.sort(np.abs(np.linalg.eigvals(M.T)))[::-1]
    return float(ev[1]), max(0.0, float(1.0 - ev[1]))   # clamp -0.0


def factory_running():
    return subprocess.run(["pgrep", "-f", "_live.scd"],
                          capture_output=True).returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--mem", default=MEM)
    a = ap.parse_args()

    if factory_running():
        print("  REFUSED: the factory is running and rewrites memory.json.")
        print("  Stop it first (sh tools/stop_factory.sh). This is a change to")
        print("  what the operator steers, and it is not made under a live run.")
        return 2

    d = json.load(open(a.mem))
    op = d.get("operator") or {}
    if ARCHIVE_KEY in d and not a.apply:
        print(f"  note: {ARCHIVE_KEY} already exists with "
              f"{len(d[ARCHIVE_KEY])} cells; a second apply would merge into it")

    dead = {c for c in op if is_dead(c)}
    live = {c for c in op if not is_dead(c)}
    # columns: does any LIVE row point INTO a dead cell? (verified zero on
    # 17 Sept, but measured here rather than remembered)
    cross = sum(v for c in live for b, v in op[c].items() if is_dead(b))
    dead_mass = sum(sum(r.values()) for c, r in op.items() if c in dead)
    live_mass = sum(sum(r.values()) for c, r in op.items() if c in live)

    print(f"\n  {os.path.relpath(a.mem, EM)}")
    print(f"  cells   live {len(live):>4}   dead {len(dead):>4}")
    print(f"  counts  live {live_mass:>9,.0f}   dead {dead_mass:>9,.0f}   "
          f"dead share {100*dead_mass/max(1,dead_mass+live_mass):.0f}%")
    print(f"  live->dead transitions: {cross:,.0f}  "
          f"({'none, the classes are sealed' if cross == 0 else 'NONZERO -- read this before applying'})")

    l2w, gw = spectrum(op, op.keys())
    l2l, gl = spectrum(op, live)
    print(f"\n  gap  whole {gw:.4f} (|l2| {l2w:.4f})   live-only {gl:.4f} (|l2| {l2l:.4f})")

    if not dead:
        print("\n  nothing to prune")
        return 0
    if not a.apply:
        print("\n  DRY RUN. Re-run with --apply to move the dead cells to "
              f"'{ARCHIVE_KEY}'.")
        return 0

    # ---- apply -------------------------------------------------------------
    stamp = time.strftime("%y%m%d_%H%M%S")
    bak = a.mem + f".bak_prune_{stamp}"
    shutil.copy2(a.mem, bak)

    archive = d.get(ARCHIVE_KEY) or {}
    for c in dead:
        archive[c] = op.pop(c)
    # and strip dead COLUMNS from live rows, if any
    stripped = 0
    for c in live:
        for b in [b for b in op[c] if is_dead(b)]:
            stripped += 1
            archive.setdefault(c, {})[b] = op[c].pop(b)
    d["operator"] = op
    d[ARCHIVE_KEY] = archive
    d.setdefault("_prune_log", []).append({
        "when": stamp, "moved_cells": len(dead), "moved_counts": dead_mass,
        "stripped_dead_columns_from_live_rows": stripped,
        "gap_before": gw, "gap_after": gl,
        "why": "dead pre-15-Sept state space pinned lambda2 at 1; see "
               ".lab/measurements/2026-09-18_the_operator_carries_a_dead_state_space.md"})

    tmp = a.mem + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(d, fh, indent=1)
    os.replace(tmp, a.mem)

    # verify by re-reading what was written
    chk = json.load(open(a.mem))
    op2 = chk["operator"]
    l2a, ga = spectrum(op2, op2.keys())
    print(f"\n  APPLIED. backup: {os.path.basename(bak)}")
    print(f"  live operator now {len(op2)} cells, gap {ga:.4f} (|l2| {l2a:.4f})")
    print(f"  archive holds {len(chk[ARCHIVE_KEY])} cells")
    if abs(ga - gl) > 1e-6:
        print("  WARNING: re-read gap differs from predicted live-only gap")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
