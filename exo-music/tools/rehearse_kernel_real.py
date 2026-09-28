#!/usr/bin/env python3
"""Would the kernel fire on a REAL fault? The crude rehearsal proved too little.

The first rehearsal manufactured a run that was silent AND clipping AND
single-machine AND out of band, and the kernel fired citing six failures against
a tolerance of two. That shows the mechanism is reachable. It does not show it
is USEFUL, because no real failure looks like that.

This replays the actual arm logs -- real factory behaviour, hours of it -- and
applies degradations of the kind this project has actually suffered:

    gain collapse        every peak scaled down. The BufRateScale change left
                         machine amplitudes uncalibrated and nobody noticed for
                         an unknown number of runs.
    vocabulary collapse  the factory settles onto a handful of machines. This is
                         P229 learning death, and the audibility score once took
                         it from nine machines to four.
    operator freeze      lambda2 stops moving. Already happened; it is why m7 is
                         suspended.
    clipping             the never-tolerated metric, the one fault the charter
                         says is never acceptable at any tolerance.

For each, it asks: how severe must this be before the kernel fires? A guard that
only fires on catastrophe is a guard that will watch a slow failure all the way
down -- and a slow failure is exactly what this factory has been having.

    python3 tools/rehearse_kernel_real.py
"""
import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_charter as SC                                    # noqa: E402
import kernel_guard as KG                                     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")


def degrade(src, dst, gain=1.0, vocab=None, clip=None, freeze=False):
    """Rewrite a real log with one plausible fault applied."""
    machines = []
    out = []
    for line in open(src, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                w, pk, cl = int(p[0]), float(p[1]), float(p[2])
            except (ValueError, IndexError):
                out.append(line); continue
            pk *= gain
            if clip is not None:
                cl = clip
            out.append(f"MASTER {w},{pk:.6f},{cl}\n")
        elif line.startswith("OPERATOR"):
            if freeze:
                p = line.split()[1].split(",")
                out.append(f"OPERATOR {p[0]},0.8000,0.2000,{p[3] if len(p)>3 else 120},"
                           f"{p[4] if len(p)>4 else '-'},9000\n")
            else:
                out.append(line)
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                if vocab:
                    if p[2] not in machines:
                        machines.append(p[2])
                    p[2] = machines[machines.index(p[2]) % vocab]
                    out.append(",".join(p) + "\n")
                else:
                    out.append(line)
            else:
                out.append(line)
    open(dst, "w").writelines(out)


def score(path, ch):
    n, rows, failed, und = SC.evaluate(path, ch)
    return n, set(failed)


def main():
    argparse.ArgumentParser().parse_args()
    ch = json.load(open(os.path.join(MUT, "charter.json")))
    kern = json.load(open(os.path.join(MUT, "kernel.json")))
    tol = ch["departures"]["tolerated_failing_metrics"]
    never = ch["departures"]["never_tolerated"]

    reals = [p for p in ("/Volumes/FMA/superdark/renders/arm_a_w100.log",
                         "/Volumes/FMA/superdark/renders/arm_c_w000.log")
             if os.path.exists(p)]
    if len(reals) < 2:
        reals = sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                       key=os.path.getmtime)[-2:]
    print()
    print(f"  charter edition {ch['edition']}, tolerance {tol}, "
          f"never tolerated {never}")
    print(f"  replaying {[os.path.basename(p) for p in reals]}")
    print()

    n0, f0 = score(reals[0], ch)
    n1, f1 = score(reals[1], ch)
    fire0, why0, _ = KG.decide([(n0, reals[0], f0), (n1, reals[1], f1)], ch, kern)
    print(f"  AS THEY ACTUALLY RAN")
    print(f"    {os.path.basename(reals[0])}: {sorted(f0) or 'none'}")
    print(f"    {os.path.basename(reals[1])}: {sorted(f1) or 'none'}")
    print(f"    kernel fires: {'YES' if fire0 else 'no'}  ({why0})")
    print()

    trials = [
        ("gain -6 dB",            dict(gain=0.5)),
        ("gain -12 dB",           dict(gain=0.25)),
        ("gain -20 dB",           dict(gain=0.1)),
        ("vocabulary -> 4",       dict(vocab=4)),
        ("vocabulary -> 2",       dict(vocab=2)),
        ("operator frozen",       dict(freeze=True)),
        ("clipping at 0.05",      dict(clip=0.05)),
        ("gain -12 dB + vocab 4", dict(gain=0.25, vocab=4)),
    ]
    print(f"  {'plausible fault':24} {'metrics failing in both':>26}  fires")
    print("  " + "-" * 62)
    for name, kw in trials:
        a, b = "/tmp/deg_a.log", "/tmp/deg_b.log"
        degrade(reals[0], a, **kw)
        degrade(reals[1], b, **kw)
        na, fa = score(a, ch)
        nb, fb = score(b, ch)
        fire, why, _ = KG.decide([(na, a, fa), (nb, b, fb)], ch, kern)
        both = sorted(fa & fb)
        print(f"  {name:24} {str(len(both)) + ': ' + ','.join(x[:2] for x in both):>26}  "
              f"{'FIRES' if fire else '-'}")
    print()
    print("  READING IT. A fault that does not reach the tolerance is a fault the")
    print("  kernel will watch indefinitely. That is by design -- the charter")
    print("  tolerates two failing metrics -- but it means the kernel is a guard")
    print("  against BROAD collapse, not against a single deep fault. The silence")
    print("  problem was one metric for days and the kernel was right not to fire,")
    print("  and also useless for finding it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
