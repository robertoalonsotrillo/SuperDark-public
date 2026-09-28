#!/usr/bin/env python3
"""Put descriptors.json back into the order the factory reads it in.

THE DEFECT, 25 Aug 2026
-----------------------
Four places decide which descriptor belongs to which grain. Three agree and one
does not:

    build_grains_onset.py:182   writes g{made:02d}.wav        NUMERIC
    manifest.json               i == position, verified       NUMERIC
    live_factory.scd:663        loads  g{i:02d}.wav           NUMERIC
    analyse_mfcc.py:137         sorted(os.listdir(dir))       LEXICOGRAPHIC

The padding is two wide, so `g10.wav` is followed lexicographically by
`g100.wav`. The orders diverge at position 11 and never recover:

    buffer   5  ->  g05.wav     descriptor slot    5     correct by luck
    buffer  11  ->  g11.wav     descriptor slot  121     reads g100's row
    buffer  50  ->  g50.wav     descriptor slot 1850     reads another grain's
    buffer 101  ->  g101.wav    descriptor slot   22     reads another grain's

2,389 of 2,400 grains carried another grain's descriptors, so every
nearest-neighbour lookup in descriptor space ran on a permutation. It raised no
error, because a permuted array is still an array of plausible numbers. This is
the same failure class as the five inherited constants and the 24 kHz transport:
wrong input, no complaint, output that looks like data.

WHAT THIS DOES NOT NEED TO DO
-----------------------------
Re-analyse. The rows are correct; only their order is wrong. A permutation is
exact and takes seconds, where re-running the MFCC pass takes an hour and would
introduce a second opportunity to get this wrong.

`pitch` and `clarity` are a separate case and are handled separately below. They
were carried into descriptors.json from descriptors_pre_mfcc.json, which was
written by build_grains_onset.py in NUMERIC order. Reordering them with the pc
columns would break what is currently correct, so they must be left alone.

    python3 tools/fix_descriptor_order.py --dir workdir_music/grains_ev
    python3 tools/fix_descriptor_order.py --dir workdir_music/grains_ev --apply
"""
import argparse
import json
import os
import re
import shutil
import sys


PC = re.compile(r"^pc\d+$")
CARRIED = ("pitch", "clarity")      # already numeric; must NOT be permuted


def numeric_key(fname):
    m = re.match(r"g(\d+)\.wav$", fname)
    if not m:
        raise SystemExit(f"ABORT: unexpected grain name {fname!r}")
    return int(m.group(1))


def build_permutation(grain_dir):
    """perm[i] = lexicographic slot holding the descriptors for grain number i."""
    files = [f for f in os.listdir(grain_dir) if f.endswith(".wav")]
    lex = sorted(files)
    slot = {f: j for j, f in enumerate(lex)}
    by_number = sorted(files, key=numeric_key)
    # grains must be 0..n-1 with no gaps, or "buffer i" has no meaning at all
    nums = [numeric_key(f) for f in by_number]
    if nums != list(range(len(nums))):
        raise SystemExit(
            f"ABORT: grain numbers are not 0..{len(nums)-1} without gaps.\n"
            f"  first few: {nums[:8]}  last few: {nums[-4:]}"
        )
    return [slot[f] for f in by_number], lex, by_number


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    p.add_argument("--apply", action="store_true",
                   help="write the file; without this it only reports")
    a = p.parse_args()

    path = os.path.join(a.dir, "descriptors.json")
    d = json.load(open(path))

    # APPLYING THIS TWICE WOULD RE-SCRAMBLE THE FILE.
    # The permutation is derived from the filenames, which do not change, so a
    # second run would happily permute an already-correct array and report
    # success. The dry run's "out of place" count is likewise a property of the
    # names and reads the same before and after, which is exactly the kind of
    # reassuring-but-meaningless number this project keeps being caught by.
    # The marker below is the only thing that distinguishes the two states.
    if "_order" in d:
        print(f"  ALREADY FIXED. {os.path.basename(path)} carries _order:")
        print(f"    {d['_order'][:110]}...")
        print("\n  Refusing to run again; a second permutation would undo it.")
        print(f"  To start over, restore {os.path.basename(path)}.lexicographic.bak")
        return

    perm, lex, by_number = build_permutation(a.dir)
    n = len(perm)

    norm = d.get("norm", {})
    pc_keys = [k for k in norm if PC.match(k)]
    if not pc_keys:
        raise SystemExit(f"ABORT: {path} has no pc columns to reorder.")

    wrong = sum(1 for i, j in enumerate(perm) if i != j)
    print(f"  grains                {n}")
    print(f"  pc columns            {sorted(pc_keys)}")
    print(f"  carried, left alone   {[k for k in CARRIED if k in norm]}")
    print(f"  slots out of place    {wrong} of {n}  ({wrong/n:.1%})")
    print(f"  first divergence      grain {next((i for i,j in enumerate(perm) if i!=j), None)}")
    print()
    for i in (5, 11, 50, 101):
        if i < n:
            print(f"    grain {i:<5} {by_number[i]:<12} descriptors currently at slot {perm[i]}")

    for k in pc_keys:
        if len(norm[k]) != n:
            raise SystemExit(
                f"ABORT: norm['{k}'] has {len(norm[k])} entries, {n} grains.\n"
                "  Refusing to permute arrays of the wrong length."
            )

    if not a.apply:
        print("\n  dry run. Re-run with --apply to write.")
        return

    backup = path + ".lexicographic.bak"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"\n  backup -> {os.path.basename(backup)}")

    for k in pc_keys:
        col = norm[k]
        norm[k] = [col[perm[i]] for i in range(n)]

    d["_order"] = ("numeric: entry i belongs to g{i}.wav, matching "
                   "live_factory.scd:663, manifest.json and "
                   "build_grains_onset.py. Reordered 25 Aug 2026 from the "
                   "lexicographic order analyse_mfcc.py wrote, under which "
                   f"{wrong} of {n} grains carried another grain's descriptors. "
                   "pitch and clarity were already numeric and were NOT touched.")
    json.dump(d, open(path, "w"))
    print(f"  written. {wrong} rows moved.")


if __name__ == "__main__":
    main()
