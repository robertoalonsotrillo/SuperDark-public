#!/usr/bin/env python3
"""The immutable archive: establish it, verify it, restore from it.

WHY THIS EXISTS
---------------
Self-ingestion by admission control lets the factory displace generation-0 FMA
grains from its working pool, one slot at a time, until none are left. That is
deliberate -- Roberto, 28 Aug: "keep the original FMA seeds as duplicate but
allow the system to delete the copy that it is working with" -- and it is what
lets P113's *c* actually fall rather than being floored in by construction.

The whole design rests on the duplicate being real. Until now it was not a
mechanism, only a convention: nothing opened grains_lic_* after --init, and each
pool manifest recorded an `archive` path. Convention is not preservation. There
was no integrity check, nothing enforced read-only, and no way to restore.

WHAT RECOVERABILITY ACTUALLY RESTS ON
-------------------------------------
Three independent layers, weakest first:

  1. the POOL          mutable, on the external SSD, actively being eaten
  2. the ARCHIVE       byte-identical copy of the grain corpora, checksummed
                       and marked read-only. Restoring the pool from it is a
                       file copy.
  3. the FMA SOURCE    452 GB of audio plus corpus_vetted.txt, corpus_ids.txt
                       and corpus_genres.csv, with build_grains_onset.py /
                       build_grains_seq.py carrying a fixed RNG seed
                       (20260823). Rebuilding the archive is deterministic but
                       depends on ffmpeg, the drive and the scripts all still
                       agreeing -- which is exactly why layer 2 exists.

P458 asks for a world in which irreversible harm is impossible. This is what
makes the factory's most destructive act -- eating the material it was given --
reversible, without making it forbidden.

    python3 tools/archive_guard.py establish --src A,B,C --archive DIR
    python3 tools/archive_guard.py verify   --archive DIR
    python3 tools/archive_guard.py restore  --archive DIR --pool RING [--layer ev]
"""
import argparse
import glob
import hashlib
import json
import os
import shutil
import stat
import sys
import time
import zipfile


