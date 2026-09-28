#!/usr/bin/env python3
"""What simultaneities does the factory actually produce, and does it repeat any?

THE HARMONIC QUESTION, ASKED AS A DISTRIBUTION RATHER THAN AS A RULE.

The decision on 3 Sept was to let the factory learn vertical structure rather
than be handed a consonance model: log which simultaneities occur, let the
judges score them, let the transfer operator navigate toward the ones that
recur. Nothing steers yet. Before anything can be said to prefer part of a
distribution, the distribution has to exist -- the same discipline that put
m9_turnover in descriptive and unbounded, and the same one that was broken when
a 2 s grain length arrived as an assumption.

This reads the VERTICAL lines and asks three things:

  WHAT INTERVALS OCCUR. Octave-folded ratios against the lowest sounding voice,
  in cents, so a reader can see whether the factory lands anywhere a listener
  would call an interval or spreads evenly across the octave. An even spread is
  a real and reportable answer: it would mean the vertical dimension is noise
  and any harmony heard is the listener's.

  DOES ANYTHING RECUR. The commonest chords, as multisets of folded ratios
  quantised to a tolerance. Recurrence is the precondition for learning: an
  operator cannot navigate toward a state it never revisits.

  IS IT DIFFERENT FROM CHANCE. The same statistics computed on the SAME pitches
  reassigned at random across windows. If the observed distribution matches the
  shuffled one, the factory has no vertical structure and saying otherwise would
  be the kind of claim this project keeps having to withdraw.

    python3 tools/vertical_census.py [logfile] [--bins 24] [--min-voices 2]
"""
import argparse
import collections
import glob
import math
import os
import random
import sys

RENDERS = "/Volumes/FMA/superdark/renders"


def newest():
    c = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")), key=os.path.getmtime)
    return c[-1] if c else None


def read(path, min_voices):
    rows = []
    for line in open(path, errors="replace"):
        if not line.startswith("VERTICAL "):
            continue
        f = line[9:].strip().split(",")
        if len(f) < 3:
            continue
        try:
            w, base = int(f[0]), float(f[1])
            rats = [float(x) for x in f[2].split("|") if x]
        except ValueError:
            continue
        if len(rats) >= min_voices:
            rows.append((w, base, rats))
    return rows


def cents(r):
    return 1200 * math.log2(r)


def fold(r):
    """Into one octave, 1.0 <= r < 2.0, the same folding the factory logs with."""
    while r >= 2.0:
        r /= 2
    while r < 1.0:
        r *= 2
    return r


NAMES = [(0, "unison"), (100, "m2"), (200, "M2"), (300, "m3"), (400, "M3"),
         (500, "P4"), (600, "tritone"), (700, "P5"), (800, "m6"), (900, "M6"),
         (1000, "m7"), (1100, "M7"), (1200, "octave")]


