#!/usr/bin/env python3
"""Recover the specs the writer lost, by reading the machines themselves.

Between 12:43 and 12:57 on 3 Sept the factory wrote nine machines and recorded
one. The other eight are on disk, complete, and their headers carry exactly the
three facts the record needed: the interpolated event duration, the layer that
duration put them in, and the SynthDef they call. Nothing has to be inferred.

This reads every br*.scd in the machines directory and writes the flat record
MachineWriter.loadSpecs now expects. Idempotent: re-running it produces the same
file. Machines the architect wrote are skipped -- they live in weights.json and
that file stays the architect's.

    python3 tools/backfill_written_specs.py --dir workdir_music/mutable [--write]
"""
import argparse
import glob
import os
import re
import sys

# "//   this   1.7052 s -> macro layer"
RE_DUR = re.compile(r"^//\s+this\s+([0-9.]+)\s*s\s*->\s*(\w+)\s+layer", re.M)
RE_INST = re.compile(r"\\instrument,\s*\\(\w+)")
# names the writer produces carry a run stamp: br + aa + bb + yymmddHHMM + xN
RE_STAMPED = re.compile(r"^br[a-z]{4}(\d{10})x\d+$")


def layer_of(d):
    """Geometric means of the three scales the policy names: 60 ms, 400 ms, 2 s.

    NOT the word in the machine's own header. That word was written by the old
    binary rule -- micro below 0.15 s, macro above, no mid at all -- and since
    no bridge ever landed below 0.46 s it said "macro" 156 times out of 156.
    Re-deriving from the duration is the whole point of the backfill.
    """
    return "micro" if d < 0.155 else ("mid" if d < 0.894 else "macro")


def parse(path):
    txt = open(path, errors="replace").read()
    name = os.path.splitext(os.path.basename(path))[0]
    md, mi = RE_DUR.search(txt), RE_INST.search(txt)
    if not md or not mi:
        return None
    ms = RE_STAMPED.match(name)
    dur = float(md.group(1))
    return {"name": name, "dur": md.group(1), "layer": layer_of(dur),
            "said": md.group(2), "inst": mi.group(1),
            "by": ms.group(1) if ms else "pre-stamp"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="workdir_music/mutable")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    mdir = os.path.join(a.dir, "machines")
    spec = os.path.join(a.dir, "written_machines.json")
    if not os.path.isdir(mdir):
        print(f"  no machines directory at {mdir}", file=sys.stderr)
        return 2

    rows, skipped = [], 0
    for p in sorted(glob.glob(os.path.join(mdir, "*.scd"))):
        r = parse(p)
        if r:
            rows.append(r)
        else:
            skipped += 1

    by_layer = {}
    by_inst = {}
    for r in rows:
        by_layer[r["layer"]] = by_layer.get(r["layer"], 0) + 1
        by_inst[r["inst"]] = by_inst.get(r["inst"], 0) + 1

    said = {}
    for r in rows:
        said[r["said"]] = said.get(r["said"], 0) + 1

    print()
    print(f"  {len(rows)} machines carry a readable header, {skipped} do not")
    print(f"  header said:  " + ", ".join(f"{k} {v}" for k, v in sorted(said.items())))
    print(f"  layer: " + ", ".join(f"{k} {v}" for k, v in sorted(by_layer.items())))
    print(f"  inst:  " + ", ".join(f"{k} {v}" for k, v in sorted(by_inst.items())))
    if os.path.exists(spec):
        n = sum(1 for l in open(spec) if "|dur" in l or '": {' in l)
        print(f"  currently recorded: {n}")

    if not a.write:
        print("\n  --write to record them")
        return 0

    parts = []
    for r in sorted(rows, key=lambda x: x["name"]):
        for f in ("dur", "layer", "inst", "by"):
            parts.append(f'  "{r["name"]}|{f}": "{r[f]}"')
    with open(spec, "w") as fh:
        fh.write("{\n" + ",\n".join(parts) + "\n}\n")
    print(f"\n  wrote {len(rows)} specs to {spec}")
    print("  the factory now knows the layer of every machine it has written;")
    print("  layerOf will stop calling its macro work micro.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
