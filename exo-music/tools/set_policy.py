#!/usr/bin/env python3
"""Set one policy key in one mutable layer, and say what changed.

WHY THIS EXISTS AT ALL. The policy is hot-reloaded every window, so editing
policy.json by hand while a factory runs is a live change to a running system
with no record of who made it or what it was before. Twice now a value has moved
and the reason was reconstructed afterwards from the sound: macro_hold_grains
went to 1 without the code that read it, and dsp_depth reached 1.0 with no note
of who raised it from 0.35.

WHAT IT REFUSES. The factory's own proposals go through charter_proposals.jsonl
and the kernel guard. This tool is for the ARCHITECT's hand edits, and it prints
the old value so the change appears in the session record instead of only in the
file. It does not touch the charter, the kernel, or any key inside them.

    python3 tools/set_policy.py mutable_shadow capture_in_sc 0
    python3 tools/set_policy.py mutable dsp_depth 0.35
    python3 tools/set_policy.py mutable_shadow capture_fifo /tmp/superdark_shadow.fifo
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Keys the factory reads as governance, not as parameters. Moving one of these
# by hand is a governance act and belongs in the charter record, not here.
REFUSED = {"charter_edition", "kernel_edition", "metrics"}


def main():
    if len(sys.argv) != 4:
        print(__doc__.strip())
        return 2
    layer, key, value = sys.argv[1], sys.argv[2], sys.argv[3]

    if key in REFUSED:
        print(f"  refusing: {key} is governance, not policy")
        return 1

    path = os.path.join(ROOT, "workdir_music", layer, "policy.json")
    if not os.path.exists(path):
        print(f"  no policy at {path}")
        return 1

    with open(path) as fh:
        pol = json.load(fh)

    # EVERY VALUE IS A STRING in this file, because the factory reads them with
    # .asFloat / .asString and a JSON number would arrive as a different type at
    # the one call site that does not convert. Preserving that invariant here
    # keeps hand edits shaped like the factory's own writes.
    old = pol.get(key)
    pol[key] = str(value)

    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(pol, fh, indent=2, sort_keys=True)
    os.replace(tmp, path)

    if old is None:
        print(f"  {layer}: {key} = {value!r}   (was unset)")
    else:
        print(f"  {layer}: {key} = {value!r}   (was {old!r})")
    print(f"  hot-reloaded at the factory's next window")
    return 0


if __name__ == "__main__":
    sys.exit(main())
