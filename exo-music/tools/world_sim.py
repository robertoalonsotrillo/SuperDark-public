#!/usr/bin/env python3
"""The world channel: an exogenous signal the factory does not generate.

Everything this factory reacts to is something it produced. The corpus is fixed
and chosen; the descriptors are computed from its own output; the operator's
memory is its own transition history; self-ingestion eats its own grains. This
is the only input whose statistics the architect does not control, which makes it
the only component that can falsify "the whole system is a closed loop dressed as
an open one."

See docs/WORLD_CHANNEL_DESIGN.md for the argument. In short:

THE STATISTICS ARE CHOSEN TO BE UNLIKE THE FACTORY'S OWN WALK, and that is the
load-bearing decision. The target walk is bounded, reflecting, isotropic and
effectively memoryless. If the world signal looked like it, no measurement could
distinguish following from coinciding and the experiment would be unfalsifiable
before it started. So the world gets three properties the walk lacks:

    1/f spectrum      long-range correlation, against the walk's white steps
    drifting mean     non-stationary over hours, against a stationary walk
    jump events       rare discontinuities, against a bounded continuous step

A trajectory that acquires a negative spectral slope, or that breaks within
seconds of an injected jump, is carrying the world's fingerprint. One that does
neither is not coupled, whatever the weight is set to.

SYNTHETIC FIRST, AND NOT FOR CONVENIENCE. A real feed makes the claim stronger
and makes it untestable in the short term, because its events arrive when they
arrive. The simulator emits jumps on demand, so the coupling measurement can be
validated against known ground truth before anything depends on it. The wire
format does not change when a real source replaces this one.

    python3 tools/world_sim.py --port 57120              # the live language port
    python3 tools/world_sim.py --port 57120 --jump-every 300
    python3 tools/world_sim.py --dry-run --seconds 20    # print, send nothing

THE PORT IS NOT 57120 BY DEFAULT AND MUST BE READ FROM THE FACTORY. sclang takes
the first free port from 57120 upward, so any earlier instance -- including a
wedged one still holding its socket -- pushes it along. On 25 Aug it landed on
57124 while a sender used 57120 and the packets went nowhere, with nothing
reporting a problem at either end. The factory prints and logs
`LANGPORT <n>`; use that number.
"""
import argparse
import math
import random
import socket
import struct
import sys
import time

NCHAN = 6          # one per descriptor coordinate; the mapping is positional
RATE = 1.0         # Hz


# ---- OSC encoding, by hand ------------------------------------------------
# Six floats to one address once a second does not justify a dependency, and a
# dependency here would have to be installed on whatever machine ends up
# carrying a real feed.
def osc_pad(b):
    return b + b"\0" * (4 - (len(b) % 4) if len(b) % 4 else 4)


def osc_message(addr, floats):
    return (osc_pad(addr.encode())
            + osc_pad(("," + "f" * len(floats)).encode())
            + b"".join(struct.pack(">f", float(v)) for v in floats))


class PinkChannel:
    """One channel: 1/f noise, a drifting mean, and occasional jumps.

    1/f BY SUMMING OCTAVE-SPACED RANDOM WALKS (Voss-McCartney). Each generator
    updates half as often as the one below it, so the summed spectrum falls at
    roughly 3 dB per octave. Chosen over filtering white noise because the
    correlation time is then explicit in the number of octaves rather than
    hidden in filter coefficients -- and the point of this signal is that its
    statistics are known and stated in advance.
    """

    def __init__(self, rng, octaves=6):
        self.rng = rng
        self.octaves = octaves
        self.rows = [rng.uniform(-1, 1) for _ in range(octaves)]
        self.counter = 0
        # the slow non-stationary component: a mean that wanders over hours, so
        # that a long run is not sampling one stationary distribution
        self.drift = rng.uniform(-0.2, 0.2)
        self.drift_target = rng.uniform(-0.3, 0.3)
        self.jump = 0.0

    def step(self):
        self.counter += 1
        # update row k every 2^k ticks -- the octave structure that makes it 1/f
        for k in range(self.octaves):
            if self.counter % (1 << k) == 0:
                self.rows[k] = self.rng.uniform(-1, 1)
        pink = sum(self.rows) / self.octaves

        # drift: an Ornstein-Uhlenbeck-ish crawl toward a slowly reselected
        # target, so the mean is non-stationary without running away
        self.drift += (self.drift_target - self.drift) * 0.0008
        if self.rng.random() < 0.0005:
            self.drift_target = self.rng.uniform(-0.3, 0.3)

        # jumps decay back rather than persisting: a discontinuity followed by a
        # return is far easier to detect in a response measurement than a step
        self.jump *= 0.97

        v = 0.5 + 0.32 * pink + self.drift + self.jump
        return min(1.0, max(0.0, v))

    def kick(self, size):
        self.jump += size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=57120,
                    help="sclang's LANGPORT -- read it from the factory, do not assume")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--jump-every", type=float, default=0,
                    help="seconds between injected discontinuities; 0 disables")
    ap.add_argument("--jump-size", type=float, default=0.35)
    ap.add_argument("--seconds", type=float, default=0, help="0 runs for ever")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--log", default=None,
                    help="append what was sent, so the coupling measurement has "
                         "the sender's own record and not only the factory's")
    a = ap.parse_args()

    rng = random.Random(a.seed)
    chans = [PinkChannel(rng) for _ in range(NCHAN)]
    sock = None if a.dry_run else socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    logf = open(a.log, "a") if a.log else None

    print(f"  world -> {a.host}:{a.port}   {NCHAN} channels at {RATE} Hz")
    if not a.dry_run:
        print(f"  IF THE FACTORY'S LANGPORT IS NOT {a.port} THESE PACKETS GO NOWHERE")
        print(f"  and nothing at either end will report it. Check the factory's")
        print(f"  LANGPORT line before trusting a null result.")
    if a.jump_every > 0:
        print(f"  injecting a jump every {a.jump_every:.0f} s, size {a.jump_size}")
    print()

    t0 = time.time()
    nxt = t0
    last_jump = t0
    sent = 0
    try:
        while True:
            now = time.time()
            if a.seconds and (now - t0) >= a.seconds:
                break

            vals = [c.step() for c in chans]

            jumped = 0
            if a.jump_every > 0 and (now - last_jump) >= a.jump_every:
                # every channel jumps together, so the event is unambiguous in
                # the response measurement -- a per-channel jump would be hard
                # to separate from the 1/f background
                for c in chans:
                    c.kick(rng.choice([-1, 1]) * a.jump_size)
                last_jump = now
                jumped = 1
                print(f"  [{now - t0:7.0f}s] JUMP")

            if sock:
                sock.sendto(osc_message("/world", vals), (a.host, a.port))
            sent += 1

            if logf:
                logf.write(f"{now:.3f},{jumped}," +
                           ",".join(f"{v:.5f}" for v in vals) + "\n")
                logf.flush()

            if a.dry_run and sent % 5 == 1:
                print("  " + "  ".join(f"{v:.3f}" for v in vals))

            nxt += 1.0 / RATE
            time.sleep(max(0.0, nxt - time.time()))
    except KeyboardInterrupt:
        pass
    finally:
        if logf:
            logf.close()

    print(f"\n  sent {sent} messages over {time.time() - t0:.0f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
