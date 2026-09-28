#!/usr/bin/env python3
"""Measure HISS, which is not what audit_grain_transients.py measures.

WHY A SECOND INSTRUMENT
Roberto first said "hiss", then "clipping", then "super short clipping sounds",
and I built a click detector on the second description. That detector
normalises each moment against its local background SPECIFICALLY so that
steady content scores zero. It is therefore blind to hiss by construction, and
a clean verdict from it says nothing at all about broadband noise. The corpus
gate it motivated made the sound "not as prominent", which is consistent with
having removed one real problem while leaving a second untouched.

THE DISCRIMINATOR THAT MATTERS
The corpus is 22050 Hz. By the sampling theorem nothing in the material can
exist above 11.025 kHz. So any energy above that band was ADDED by the chain
and did not come from the music. That single number separates "the material
hisses" from "something downstream hisses" without needing a reference.

WHAT IS REPORTED
  floor dBFS   10th-percentile short-term RMS: the level BETWEEN events, which
               is what hiss actually is. Peak and mean levels are dominated by
               the music and hide it completely.
  >11k frac    energy above 11.025 kHz as a fraction of the total. Should be
               ~0 for anything that is only the corpus played back.
  >11k dBFS    absolute level of that band, because a fraction can look large
               simply because everything else is quiet.
  flatness     spectral flatness of the QUIETEST frames. White noise -> 1.0,
               tonal material -> near 0. Hiss is flat; a quiet passage of
               music is not.
  dyn range    peak minus floor. A rising floor with a fixed peak is exactly
               what "hiss" sounds like, and it is the number that should move
               if the fault is a fixed-level noise source.

  python3 noise_floor.py a.wav b.wav ...
"""
import sys
import wave

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from bisect_report import read_wav  # noqa: E402

NYQ_CORPUS = 11025.0


def analyse(path, frame_ms=25.0):
    x, sr, ch = read_wav(path)
    n = max(64, int(sr * frame_ms / 1000))
    nf = len(x) // n
    if nf < 8:
        return None
    fr = x[: nf * n].reshape(nf, n)

    rms = np.sqrt((fr ** 2).mean(axis=1))
    floor = float(np.percentile(rms, 10))
    peak = float(np.abs(x).max())

    # spectrum of the whole file
    S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    tot = max(S.sum(), 1e-30)
    hi = S[f > NYQ_CORPUS].sum()
    hi_frac = float(hi / tot)
    # absolute level of the >11k band, referred to full scale
    hi_db = 10 * np.log10(max(hi / max(len(x), 1), 1e-30))

    # flatness of the QUIETEST frames only: that is where hiss lives
    quiet = fr[np.argsort(rms)[: max(3, nf // 10)]]
    fl = []
    for q in quiet:
        P = np.abs(np.fft.rfft(q * np.hanning(len(q)))) ** 2 + 1e-30
        fl.append(np.exp(np.log(P).mean()) / P.mean())
    flat = float(np.mean(fl))

    db = lambda v: 20 * np.log10(v) if v > 0 else -np.inf  # noqa: E731
    return {
        "sr": sr, "ch": ch, "sec": len(x) / sr,
        "peak_db": db(peak), "floor_db": db(floor),
        "dyn": db(peak) - db(floor),
        "hi_frac": hi_frac, "hi_db": hi_db, "flat": flat,
    }


def main(paths):
    print()
    print(f"{'file':34} {'sr':>6} {'sec':>5} {'peak dB':>8} {'floor dB':>9} "
          f"{'dyn':>6} {'>11k frac':>10} {'>11k dB':>9} {'flatness':>9}")
    print("-" * 105)
    for p in paths:
        try:
            r = analyse(p)
        except Exception as e:
            print(f"{p.split('/')[-1][:34]:34} ERROR {e}")
            continue
        if r is None:
            print(f"{p.split('/')[-1][:34]:34} too short")
            continue
        print(f"{p.split('/')[-1][:34]:34} {r['sr']:6d} {r['sec']:5.1f} "
              f"{r['peak_db']:8.2f} {r['floor_db']:9.2f} {r['dyn']:6.1f} "
              f"{r['hi_frac']:10.2e} {r['hi_db']:9.1f} {r['flat']:9.4f}")
    print()
    print("  >11.025 kHz is ABOVE THE CORPUS NYQUIST. Energy there did not come")
    print("  from the music. A high flatness in the quietest frames means those")
    print("  frames are noise rather than quiet music.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1:])
