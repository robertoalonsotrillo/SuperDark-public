#!/usr/bin/env python3
"""Does the SOUND return to itself? The charter has no metric that can tell.

THE BLIND SPOT THIS FILLS. Every variety metric in the charter is over machine
IDENTITY: m4_vocabulary_breadth counts behaviours per 100 windows,
m5_not_converging is entropy over machine selection, m9_turnover is how often
the machine changes, m6_texture is voice count. All four can pass perfectly
while the output is sonically identical -- which is what Roberto reported on
4 Sept: "a tendency to drift into sonically repetitive patterns even if the
machines are different."

That is the same shape as m3_no_clipping reading the pre-encoder signal. The
metric measures the thing the system CONTROLS and not the thing the listener
RECEIVES, and the gap between them is where the fault lives.

WHY DIFFERENT MACHINES SOUND THE SAME, from the code rather than from the ear. A
machine controls its rhythm and its envelope. It does not control the material
(one global target, so every voice draws from the same neighbourhood at the same
moment), the pitch (pitch_weight 4.0 concentrates them further), the macro bed
(macro_hold_grains 1, so it is one recording looped), or the processing (one
trajectory shape for all). The vocabulary varies in the dimension the ear cares
least about.

WHAT IS MEASURED. A log-band spectrum every half second, then for each frame the
MAXIMUM cosine similarity to any frame between `--near` and `--far` seconds
earlier. Adjacent frames are excluded because they are trivially similar and
their similarity is coherence, not repetition; the question is whether the sound
comes BACK, not whether it is continuous.

AND AGAINST A NULL, because a corpus with a narrow timbral range scores high
however it is arranged. The same frames are shuffled in time and re-measured. If
observed and shuffled agree, the factory is as repetitive as its own material
forces and no arrangement would help; if observed is HIGHER, the factory is
returning to places more than chance and that excess is the thing to reduce.

THE FIRST VERSION OF THIS FILE MEASURED A CONSTANT, and said so with confidence.
Run 6 Sept on the hour Roberto had just listened to, it reported recurrence
0.9884 against a shuffled 0.9902, z = -0.28, and printed "the factory is no more
self-similar than its own material forces; rearranging it would not help." The
control that should have been run first was then run: 140 unrelated FMA tracks by
140 different artists, same duration, same pipeline. They scored 0.9961 -- HIGHER
than the factory. A measure on which maximal diversity looks more repetitive than
the thing being diagnosed is not measuring repetition.

WHY IT SATURATED. The features are log-band energies, so every component is
non-negative, and the cosine between two non-negative vectors cannot go far below
1 once they share the broad spectral tilt that all music shares. The statistic
spent its whole range on "this is music" and had almost nothing left for "this is
the same music". Fourth time in this project that a similarity has looked
decisive while reporting a constant, after the alignment rho of 0.998, the
circular-shift null, and the vertical census scoring voice persistence.

THE FIX IS TO CENTRE. Subtracting the mean spectrum across frames before
normalising turns the cosine into a correlation across bands, which removes the
common component and leaves only how each frame DEPARTS from the run's average
sound. `--raw` keeps the old behaviour so the numbers in earlier commits can
still be reproduced; it should not be used for a new claim.

Admissibility was pre-registered before this version ran, in
docs/measurements/2026-09-06_recurrence_prereg.md: a loop must score above the
factory, the factory above 140 unrelated tracks, and the gap must exceed five
standard errors. A statistic that fails is discarded, not retuned.

    python3 tools/sonic_variety.py /tmp/hour/hour.mp3
    python3 tools/sonic_variety.py a.mp3 --compare b.mp3
    python3 tools/sonic_variety.py a.mp3 --raw     # the saturated original
"""
import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np

SR = 22050


def decode(path):
    raw = tempfile.mktemp(suffix=".f32")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path,
                    "-ac", "1", "-ar", str(SR), "-f", "f32le", raw], check=True)
    x = np.fromfile(raw, dtype="<f4")
    try:
        os.unlink(raw)
    except OSError:
        pass
    return x


