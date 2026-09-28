#!/usr/bin/env python3
"""Where does the attractor live: selection or supply?

Reads one window log plus workdir_music/mutable/{weights,written_machines,
memory}.json and the machines/ directory, and answers, per layer, how much of
the machine SUPPLY the run actually sounded. Also builds the micro transition
matrix, tallies ACQUIRED/ACQFAIL, and decomposes renders/vocabulary.json
("machines ever invented" on the panel) into what it actually counts.

Usage:
    python3 tools/the_attractor.py [LOG] [--mutable DIR] [--vocab vocabulary.json]

Defaults to the 19 Sept ten-arm log. Output is plain text; the numbers in
.lab/measurements/2026-09-20_the_attractor.md come from this script.

Log line formats it depends on (from live_factory.scd):
    <t>,<win>,<micro machine>,runtime|class,<amp>,<cent>,<flat>,<avail.size>,<reloads>,...
    SLOTS <win>,<macro>,<mid>,<micro>
    ACQUIRED <win>,<name>,<a>,<b>,<dur>,<layer>
    ACQFAIL <win>,<reason>
"""
import argparse, collections, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_LOG = "/Volumes/FMA/superdark/renders/live_260919_141610.log"
DEFAULT_MUT = os.path.join(ROOT, "workdir_music", "mutable")
DEFAULT_VOCAB = "/Volumes/FMA/superdark/renders/vocabulary.json"

BASE = {"sc", "lu", "so", "ma", "cr", "te", "ry", "an", "hp", "st",
        "ht", "gl", "cp", "wa", "gp", "bu", "dr", "pu", "hm", "me"}


def entropy(counter):
    n = sum(counter.values())
    return -sum(v / n * math.log2(v / n) for v in counter.values() if v)


