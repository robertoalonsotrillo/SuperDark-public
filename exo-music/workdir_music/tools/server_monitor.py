#!/usr/bin/env python3
"""Ask scsynth what it is actually doing, once every N seconds.

WHY THIS EXISTS
---------------
The shadow factory logged 77,491 `command FIFO full` messages beginning at
window ~100 (21 minutes in) on a machine it had entirely to itself, then ran
another 7.75 hours with the server silently DROPPING OSC commands. Nothing in
the factory's own metrics registered it: MASTER lines kept arriving, machines
kept being written, audio kept playing.

scsynth's command FIFO is a fixed-size ring drained by the AUDIO thread. There
are only two ways to fill it:

  (a) the language sends commands faster than the audio thread drains them
      -- a burst problem, and the buffer loader was already batched for this;
  (b) the audio thread is too busy to drain it -- a DSP OVERLOAD problem,
      which is what happens if synths accumulate and never free.

These have opposite fixes, so guessing is expensive. /status answers it
directly: numSynths and numUGens say whether nodes are leaking, peakCPU says
whether the audio thread is saturated. Sampling both against the window counter
and the FIFO-full count says which one moved FIRST.

    python3 tools/server_monitor.py --port 57110 --log /tmp/live.log
"""
import argparse
import os
import re
import socket
import struct
import time


def osc_msg(addr, tags=","):
    def pad(b):
        return b + b"\0" * (4 - len(b) % 4)
    return pad(addr.encode()) + pad(tags.encode())


def parse_reply(data):
    """Decode /status.reply by reading its typetag string, not by assuming a
    fixed layout -- the sample-rate fields are floats in some builds and
    doubles in others, and a hardcoded struct silently misreads the CPU."""
    end = data.index(b"\0")
    addr = data[:end].decode()
    i = (end + 4) & ~3
    if not data[i:i + 1] == b",":
        return addr, []
    tend = data.index(b"\0", i)
    tags = data[i + 1:tend].decode()
    i = (tend + 4) & ~3
    out = []
    for t in tags:
        if t == "i":
            out.append(struct.unpack_from(">i", data, i)[0]); i += 4
        elif t == "f":
            out.append(struct.unpack_from(">f", data, i)[0]); i += 4
        elif t == "d":
            out.append(struct.unpack_from(">d", data, i)[0]); i += 8
    return addr, out


def factory_window(logpath):
    if not logpath or not os.path.exists(logpath):
        return None
    last = None
    try:
        with open(logpath, errors="replace") as f:
            for line in f:
                if line.startswith("t=") and " win=" in line:
                    m = re.search(r"win=(\d+)", line)
                    if m:
                        last = int(m.group(1))
    except OSError:
        pass
    return last


def fifo_count(logpath):
    if not logpath or not os.path.exists(logpath):
        return 0
    n = 0
    with open(logpath, errors="replace") as f:
        for line in f:
            if "command FIFO full" in line:
                n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=57110)
    ap.add_argument("--log", help="the factory's stdout log")
    ap.add_argument("--every", type=float, default=15.0)
    ap.add_argument("--out", default="/tmp/srvmon.csv")
    a = ap.parse_args()

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(2.0)
    t0 = time.time()

    new = not os.path.exists(a.out)
    f = open(a.out, "a", buffering=1)          # line-buffered: readable live
    if new:
        f.write("t,win,ugens,synths,groups,defs,avgcpu,peakcpu,fifofull\n")

    hdr = f"  {'t':>6} {'win':>5} {'synths':>7} {'ugens':>7} {'avgCPU':>7} {'peakCPU':>8} {'FIFOfull':>9}"
    print(hdr); print("  " + "-" * (len(hdr) - 2), flush=True)

    while True:
        el = time.time() - t0
        try:
            s.sendto(osc_msg("/status"), ("127.0.0.1", a.port))
            data, _ = s.recvfrom(4096)
            _, v = parse_reply(data)
        except (socket.timeout, OSError, ValueError, struct.error):
            v = []
        if len(v) >= 7:
            _, ugens, synths, groups, defs, avg, peak = v[:7]
        else:
            ugens = synths = groups = defs = -1
            avg = peak = -1.0
        win = factory_window(a.log)
        ff = fifo_count(a.log)
        f.write(f"{el:.0f},{win if win is not None else ''},{ugens},{synths},"
                f"{groups},{defs},{avg:.2f},{peak:.2f},{ff}\n")
        print(f"  {el:6.0f} {str(win) if win is not None else '-':>5} {synths:>7} "
              f"{ugens:>7} {avg:>6.1f}% {peak:>7.1f}% {ff:>9}", flush=True)
        time.sleep(a.every)


if __name__ == "__main__":
    main()
