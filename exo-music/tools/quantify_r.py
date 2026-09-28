#!/usr/bin/env python3
"""How much behaviour has the factory actually written into itself? r, in bytes.

THE GAP THIS CLOSES. The comparison figure says of r -- acquisition outrunning
reconstitution -- "bytes written to its own behaviour. implemented; MAGNITUDE NOT
QUANTIFIED". That has been true since August and it is the one row where the
missing number is trivially obtainable: the factory logs an ACQUIRED line every
time it writes, and the files are on disk.

WHY THE FILES ON DISK UNDERSTATE IT. Until 3 Sept the machine name was
"br" ++ a ++ b ++ written, where `written` restarts at 0 every run. Run N and
run N+1 therefore produced the same names, and the later run silently overwrote
the earlier: measured on the 8 h run of 3 Sept, ALL SIXTEEN machines written
that night landed on names already loaded at boot. So counting files answers
"how many survive", not "how much was written".

The ACQUIRED lines answer the second question, because they were emitted at the
moment of writing and no later run can overwrite a log entry.

WHAT r IS AND IS NOT. This measures the factory's authored behaviour in bytes
and in count -- the numerator of P75's r. It does NOT measure reconstitution,
which is the denominator, and without that denominator this is a magnitude and
not a ratio. Anyone quoting it as "r" without saying so is overclaiming. What it
does settle is the figure's own complaint: the magnitude is no longer unknown.

    python3 tools/quantify_r.py
"""
import argparse
import collections
import glob
import json
import os
import re
import sys

RENDERS = "/Volumes/FMA/superdark/renders"
HERE = os.path.dirname(os.path.abspath(__file__))
MACH = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable", "machines")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--renders", default=RENDERS)
    ap.add_argument("--machines", default=MACH)
    a = ap.parse_args()

    # every write the factory ever logged, across every run on disk
    writes = []          # (run, window, name, a, b, dur, layer)
    per_run = collections.Counter()
    for p in sorted(glob.glob(os.path.join(a.renders, "*.log"))):
        run = os.path.basename(p)
        for line in open(p, errors="replace"):
            if line.startswith("ACQUIRED"):
                f = line.split()[1].split(",")
                if len(f) >= 6:
                    writes.append((run, int(f[0]), f[1], f[2], f[3], f[4], f[5]))
                    per_run[run] += 1

    if not writes:
        print("  no ACQUIRED lines found (SSD unmounted?)", file=sys.stderr)
        return 2

    # what survives on disk, and how big it is
    files = glob.glob(os.path.join(a.machines, "br*.scd"))
    disk_bytes = sum(os.path.getsize(f) for f in files)
    median = sorted(os.path.getsize(f) for f in files)[len(files) // 2] if files else 0

    names = [w[2] for w in writes]
    distinct_names = set(names)
    # a transition pair, which is what a bridge actually is
    pairs = set((w[3], w[4]) for w in writes)

    print()
    print("  WRITES, from ACQUIRED lines -- a log entry cannot be overwritten")
    print(f"    total writes logged         {len(writes)}")
    print(f"    across runs                 {len(per_run)}")
    print(f"    distinct NAMES emitted      {len(distinct_names)}")
    print(f"    distinct TRANSITION PAIRS   {len(pairs)}")
    print(f"    name collisions             {len(writes) - len(distinct_names)}"
          f"  ({100*(len(writes)-len(distinct_names))/len(writes):.0f}% of writes"
          f" reused a name)")
    print()
    print("  ON DISK NOW")
    print(f"    files surviving             {len(files)}")
    print(f"    bytes                       {disk_bytes:,}")
    print(f"    median machine              {median:,} bytes")
    print()
    est = len(writes) * median
    print("  MAGNITUDE OF AUTHORED BEHAVIOUR")
    print(f"    written, estimated          {est:,} bytes"
          f"  ({len(writes)} writes x {median:,} median)")
    print(f"    of which survives on disk   {disk_bytes:,} bytes"
          f"  ({100*disk_bytes/max(1,est):.0f}%)")
    print(f"    lost to name collision      {est - disk_bytes:,} bytes")
    print()
    print("  BY RUN, the ten largest")
    for run, n in per_run.most_common(10):
        print(f"    {run[:34]:34} {n:4d} writes")
    print()
    print("  WHAT THIS IS NOT")
    print("    A ratio. r is acquisition over RECONSTITUTION, and the denominator")
    print("    is not measured here -- the architect's own edits to the factory's")
    print("    behaviour would have to be counted the same way. This is the")
    print("    numerator, in bytes, and the figure's complaint was that even that")
    print("    was unknown.")
    print()
    print("    Byte count is also a weak proxy for behaviour: 16 machines written")
    print("    on 3 Sept produced 2 new BEHAVIOURS, the rest collapsing onto")
    print("    bridges that already existed. Bytes measure authorship, not")
    print("    variety, and the two have been shown to diverge by a factor of 8.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
