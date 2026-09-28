#!/usr/bin/env python3
"""Seal the evaluation rig, and refuse to evaluate through a broken seal.

WHY THIS EXISTS
---------------
Every scorer in this project lives in tools/, in the same repo, on the same
disk, with the same permissions as everything else. The factory cannot reach
them, but only because SuperCollider here has no file write. That is a property
of how the factory happened to be built, with nothing behind it.

The people building Exo put this plainly in their release proposal: "An agent
only judged by scores will eventually treat the scoring mechanism as one more
thing that it can modify," citing Sakana's Darwin Godel Machine doing it. Their
answer is an evaluation rig that sits behind eval.sh and "is not part of Exo".

SuperDark cannot rewrite its own code, so that failure mode is not available to
it. The failure available HERE is mine: editing a measure and then reporting the
new number against the old pre-registration. That has already happened three
times in a softer form, when a spectral measure saturated and every earlier
verdict computed with it silently changed meaning.

So the seal is aimed at the architect, not the factory. It makes the identity of
a measure checkable at the moment a number is produced.

WHAT IT DOES
------------
  seal     hash every file in harness/sealed_scorers.txt into frozen/MANIFEST.json
  verify   recompute and compare; exit 1 on any mismatch, addition or loss
  status   human summary
  adopt    record a deliberate change to a sealed scorer, with a reason

`adopt` is the important one. A sealed scorer is not forbidden from changing.
It is forbidden from changing *quietly*. Adopting writes the old and new hash
and the reason into frozen/SEAL_LOG.jsonl, so every measurement can be traced
to the exact text of the measure that produced it.

    python3 tools/seal_rig.py seal
    python3 tools/seal_rig.py verify
    python3 tools/seal_rig.py adopt tools/sonic_variety.py --why "centre before normalising"
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
LIST = os.path.join(EM, "harness", "sealed_scorers.txt")
MANIFEST = os.path.join(EM, "frozen", "MANIFEST.json")
SEAL_LOG = os.path.join(EM, "frozen", "SEAL_LOG.jsonl")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def listed():
    out = []
    with open(LIST) as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                out.append(line)
    return out


def measure():
    present, missing = {}, []
    for rel in listed():
        path = os.path.join(EM, rel)
        if os.path.isfile(path):
            present[rel] = {"sha256": sha256(path),
                            "bytes": os.path.getsize(path)}
        else:
            missing.append(rel)
    return present, missing


def load_manifest():
    if not os.path.isfile(MANIFEST):
        return None
    with open(MANIFEST) as fh:
        return json.load(fh)


def log(rec):
    rec.setdefault("t", time.time())
    rec.setdefault("iso", dt.datetime.now().isoformat(timespec="seconds"))
    with open(SEAL_LOG, "a") as fh:
        fh.write(json.dumps(rec) + "\n")


def cmd_seal(args):
    present, missing = measure()
    old = load_manifest()
    if old and not args.force:
        changed = [k for k in present
                   if k in old["files"]
                   and old["files"][k]["sha256"] != present[k]["sha256"]]
        if changed:
            print("REFUSED: these sealed scorers have changed since the last seal:")
            for k in changed:
                print(f"  {k}")
            print("\nUse `adopt <path> --why ...` for each, which records the old")
            print("and new hash and the reason. Re-sealing over a silent change is")
            print("the exact thing the seal exists to prevent. --force overrides,")
            print("and is recorded.")
            return 1
    man = {
        "sealed": time.time(),
        "sealed_iso": dt.datetime.now().isoformat(timespec="seconds"),
        "forced": bool(args.force),
        "n": len(present),
        "missing": missing,
        "files": present,
    }
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    log({"event": "seal", "n": len(present), "missing": missing,
         "forced": bool(args.force)})
    print(f"sealed {len(present)} scorers -> frozen/MANIFEST.json")
    for m in missing:
        print(f"  NOT FOUND (listed but absent): {m}")
    return 0


def cmd_verify(args):
    man = load_manifest()
    if man is None:
        print("FAIL  no seal. Run `seal` first.")
        return 1
    present, missing = measure()
    sealed = man["files"]
    bad = 0

    for rel, rec in sorted(sealed.items()):
        if rel not in present:
            print(f"FAIL  vanished       {rel}")
            bad += 1
        elif present[rel]["sha256"] != rec["sha256"]:
            print(f"FAIL  modified       {rel}")
            print(f"        sealed {rec['sha256'][:16]}")
            print(f"        now    {present[rel]['sha256'][:16]}")
            bad += 1
        elif args.verbose:
            print(f"ok    {rel}")

    for rel in sorted(set(present) - set(sealed)):
        print(f"FAIL  listed, unsealed  {rel}")
        bad += 1

    for rel in missing:
        print(f"warn  listed, absent    {rel}")

    if bad:
        print(f"\n{bad} problem(s). Any number produced now is not attributable")
        print("to the measure its pre-registration names.")
        return 1
    print(f"ok    seal intact, {len(sealed)} scorers, "
          f"sealed {man['sealed_iso']}")
    return 0


def cmd_status(args):
    man = load_manifest()
    if man is None:
        print("unsealed")
        return 1
    print(f"sealed {man['sealed_iso']}  {man['n']} scorers"
          f"{'  (FORCED)' if man.get('forced') else ''}")
    if os.path.isfile(SEAL_LOG):
        with open(SEAL_LOG) as fh:
            lines = fh.readlines()
        adopts = [json.loads(x) for x in lines if '"adopt"' in x]
        print(f"{len(adopts)} adopted change(s) on record")
        for a in adopts[-5:]:
            print(f"  {a['iso']}  {a['path']}  {a['why']}")
    return 0


def cmd_adopt(args):
    man = load_manifest()
    if man is None:
        return cmd_seal(argparse.Namespace(force=False))
    rel = os.path.relpath(os.path.abspath(args.path), EM)
    path = os.path.join(EM, rel)
    if not os.path.isfile(path):
        sys.exit(f"no such file: {rel}")
    if rel not in man["files"]:
        sys.exit(f"{rel} is not sealed. Add it to harness/sealed_scorers.txt "
                 f"and run `seal`.")
    old = man["files"][rel]["sha256"]
    new = sha256(path)
    if old == new:
        print(f"{rel} is unchanged; nothing to adopt")
        return 0
    man["files"][rel] = {"sha256": new, "bytes": os.path.getsize(path)}
    man["sealed"] = time.time()
    man["sealed_iso"] = dt.datetime.now().isoformat(timespec="seconds")
    with open(MANIFEST, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    log({"event": "adopt", "path": rel, "old": old, "new": new,
         "why": args.why})
    print(f"adopted {rel}")
    print(f"  {old[:16]} -> {new[:16]}")
    print(f"  why: {args.why}")
    print("\nEvery measurement taken before this line used the old text. If any")
    print("of them is quoted anywhere, say which hash produced it.")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("seal"); c.add_argument("--force", action="store_true")
    c.set_defaults(fn=cmd_seal)

    c = sub.add_parser("verify"); c.add_argument("-v", "--verbose",
                                                 action="store_true")
    c.set_defaults(fn=cmd_verify)

    c = sub.add_parser("status"); c.set_defaults(fn=cmd_status)

    c = sub.add_parser("adopt"); c.add_argument("path")
    c.add_argument("--why", required=True)
    c.set_defaults(fn=cmd_adopt)

    args = ap.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
