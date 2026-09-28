#!/usr/bin/env python3
"""Does best-of-K on the section centre actually spread a half hour out?

The factory cannot be run today -- the audio subsystem needs a reboot -- and the
mechanism must not go live untested. This simulates the section sequence exactly
as live_factory.scd draws it and measures the quantity the intervention claims to
move, with the K=1 arm as its own control.

WHAT IS SIMULATED, from the code and from the 7.9 h run of 4 Sept:
  * a section every ~125 s; 229 sections in 28,572 s
  * section_return 0.35, so about a third are recalls of a remembered centre
    (measured on that run: 74 returns, 155 new)
  * a new centre is rrand(0.15, 0.85) per dimension, 6 dimensions, independent
  * novelty_horizon 16 sections is about 33 minutes, which is the band where the
    recurrence measure put the factory at position 0.74

WHAT IS NOT SIMULATED, and why it does not matter for this question: the
transition table's weighting of which remembered section is recalled, and the
per-window drift inside a section. The first only changes WHICH old centre is
returned to, not that one is; the second was measured at position 0.10 and is not
the fault. Both are held identical across the arms in any case.

THREE CRITERIA, fixed before the run:
  1. SPREAD RISES. The median distance from a new centre to the nearest of the
     last 16 occupied centres must rise materially from K=1 to K=8.
  2. COVERAGE HOLDS. Per-dimension mean and standard deviation of the chosen
     centres must not move much from the K=1 arm. A pressure that fixes
     recurrence by pushing every centre into the corners of the box has replaced
     one degenerate distribution with another, and the marginals are where that
     shows.
  3. RECALL SURVIVES. The share of sections that are returns must be unchanged.
     The intervention is not allowed to buy variety by weakening memory, which is
     the mechanism that makes the factory hearable as a factory.

    python3 tools/test_novelty_pressure.py
"""
import numpy as np

DIMS = 6
LO, HI = 0.15, 0.85
N_SECTIONS = 229
P_RETURN = 0.35
HORIZON = 16
ARMS = [1, 2, 4, 8, 16]
RUNS = 40


# REFLECTING THE NEIGHBOURS IN THE FACES OF THE BOX DOES NOTHING. TRIED, PROVEN
# INERT, RECORDED SO IT IS NOT TRIED AGAIN.
#
# The edge effect below is real: maximising distance to recent points inside a
# box rewards the walls, because a candidate near a face has fewer directions
# from which a neighbour can crowd it. The standard correction is to add each
# neighbour's mirror images and let them supply the missing crowding. Run as a
# second arm, it returned figures identical to the plain arm in every digit,
# which looked like a harness bug and is not.
#
# For a neighbour p and a candidate c, the image across the wall at w differs
# from p in one dimension only, at |c_j + p_j - 2w|, against the original's
# |c_j - p_j|. The difference between them is 2*(min(c_j, p_j) - w), which is
# non-negative for every point inside the box. The image is therefore NEVER
# nearer than the point it mirrors, and the minimum cannot move.
#
# Mirror images help on a PERIODIC domain, where wrapping brings a far point
# near. This domain reflects rather than wraps, and reflection pushes away. The
# edge bias cannot be removed this way, so it is bounded instead: criterion 2
# below prices it, and the sweep selects the largest K that pays.


def simulate(k, horizon, rng):
    """One run. Returns (chosen new centres, nearest-recent distances, n_return)."""
    archive, occupied = [], []
    new_centres, gaps, n_return = [], [], 0
    for _ in range(N_SECTIONS):
        if len(archive) > 1 and rng.random() < P_RETURN:
            centre = archive[rng.integers(len(archive))]
            n_return += 1
        else:
            recent = np.array(occupied[-horizon:]) if occupied else None
            best, best_d = None, -1.0
            for t in range(k):
                c = rng.uniform(LO, HI, DIMS)
                if recent is None or not len(recent):
                    d = 0.0
                else:
                    d = float(np.linalg.norm(recent - c, axis=1).min())
                if d > best_d:
                    best_d, best = d, c
            centre = best
            archive.append(centre)
            new_centres.append(centre)
            # THE REPORTED GAP IS ALWAYS THE TRUE DISTANCE TO A REAL NEIGHBOUR,
            # never the reflected score. The images inflate the score, so
            # comparing a reflected arm's score against a plain arm's distance
            # would compare two different quantities -- the mistake that made the
            # 0.9 drift threshold uncitable.
            gaps.append(0.0 if recent is None or not len(recent)
                        else float(np.linalg.norm(recent - centre, axis=1).min()))
        occupied.append(centre)
    return np.array(new_centres), np.array(gaps), n_return