def features(x, hop_s=0.5, nbands=24, centre=True):
    """Log-band energy per frame, L2-normalised.

    Normalised because LOUDNESS is not the question -- a quiet passage and a loud
    one with the same spectrum are the same sonic place, and m2_level already
    watches level. What is being compared is the shape of the spectrum.
    """
    N = 2048
    H = int(SR * hop_s)
    n = (len(x) - N) // H
    if n < 8:
        return np.zeros((0, nbands))
    idx = np.arange(N)[None, :] + H * np.arange(n)[:, None]
    S = np.abs(np.fft.rfft(x[idx] * np.hanning(N), axis=1))
    f = np.fft.rfftfreq(N, 1 / SR)
    edges = np.geomspace(50, min(9000, f[-1]), nbands + 1)
    B = np.zeros((n, nbands))
    for b in range(nbands):
        m = (f >= edges[b]) & (f < edges[b + 1])
        if m.any():
            B[:, b] = S[:, m].mean(1)
    B = np.log1p(B * 500)
    # drop frames that are essentially silent: they are all identical to each
    # other and would report the factory's silences as repetition
    keep = B.sum(1) > np.percentile(B.sum(1), 15)
    B = B[keep]
    # CENTRE BEFORE NORMALISING. Without this the vectors are non-negative and
    # every cosine sits above 0.98 whatever the material -- see the module
    # docstring. Subtracting the run's mean spectrum makes the dot product a
    # correlation over bands, so what is compared is how each frame DEPARTS from
    # the average sound of the run and not the fact that both are music.
    #
    # The mean is taken WITHIN the run, so a run whose average spectrum is odd is
    # not penalised for it. That is deliberate: the question is whether the sound
    # comes back to where it has been, which is internal to the run. It also
    # means the figure is not comparable across two files of very different
    # material without saying so, which --compare prints.
    if centre:
        B = B - B.mean(0, keepdims=True)
    nrm = np.linalg.norm(B, axis=1, keepdims=True)
    nrm[nrm == 0] = 1
    return B / nrm


def recurrence(B, hop_s, near, far, rng=None):
    """For each frame, the best match in a window that ended `near` seconds ago."""
    n = len(B)
    lo, hi = int(near / hop_s), int(far / hop_s)
    if n < hi + 8:
        hi = max(lo + 8, n - 8)
    out = []
    order = np.arange(n) if rng is None else rng.permutation(n)
    Bs = B[order]
    for t in range(hi, n):
        past = Bs[max(0, t - hi):t - lo]
        if len(past) < 4:
            continue
        out.append(float((past @ Bs[t]).max()))
    return np.array(out) if out else np.array([0.0])


def blockwise_se(v, blocks=10):
    """Standard error over CONTIGUOUS blocks, not over frames.

    Neighbouring frames are correlated by construction -- a 0.5 s hop through a
    2048-sample window overlaps, and the music itself persists -- so dividing the
    frame-wise standard deviation by sqrt(n) would understate the error by an
    order of magnitude and make any two arms look separated. The pre-registered
    criterion is stated in standard errors, so this is the number the criterion
    is actually enforced against and it has to be the honest one.
    """
    if len(v) < blocks * 4:
        return float(np.std(v) / max(1, np.sqrt(len(v))))
    cut = len(v) // blocks * blocks
    means = v[:cut].reshape(blocks, -1).mean(1)
    return float(np.std(means, ddof=1) / np.sqrt(blocks))