def supply(mut):
    """Every machine the factory can select, with its layer, by source."""
    w = json.load(open(os.path.join(mut, "weights.json")))["machines"]
    wm = json.load(open(os.path.join(mut, "written_machines.json")))
    on_disk = {f[:-4] for f in os.listdir(os.path.join(mut, "machines"))
               if f.endswith(".scd")}
    layer, kind = {}, {}
    for k, v in w.items():
        layer[k] = v["layer"]; kind[k] = "class"
    for n in {k.split("|")[0] for k in wm}:
        layer[n] = wm[n + "|layer"]; kind[n] = "bridge(written)"
    for n in on_disk:
        if n not in layer:
            layer[n] = "micro"; kind[n] = "runtime(hand-written, no spec)"
    return layer, kind, on_disk


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", nargs="?", default=DEFAULT_LOG)
    ap.add_argument("--mutable", default=DEFAULT_MUT)
    ap.add_argument("--vocab", default=DEFAULT_VOCAB)
    a = ap.parse_args()

    layer, kind, on_disk = supply(a.mutable)
    by_layer = collections.defaultdict(set)
    for n, l in layer.items():
        by_layer[l].add(n)
    print("SUPPLY (weights.json + written_machines.json + machines/*.scd)")
    for l in ("micro", "mid", "macro"):
        s = by_layer[l]
        print(f"  {l:5s} {len(s):3d}  classes {sum(kind[n]=='class' for n in s):2d}"
              f"  bridges {sum(n.startswith('br') for n in s):3d}"
              f"  hand-written runtime {sum(kind[n].startswith('runtime') for n in s)}")
    print(f"  total {len(layer)}   (on disk as .scd: {len(on_disk)})")

    ev, slots, acq, fail = [], {}, [], collections.Counter()
    for line in open(a.log):
        if line[:1].isdigit():
            ev.append(line.strip().split(","))
        elif line.startswith("SLOTS "):
            f = line.strip().split(" ", 1)[1].split(",")
            slots[int(f[0])] = f[1:]
        elif line.startswith("ACQUIRED "):
            acq.append(line.strip())
        elif line.startswith("ACQFAIL "):
            fail[line.strip().split(",", 1)[1].split(":")[0]] += 1
    print(f"\nLOG {a.log}\n  windows {len(ev)}")

    # --- used vs supply, per layer -----------------------------------------
    used = {"macro": collections.Counter(), "mid": collections.Counter(),
            "micro": collections.Counter()}
    first = {}
    for w, (mac, mid, mic) in slots.items():
        for l, m in (("macro", mac), ("mid", mid), ("micro", mic)):
            used[l][m] += 1
            first.setdefault((l, m), w)
    print("\nUSED vs SUPPLY")
    for l in ("micro", "mid", "macro"):
        s, u = by_layer[l], set(used[l])
        last_first = max(first[(l, m)] for m in u)
        print(f"  {l:5s} supply {len(s):3d} used {len(u):3d}  never sounded: {sorted(s-u) or 'none'}"
              f"  used-but-not-in-supply: {sorted(u-s) or 'none'}"
              f"  last first-appearance: window {last_first}")

    # --- the micro vocabulary ----------------------------------------------
    mic = collections.Counter(e[2] for e in ev)
    print(f"\nMICRO SLOT: {len(mic)} names, entropy {entropy(mic):.2f} bits"
          f" (uniform over {len(mic)} = {math.log2(len(mic)):.2f})")
    print("  name                                  n   kind      layer  first-window")
    for m, n in mic.most_common():
        e0 = next(e for e in ev if e[2] == m)
        print(f"  {m:36s} {n:4d}  {e0[3]:8s}  {layer.get(m,'?'):5s}  {e0[1]}")

    # per arm (reloads field increments once per arm boundary in the harness)
    arms = collections.defaultdict(list)
    for e in ev:
        arms[int(e[8])].append(e)
    print("\nPER ARM (grouped by the reloads field)")
    print("  arm  n    micro mid macro  microH")
    for k, es in sorted(arms.items()):
        c = collections.Counter(e[2] for e in es)
        mids = {slots[int(e[1])][1] for e in es if int(e[1]) in slots}
        macs = {slots[int(e[1])][0] for e in es if int(e[1]) in slots}
        print(f"  {k:3d} {len(es):4d}   {len(c):3d}  {len(mids):3d}  {len(macs):3d}   {entropy(c):.2f}")

    # --- transition matrix among the non-bridge micro machines --------------
    seq = [e[2] for e in ev]
    chg = [seq[0]] + [m for p, m in zip(seq, seq[1:]) if m != p]
    T = collections.Counter(zip(chg, chg[1:]))
    nb = sorted({m for m in chg if not m.startswith("br")})
    T18 = {k: v for k, v in T.items() if not k[0].startswith("br") and not k[1].startswith("br")}
    n18 = sum(T18.values()); cells = len(nb) * (len(nb) - 1); exp = n18 / cells
    chi = sum((T18.get((x, y), 0) - exp) ** 2 / exp for x in nb for y in nb if x != y)
    rows = collections.defaultdict(collections.Counter)
    for (x, y), v in T.items():
        rows[x][y] += v
    Hs = [entropy(rows[m]) for m in sorted(rows)]
    print(f"\nTRANSITIONS (collapsed runs): {len(chg)-1} changes among {len(set(chg))} names")
    print(f"  {len(nb)}x{len(nb)} non-bridge block: {n18} transitions, {len(T18)}/{cells} cells non-zero,"
          f" max cell {max(T18.values())} vs uniform mean {exp:.1f}, chi2 {chi:.0f} on {cells-1} df")
    print(f"  row entropy min/max {min(Hs):.2f}/{max(Hs):.2f} bits (uniform over 26 = {math.log2(26):.2f})")
    print("  top cells:", [(x, y, v) for (x, y), v in sorted(T18.items(), key=lambda kv: -kv[1])[:6]])

    # --- avail size --------------------------------------------------------
    av = sorted(int(e[7]) for e in ev)
    print(f"\nAVAIL SIZE per window: min {av[0]} median {av[len(av)//2]} max {av[-1]}  (supply {len(layer)})")

    # --- invention ---------------------------------------------------------
    print(f"\nINVENTION: ACQUIRED {len(acq)}   ACQFAIL {sum(fail.values())}  reasons {dict(fail)}")

    # --- operator cells vs avail names -------------------------------------
    op = json.load(open(os.path.join(a.mutable, "memory.json"))).get("operator", {})
    suff = [c for c in op if "@" in c]
    match = [c for c in op if c in layer]
    print(f"\nOPERATOR cells {len(op)}: with '@bucket' suffix {len(suff)}, matching a bare avail name {len(match)}")
    print("  dominantOver(avail) does cells.indexOf(m) on bare names: "
          + ("returns nil, operator block breaks before mixing" if not match else "some cells match"))

    # --- vocabulary.json decomposition -------------------------------------
    if os.path.exists(a.vocab):
        ever = json.load(open(a.vocab)).get("ever", [])
        cat = collections.Counter()
        gone = []
        for m in ever:
            if m in BASE: cat["base class"] += 1
            elif m.endswith("@slow"): cat["'@slow' suffixed duplicate"] += 1
            elif m.startswith("br:"): cat["'br:a>b' pseudo-name"] += 1
            elif " 2" in m: cat["' 2' Finder-copy duplicate"] += 1
            elif m in on_disk: cat["runtime machine on disk"] += 1
            else: cat["bridge no longer on disk"] += 1; gone.append(m)
        print(f"\nPANEL 'ever' = {len(ever)} decomposes as {dict(cat)}")
        print(f"  no longer on disk: {gone}")


if __name__ == "__main__":
    main()