def sha256(path, buf=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(buf)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def set_readonly(path, ro=True):
    """Clear the write bits. This stops an accidental overwrite, not a
    determined one -- anything running as this user can chmod it back. It is a
    guardrail, and calling it a guarantee would be a lie."""
    try:
        m = os.stat(path).st_mode
        os.chmod(path, (m & ~0o222) if ro else (m | stat.S_IWUSR))
        return True
    except OSError:
        return False


def clear_readonly(path):
    """Best effort. On exFAT chmod is a no-op and this changes nothing, which is
    fine: the point is not to fail on a filesystem that does honour the bits."""
    try:
        if os.path.exists(path):
            os.chmod(path, 0o644)
    except OSError:
        pass


def establish(srcs, archive):
    os.makedirs(archive, exist_ok=True)
    index = {"created": time.time(), "corpora": {}}
    ipath = os.path.join(archive, "archive.json")
    if os.path.exists(ipath):
        try:
            index = json.load(open(ipath))
        except (OSError, ValueError):
            pass

    for src in srcs:
        name = os.path.basename(src.rstrip("/"))
        dst = os.path.join(archive, name)
        files = sorted(glob.glob(os.path.join(src, "*.wav")))
        if not files:
            print(f"  {src}: no grains, skipped")
            continue
        os.makedirs(dst, exist_ok=True)
        print(f"  {name}: copying and checksumming {len(files)} grains ...")
        sums, total, refreshed = {}, 0, 0
        for p in files:
            fn = os.path.basename(p)
            q = os.path.join(dst, fn)
            # COPY WHEN THE CONTENT DIFFERS, not merely when the file is absent.
            #
            # This was `if not os.path.exists(q)`, which made establish a no-op
            # over an existing archive. On 31 Aug the corpora were resampled to
            # 44100 and establish was re-run; it printed "copying and
            # checksumming 1200 grains", copied nothing, and re-checksummed the
            # 22050 files from 01:09. verify then passed, because it compared
            # stale audio against checksums taken from that same stale audio.
            # The restart zip built from it was equally stale, so a reset would
            # have silently reverted the corpus to the pre-resample material and
            # reinstated the interpolation imaging.
            #
            # Roberto found it by asking whether the reset actually worked. An
            # archive that cannot be refreshed is worse than no archive: it
            # answers "intact" to a question about the wrong files.
            src_sum = sha256(p)
            if (not os.path.exists(q)) or sha256(q) != src_sum:
                # copyfile, not copy2: exFAT has no chflags and copystat raises
                # EINVAL there.
                clear_readonly(q)
                shutil.copyfile(p, q)
                refreshed += 1
            sums[fn] = sha256(q)
            total += os.path.getsize(q)
            set_readonly(q)
        # sidecar metadata the corpora carry alongside the audio
        for extra in ("descriptors.json", "manifest.json"):
            e = os.path.join(src, extra)
            if os.path.exists(e):
                shutil.copyfile(e, os.path.join(dst, extra))
                sums[extra] = sha256(os.path.join(dst, extra))
                set_readonly(os.path.join(dst, extra))
        # did the write-protection actually take? On exFAT it does not: the
        # filesystem has no Unix permission bits, so chmod succeeds and changes
        # nothing. Measure rather than assume, and say so.
        if refreshed:
            print(f"    {refreshed} file(s) REFRESHED (content differed from the source)")
        else:
            print(f"    no file differed; archive already matched the source")
        probe = next(iter(sums))
        enforced = not (os.stat(os.path.join(dst, probe)).st_mode & 0o222)
        index["corpora"][name] = {
            "source": os.path.abspath(src), "files": len(sums),
            "bytes": total, "sha256": sums, "stamped": time.time(),
            "readonly_enforced": enforced}
        print(f"    {len(sums)} files, {total/1e6:.1f} MB, "
              f"{'read-only' if enforced else 'NOT write-protected'}")
        if not enforced:
            print("      this filesystem ignores permission bits (exFAT does).")
            print("      Protection here is DETECTION, not prevention: the")
            print("      checksums catch damage and 'restore' repairs it, but")
            print("      nothing stops a stray delete. Verify before trusting.")

    # the index itself must stay writable to be updated; it is checksummed by
    # its own contents rather than protected
    json.dump(index, open(ipath, "w"), indent=1)
    print(f"  archive index -> {ipath}")


def verify(archive):
    ipath = os.path.join(archive, "archive.json")
    if not os.path.exists(ipath):
        raise SystemExit(f"  no archive index at {ipath}; run 'establish' first")
    index = json.load(open(ipath))
    bad = 0
    for name, rec in index["corpora"].items():
        d = os.path.join(archive, name)
        missing, changed = [], []
        for fn, want in rec["sha256"].items():
            p = os.path.join(d, fn)
            if not os.path.exists(p):
                missing.append(fn)
            elif sha256(p) != want:
                changed.append(fn)
        ro = sum(1 for fn in rec["sha256"]
                 if os.path.exists(os.path.join(d, fn))
                 and not (os.stat(os.path.join(d, fn)).st_mode & 0o222))
        status = "OK" if not (missing or changed) else "DAMAGED"
        prot = ("read-only" if ro == rec["files"]
                else f"unprotected ({ro}/{rec['files']} read-only; "
                     f"exFAT ignores permission bits)")
        print(f"  {name:22} {rec['files']:>5} files  {status}   {prot}")
        for fn in missing[:5]:
            print(f"      MISSING  {fn}")
        for fn in changed[:5]:
            print(f"      CHANGED  {fn}")
        if len(missing) + len(changed) > 10:
            print(f"      ... and {len(missing)+len(changed)-10} more")
        bad += len(missing) + len(changed)
    print()
    if bad:
        print(f"  {bad} files differ from the archive. The duplicate the whole")
        print("  self-ingestion design rests on is NOT intact. Do not treat the")
        print("  pool as restorable until this is resolved.")
        return 1
    print("  archive intact. The pool can be restored from it by file copy.")
    return 0


def restore(archive, pool, layers=None):
    ipath = os.path.join(archive, "archive.json")
    if not os.path.exists(ipath):
        raise SystemExit(f"  no archive index at {ipath}")
    index = json.load(open(ipath))
    n = 0
    for name, rec in index["corpora"].items():
        layer = name.split("_")[-1]
        if layers and layer not in layers:
            continue
        src = os.path.join(archive, name)
        dst = os.path.join(pool, f"grains_pool_{layer}")
        os.makedirs(dst, exist_ok=True)
        for fn in rec["sha256"]:
            if not fn.endswith(".wav"):
                continue
            q = os.path.join(dst, fn)
            if os.path.exists(q):
                set_readonly(q, False)
            shutil.copyfile(os.path.join(src, fn), q)
            set_readonly(q, False)          # the POOL must stay writable
            n += 1
        mp = os.path.join(dst, "manifest.json")
        if os.path.exists(mp):
            m = json.load(open(mp))
            for e in m.get("manifest", []):
                e["gen"] = 0.0
                e["born"] = 0.0
                e["source"] = "archive:" + name
            m["restored"] = time.time()
            json.dump(m, open(mp, "w"), indent=1)
        print(f"  {name} -> {os.path.basename(dst)}  ({rec['files']} files)")
    print(f"  restored {n} grains to generation 0.")
    print("  NOTE: descriptors are not recomputed here. If the factory was")
    print("  reading pool descriptors, regenerate them before the next run.")


def pack(archive, out, extras=()):
    """One zip that can restart the factory from nothing.

    Why a zip and not the loose tree it already has:

      it survives exFAT      the drive has 1 MiB allocation blocks and no Unix
                             permission bits, so 5,406 loose grain files occupy
                             5.3 GB for 576 MB of audio AND cannot be marked
                             read-only. One archive file costs its real size and
                             is a single object to not delete by accident.
      it is complete         grains alone do not restart a factory. descriptors
                             .json is what the factory navigates by, and without
                             the frozen bases nothing new can be projected into
                             the same space. All of it travels together or the
                             restart is partial in a way nobody notices until
                             the neighbourhoods come back wrong.
      it is verified         every entry's SHA-256 is checked by reading the zip
                             BACK after writing. A backup nobody has restored
                             from is not a backup.
    """
    ipath = os.path.join(archive, "archive.json")
    if not os.path.exists(ipath):
        raise SystemExit(f"  no archive index at {ipath}; run 'establish' first")
    index = json.load(open(ipath))

    members = []                       # (arcname, abspath)
    for name, rec in index["corpora"].items():
        d = os.path.join(archive, name)
        for fn in rec["sha256"]:
            p = os.path.join(d, fn)
            if os.path.exists(p):
                members.append((f"{name}/{fn}", p))
    for fn in sorted(os.listdir(archive)):
        p = os.path.join(archive, fn)
        if os.path.isfile(p):
            members.append((fn, p))     # archive.json + basis_*.json
    for e in extras:
        if os.path.exists(e):
            members.append((f"corpus_lists/{os.path.basename(e)}", e))
        else:
            print(f"  extra not found, skipped: {e}")

    raw = sum(os.path.getsize(p) for _, p in members)
    print(f"  packing {len(members)} files, {raw/1e6:.1f} MB raw ...")
    tmp = out + ".part"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=6,
                         allowZip64=True) as z:
        for i, (arc, p) in enumerate(members):
            z.write(p, arc)
            if (i + 1) % 1000 == 0:
                print(f"    {i+1}/{len(members)}", flush=True)
    os.replace(tmp, out)
    size = os.path.getsize(out)
    print(f"  wrote {out}  {size/1e6:.1f} MB  ({size/max(1,raw):.1%} of raw)")

    # --- read it back and check every checksum ---------------------------
    print("  verifying the zip by reading it back ...")
    bad = 0
    with zipfile.ZipFile(out) as z:
        names = set(z.namelist())
        for name, rec in index["corpora"].items():
            for fn, want in rec["sha256"].items():
                arc = f"{name}/{fn}"
                if arc not in names:
                    print(f"    MISSING IN ZIP  {arc}")
                    bad += 1
                    continue
                h = hashlib.sha256()
                with z.open(arc) as f:
                    while True:
                        b = f.read(1 << 20)
                        if not b:
                            break
                        h.update(b)
                if h.hexdigest() != want:
                    print(f"    CHECKSUM DIFFERS  {arc}")
                    bad += 1
    if bad:
        raise SystemExit(f"  {bad} entries did not verify. DO NOT rely on this zip.")
    print("  every entry verified against the archive checksums.")
    print("  this zip can restart the factory from nothing.")