def report(tag, x, a):
    B = features(x, a.hop, centre=not a.raw)
    if len(B) < 64:
        print(f"  {tag}: too short")
        return None
    obs = recurrence(B, a.hop, a.near, a.far)
    rng = np.random.default_rng(0)
    nul = np.concatenate([recurrence(B, a.hop, a.near, a.far, rng)
                          for _ in range(a.draws)])
    z = (obs.mean() - nul.mean()) / (nul.std() + 1e-9)
    # participation ratio: how many distinct sonic places the run occupies.
    # 1 / sum(p^2) over the eigenvalue spectrum of the frame covariance -- a
    # factory sitting in one place has a ratio near 1 whatever its machine count.
    C = np.cov(B.T)
    ev = np.linalg.eigvalsh(C)
    ev = ev[ev > 0]
    pr = (ev.sum() ** 2) / (ev ** 2).sum() if len(ev) else 0
    se = blockwise_se(obs)
    print(f"  {tag}")
    print(f"    frames {len(B)}  ({len(B) * a.hop / 60:.1f} min of sounding audio)")
    print(f"    recurrence  observed {obs.mean():.4f} +/- {se:.4f} (block SE)")
    print(f"                shuffled {nul.mean():.4f} +/- {nul.std():.4f}")
    print(f"    excess over chance   z = {z:+.2f}")
    print(f"    p90 of best-match    {np.percentile(obs, 90):.4f}")
    print(f"    spectral participation ratio  {pr:.2f} of {B.shape[1]} bands")
    return dict(mean=float(obs.mean()), se=se, null=float(nul.mean()),
                z=float(z), p90=float(np.percentile(obs, 90)), pr=float(pr),
                frames=len(B))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("audio")
    ap.add_argument("--compare", default=None)
    ap.add_argument("--hop", type=float, default=0.5)
    ap.add_argument("--near", type=float, default=20.0,
                    help="ignore matches closer than this: continuity is not repetition")
    ap.add_argument("--far", type=float, default=300.0,
                    help="how far back to look for a return")
    ap.add_argument("--draws", type=int, default=5)
    ap.add_argument("--raw", action="store_true",
                    help="uncentred cosine: the saturated original, kept only so "
                         "the figures quoted before 6 Sept can be reproduced")
    a = ap.parse_args()

    print()
    print(f"  SONIC RECURRENCE  (match window {a.near:.0f}-{a.far:.0f} s back, "
          f"{a.hop}s frames)")
    if a.raw:
        print("  --raw: UNCENTRED. This statistic returns about 0.99 for any")
        print("  music, including 140 unrelated tracks. Do not build a claim on it.")
    print()
    r1 = report(os.path.basename(a.audio), decode(a.audio), a)
    r2 = None
    if a.compare:
        print()
        r2 = report(os.path.basename(a.compare), decode(a.compare), a)

    print()
    if r1 and r2:
        d = r2["mean"] - r1["mean"]
        print(f"  CHANGE  recurrence {r1['mean']:.4f} -> {r2['mean']:.4f} "
              f"({d:+.4f}),  z {r1['z']:+.2f} -> {r2['z']:+.2f},  "
              f"participation {r1['pr']:.2f} -> {r2['pr']:.2f}")
        print("  Lower recurrence and higher participation is more varied. A drop in")
        print("  recurrence with NO rise in participation is the factory wandering")
        print("  rather than exploring, which is not the same thing and is worse.")
    elif r1:
        # THE z LINE IS DECORATION AND MUST NOT BE READ AS A VERDICT. The shuffled
        # null's standard deviation is around 0.08 -- shuffling reorders whole
        # stretches, so draws differ wildly -- and z therefore fails to reach
        # significance for ANY signal, including a clip looped 140 times. Until
        # 6 Sept this branch printed "the factory is no more self-similar than its
        # own material forces; rearranging it would not help" on that basis, and
        # printed the same sentence for the literal loop.
        #
        # A single number means nothing on its own here. It means something
        # against the two calibration arms, which is what recurrence_sweep.py is
        # for and what docs/measurements/2026-09-06_recurrence_result.md records.
        print("  ONE FILE, ONE NUMBER. Recurrence has no absolute scale: it rises")
        print("  with the match window for every signal, and 0.85 is meaningless")
        print("  without knowing what a loop and what 140 unrelated artists score")
        print("  at the same window. Run tools/recurrence_sweep.py against both")
        print("  calibration arms before this figure carries any claim.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
