#!/usr/bin/env python3
"""Every class in lib/ must be referenced by the file the factory runs.

THE FAILURE THIS EXISTS TO CATCH. sclang loads an unreferenced class in total
silence. It compiles, the banner prints, the factory runs, and the class does
nothing for ever. There is no warning, no error, and no symptom in the audio --
the factory simply behaves as though the feature was never built.

It has now happened three times in this project:

  nearestAround   defined but never declared in the enclosing var block. sclang
                  compiled it, printed the banner, executed nothing, sat at 0%
                  CPU. Two hours, found by rebuilding onto HEAD one edit at a
                  time.
  resting         declared twice. Same silent class, twenty minutes.
  PatternGrammar  a whole compositional layer -- class, tests, and both arms
                  inside MachineWriter.propose -- referenced ZERO times in
                  live_factory.scd for two days, while task 54 sat marked
                  complete. Simultaneity.sc was in the same state.

The common shape is that the WORK was done and the WIRING was not, and nothing
in the toolchain distinguishes those two states. A test that exercises the class
directly passes in all three cases, which is why test_grammar.scd did not catch
it. The only question that separates them is whether the running file names the
class at all.

WHAT COUNTS AS A CALL SITE. The class name appearing outside a comment in the
factory source. Deliberately crude: this is a wiring check, not a static
analysis, and a name that appears somewhere real is enough to prove the wiring
was considered. A name that appears only inside a comment is exactly the state
PatternGrammar was in -- mentioned in a deferral note at line 1822 and called
nowhere -- so comments are stripped before matching.

    python3 tools/check_call_sites.py            # exit 1 if any class is orphaned
    python3 tools/check_call_sites.py --list     # show every class and its status
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "workdir_music", "lib")
FACTORY = os.path.join(ROOT, "workdir_music", "tools", "live_factory.scd")

# Classes the live factory is not expected to name, each with the reason. An
# entry here is a claim that the class belongs to a different entry point, and
# it has to say which -- "unused for now" is not a reason and should be a
# deletion instead.
EXEMPT = {
    "ArchonCapture": "offline renderer only; run_live.sh strips it explicitly "
                     "because it overrides Pkill.play to capture patterns",
    "Handler_Local": "loaded by class name from the patched live_classes copy",
    "Methods_Local": "extension methods, referenced by the methods they add",
    "Synths_Local": "extension methods, referenced by the synths they define",
    "Pkill_Local": "extension methods on Pkill",
}


def strip_comments(text):
    """Remove // line comments and /* */ blocks, so a mention is a real one."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"^\s*//.*$", " ", text, flags=re.M)
    text = re.sub(r"//.*$", " ", text, flags=re.M)
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    if not os.path.exists(FACTORY):
        print(f"  no factory source at {FACTORY}", file=sys.stderr)
        return 2

    body = strip_comments(open(FACTORY, errors="replace").read())

    orphans, wired, exempt = [], [], []
    for path in sorted(glob.glob(os.path.join(LIB, "*.sc"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if name in EXEMPT:
            exempt.append(name)
            continue
        if re.search(r"\b" + re.escape(name) + r"\b", body):
            wired.append(name)
        else:
            orphans.append(name)

    if a.list or orphans:
        print()
        for n in wired:
            print(f"  WIRED    {n}")
        for n in exempt:
            print(f"  exempt   {n:16} {EXEMPT[n]}")
        for n in orphans:
            print(f"  ORPHAN   {n}")

    if orphans:
        print()
        print(f"  {len(orphans)} class(es) in lib/ are never named in live_factory.scd.")
        print("  sclang will load them in silence and they will do nothing.")
        print("  Either wire the class into the factory, add it to EXEMPT with a")
        print("  reason naming its real entry point, or delete it.")
        return 1

    print(f"\n  {len(wired)} wired, {len(exempt)} exempt, 0 orphaned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
