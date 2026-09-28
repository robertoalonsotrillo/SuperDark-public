#!/usr/bin/env python3
"""The adversarial layer: manufacture real failures in a shadow factory.

WHY THIS EXISTS (P502)
----------------------
Judges scored only against the charter's metrics will collude with the producers:
"if that were the case, then evaluator agents and productive agents would be
easily incentivized to collaborate in the direction of overfitting." The second
reward signal is REALIZED CONSEQUENCE -- "whether a given verdict predicted real
downstream outcomes... a judge that flagged some anomalous behavior should be
duly incentivized only if that anomalous behavior preceded a true regression."

But real regressions are rare in a healthy factory. Measured over the six-hour
run: 108 failure windows in 1,950, and 102 of those were the same kind. P502:
"this reward mechanism is not only sparse but shrinking over time. To create
enough of this kind of scoring to be useful, we need to actually farm and
manufacture it, which we do by inducing a level of adversarial activity."

WHY A SHADOW FACTORY AND NOT THE LIVE ONE
-----------------------------------------
Roberto: "it may be risky though, as the output is audible." Correct, and the
paper's answer is P458: "A well-designed 'hard world' is one in which
IRREVERSIBLE HARM IS IMPOSSIBLE." The partition for an audible factory:

  irreversible, must be impossible   killing the factory (it forfeits its
                                     accumulated coherence and re-warms for
                                     eight minutes), deleting corpus,
                                     corrupting charter or memory
  reversible, can be priced          a bad-sounding ninety seconds

Rather than police that boundary on the instrument people listen to, the shadow
runs the same code on the same corpus, is never streamed, and is perturbed
freely. Its failures are real -- P506 insists they cannot be staged -- they are
just not audible to anyone. This also builds P318's economy as a side effect.

WHAT IT MAY AND MAY NOT TOUCH
-----------------------------
ONLY policy.json, which the factory re-reads every window, and only keys whose
effect reverses when the value is restored. It cannot kill processes, cannot
touch the corpus, cannot write machines, cannot edit the charter or kernel, and
cannot alter memory. Those are the hard casts (P456: "inviolable from both the
inside of the factory and its outside"), and a chaos monkey with reach into them
would not be manufacturing failure, it would be ending the factory.

Every perturbation AUTO-REVERTS after a bounded number of windows, and every one
is logged with the window it started and ended, so realized-consequence scoring
can ask whether a judge saw it coming.

    python3 tools/chaos.py --mutable mutable_shadow --log <shadow live log>
"""
import argparse
import json
import os
import random
import re
import time

# key -> (harmful value, why this is a real failure and not merely a change)
PERTURBATIONS = {
    "voices_max": (1,
        "collapses polyphony to a single voice; texture thins to nothing"),
    "micro_continuity": (0.0,
        "the radio effect, deliberately: every grain cuts to unrelated music"),
    "target_drift": (0.9,
        "the target lurches across descriptor space instead of wandering, so no "
        "neighbourhood is coherent"),
    "novelty_penalty": (0.95,
        "punishes any machine that played recently, so the vocabulary thrashes"),
    "temperature": (12.0,
        "sharpens selection to argmax: one machine wins and keeps winning, "
        "which is the convergence the whole project is trying to avoid"),
    "master_gain": (0.15,
        "drops level toward the amplitude floor, manufacturing silence_run"),
    "section_pull": (0.0,
        "sections stop being regions; the target wanders out of every one"),
    "path_max": (2,
        "the grain path collapses to two grains, so every voice repeats them"),
}


def current_window(logpath):
    """Read the factory's own window counter, so perturbations are timed in the
    factory's clock rather than in wall time. A stalled factory should not have
    its perturbations expire while it is not producing anything."""
    if not logpath or not os.path.exists(logpath):
        return None
    last = None
    try:
        with open(logpath, errors="replace") as f:
            for line in f:
                if line.startswith("MASTER "):
                    last = int(line.split()[1].split(",")[0])
    except (ValueError, IndexError, OSError):
        pass
    return last


