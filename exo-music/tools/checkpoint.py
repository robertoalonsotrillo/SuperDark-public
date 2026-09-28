#!/usr/bin/env python3
"""A checkpoint: the one object the factory has never had.

WHY THIS EXISTS
---------------
`archive_guard.py` makes the corpus recoverable. Nothing makes the *state*
recoverable. `memory.json`, `policy.json`, the charter, the weights and the
machines are overwritten in place, so the operator that a measurement describes
stops existing the moment the next window is written. That is why m7 turned out
to be measuring the operator's AGE: the operator persists across runs and there
is no way to say which operator a number came from.

It is also why 10 September could not attribute anything. Three changes went
live together with a restart and a reassembled corpus, and the measurement
document had to say so in as many words: "No movement here is attributable to
any one of them." The fix is not more care. It is a checkpoint you can fork
from, so a comparison starts twice from the same place.

WHAT A CHECKPOINT IS
--------------------
Everything needed to put the factory back into a named state, plus enough
provenance to prove which state that was:

  policy layer   policy.json, charter.json, weights.json, machines/,
                 written_machines.json, audibility.json, bridged.json
  operator       memory.json
  substrate      kernel.json, and the journals as they stood
  code identity  git HEAD, dirty flag, sha256 of live_factory.scd and lib/*.sc
  corpus identity sha256 of each pool manifest (the grains themselves are
                 archive_guard's job, not this file's)
  run context    the log this was taken during, and its window count

WHAT IT DELIBERATELY REFUSES
----------------------------
`restore` will not run while the factory is running. Restoring state under a
live factory produces exactly the failure `run_integrity.py` was written
against: a log with an unmarked seam in it, which is worse than a stopped run,
because the seam is read as continuous data. Stop the factory, restore, start
it. --force exists and is recorded in the manifest when used.

    python3 tools/checkpoint.py create --label rq25-baseline
    python3 tools/checkpoint.py list
    python3 tools/checkpoint.py verify ck_260915_163000_rq25-baseline
    python3 tools/checkpoint.py diff  ck_A ck_B
    python3 tools/checkpoint.py restore ck_A
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)                       # exo-music/
W = os.path.join(EM, "workdir_music")
MUT = os.path.join(W, "mutable")
LIB = os.path.join(W, "lib")
FACTORY = os.path.join(W, "tools", "live_factory.scd")
RENDERS = "/Volumes/FMA/superdark/renders"
POOL = "/Volumes/FMA/superdark/play"
STORE = os.path.join(EM, "harness", "checkpoints")

# The policy layer plus the operator. Everything the factory reads that can
# differ between two runs and change what you hear.
STATE_FILES = [
    "policy.json", "charter.json", "kernel.json", "memory.json",
    "weights.json", "written_machines.json", "audibility.json",
    "bridged.json", "charter_decisions.jsonl", "charter_proposals.jsonl",
    "kernel_journal.jsonl",
]
STATE_DIRS = ["machines"]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def sha256_text(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def git(*args):
    try:
        out = subprocess.run(["git", "-C", EM] + list(args),
                             capture_output=True, text=True, timeout=20)
        return out.stdout.strip()
    except Exception:
        return ""


def factory_running():
    r = subprocess.run(["pgrep", "-f", "live_factory.scd"],
                       capture_output=True)
    if r.returncode == 0:
        return True
    # the factory is launched through sclang with a conf file; catch that too
    r = subprocess.run(["pgrep", "-f", "sclang"], capture_output=True)
    return r.returncode == 0


def current_run():
    """The newest window log, and how many windows it has."""
    try:
        logs = [f for f in os.listdir(RENDERS)
                if f.startswith("live_") and f.endswith(".log")]
    except OSError:
        return None, 0
    if not logs:
        return None, 0
    logs.sort(key=lambda f: os.path.getmtime(os.path.join(RENDERS, f)))
    newest = logs[-1]
    n = 0
    try:
        with open(os.path.join(RENDERS, newest), errors="replace") as fh:
            for line in fh:
                if line.startswith("VOICES"):
                    n += 1
    except OSError:
        pass
    return newest, n


def code_identity():
    ident = {"git_head": git("rev-parse", "HEAD"),
             "git_branch": git("rev-parse", "--abbrev-ref", "HEAD"),
             "git_dirty": bool(git("status", "--porcelain")),
             "files": {}}
    if os.path.exists(FACTORY):
        ident["files"]["live_factory.scd"] = sha256_file(FACTORY)
    if os.path.isdir(LIB):
        for f in sorted(os.listdir(LIB)):
            if f.endswith(".sc"):
                ident["files"]["lib/" + f] = sha256_file(os.path.join(LIB, f))
    return ident


def corpus_identity():
    """Hash the pool manifests, not the grains. archive_guard owns the grains."""
    out = {}
    for root in (POOL, W):
        if not os.path.isdir(root):
            continue
        for entry in sorted(os.listdir(root)):
            man = os.path.join(root, entry, "manifest.json")
            if os.path.isfile(man):
                out[entry] = sha256_file(man)
    return out


def policy_digest():
    """The policy keys that actually steer behaviour, flattened, for diffing."""
    path = os.path.join(MUT, "policy.json")
    if not os.path.isfile(path):
        return {}
    with open(path) as fh:
        p = json.load(fh)
    return {k: v for k, v in sorted(p.items()) if not k.startswith("_")}


def cmd_create(args):
    stamp = dt.datetime.now().strftime("%y%m%d_%H%M%S")
    label = (args.label or "unlabelled").replace(" ", "-")
    cid = f"ck_{stamp}_{label}"
    dest = os.path.join(args.store, cid)
    if os.path.exists(dest):
        sys.exit(f"checkpoint {cid} already exists")
    os.makedirs(dest)

    run_log, windows = current_run()
    manifest = {
        "id": cid,
        "label": args.label,
        "note": args.note,
        "created": time.time(),
        "created_iso": dt.datetime.now().isoformat(timespec="seconds"),
        "factory_running": factory_running(),
        "run_log": run_log,
        "run_windows": windows,
        "code": code_identity(),
        "corpus": corpus_identity(),
        "policy": policy_digest(),
        "state_files": [],
    }

    tar_path = os.path.join(dest, "state.tar.gz")
    with tarfile.open(tar_path, "w:gz") as tar:
        for name in STATE_FILES:
            src = os.path.join(MUT, name)
            if os.path.isfile(src):
                tar.add(src, arcname="mutable/" + name)
                manifest["state_files"].append(
                    {"name": name, "sha256": sha256_file(src),
                     "bytes": os.path.getsize(src)})
        for name in STATE_DIRS:
            src = os.path.join(MUT, name)
            if os.path.isdir(src):
                tar.add(src, arcname="mutable/" + name)
                manifest["state_files"].append(
                    {"name": name + "/", "sha256": None, "bytes": None})

    manifest["state_tar_sha256"] = sha256_file(tar_path)
    with open(os.path.join(dest, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=True)
    with open(os.path.join(dest, "SHA256SUMS"), "w") as fh:
        fh.write(f"{manifest['state_tar_sha256']}  state.tar.gz\n")

    print(f"{cid}")
    print(f"  run       {run_log} ({windows} windows)")
    print(f"  git       {manifest['code']['git_head'][:12]}"
          f"{' DIRTY' if manifest['code']['git_dirty'] else ''}")
    print(f"  files     {len(manifest['state_files'])}")
    print(f"  size      {os.path.getsize(tar_path)/1024:.0f} KB")
    print(f"  path      {dest}")
    return 0


def load(cid, store):
    path = os.path.join(store, cid, "manifest.json")
    if not os.path.isfile(path):
        sys.exit(f"no such checkpoint: {cid}")
    with open(path) as fh:
        return json.load(fh)


def cmd_list(args):
    if not os.path.isdir(args.store):
        print("no checkpoints yet")
        return 0
    ids = sorted(d for d in os.listdir(args.store) if d.startswith("ck_"))
    if not ids:
        print("no checkpoints yet")
        return 0
    for cid in ids:
        m = load(cid, args.store)
        print(f"{cid:44s} {m.get('run_windows', 0):>6} win  "
              f"{(m.get('code', {}).get('git_head') or '')[:8]:8s} "
              f"{m.get('note') or m.get('label') or ''}")
    return 0


def cmd_verify(args):
    m = load(args.id, args.store)
    tar_path = os.path.join(args.store, args.id, "state.tar.gz")
    ok = True
    have = sha256_file(tar_path)
    if have != m["state_tar_sha256"]:
        print(f"FAIL  state.tar.gz  {have[:12]} != {m['state_tar_sha256'][:12]}")
        ok = False
    else:
        print("ok    state.tar.gz")
    # the archive must open and contain what the manifest claims
    try:
        with tarfile.open(tar_path) as tar:
            names = set(tar.getnames())
    except Exception as e:
        print(f"FAIL  archive unreadable: {e}")
        return 1
    for entry in m["state_files"]:
        want = "mutable/" + entry["name"].rstrip("/")
        if want not in names:
            print(f"FAIL  missing from archive: {entry['name']}")
            ok = False
    print("ok    archive contents" if ok else "FAIL  archive contents")
    return 0 if ok else 1


def flat(d, prefix=""):
    out = {}
    for k, v in d.items():
        key = prefix + k
        if isinstance(v, dict):
            out.update(flat(v, key + "."))
        else:
            out[key] = v
    return out


def cmd_diff(args):
    a = load(args.a, args.store)
    b = load(args.b, args.store)
    pa, pb = flat(a.get("policy", {})), flat(b.get("policy", {}))
    keys = sorted(set(pa) | set(pb))
    changed = [k for k in keys if pa.get(k) != pb.get(k)]
    print(f"policy: {len(changed)} of {len(keys)} keys differ")
    for k in changed:
        print(f"  {k}: {pa.get(k, '<absent>')!r} -> {pb.get(k, '<absent>')!r}")

    ca, cb = a.get("code", {}), b.get("code", {})
    if ca.get("git_head") != cb.get("git_head"):
        print(f"code: git {(ca.get('git_head') or '')[:12]} -> "
              f"{(cb.get('git_head') or '')[:12]}")
    fa, fb = ca.get("files", {}), cb.get("files", {})
    for f in sorted(set(fa) | set(fb)):
        if fa.get(f) != fb.get(f):
            print(f"  {f} changed")
    if a.get("corpus") != b.get("corpus"):
        print("corpus: manifests differ (pool was rebuilt or reassembled)")
    if not changed and ca.get("git_head") == cb.get("git_head") \
            and fa == fb and a.get("corpus") == b.get("corpus"):
        print("no difference in policy, code or corpus identity")
    return 0


def cmd_restore(args):
    m = load(args.id, args.store)
    if factory_running() and not args.force:
        print("REFUSED: the factory is running.")
        print("Restoring state under a live factory leaves an unmarked seam in")
        print("the window log, and a seam is read as continuous data. Stop the")
        print("factory first, or pass --force and accept that the log lies.")
        return 2
    if cmd_verify(args) != 0:
        print("REFUSED: checkpoint failed verification")
        return 1

    tar_path = os.path.join(args.store, args.id, "state.tar.gz")
    target = args.into or MUT
    # keep what is there now, so a bad restore is itself reversible
    if os.path.isdir(target) and not args.no_backup:
        bak = target + ".before_" + args.id
        if os.path.exists(bak):
            shutil.rmtree(bak)
        shutil.copytree(target, bak)
        print(f"kept  current state at {bak}")

    with tempfile.TemporaryDirectory() as tmp:
        with tarfile.open(tar_path) as tar:
            tar.extractall(tmp)
        src = os.path.join(tmp, "mutable")
        os.makedirs(target, exist_ok=True)
        for entry in sorted(os.listdir(src)):
            s, d = os.path.join(src, entry), os.path.join(target, entry)
            if os.path.isdir(s):
                if os.path.isdir(d):
                    shutil.rmtree(d)
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
            print(f"restored {entry}")

    rec = {"t": time.time(),
           "iso": dt.datetime.now().isoformat(timespec="seconds"),
           "event": "checkpoint_restored", "checkpoint": args.id,
           "into": target, "forced": bool(args.force)}
    with open(os.path.join(EM, "harness", "harness_journal.jsonl"), "a") as fh:
        fh.write(json.dumps(rec) + "\n")
    print(f"\nrestored {args.id} into {target}")
    print("The restore is itself an event and is in harness_journal.jsonl.")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--store", default=STORE)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("create")
    c.add_argument("--label", default="unlabelled")
    c.add_argument("--note", default="")
    c.set_defaults(fn=cmd_create)

    c = sub.add_parser("list");   c.set_defaults(fn=cmd_list)

    c = sub.add_parser("verify"); c.add_argument("id")
    c.set_defaults(fn=cmd_verify)

    c = sub.add_parser("diff");   c.add_argument("a"); c.add_argument("b")
    c.set_defaults(fn=cmd_diff)

    c = sub.add_parser("restore"); c.add_argument("id")
    c.add_argument("--into", default=None)
    c.add_argument("--force", action="store_true")
    c.add_argument("--no-backup", action="store_true")
    c.set_defaults(fn=cmd_restore)

    args = ap.parse_args()
    os.makedirs(os.path.join(EM, "harness"), exist_ok=True)
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
