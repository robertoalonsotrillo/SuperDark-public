# The long-range number moved, and the short-range number moved the wrong way

8 September 2026. Run `live_260908_100337`, 1,739 windows over 5.4 hours. Three
arms at exactly 7,200 s each, 12,239 frames apiece. First thirty minutes
discarded, as pre-registered, because the spread's horizon fills over 16 sections
and the mechanism is still warming up before then.

## The table

| match window | LOOP | FACTORY | DIVERSE | position | 5 Sept |
|---|---|---|---|---|---|
| 2–20 s | 0.7467 | 0.7954 | 0.7946 | arms not separated | — |
| 5–60 s | 0.8988 | 0.8166 | 0.7993 | **0.17** | 0.10 |
| 20–300 s | 0.9161 | 0.8456 | 0.8103 | **0.33** | 0.21 |
| 60–900 s | 0.9749 | 0.8704 | 0.8398 | **0.23** | 0.33 |
| 300–1800 s | 0.9976 | 0.8810 | 0.8531 | **0.19** | **0.74** |
| 600–3600 s | 0.9977 | 0.8944 | 0.8672 | **0.21** | never measurable |

Every row is powered this time. The 600–3600 s row exists for the first time.

## What improved

**The 300–1800 s position fell from 0.74 to 0.19.** That is the number the
section spread was built to move, and it has moved almost the whole distance to
the diverse arm.

**The shape changed, which is the stronger claim.** On 5 September the position
climbed monotonically with window length — 0.10, 0.21, 0.33, 0.74 — which was the
signature of a factory that varies locally and repeats globally. It is now flat:
0.17, 0.33, 0.23, 0.19, 0.21. There is no longer a timescale at which the factory
approaches a loop.

## What got worse, and it was pre-registered

**The 5–60 s position rose from 0.10 to 0.17, and 20–300 s from 0.21 to 0.33.**

The pre-registration for this experiment said, in as many words: *"the 0.10 at
5–60 s must not rise."* It rose. That condition is violated and the result has to
be reported as mixed, not as a success.

## This is not a controlled comparison, and the difference cannot all be credited

Between 5 September and today the factory also gained a fix for the voice-fill
hang, a salvaged `memory.json`, and a corpus reassembled at self-ingest weight
0.75. The runs differ in length (70 min against 120 min) and in day. Attributing
0.74 → 0.19 to the section spread alone is not warranted by this design, and
saying so is not modesty: a single-arm before-and-after across four changes is
exactly the shape of evidence this project has had to withdraw before.

What can be said is that the spread demonstrably ran — 101 sections, 73 improving
on their discarded first draw, 28 tying, none worse, mean lift +32% against the
+25% the offline sweep predicted, at a full horizon of 16 — and that the number it
targets is now small.

## The short-range rise has a candidate cause, reported independently

Roberto, listening to this same run: *"the macro has a tendency to just produce
long sustained low-pitched notes forever, there is not too much structural or
spectral variety."*

A sustained tone is self-similar at 5–60 s and says little about 300–1800 s. So
the ear and the table are plausibly describing one phenomenon from two sides. The
mechanism is in the code and is not subtle: `macro_hold_grains` is **1**, so a
macro voice's entire grain pool is the single nearest grain in pitch, held and
overlapped across a 90-second span. `macro_rate_lo/hi` spans 5.2 semitones and
`macro_cut_lo/hi` band-limits to 220–3600 Hz.

That is a hypothesis, not a finding. It predicts something testable.

## The next experiment, and its prediction fixed now

One knob: `macro_hold_grains` from **1 to 6**. Nothing else changes.

- **Prediction:** the 5–60 s position falls back toward 0.10, and the 300–1800 s
  position stays below 0.3.
- **If 5–60 falls and 300–1800 holds**, the short-range rise was the macro sustain
  and the spread's gain survives it.
- **If 300–1800 rises with it**, the two are coupled — the factory was buying its
  long-range variety out of macro monotony — and the trade has to be chosen
  deliberately rather than discovered.
- **If neither moves**, `macro_hold_grains` is not the lever and the sustain is
  coming from the span or the filter band instead.

Two hours per arm, first thirty minutes discarded, same three arms, same windows.
Do not change the rate range or the filter band in the same run: three knobs at
once would say nothing about which one worked.
