#!/usr/bin/env python3
"""Why is the factory silent? Three hypotheses, separated by what it REQUESTED.

The question was stuck because every quantity in the log measured the OUTPUT.
`amp` is Amplitude.kr on the output bus and `masterPeak` is the per-window max
of the same signal, so correlating them said nothing, and conditioning one on
the other -- which is what m1_audible_when_driving does -- is close to circular.

The REQUEST line added on 2 Sept measures the demand side instead:

    REQUEST win,fires,events,meanAmp
      fires     voices started this window
      events    note events those voices produced
      meanAmp   mean \\amp each event carried, AFTER the life-arc multiplier

Silence then has three distinguishable causes:

    H1  NOBODY FIRED         fires ~ 0. A scheduling problem: the factory is
                             not starting voices.
    H2  FIRED, NO EVENTS     fires > 0 but events ~ 0. The machines are running
                             but their patterns are not producing notes.
    H3  EVENTS, NO LEVEL     events > 0 but meanAmp near zero. The music is
                             being played at amplitudes that cannot be heard --
                             which would point at the life arc, or at machine
                             \\amp values calibrated for a different playback
                             path. Note the standing comment in live_factory.scd:
                             the two playback paths disagree about BufRateScale
                             and "no machine's \\amp was recalibrated".

Whichever dominates is where the silence lives, and the three imply completely
different repairs.

    python3 tools/why_silent.py
"""
import argparse
import glob
import os
import statistics as st
import sys


def read(path):
    req, peak = {}, {}
    for line in open(path, errors="replace"):
        if line.startswith("REQUEST "):
            p = line.split()[1].split(",")
            try:
                req[int(p[0])] = (int(p[1]), int(p[2]), float(p[3]))
            except (ValueError, IndexError):
                pass
        elif line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                peak[int(p[0])] = float(p[1])
            except (ValueError, IndexError):
                pass
    return req, peak


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=None)
    a = ap.parse_args()
    log = a.log or sorted(glob.glob("/Volumes/FMA/superdark/renders/live_*.log"),
                          key=os.path.getmtime)[-1]
    req, peak = read(log)
    ws = sorted(set(req) & set(peak))
    if len(ws) < 20:
        raise SystemExit(f"  only {len(ws)} instrumented windows so far; "
                         f"let it run longer")

    sil = [w for w in ws if peak[w] < 0.004]
    snd = [w for w in ws if peak[w] >= 0.004]
    print()
    print(f"  {os.path.basename(log)}: {len(ws)} instrumented windows, "
          f"{len(sil)} silent ({100*len(sil)/len(ws):.0f}%)")
    print()
    print(f"  {'':10} {'fires':>16} {'events':>16} {'mean amp':>16}")
    for tag, sel in (("silent", sil), ("sounding", snd)):
        if not sel:
            continue
        f = [req[w][0] for w in sel]
        e = [req[w][1] for w in sel]
        m = [req[w][2] for w in sel]
        print(f"  {tag:10} {st.median(f):7.1f} (max {max(f):3d}) "
              f"{st.median(e):7.1f} (max {max(e):4d}) "
              f"{st.median(m):10.5f} (max {max(m):.3f})")

    if not sil:
        print("\n  no silent windows in this stretch; nothing to attribute")
        return 0

    # Attribute each silent window to the first hypothesis that fits.
    h1 = [w for w in sil if req[w][0] == 0]
    h2 = [w for w in sil if req[w][0] > 0 and req[w][1] == 0]
    h3 = [w for w in sil if req[w][1] > 0]
    print()
    print("  ATTRIBUTION of the silent windows:")
    print(f"    H1  no voices fired          {len(h1):5d}  "
          f"{100*len(h1)/len(sil):5.0f}%")
    print(f"    H2  fired, produced no events{len(h2):5d}  "
          f"{100*len(h2)/len(sil):5.0f}%")
    print(f"    H3  events, but no level     {len(h3):5d}  "
          f"{100*len(h3)/len(sil):5.0f}%")
    if h3:
        m = [req[w][2] for w in h3]
        print(f"        their mean requested amp: median {st.median(m):.5f}, "
              f"max {max(m):.4f}")

    print()
    top = max((len(h1), "H1"), (len(h2), "H2"), (len(h3), "H3"))[1]
    if top == "H1":
        print("  The factory is not STARTING voices in these windows. That is a")
        print("  scheduling question -- what governs when a voice fires -- and")
        print("  has nothing to do with the corpus or with amplitude.")
    elif top == "H2":
        print("  Voices are running but their patterns produce no notes. The")
        print("  machines are alive and silent, which points at the machine")
        print("  definitions rather than at levels.")
    else:
        print("  Notes ARE being played, at amplitudes too low to hear. That is")
        print("  the life arc, or machine \\amp values calibrated against the")
        print("  older playback path. Both are fixable and both change the music,")
        print("  so both are decisions rather than repairs.")
    print()
    print("  Sounding windows are shown alongside so the silent ones can be read")
    print("  as a difference rather than in isolation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
