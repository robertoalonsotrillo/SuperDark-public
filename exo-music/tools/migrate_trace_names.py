#!/usr/bin/env python3
"""Strip the operator's "@bucket" suffix from the trace's machine names.

WHY THIS IS NEEDED, AND WHY IT IS URGENT
`attend()` in live_factory.scd builds its recall dictionary keyed by
`trace[i][\\machine]`, and the caller looks those keys up in `avail`, which holds
plain machine names:

    vec = avail.collect({ |m| rec[m] ? 0 });
    if (vec.sum <= 0) { brk.value };

When `operator_sees_macro` is 1 the trace's machine field carried the operator's
composite symbol, `sc@slow` and the like. `avail` never contains such a name, so
every lookup returned 0, the sum was 0, and the block took its escape.

**Attention was a guaranteed no-op.** Raising `attention_weight` would have
changed nothing, silently, and the honest-looking conclusion would have been
"attention has no effect on the factory". It is the fourth mechanism in this
project found built and inert, after self_ingest_weight going unread,
PatternGrammar sitting unwired, and the ingest daemon watching an empty
directory.

The live factory stopped writing suffixed names on 15 Sept (currentMachine is
now taken before the suffix). This migrates the HISTORY, 6,570 of 8,000 entries
at the time of writing. Without it, attention could match only entries written
after the fix, and the trace is capped at 8,000, so it would take about a day of
running to flush.

WHAT IT TOUCHES AND WHAT IT DOES NOT
Only `trace[*]["m"]`. Not sections, not their family lists (already clean), not
transitions, not the operator's own dictionary. The operator observed the
composite symbol through `op.observe` on a separate path, and that record is
untouched, so the widened alphabet keeps its meaning.

RUN IT WITH THE FACTORY STOPPED. A running factory holds the trace in memory and
will overwrite this file at its next save.

    python3 tools/migrate_trace_names.py --dry-run
    python3 tools/migrate_trace_names.py --apply
"""
import argparse
import collections
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
MEM = os.path.join(EM, "workdir_music", "mutable", "memory.json")


def factory_running():
    return subprocess.run(["pgrep", "-f", "_live.scd"],
                          capture_output=True).returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--memory", default=MEM)
    args = ap.parse_args()
    if not (args.apply or args.dry_run):
        ap.error("pass --dry-run or --apply")

    if args.apply and factory_running():
        print("REFUSED: the factory is running and holds the trace in memory.")
        print("It would overwrite this file at its next save. Stop it first.")
        return 2

    with open(args.memory) as fh:
        d = json.load(fh)

    trace = d.get("trace", [])
    suffixed = [e for e in trace if "@" in str(e.get("m", ""))]
    buckets = collections.Counter(
        str(e["m"]).split("@", 1)[1] for e in suffixed)

    print(f"trace entries      {len(trace)}")
    print(f"with '@'           {len(suffixed)} "
          f"({100 * len(suffixed) / max(len(trace), 1):.1f}%)")
    print(f"buckets seen       {dict(buckets)}")
    if suffixed:
        before = str(suffixed[0]["m"])
        print(f"example            {before}  ->  {before.split('@', 1)[0]}")

    distinct_after = len({str(e.get("m", "")).split("@", 1)[0] for e in trace})
    print(f"distinct names     {len({str(e.get('m','')) for e in trace})} "
          f"-> {distinct_after} after stripping")

    if not args.apply:
        print("\ndry run; nothing written")
        return 0

    bak = args.memory + ".before_trace_migration_" + time.strftime("%y%m%d_%H%M%S")
    shutil.copy2(args.memory, bak)
    print(f"\nkept the original at {os.path.basename(bak)}")

    for e in trace:
        m = str(e.get("m", ""))
        if "@" in m:
            e["m"] = m.split("@", 1)[0]

    tmp = args.memory + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(d, fh)
    os.replace(tmp, args.memory)

    with open(args.memory) as fh:
        check = json.load(fh)
    left = sum(1 for e in check.get("trace", []) if "@" in str(e.get("m", "")))
    print(f"rewrote {args.memory}")
    print(f"remaining '@' in trace machine names: {left}")
    return 0 if left == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
