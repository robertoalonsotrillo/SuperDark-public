#!/usr/bin/env python3
"""Map each machine's filter contour onto the band the corpus actually occupies.

MEASURED, grains_600 (300 grains, 22050 Hz, Nyquist 11025):

    rolloff 50%   median   369 Hz    p90  1275 Hz
    rolloff 90%   median   896 Hz    p90  3024 Hz
    rolloff 99%   median  2335 Hz    p90  6414 Hz    max 10172 Hz

The corpus is dark. Archon's machines were written for bright material and say
so in their constants:

    gl  (audible)   Env([bright*1000, bright*2000, bright*500])    825 - 3300 Hz
    st  (silent)    Env([rrand(2500,6000), rrand(6000,16000), …]) 2500 - 16000 Hz
    gp  (silent)    Env([cent, cent*5, cent/2])                   2574 - 25740 Hz
    bu  (silent)    Env([cent, cent*5, cent/2])                   2574 - 25740 Hz

`gl` is not written better than the others. It happens to land where the corpus
lives. `st` and `gp` high-pass three octaves above anything that exists, and
`gp`/`bu` sweep past Nyquist. Confirmed by experiment: handed a flat 44.1 kHz
noise corpus, `st` gains 9.0 dB and `gp` gains 20.4 dB, while `gl` LOSES 6.4 dB.

This is the third instance of one failure mode, after discretize(128) and
voice_span 4.0: a constant calibrated against one corpus, transferred silently
to another. Nothing errors, because the score entries are still produced.

WHAT THIS DOES NOT DO: clamp. Clipping 25740 to 2335 would flatten every sweep
into a constant and delete the gesture the envelope exists to make. `scBand`
rescales the contour into the band and keeps its shape and direction, so a
machine that sweeps up still sweeps up, over frequencies that contain audio.

`scBand` is written out as a class extension rather than using the built-in
`normalize(min, max)`, because on these arrays `normalize` returned its input
unchanged: the first version of this patch applied cleanly to the text, did
nothing at all, and produced renders bit-identical to the unpatched ones.

The band differs by filter type, which is the point:
  HPF machines  a cutoff at the ceiling passes nothing, so they get a LOW band
  BPF machines  a centre anywhere in the occupied range passes something

Applied to a COPY. lib/Handler_Local.sc is never modified.
"""
import re
import sys

# derived from the measurement above, not chosen to taste
HPF_BAND = (200, 3000)    # below the median 99% rolloff of 2335 Hz
BPF_BAND = (300, 5000)    # up to the p90 99% rolloff of 6414 Hz

INSTRUMENT_BAND = {"playbackHP": HPF_BAND, "playback": BPF_BAND, "playgran": BPF_BAND}


EXTENSION = """// Written by tools/patch_cutoffs.py. Maps a contour onto a frequency band,
// preserving its shape and direction. The built-in normalize(min, max) returns
// these arrays unchanged, which made the first version of the cutoff patch a
// silent no-op.
+ SequenceableCollection {
\tscBand { |lo, hi|
\t\tvar mn = this.minItem, mx = this.maxItem;
\t\t^if (mx <= mn) { this.collect({ lo }) } {
\t\t\tthis.collect({ |v| v.linlin(mn, mx, lo, hi) }) };
\t}
}
"""


def patch(path):
    import os

    with open(os.path.join(os.path.dirname(path), "ScBand.sc"), "w") as f:
        f.write(EXTENSION)
    src = open(path).read().split("\n")
    methods = [
        (i, re.match(r"^\t(\w+) \{", l).group(1))
        for i, l in enumerate(src)
        if re.match(r"^\t\w+ \{", l)
    ]
    players = [(i, n) for i, n in methods if n.endswith("Player")]

    edits, report = [], []
    for start, name in players:
        stop = next((i for i, _ in methods if i > start), len(src))

        # each \cutoff slot, and the .asArray that closes its value expression
        for x in range(start, stop):
            if not re.match(r"^\s*\\cutoff,", src[x]):
                continue

            # the instrument for THIS pattern, not the method's first one.
            # stretchPlayer declares \playback for one pattern and \playbackHP
            # for the other, and taking the first attributed a high-pass site
            # to the wrong band.
            instrument = None
            for y in range(x, start, -1):
                m = re.search(r"\\instrument,\s*\\(\w+)", src[y])
                if m:
                    instrument = m.group(1)
                    break
            lo, hi = INSTRUMENT_BAND.get(instrument, BPF_BAND)

            tgt = next(
                (y for y in range(x, min(x + 12, stop)) if ".asArray" in src[y]), None
            )
            if tgt is None or "scBand" in src[tgt]:
                continue
            edits.append((tgt, src[tgt].replace(".asArray", f".asArray.scBand({lo}, {hi})")))
            report.append(f"  {name:16} {instrument or '?':11} line {tgt + 1}  -> {lo}-{hi} Hz")

    for line, text in edits:
        src[line] = text
    open(path, "w").write("\n".join(src))
    print("\n".join(report))
    print(f"  mapped {len(edits)} cutoff contours onto the measured corpus band")
    return len(edits)


if __name__ == "__main__":
    if patch(sys.argv[1]) == 0:
        sys.exit("  ABORT: no cutoff sites patched; has the file changed?")