def nearest_name(c):
    k, nm = min(NAMES, key=lambda t: abs(t[0] - c))
    return nm, c - k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", nargs="?", default=None)
    ap.add_argument("--bins", type=int, default=24)
    ap.add_argument("--min-voices", type=int, default=2)
    ap.add_argument("--tol", type=int, default=50, help="cents, for chord identity")
    ap.add_argument("--far", type=int, default=12,
                    help="window separation no voice can bridge; voice_span_macro"
                         " is 90 s and a window is 11.7 s, so 12 is about 140 s")
    a = ap.parse_args()

    p = a.log or newest()
    if not p or not os.path.exists(p):
        print("  no log", file=sys.stderr)
        return 2
    rows = read(p, a.min_voices)
    print()
    print(f"  {os.path.basename(p)}")
    print(f"  {len(rows)} windows with {a.min_voices}+ pitched voices")
    if len(rows) < 10:
        print("  TOO FEW to say anything. This needs hours, not minutes.")
        return 0

    # ---- what intervals occur -------------------------------------------
    iv = [cents(r) for _, _, rats in rows for r in rats[1:]]
    hist = collections.Counter(int(c // (1200 / a.bins)) for c in iv)
    print()
    print(f"  INTERVALS ABOVE THE LOWEST VOICE  (n={len(iv)}, "
          f"{a.bins} bins of {1200//a.bins} cents)")
    top = max(hist.values()) if hist else 1
    for b in range(a.bins):
        n = hist.get(b, 0)
        c0 = b * (1200 / a.bins)
        nm, off = nearest_name(c0 + (600 / a.bins))
        bar = "#" * int(38 * n / top)
        print(f"    {int(c0):4}-{int(c0 + 1200 / a.bins):4}c  {nm:>7}  "
              f"{n:5}  {bar}")

    # flatness: how far from an even spread across the octave
    exp = len(iv) / a.bins
    chi = sum((hist.get(b, 0) - exp) ** 2 / exp for b in range(a.bins)) if exp else 0
    print(f"    chi-square against a flat octave: {chi:.1f} on {a.bins - 1} df")

    # ---- does anything recur --------------------------------------------
    def sig(rats):
        return tuple(sorted(int(round(cents(r) / a.tol)) for r in rats))
    ch = collections.Counter(sig(rats) for _, _, rats in rows)
    print()
    print(f"  CHORDS THAT RECUR  ({len(ch)} distinct at {a.tol}c tolerance, "
          f"{len(rows)} windows)")
    for s, n in ch.most_common(8):
        cs = [x * a.tol for x in s]
        nm = " ".join(nearest_name(c)[0] for c in cs)
        print(f"    {n:5}x  {nm}")
    rep = sum(n for s, n in ch.items() if n > 1) / max(1, len(rows))
    print(f"    {100 * rep:.1f}% of windows are a chord seen more than once")

    # ---- is it different from chance ------------------------------------
    # THE SHUFFLE MUST HAPPEN BEFORE THE SLICING, AND IN THE FIRST VERSION IT
    # DID NOT. random.shuffle(pool) sat AFTER the loop that cut pool into
    # windows, so `shuf` was the observed data re-sorted and the null returned
    # its input. It printed "observed 189 / shuffled 189, 30.4% / 30.4%" and
    # concluded NO DIFFERENCE -- which is the answer I expected, which is
    # exactly what made it dangerous. A null that agrees with the hypothesis you
    # already hold is the one you are least likely to check.
    #
    # Repeated over many draws now, because a single shuffle is one sample of
    # the null and the quantity being compared is a rate.
    random.seed(0)
    obs_pool = [r for _, _, rats in rows for r in rats]
    sizes = [len(rats) for _, _, rats in rows]
    reps, dists = [], []
    for _ in range(200):
        pool = obs_pool[:]
        random.shuffle(pool)                       # BEFORE slicing
        shuf, i = [], 0
        for k in sizes:
            take = pool[i:i + k]
            i += k
            if len(take) == k:
                # re-fold against the new lowest, or the ratios would still
                # carry the window they came from
                lo = min(take)
                shuf.append(sorted(fold(r / lo) for r in take))
        c2 = collections.Counter(sig(x) for x in shuf)
        reps.append(sum(n for s, n in c2.items() if n > 1) / max(1, len(shuf)))
        dists.append(len(c2))
    import statistics as st
    mu, sd = st.mean(reps), (st.pstdev(reps) or 1e-9)
    z = (rep - mu) / sd
    print()
    print("  AGAINST CHANCE, same pitches reassigned across windows, 200 draws")
    print(f"    observed  distinct {len(ch):5}   repeat rate {100 * rep:5.1f}%")
    print(f"    shuffled  distinct {st.mean(dists):5.0f}   repeat rate "
          f"{100 * mu:5.1f}% +/- {100 * sd:.1f}")
    print(f"    z = {z:+.2f}")
    if abs(z) < 2:
        print("    NO DIFFERENCE. The factory has no vertical structure yet, and")
        print("    any harmony heard in it is the listener's. That is the honest")
        print("    reading and it is what should be expected before anything steers.")
    else:
        print("    A difference exists against THIS null -- and this null is too")
        print("    weak to support a harmonic reading. See the persistence test.")

    # ---- IS IT HARMONY, OR IS IT JUST THAT VOICES LAST? ------------------
    #
    # A voice lasts 40-90 s and a window is 11.7 s, so ADJACENT WINDOWS SHARE
    # VOICES and therefore share pitches. That alone produces recurring chords
    # with no vertical structure of any kind, and the shuffle above destroys
    # temporal adjacency, so it scores that autocorrelation as though it were
    # harmony. The z of +5.43 measured on the first honest run is almost
    # certainly voice persistence wearing a chord's clothes.
    #
    # The discriminating question: do chords recur between windows FAR ENOUGH
    # APART that no voice can be common to both? If the excess survives at that
    # separation, something is returning to the same simultaneity across
    # unrelated voices. If it vanishes, the recurrence was persistence and there
    # is no harmonic finding here -- which is what should be expected today,
    # because nothing coordinates the voices.
    span = max(1, int(a.far))
    print()
    print(f"  PERSISTENCE CONTROL: chords recurring at least {span} windows apart")
    seen = {}
    far_hits = far_tot = 0
    for w, _, rats in rows:
        s = sig(rats)
        prev = seen.get(s)
        far_tot += 1
        if prev is not None and (w - prev) >= span:
            far_hits += 1
        # keep the EARLIEST occurrence, so the gap is measured honestly
        if s not in seen:
            seen[s] = w
    far_rate = far_hits / max(1, far_tot)
    # the same on the shuffles, which have no temporal structure at all
    fr = []
    for _ in range(200):
        pool = obs_pool[:]
        random.shuffle(pool)
        sh, i, sn, hit = [], 0, {}, 0
        for wi, k in enumerate(sizes):
            take = pool[i:i + k]; i += k
            if len(take) != k:
                continue
            lo = min(take)
            s = sig([fold(r / lo) for r in take])
            if s in sn and (wi - sn[s]) >= span:
                hit += 1
            if s not in sn:
                sn[s] = wi
        fr.append(hit / max(1, len(sizes)))
    mu2, sd2 = st.mean(fr), (st.pstdev(fr) or 1e-9)
    z2 = (far_rate - mu2) / sd2
    print(f"    observed {100 * far_rate:5.1f}%   shuffled {100 * mu2:5.1f}% "
          f"+/- {100 * sd2:.1f}   z = {z2:+.2f}")
    if abs(z2) < 2:
        print("    THE EXCESS WAS PERSISTENCE. Adjacent windows share voices, so")
        print("    they share pitches; across a gap no voice can bridge, the")
        print("    factory returns to a simultaneity no more often than chance.")
        print("    There is no vertical structure and any harmony heard is the")
        print("    listener's. This is the expected result and the baseline that")
        print("    a later, steering version has to beat.")
    elif z2 > 0:
        print("    RECURRENCE SURVIVES a gap no voice can bridge. Something")
        print("    returns to the same simultaneity across unrelated voices.")
        print("    Still not a preference -- nothing selects for it -- but no")
        print("    longer explicable as voices lasting a long time.")
    else:
        # THE SIGN MATTERS AND THE FIRST VERSION OF THIS TEXT IGNORED IT.
        # It printed "the excess SURVIVES" for any |z| >= 2, so a NEGATIVE
        # result -- the factory recurring LESS than chance -- was reported as
        # evidence FOR structure. Exactly backwards, and it would have gone into
        # a grant application that way.
        print("    ANTI-RECURRENCE. Across a gap no voice can bridge the factory")
        print("    returns to a simultaneity LESS often than chance. It is not")
        print("    failing to build harmony; it is actively moving away from")
        print("    every vertical configuration it reaches.")
        print()
        print("    The cause is almost certainly the design: the tonic drifts,")
        print("    sections reset it, and the pitch walk is aperiodic, so the")
        print("    factory never comes back. THIS IS THE PROBLEM FOR LEARNING.")
        print("    An operator cannot navigate toward states it revisits less")
        print("    often than random -- recurrence is the precondition, and the")
        print("    current design forbids it. Any steering version has to make")
        print("    the factory ABLE to return before it can be asked to prefer.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