def wait_windows(logpath, base, n, stall_after, what):
    """Wait for the factory's own counter to advance by n windows, but never
    forever.

    WHY THE BACKSTOP EXISTS. Counting in factory windows rather than seconds is
    right, and deliberate: a perturbation should not expire while the factory is
    producing nothing to be perturbed. But it assumes the window counter is
    LIVE, and on 28 Aug it was not. The factory's log handle died at window 716
    while the factory itself ran on past 775 -- lsof showed the file gone from
    the process, and SuperCollider's File.write on a closed file fails silently.
    current_window() therefore returned a frozen 716 for over an hour. The
    monkey held path_max=2 on a genuinely running, genuinely audible-in-
    principle factory and, waiting on windows that could never arrive, would
    never have reverted.

    That breaks the single property this tool rests on and that P458 requires of
    a hard world: every perturbation is reversible, and reverses. A perturbation
    that cannot expire is not adversarial pressure, it is damage.

    So the counter is trusted only while it MOVES. If it has not advanced for
    stall_after seconds, stop waiting and report it, so the caller can restore
    the original value and the operator learns the log is dead.
    """
    t0 = last_move = time.time()
    seen = base
    while True:
        time.sleep(4)
        w = current_window(logpath)
        if w is not None:
            if w != seen:
                seen, last_move = w, time.time()
            if base is not None and w - base >= n:
                return w, False
        idle = time.time() - last_move
        if idle > stall_after:
            print(f"  [{time.strftime('%H:%M:%S')}] STALL SUSPECTED while {what}: "
                  f"window counter stuck at {seen} for {idle/60:.1f} min.")
            print(  "                the factory is stopped, or its log handle has died")
            print(  "                (that has happened). Reverting rather than holding.")
            return seen, True
        # a base we never resolved is a log that was never readable at all
        if base is None and time.time() - t0 > stall_after:
            return seen, True


def read_policy(p):
    return json.load(open(p))


def write_key(p, key, value):
    """Edit in place by regex, not by re-serialising. policy.json carries ~60
    long `_key` comment fields recording why each value is what it is; a
    json.dump round-trip would preserve them but reflow the whole file, and the
    factory re-reads this file every window while it is being written."""
    s = open(p).read()
    pat = re.compile(rf'("{re.escape(key)}"\s*:\s*)([^,\n]+)')
    if not pat.search(s):
        return False
    s = pat.sub(lambda m: m.group(1) + json.dumps(value), s, count=1)
    open(p, "w").write(s)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mutable", default="mutable_shadow")
    ap.add_argument("--log", help="the shadow factory's window log")
    ap.add_argument("--every", type=int, default=40, help="windows between events")
    ap.add_argument("--duration", type=int, default=12, help="windows a perturbation lasts")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--stall-after", type=int, default=300,
                    help="seconds without the window counter moving before a "
                         "perturbation is reverted regardless (default 300)")
    ap.add_argument("--once", action="store_true", help="one perturbation, then exit")
    a = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pol = os.path.join(root, a.mutable, "policy.json")
    if not os.path.exists(pol):
        raise SystemExit(f"ABORT: {pol} does not exist")
    if os.path.basename(os.path.dirname(pol)) == "mutable":
        raise SystemExit(
            "ABORT: refusing to perturb the LIVE mutable directory.\n"
            "  The shadow exists so that nothing audible is ever damaged.\n"
            "  Pass --mutable mutable_shadow.")

    rng = random.Random(a.seed)
    journal = os.path.join(root, a.mutable, "chaos.jsonl")
    print(f"  chaos monkey on {a.mutable}")
    print(f"  every {a.every} windows, lasting {a.duration}, journal -> chaos.jsonl")
    print(f"  it may touch ONLY policy.json, and only reversible keys.")

    while True:
        w0 = current_window(a.log)
        key, (bad, why) = rng.choice(list(PERTURBATIONS.items()))
        original = read_policy(pol).get(key)
        if original is None:
            time.sleep(5); continue

        if not write_key(pol, key, bad):
            time.sleep(5); continue
        ev = dict(kind="perturb", key=key, was=original, to=bad, why=why,
                  window_start=w0, t=time.time())
        with open(journal, "a") as f:
            f.write(json.dumps(ev) + "\n")
        print(f"  [{time.strftime('%H:%M:%S')}] w{w0}  {key}: {original} -> {bad}")
        print(f"                {why}")

        # hold for `duration` WINDOWS, not seconds -- with a wall-clock backstop
        w1, stalled = wait_windows(a.log, w0, a.duration, a.stall_after,
                                   f"holding {key}={bad}")

        write_key(pol, key, original)
        with open(journal, "a") as f:
            f.write(json.dumps(dict(kind="revert", key=key, to=original,
                                    window_start=w0, window_end=w1,
                                    stalled=stalled, t=time.time())) + "\n")
        note = "  (reverted on the stall backstop, not on window count)" if stalled else ""
        print(f"  [{time.strftime('%H:%M:%S')}] w{w1}  {key} restored to {original}{note}")

        if a.once:
            return
        if stalled:
            # Do not keep perturbing something whose state we cannot read. Wait
            # for the counter to start moving again before resuming.
            print("  holding off until the window counter moves again...")
            base = current_window(a.log)
            _, still = wait_windows(a.log, base, 1, a.stall_after * 6,
                                    "waiting for the factory to come back")
            if still:
                print("  the factory has not produced a window in a long time. Exiting")
                print("  so that nothing is left perturbed. Check the factory and the log.")
                return
        # wait out the gap before the next one, again in factory windows
        base = current_window(a.log)
        wait_windows(a.log, base, a.every, a.stall_after * 6,
                     "waiting for the next event")


if __name__ == "__main__":
    main()
