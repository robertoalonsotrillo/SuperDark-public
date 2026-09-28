#!/usr/bin/env python3
"""Notice, and RECORD, the things that quietly ruin a long run.

WHY THIS EXISTS
On 28 Aug an 8 h run lost 85% of its data to a laptop sleep: the clock jumped
20,309 s, the FIFO filled 77,491 times, and not one charter metric noticed. The
run was read as data. Tonight the external SSD disconnected on its own and took
the corpora, the pool, the window log and both experiment arms out of reach; the
factory died and the stream mount still answered 200.

The pattern in both is the same and it is the dangerous one: the failure is
INVISIBLE TO THE THING BEING MEASURED. A metric computed over windows cannot see
that windows stopped happening, and a page showing green cannot see that its
source is gone. So this watches from outside and writes down what it saw.

WHAT IT REFUSES TO DO
It does not restart anything. A watchdog that silently repairs a run produces a
log with an unmarked seam in it, which is worse than a run that stopped, because
the seam is then read as continuous data. This records and shouts; recovery is a
decision for a person who can see what happened.

WHERE IT WRITES, AND WHY THAT MATTERS
/tmp, on the INTERNAL disk. The event this most needs to survive is the external
disk vanishing, and a log stored on the disk it is watching cannot report that
disk's disappearance.

    python3 tools/run_integrity.py --watch          # foreground
    python3 tools/run_integrity.py --report         # what happened overnight
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import time

SSD = "/Volumes/FMA"
RENDERS = "/Volumes/FMA/superdark/renders"
EVENTS = "/tmp/superdark_integrity.jsonl"
PERIOD = 20.0
# A monotonic-vs-wall discrepancy above this is a system sleep or a clock step.
# Well above ordinary scheduling jitter at a 20 s period, well below the 20,309 s
# jump that went unnoticed in August.
SLEEP_TOL = 8.0


def count_lines(path, prefix):
    """How many lines in the window log start with prefix. None if unreadable."""
    try:
        with open(path, errors="replace") as fh:
            return sum(1 for line in fh if line.startswith(prefix))
    except OSError:
        return None


# THE PROBES, AND WHY THEY ARE DECLARED RATHER THAN INLINED.
#
# 17 Sept 2026. scsynth segfaulted at 06:02 and this monitor did not say so.
# The probe read `alive("scsynth -u 57700")`; start_loop.sh boots the server on
# `SCPORT="${SCPORT:-57110}"`. The pattern had never matched a running process in
# its life. Across 52 recorded events spanning many runs the subject `scsynth`
# appears ZERO times -- only sclang (23) and ssd (3) ever fired.
#
# The failure is not the typo. It is that A PROBE PINNED FALSE IS SILENT, and so
# is a probe correctly reporting a healthy process. `watch()` emitted only on
# TRANSITIONS, so "wired to a pattern that matches nothing" and "watching
# something that never broke" produced identical output: nothing at all. This
# file's own header calls the dangerous failure the one that is invisible to the
# thing being measured, and its own instrument had that failure.
#
# Two changes follow from that. The initial state is emitted, so a probe that is
# down at start says so on line one instead of waiting for a transition that
# cannot come. And a probe that has never once matched announces ITSELF, with its
# pattern quoted, because that is the only evidence that distinguishes the two
# silences.
#
# `exact` uses pgrep -x on the process name. The scsynth probe broke because it
# encoded a PORT NUMBER, which is configuration, into a liveness check. The
# process name is not configuration.
PROBES = {
    "sclang":   {"pat": "sclang -l",             "exact": False},
    "scsynth":  {"pat": "scsynth",               "exact": True},
    "splitter": {"pat": "fifo_splitter.py --fifo", "exact": False},
}
# A probe may legitimately be down for a while at the start of a run. Below this
# it is "not up yet"; above it, with no match ever, it is "wired to nothing".
NEVER_GRACE = 300.0


def alive(pat, exact=False):
    return subprocess.run(["pgrep", "-x" if exact else "-f", pat],
                          capture_output=True).returncode == 0


def probe_all():
    return {k: alive(v["pat"], v["exact"]) for k, v in PROBES.items()}


def newest_log():
    c = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")),
               key=os.path.getmtime) if os.path.isdir(RENDERS) else []
    return c[-1] if c else None


def windows(path):
    """Last window number seen, so a stalled factory is distinguishable from a
    dead one: a dead factory has no process, a stalled one has a process and a
    log that stopped growing."""
    if not path or not os.path.exists(path):
        return None
    last = None
    try:
        with open(path, "rb") as f:
            f.seek(max(0, os.path.getsize(path) - 8192))
            for line in f.read().decode(errors="replace").splitlines():
                if line.startswith("MASTER "):
                    try:
                        last = int(line.split()[1].split(",")[0])
                    except (ValueError, IndexError):
                        pass
    except OSError:
        return None
    return last


def emit(kind, **kw):
    rec = {"t": time.time(), "iso": time.strftime("%Y-%m-%dT%H:%M:%S"),
           "kind": kind}
    rec.update(kw)
    with open(EVENTS, "a") as f:
        f.write(json.dumps(rec) + "\n")
    print(f"  {rec['iso']}  {kind}  "
          + " ".join(f"{k}={v}" for k, v in kw.items()), flush=True)


def watch():
    emit("start", ssd=os.path.isdir(SSD), log=os.path.basename(newest_log() or ""))
    mono, wall = time.monotonic(), time.time()
    began = time.monotonic()
    state = dict(probe_all(), ssd=os.path.isdir(SSD))
    # EMIT THE INITIAL STATE. Previously only transitions were recorded, so a
    # subject that was down when the monitor started stayed unmentioned for the
    # whole run. On 17 Sept that silence was indistinguishable from health.
    emit("initial", **{k: ("up" if v else "DOWN") for k, v in state.items()})
    ever = {k: v for k, v in state.items()}
    announced = set()
    lastw, stalls = windows(newest_log()), 0
    # start from what is already there, so a restart does not re-report history
    lastfs = count_lines(newest_log() or "", "FILL_STALL") or 0

    while True:
        time.sleep(PERIOD)
        dm, dw = time.monotonic() - mono, time.time() - wall
        mono, wall = time.monotonic(), time.time()
        # Wall advancing far beyond monotonic is the signature of a sleep: the
        # monotonic clock does not run while the machine is suspended.
        if abs(dw - dm) > SLEEP_TOL:
            emit("CLOCK_JUMP", seconds=round(dw - dm, 1),
                 note="system slept or the clock stepped; windows in this "
                      "interval are not contiguous and must be excluded")

        now = dict(probe_all(), ssd=os.path.isdir(SSD))
        for k in now:
            if now[k]:
                ever[k] = True
            if now[k] != state[k]:
                emit("UP" if now[k] else "DOWN", what=k)
        state = now

        # A PROBE THAT HAS NEVER MATCHED ANYTHING REPORTS ITSELF.
        # This is the check that would have caught the scsynth port typo on the
        # first run instead of on the night it mattered. Without it the only
        # evidence of a mis-wired probe is an absence, and an absence is exactly
        # what a healthy subject produces too.
        if time.monotonic() - began > NEVER_GRACE:
            for k in PROBES:
                if not ever[k] and k not in announced:
                    announced.add(k)
                    emit("PROBE_NEVER_MATCHED", what=k,
                         pattern=PROBES[k]["pat"],
                         mode="pgrep -x" if PROBES[k]["exact"] else "pgrep -f",
                         note="this probe has not matched a single process "
                              "since the monitor started. Either the subject "
                              "has been down the whole run, or the pattern is "
                              "wrong and this probe is watching nothing. Both "
                              "are worth knowing and neither is visible from "
                              "the probe staying quiet.")

        w = windows(newest_log())
        if w is not None and lastw is not None:
            if w == lastw:
                stalls += 1
                # Windows are 11.7 s; three periods with no new one is a stall,
                # not slow scheduling.
                if stalls == 3:
                    emit("STALLED", window=w,
                         note="no new window in 60 s while the factory is up")
            else:
                if stalls >= 3:
                    emit("RESUMED", window=w, stalled_at=lastw)
                stalls = 0
        lastw = w if w is not None else lastw

        # VOICE-FILL STALLS, WHICH NOTHING WATCHED. 15 Sept 2026: a run logged
        # 15 FILL_STALL across 453 windows and every instrument said it was
        # healthy -- charter passed on all eight metrics, the public panel was
        # fresh, and this monitor reported clean. The factory was quietly
        # failing to reach its requested voice count on 3% of windows and the
        # only reason anyone noticed was that the log got read by hand before
        # the factory was stopped.
        #
        # This monitor already watches the things that stop a run. A FILL_STALL
        # does not stop a run; it degrades one, silently, which is the failure
        # this file's own header calls the dangerous one.
        lg = newest_log()
        if lg:
            n = count_lines(lg, "FILL_STALL")
            if n is not None and n > lastfs:
                emit("FILL_STALL", total=n, added=n - lastfs,
                     log=os.path.basename(lg),
                     note="a voice slot could not be filled: the machine "
                          "returned Nil. The run continues with fewer voices "
                          "than it asked for, so any measurement taken across "
                          "this stretch is of a degraded factory.")
                lastfs = n


def report():
    if not os.path.exists(EVENTS):
        print("  no integrity log; the monitor has not run")
        return 1
    ev = [json.loads(l) for l in open(EVENTS) if l.strip()]
    bad = [e for e in ev if e["kind"] in
           ("CLOCK_JUMP", "DOWN", "STALLED", "FILL_STALL",
            "PROBE_NEVER_MATCHED")]
    print()
    print(f"  {len(ev)} events, {len(bad)} of them faults")
    for e in ev:
        if e["kind"] == "start":
            print(f"    {e['iso']}  monitor started")
        elif e["kind"] == "initial":
            sub = " ".join(f"{k}={v}" for k, v in e.items()
                           if k not in ("t", "iso", "kind"))
            print(f"    {e['iso']}  at start: {sub}")
    for e in bad:
        extra = e.get("what") or e.get("seconds") or e.get("window")
        print(f"    {e['iso']}  {e['kind']:20} {extra}")
    print()
    # A MIS-WIRED PROBE OUTRANKS EVERYTHING BELOW IT. If an instrument was not
    # watching, the rest of this report is a statement about the instrument, not
    # about the run.
    dead = [e for e in bad if e["kind"] == "PROBE_NEVER_MATCHED"]
    if dead:
        print("  A PROBE NEVER MATCHED ANYTHING. Until this is resolved, the")
        print("  absence of faults below is not evidence that there were none.")
        for e in dead:
            print(f"    {e['what']:10} pattern {e.get('pattern','?')!r} "
                  f"via {e.get('mode','?')}")
        print()
    if any(e["kind"] == "CLOCK_JUMP" for e in bad):
        print("  A CLOCK JUMP OCCURRED. The run is not one continuous series.")
        print("  Do not read metrics across it; split at the jump or discard.")
    elif any(e["kind"] == "DOWN" for e in bad):
        print("  Something went down mid-run. Check what, and when, before")
        print("  treating the log as a single experiment.")
    elif not bad:
        print("  Clean. No sleeps, no dropouts, no stalls. The run is readable")
        print("  as one continuous series.")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--watch", action="store_true")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    sys.exit(report() if a.report else (watch() or 0))
