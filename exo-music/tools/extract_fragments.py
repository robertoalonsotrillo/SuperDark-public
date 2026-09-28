#!/usr/bin/env python3
r"""The originals, taken apart into fragments the factory can compose from.

22 Sept 2026. Every machine the factory has written is one Pbind, one
instrument, dry, whose five numeric slots are grammar terms over eight
combinators. The twenty originals in Handler_Local.sc are the whole idiom:
rate palettes with reversed playback and octaves, envelope logic tied to the
sample size, out-bus sequences that decide which events ring, multi-layer
stacks, a finite-state machine, a cadence. The writer could not reach any of
it. This tool takes each original apart MECHANICALLY -- no curation, no
rewriting -- so the writer can place a slot expression the architect wrote for
one machine inside a machine the factory is writing for another. Which
fragments, from which originals, into which slots, is the factory's choice.

WHAT IS EXTRACTED, per original:
  prelude   the `var a = ..., b = ...;` block at the top of the player, with
            every local renamed <machine>_<name> so two originals' locals can
            share one file. Fragments reference these renamed locals.
  slots     the expression after \dur, \rate, \cutoff, \pan, \amp, \atk, \rel,
            \out in the player's Pkill/Pbind, taken with balanced brackets up
            to the next top-level comma. Same renaming.

WHAT IS NOT: \buf (the writer supplies its own), \instrument, \env, and the
cleanup function. Nothing is evaluated here; sclang compiles each fragment in
tools/test_composer.scd before any of this is allowed near the factory.

    python3 tools/extract_fragments.py            # writes mutable/fragments.json
    python3 tools/extract_fragments.py --print sc # show one machine's fragments
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDLER = os.path.join(ROOT, "workdir_music", "lib", "Handler_Local.sc")
OUT = os.path.join(ROOT, "workdir_music", "mutable", "fragments.json")
SLOTS = ["dur", "rate", "cutoff", "pan", "amp", "atk", "rel", "out"]

# symbol -> player method, read from the Handler's own dispatch table
def read_dispatch(src):
    m = {}
    for sym, meth in re.findall(r"\\(\w+),\s*\{\s*this\.(\w+Player)\(buf\)", src):
        m[sym] = meth
    return m


def method_body(src, meth):
    """Text between the braces of `meth {` ... `}` with balanced braces."""
    i = src.find(meth + " {")
    if i < 0:
        return None
    j = src.index("{", i)
    depth = 0
    for k in range(j, len(src)):
        c = src[k]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return src[j + 1:k]
    return None


def strip_comments(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    s = re.sub(r"//[^\n]*", "", s)
    return s


def split_top(s, sep=","):
    """Split on `sep` at bracket depth 0."""
    out, depth, cur = [], 0, []
    for c in s:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == sep and depth == 0:
            out.append("".join(cur)); cur = []
        else:
            cur.append(c)
    out.append("".join(cur))
    return out


def prelude_and_locals(body):
    """The `var ...;` statement and the names it declares."""
    m = re.search(r"\bvar\b(.*?);", body, flags=re.S)
    if not m:
        return "", []
    decl = m.group(1)
    names = []
    for part in split_top(decl):
        # `var a = 1, b = 2, voice;` -- a local with no initialiser is still a
        # local, and two originals both declaring `voice` collide in one file
        mm = re.match(r"\s*(\w+)\s*(=|$)", part.strip() + "")
        if mm:
            names.append(mm.group(1))
    return decl.strip(), names


def rename(expr, names, prefix):
    """<name> -> <prefix>_<name> for declared locals, as identifiers only:
    not inside a \\symbol, not part of a longer word, not a method call."""
    for n in sorted(names, key=len, reverse=True):
        expr = re.sub(r"(?<![\\\w.])" + re.escape(n) + r"(?![\w])",
                      prefix + "_" + n, expr)
    return expr


def slots_of(body):
    """The Pkill(...) / Pbind(...) argument list, as key -> expression."""
    m = re.search(r"\bP(?:kill|bind)\s*\(", body)
    if not m:
        return {}
    j = m.end() - 1
    depth = 0
    for k in range(j, len(body)):
        c = body[k]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                args = body[j + 1:k]
                break
    else:
        return {}
    parts = [p.strip() for p in split_top(args)]
    out = {}
    i = 0
    while i + 1 < len(parts):
        key = parts[i]
        if re.fullmatch(r"\\\w+", key):
            out[key[1:]] = parts[i + 1].strip()
            i += 2
        else:
            i += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--print", dest="show", default=None)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    src = open(HANDLER).read()
    dispatch = read_dispatch(src)
    frags = {}
    for sym, meth in sorted(dispatch.items()):
        body = method_body(src, meth)
        if body is None:
            print(f"  {sym}: no body for {meth}", file=sys.stderr)
            continue
        body = strip_comments(body)
        decl, names = prelude_and_locals(body)
        slots = slots_of(body)
        entry = {
            "player": meth,
            "instrument": slots.get("instrument", "\\playback").lstrip("\\"),
            "locals": names,
            "prelude": rename(decl, names, sym) if decl else "",
            "slots": {k: rename(v, names, sym) for k, v in slots.items() if k in SLOTS},
        }
        frags[sym] = entry

    have = {k: sorted(v["slots"]) for k, v in frags.items()}
    n_slots = sum(len(v) for v in have.values())
    if a.show:
        print(json.dumps(frags[a.show], indent=1))
        return
    doc = {
        "_comment": "Fragments of the twenty originals in Handler_Local.sc, "
                    "extracted mechanically by tools/extract_fragments.py on "
                    "22 Sept 2026. Locals are renamed <machine>_<name>. The "
                    "writer composes from these; which, where, is the factory's "
                    "choice. Regenerate after any edit to Handler_Local.sc.",
        "slots": SLOTS,
        "machines": frags,
    }
    json.dump(doc, open(a.out, "w"), indent=1)
    print(f"{len(frags)} originals, {n_slots} slot fragments -> {a.out}")
    missing = {k: [s for s in SLOTS if s not in v] for k, v in have.items()}
    missing = {k: v for k, v in missing.items() if v}
    if missing:
        print("missing slots:", missing)


if __name__ == "__main__":
    main()
