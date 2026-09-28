#!/usr/bin/env python3
"""Does a stalled encoder reach back and stall the factory?

This is the ONE failure that makes the FIFO topology worse than what it replaces.
Everything else the splitter does wrong costs a listener some audio; this costs
the work itself, because scsynth's disk thread blocking is a dropout in the
factory's own output.

METHOD. A writer pushes float32 stereo into the FIFO at exactly realtime rate,
the way scsynth would, and TIMES EVERY WRITE. Partway through, the encoder is
SIGSTOPped -- a frozen consumer that never closes its pipe, which is what a
hung Icecast looks like and is strictly worse than one that dies. The writer
keeps going. Then SIGCONT.

PASS REQUIRES ALL OF:
  1. no single write blocks longer than 250 ms while the encoder is frozen
     (scsynth's disk thread would survive a hiccup; it would not survive a wait
     proportional to the outage)
  2. segments keep being produced during the freeze -- ingestion is independent
     of the stream, which is the point of splitting at all
  3. every published segment decodes and is full length; none is a .part
  4. drops are counted rather than silent. An unreported drop is the failure
     mode this project has hit repeatedly: .try around an unchecked operation,
     the 0-byte second chunk, the encoder reported "up" by a pgrep that matched
     the wrong process.
"""
import os
import signal
import subprocess
import sys
import time

import wave

import numpy as np

SR, CH, ITEM = 44100, 2, 8
READ = 1 << 16
HERE = os.path.dirname(os.path.abspath(__file__))
SPL = os.path.join(os.path.dirname(HERE), "workdir_music", "stream", "fifo_splitter.py")

FIFO = "/tmp/splitter_test.fifo"
SEGDIR = "/tmp/splitter_test_segs"
ENCOUT = "/tmp/splitter_test_enc.raw"


def enc_targets(splitter_pid):
    """The encoder and its shell -- and NOT the splitter.

    The first version of this used `pgrep -f "cat > ..."`, which matched THREE
    processes: the shell, the encoder, and THE SPLITTER ITSELF, whose own command
    line carries that string as the value of --encoder-cmd. The test therefore
    froze the process it was testing, the pipe stopped being drained, the writer
    blocked, and the run hung at 8.2 s looking exactly like a design failure.

    Matching by DESCENT instead of by command-line text: children of the splitter
    are the encoder's shell and, once the shell execs, the encoder. The splitter
    cannot be its own child, so the ambiguity is structurally impossible rather
    than merely unlikely.
    """
    out = subprocess.run(["pgrep", "-P", str(splitter_pid)],
                         capture_output=True, text=True).stdout.split()
    pids = [int(p) for p in out]
    for p in list(pids):                       # grandchildren, if sh forked
        more = subprocess.run(["pgrep", "-P", str(p)],
                              capture_output=True, text=True).stdout.split()
        pids += [int(q) for q in more]
    return pids


def cleanup():
    for p in (FIFO, ENCOUT):
        try:
            os.unlink(p)
        except OSError:
            pass
    if os.path.isdir(SEGDIR):
        for f in os.listdir(SEGDIR):
            os.unlink(os.path.join(SEGDIR, f))


def main():
    cleanup()
    os.makedirs(SEGDIR, exist_ok=True)
    os.mkfifo(FIFO)

    proc = subprocess.Popen(
        [sys.executable, SPL, "--fifo", FIFO, "--segdir", SEGDIR,
         "--encoder-cmd", f"cat > {ENCOUT}",
         "--segment-seconds", "3", "--encoder-buffer", "2",
         "--segment-buffer", "20", "--ring-gb", "1", "--status-every", "5"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    time.sleep(2.0)

    fd = os.open(FIFO, os.O_WRONLY)
    print("\n  writer attached, pushing at realtime rate")

    per = READ / (SR * ITEM)              # seconds of audio per block
    total = 30.0
    freeze_at, thaw_at = 8.0, 18.0
    n = int(total / per)
    phase = 0.0
    latencies, frozen_lat = [], []
    enc_pid = None
    t0 = time.time()
    froze = thawed = False

    for i in range(n):
        t = (np.arange(READ // ITEM) + phase) / SR
        phase += READ // ITEM
        x = np.stack([0.2 * np.sin(2 * np.pi * 220 * t),
                      0.2 * np.sin(2 * np.pi * 331 * t)], axis=1).astype("<f4")
        blk = x.tobytes()

        elapsed = time.time() - t0
        if not froze and elapsed >= freeze_at:
            targets = enc_targets(proc.pid)
            for p in targets:
                try:
                    os.kill(p, signal.SIGSTOP)
                    enc_pid = p
                except ProcessLookupError:
                    pass
            print(f"  [{elapsed:5.1f}s] encoder FROZEN ({len(targets)} pid(s): "
                  f"{targets})")
            froze = True
        if froze and not thawed and elapsed >= thaw_at:
            for p in enc_targets(proc.pid):
                try:
                    os.kill(p, signal.SIGCONT)
                except ProcessLookupError:
                    pass
            print(f"  [{elapsed:5.1f}s] encoder THAWED")
            thawed = True

        w0 = time.time()
        os.write(fd, blk)
        lat = time.time() - w0
        latencies.append(lat)
        if froze and not thawed:
            frozen_lat.append(lat)

        # hold realtime pace
        target = t0 + (i + 1) * per
        slack = target - time.time()
        if slack > 0:
            time.sleep(slack)

    os.close(fd)
    time.sleep(3.0)
    proc.terminate()
    try:
        log = proc.communicate(timeout=5)[0]
    except subprocess.TimeoutExpired:
        proc.kill(); log = ""

    lat = np.array(latencies) * 1000
    fro = np.array(frozen_lat) * 1000 if frozen_lat else np.array([0.0])
    segs = sorted(f for f in os.listdir(SEGDIR) if f.endswith(".wav"))
    parts = [f for f in os.listdir(SEGDIR) if f.endswith(".part")]

    print()
    print(f"  write latency overall   median {np.median(lat):7.3f} ms   "
          f"max {lat.max():8.3f} ms")
    print(f"  write latency FROZEN    median {np.median(fro):7.3f} ms   "
          f"max {fro.max():8.3f} ms   ({len(fro)} writes)")
    print(f"  segments published      {len(segs)}   stray .part files {len(parts)}")

    ok_len = True
    for s in segs:
        # Opened the way self_ingest opens it. A segment that this cannot read
        # is a segment the ingester would starve on.
        with wave.open(os.path.join(SEGDIR, s)) as w:
            dur = w.getnframes() / w.getframerate()
            bad = (abs(dur - 3.0) > 0.02 or w.getframerate() != SR
                   or w.getsampwidth() != 4 or w.getnchannels() != CH)
        if bad:
            ok_len = False
            print(f"    BAD segment {s}: {dur:.3f}s @ {w.getframerate()}")

    drops = [l for l in log.splitlines() if "drop" in l]
    print(f"  splitter reported drops : {drops[-1].strip() if drops else 'no status line'}")

    print()
    checks = [
        ("writer never blocked while encoder frozen", fro.max() < 250.0),
        ("segments produced during the freeze", len(segs) >= 6),
        ("every segment full length and valid", ok_len),
        ("no half-written file left visible", len(parts) == 0),
        ("drops counted, not silent", bool(drops)),
    ]
    for name, good in checks:
        print(f"  [{'PASS' if good else 'FAIL'}] {name}")
    cleanup()
    print()
    return 0 if all(g for _, g in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
