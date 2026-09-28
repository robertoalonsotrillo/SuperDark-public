#!/usr/bin/env python3
"""Would a push expose a credential? Test the VALUES, never trust the ignore file.

WHY THIS IS A TOOL AND NOT A GLANCE
On 31 Aug `.stream_secrets` and `icecast.xml` were about to be pushed publicly.
The first check missed them because `git status` collapses an untracked directory
to a single entry, so the files inside were never listed. The fix then was to test
the actual secret strings against the actual push content, and that is what this
does, every time, instead of relying on .gitignore being right.

It prints KEY NAMES and match locations. It never prints a value, because a tool
that reports a leak by echoing the secret into a terminal log has created a second
one.

A match is not automatically a leak: RELAY_HOST is a public hostname and appears
in scripts by design. The tool separates values that look like credentials from
values that look like configuration, and says which is which.

    python3 tools/secret_scan.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(ROOT)
SECRETS = os.path.join(ROOT, "workdir_music", "stream", ".stream_secrets")

# Keys whose values are public by design. Everything else is treated as a
# credential until shown otherwise.
PUBLIC = {"RELAY_HOST", "MOUNT", "TUNNEL_PORT", "ICECAST_REMOTE", "PORT"}


def parse(path):
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path):
        line = line.strip()
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out


def push_content():
    """Everything a push would carry: the diff against HEAD plus every untracked
    file, with directories expanded -- the exact thing the first check missed."""
    blobs = []
    d = subprocess.run(["git", "-C", REPO, "diff", "HEAD"],
                       capture_output=True, text=True).stdout
    blobs.append(("<staged diff>", d))
    st = subprocess.run(["git", "-C", REPO, "status", "--porcelain",
                         "--untracked-files=all"],
                        capture_output=True, text=True).stdout
    for line in st.splitlines():
        if line.startswith("??"):
            p = os.path.join(REPO, line[3:].strip())
            if os.path.isfile(p) and os.path.getsize(p) < 4_000_000:
                try:
                    blobs.append((line[3:].strip(),
                                  open(p, encoding="utf-8", errors="replace").read()))
                except OSError:
                    pass
    return blobs


def main():
    sec = parse(SECRETS)
    if not sec:
        print("  no .stream_secrets found; nothing to check")
        return 0
    blobs = push_content()
    print(f"\n  {len(sec)} keys, checked against {len(blobs)} blobs a push would carry\n")
    print(f"  {'key':18} {'len':>4}  {'class':14} where it appears")
    print("  " + "-" * 74)
    leaked = []
    for k, v in sorted(sec.items()):
        if len(v) < 6:
            cls = "too short"
            hits = []
        else:
            cls = "public" if k in PUBLIC else "CREDENTIAL"
            hits = [name for name, text in blobs if v in text]
        mark = ", ".join(hits[:3]) if hits else "nowhere"
        print(f"  {k:18} {len(v):4d}  {cls:14} {mark}")
        if hits and cls == "CREDENTIAL":
            leaked.append((k, hits))
    print()
    if leaked:
        print("  DO NOT PUSH. These credentials appear in content a push would carry:")
        for k, hits in leaked:
            print(f"    {k} -> {', '.join(hits)}")
        return 1
    print("  CLEAN. No credential value appears in the diff or in any untracked file.")
    ig = []
    for f in (".stream_secrets", "icecast.xml"):
        p = os.path.join(ROOT, "workdir_music", "stream", f)
        if os.path.exists(p):
            r = subprocess.run(["git", "-C", REPO, "check-ignore", "-q", p])
            ig.append((f, r.returncode == 0))
    for f, ok in ig:
        print(f"    {f}: {'ignored' if ok else 'NOT IGNORED — fix before pushing'}")
    return 0 if all(ok for _, ok in ig) else 1


if __name__ == "__main__":
    sys.exit(main())