def main():
    print()
    print(f"  {N_SECTIONS} sections per run, {RUNS} runs per arm, "
          f"horizon {HORIZON} sections (~33 min)")
    print()
    print(f"  {'K':>3}  {'median gap':>11} {'p10':>7} {'p90':>7}   "
          f"{'dim mean':>9} {'dim sd':>7}  {'returns':>8}")
    rows = {}
    for k in ARMS:
        rng = np.random.default_rng(20260906)
        gaps, centres, rets = [], [], []
        for _ in range(RUNS):
            c, g, nr = simulate(k, HORIZON, rng)
            gaps.append(g)
            centres.append(c)
            rets.append(nr)
        gaps = np.concatenate(gaps)
        centres = np.concatenate(centres)
        rows[k] = dict(med=float(np.median(gaps)), mean=float(centres.mean()),
                       sd=float(centres.std()),
                       ret=float(np.mean(rets)) / N_SECTIONS)
        print(f"  {k:3d}  {np.median(gaps):11.4f} {np.percentile(gaps,10):7.4f} "
              f"{np.percentile(gaps,90):7.4f}   {centres.mean():9.4f} "
              f"{centres.std():7.4f}  {rows[k]['ret']*100:7.1f}%")

    # sd of a uniform on [LO, HI] -- the value the control should reproduce and
    # the value the edge bias inflates
    unif_sd = (HI - LO) / np.sqrt(12)
    r1 = rows[1]
    print()
    print(f"  uniform sd on [{LO}, {HI}] is {unif_sd:.4f}; the control measures "
          f"{r1['sd']:.4f}")
    print()
    print("  AGAINST THE PRE-REGISTERED CRITERIA, ARM BY ARM")
    print()
    print(f"  {'K':>3}  {'spread':>18}  {'coverage':>22}  {'recall':>16}")
    admissible = []
    for k in ARMS:
        r = rows[k]
        lift = (r["med"] - r1["med"]) / r1["med"] * 100
        dsd = r["sd"] - r1["sd"]
        ok1 = r["med"] > r1["med"] * 1.25
        ok2 = abs(r["mean"] - r1["mean"]) < 0.02 and abs(dsd) < 0.02
        ok3 = abs(r["ret"] - r1["ret"]) < 0.02
        if ok1 and ok2 and ok3:
            admissible.append(k)
        print(f"  {k:3d}  {lift:+7.1f}% {'PASS' if ok1 else 'fail':>9}  "
              f"sd {dsd:+.4f} ({dsd/unif_sd*100:+.0f}%) {'PASS' if ok2 else 'fail':>4}  "
              f"{r['ret']*100:6.1f}% {'PASS' if ok3 else 'fail':>7}")

    print()
    if admissible:
        k = max(admissible)
        print(f"  LARGEST ADMISSIBLE K IS {k}.")
        print("  The two criteria pull opposite ways in K and cross between the")
        print("  arms above: spread rises with K, and so does the edge bias, because")
        print("  best-of-K in a box favours the walls and reflection cannot remove")
        print("  it (see the note at the top of this file). Criterion 2 is what")
        print("  prices that, and the 0.02 bar in it was chosen by the architect,")
        print("  not derived -- moving it moves the answer, and it should be moved")
        print("  by an argument about the corpus and not to admit a larger K.")
        print()
        print("  ARITHMETIC ONLY. This does not say the factory runs the code --")
        print("  a NOVPRESS line in a live log is the only thing that can -- and it")
        print("  does not say the audio is less repetitive, which needs")
        print("  recurrence_sweep.py against the loop and diverse arms.")
    else:
        print("  NO ADMISSIBLE ARM. Do not put this live.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