def unpack(zpath, dest):
    os.makedirs(dest, exist_ok=True)
    print(f"  extracting {zpath} -> {dest}")
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest)
    ipath = os.path.join(dest, "archive.json")
    if not os.path.exists(ipath):
        print("  extracted, but no archive.json inside; cannot verify")
        return 0
    return verify(dest)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("establish")
    e.add_argument("--src", required=True, help="comma-separated corpora")
    e.add_argument("--archive", required=True)
    v = sub.add_parser("verify")
    v.add_argument("--archive", required=True)
    r = sub.add_parser("restore")
    r.add_argument("--archive", required=True)
    r.add_argument("--pool", required=True)
    r.add_argument("--layer", help="comma-separated; default all")
    pk = sub.add_parser("pack")
    pk.add_argument("--archive", required=True)
    pk.add_argument("--out", required=True)
    pk.add_argument("--extra", default="",
                    help="comma-separated extra files (corpus id lists etc.)")
    up = sub.add_parser("unpack")
    up.add_argument("--zip", required=True, dest="zpath")
    up.add_argument("--dest", required=True)
    a = ap.parse_args()

    if a.cmd == "establish":
        establish([s for s in a.src.split(",") if s.strip()], a.archive)
    elif a.cmd == "verify":
        sys.exit(verify(a.archive))
    elif a.cmd == "pack":
        pack(a.archive, a.out,
             [e for e in a.extra.split(",") if e.strip()])
    elif a.cmd == "unpack":
        sys.exit(unpack(a.zpath, a.dest))
    else:
        restore(a.archive, a.pool,
                [l for l in (a.layer or "").split(",") if l.strip()] or None)


if __name__ == "__main__":
    main()
