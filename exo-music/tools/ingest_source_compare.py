#!/usr/bin/env python3
"""Is the MP3 stream good enough to INGEST from, or only good enough to hear?

THE DECISION THIS SERVES
Clean audio has one source: SuperCollider writing to disk, because any device
capture reintroduces the loopback clicks. Two consumers want it and want
opposite things -- the stream needs an unbroken growing file, the ingester needs
closed chunks it can decode and discard -- and the recording grows at 353 KB/s,
about 30 GB/day, so it cannot grow for ever.

One proposal removes the conflict entirely: let the ingester pull the public
Icecast mount instead of touching the file. The two consumers then never share
anything. Roberto asked the right question of it: "but will it be clean?"

CLEAN FOR LISTENING IS NOT CLEAN FOR INGESTING
The delivered stream measures 0.08 clicks/s, better than an offline render. That
settles audibility and settles nothing about ingestion, because a grain cut from
that audio has to survive admission and then be FOUND AGAIN by descriptor. Two
specific hazards:

  MP3 PRE-ECHO   the codec smears energy backwards across a transform block
                 before a sharp attack. The corpus is ONSET-ALIGNED: every grain
                 begins at an attack. So pre-echo lands exactly where every
                 grain starts, and vet() rejects on impulsiveness.
  DESCRIPTOR     admitted grains are placed by mfcc_stats through the frozen
  DRIFT          basis. If the codec moves those coordinates, self-material is
                 filed in the wrong place and the factory navigates to it by
                 numbers that no longer describe it -- the failure that already
                 cost a pool rebuild once.

The 11 kHz encoder lowpass is NOT among the hazards. The corpora derive from
22050 Hz material and hold nothing above 11.025 kHz, so that filter removes
approximately nothing. Stated because it is the objection that looks obvious and
is wrong.

WHAT THIS MEASURES, on the same wall-clock audio captured both ways:
  1. grain_score() distributions, and how many grains each source loses to the
     impulsive vet at the live threshold
  2. vet() rejection rates by reason
  3. descriptor displacement through the frozen basis, source against source

A codec that costs a few percent of admissions is tolerable. One that shifts
descriptors is not, because it corrupts the map rather than the material.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import self_ingest as SI                              # noqa: E402
import descriptor_basis as DB                         # noqa: E402
from audit_grain_transients import grain_score        # noqa: E402
from bisect_report import read_wav                    # noqa: E402


def cut(x, sr, dur, n_grains, rng):
    """Random slices, the way self_ingest samples a capture."""
    n = int(sr * dur)
    out = []
    if len(x) < n * 2:
        return out
    for s in rng.choice(len(x) - n, size=min(n_grains, len(x) - n), replace=False):
        out.append(x[int(s):int(s) + n])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True, help="SC recording (reference)")
    ap.add_argument("--b", required=True, help="delivered stream (candidate)")
    ap.add_argument("--layer", default="ev", choices=["ev", "mid", "macro"])
    ap.add_argument("--n", type=int, default=400)
    ap.add_argument("--basis-dir", default="/Volumes/FMA/superdark/archive")
    a = ap.parse_args()

    dur = SI.LAYERS[a.layer]
    rng = np.random.default_rng(20260901)

    xa, sra, _ = read_wav(a.a)
    xb, srb, _ = read_wav(a.b)
    SI.SR = sra
    print()
    print(f"  reference : {os.path.basename(a.a)}  {len(xa)/sra:.0f}s")
    print(f"  candidate : {os.path.basename(a.b)}  {len(xb)/srb:.0f}s")
    print(f"  layer {a.layer} ({dur*1000:.0f} ms grains), {a.n} slices each")

    # SAME slice positions in both, so a difference is the codec and not the
    # draw. The two captures cover the same wall clock but are not sample
    # aligned -- the stream lags by encoder and burst latency -- so this is a
    # comparison of DISTRIBUTIONS, not of paired grains. Said plainly because
    # treating them as paired would invent precision that is not there.
    ga = cut(xa, sra, dur, a.n, np.random.default_rng(1))
    gb = cut(xb, srb, dur, a.n, np.random.default_rng(1))

    print()
    print(f"  {'source':12} {'grains':>7} {'median':>8} {'p90':>8} {'p99':>8} "
          f"{'over 40':>9} {'vet reject':>11}")
    print("  " + "-" * 70)
    stats = {}
    for tag, gs in (("SC file", ga), ("MP3 stream", gb)):
        sc = np.array([grain_score(g.mean(1) if g.ndim > 1 else g, sra)[0] for g in gs])
        rej = 0
        reasons = {}
        for g in gs:
            gg = g if g.ndim > 1 else np.stack([g, g], axis=1)
            ok, why = SI.vet(gg)
            if not ok:
                rej += 1
                reasons[why] = reasons.get(why, 0) + 1
        stats[tag] = (sc, rej, reasons)
        print(f"  {tag:12} {len(gs):7d} {np.median(sc):8.2f} "
              f"{np.percentile(sc,90):8.2f} {np.percentile(sc,99):8.2f} "
              f"{100*(sc>40).mean():8.1f}% {100*rej/max(len(gs),1):10.1f}%")
    for tag in ("SC file", "MP3 stream"):
        r = stats[tag][2]
        if r:
            print(f"    {tag} rejections: {r}")

    # DESCRIPTOR DISPLACEMENT. Both sets projected through the SAME frozen basis
    # the factory navigates by. Compared as distributions per axis.
    bp = os.path.join(a.basis_dir, f"basis_{a.layer}.json")
    if os.path.exists(bp):
        basis = DB.load_basis(bp)
        def coords(gs):
            out = []
            for g in gs[:150]:
                mono = g.mean(1) if g.ndim > 1 else g
                try:
                    import analyse_mfcc as AM
                    import build_grains_onset as BGO
                    fb = AM.mel_filterbank(sra, AM.FFT, AM.N_MEL)
                    feats = (AM.mfcc_stats(mono, sra, fb),
                             *BGO.pitch_of(mono[:int(0.2*sra)], sra))
                    d, _ = DB.project(basis, feats=feats)
                    out.append([d[f"pc{j}"] for j in range(5)])
                except Exception:
                    pass
            return np.array(out)
        ca, cb = coords(ga), coords(gb)
        if len(ca) > 10 and len(cb) > 10:
            print()
            print("  descriptor coordinates through the frozen basis (pc0..pc4):")
            print(f"    {'axis':6} {'SC mean':>9} {'MP3 mean':>9} {'shift':>8} "
                  f"{'SC sd':>8}  shift in sd")
            for j in range(5):
                ma, mb = ca[:, j].mean(), cb[:, j].mean()
                sd = ca[:, j].std()
                print(f"    pc{j:<4} {ma:9.4f} {mb:9.4f} {mb-ma:+8.4f} {sd:8.4f}"
                      f"  {abs(mb-ma)/max(sd,1e-9):8.2f}")
            worst = max(abs(cb[:, j].mean()-ca[:, j].mean())/max(ca[:, j].std(),1e-9)
                        for j in range(5))
            print()
            print(f"    worst axis displacement: {worst:.2f} standard deviations")
            print("    Under ~0.25 sd the codec does not move the map and ingesting")
            print("    from the stream is safe. Above ~0.5 sd self-material would be")
            print("    filed where it does not belong.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
