# The full-vector prediction was confirmed, and the measure now disagrees with the ear

10 September 2026. Run `live_260910_002430`, 2,662 windows over 8.1 hours. Three
arms at 7,200 s each, 12,239 frames apiece, 02:24–04:24, first thirty minutes
discarded.

## Three configurations, same measure

| match window | A: hold=1 | B: hold=6 | C: hold=6 + full-vector + rest |
|---|---|---|---|
| 5–60 s | **0.17** | **0.11** | 0.25 |
| 20–300 s | **0.33** | 0.25 | 0.43 |
| 60–900 s | **0.23** | 0.28 | 0.28 |
| 300–1800 s | **0.19** | 0.44 | 0.22 |
| 600–3600 s | **0.21** | 0.48 | 0.22 |

A and B are the two halves of 8 September, hot-swapped inside one run. C is
today, after a restart, with three changes live together.

## The prediction was confirmed, in mechanism

Before the run, the full-vector change was argued to give **less** within-voice
variety and **more** between-voice distinctiveness — a coherent 41%-of-corpus
region per voice instead of a 70% grab-bag. That is exactly the shape of the
result:

- **Long range recovered.** 300–1800 s fell 0.44 → 0.22 and 600–3600 s 0.48 →
  0.22. The damage hold=6 did is undone: voices at different targets are now
  distinct regions rather than repeated samples of the whole corpus.
- **Short range worsened.** 5–60 s rose 0.11 → 0.25 and 20–300 s 0.25 → 0.43,
  because each voice now moves within a tighter timbral neighbourhood.

Both halves of a prediction that ran against my own earlier, wrong explanation.
The corpus measurement made before the run said what would happen and it did.

## And the uncomfortable part

**On this measure, configuration A — the original `hold=1` — is the best of the
three at every single window.** 0.17 against 0.25, 0.33 against 0.43, 0.23
against 0.28, 0.19 against 0.22, 0.21 against 0.22.

A is the configuration Roberto described as *"endless sustained low-pitched notes
forever, the behaviour is sonically limited."*

So the instrument and the ear now point opposite ways, and that is the finding.
Either the recurrence measure does not capture what makes a macro layer feel
exhausted, or a single 0.8 s grain held across a 90 s span is *spectrally* varied
across a run while being *perceptually* monotonous within any one stretch. The
second reads as the more likely: each voice was a different grain, so the run
covers the corpus, and a listener inside any ninety seconds hears one unchanging
tone.

This is the m4-versus-sound gap in a new place. Every variety metric in the
charter can pass while the output is sonically identical; here a *sonic* measure
passes while the layer is perceptually static. The measure is over 0.5 s frames
of the full mix, and macro is roughly 13% of audible events against micro's 87%,
so a macro-specific complaint is close to invisible in it.

## What this does not license

Three changes went live together — `macro_full_vector`, `rest_macro_after`, and
the −70 dB ingest floor — plus a restart and a reassembled corpus. **No movement
here is attributable to any one of them.** A clean attribution needs
`macro_full_vector 0` against an otherwise identical run, two hours each.

## What to do next, and it is a decision rather than a measurement

The numbers cannot choose between A and C, because they prefer A and Roberto
rejects A. The honest options:

1. **Trust the ear and keep C.** The macro layer now rests (82 times in 8.1 h
   against 11 in 8 h) and each voice inhabits a coherent region. The measure says
   this costs short-range variety; the listener says the previous state was
   unlistenable. Aesthetic authority sits with the listener.
2. **Build the measurement the complaint deserves.** Isolate macro-attributable
   stretches using the slot log and measure that layer on its own terms, instead
   of averaging it against seven times its number of micro events. Until that
   exists, no number here can adjudicate a macro question.

Option 2 is the one that would let the instrument and the ear be compared at all.
