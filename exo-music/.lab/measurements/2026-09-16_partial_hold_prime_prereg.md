# Pre-registration: M-D′, held tone on isolated macro, done properly

16 September 2026, 00:35. Written before the isolation run that will feed it and
before the scorer exists. Supersedes the decision rule of
`2026-09-15_partial_hold_prereg.md`; the tracker itself is unchanged and is
reused.

## Why M-D was retired and M-D′ is not just a re-run

M-D's control arm passed: one hold of 29.854 s over a 30 s synthesised tone,
99.5% coverage. **The instrument works.** What failed was the decision rule, and
it failed in two ways that are now fixed:

1. **LOOP was identical to FACTORY by construction.** The LOOP arm was a repeat
   of the factory's own isolated macro, and a hold is a within-stretch quantity,
   so looping reproduces the same holds. Both medians came out 0.0920 exactly.
   The rule tested the factory against real music wearing a different label.
2. **Median with a pooled sd is unfalsifiable for heavy-tailed durations.** Holds
   ran from one frame to 9.5 s; the sd is dominated by the tail, so a 2×
   difference in medians normalised to 0.17 sd.

This is a different failure from the four saturations before it. There the
*statistic* could not discriminate. Here the statistic discriminates and the
*rule* could not. A saturated statistic gets replaced; a bad rule gets rewritten
against the same statistic. That is what this is.

## The decision statistic, fixed now

**`long_hold_cover`**: the fraction of sounding time spent inside holds of at
least 1.0 s.

It was already defined and reported in yesterday's pre-registration. It was not
the decision statistic, and yesterday's numbers may therefore not be claimed. It
becomes the decision statistic **here, before the data exists**, which is the
whole difference.

## The contrast

**FACTORY against DIVERSE.** LOOP is dropped for this measure, and the reason is
recorded above: for a within-stretch duration statistic a loop of the factory is
the factory.

- **FACTORY**: isolated macro, `layers_active = "macro"`, a fresh run.
- **DIVERSE**: 600 unrelated FMA clips, 30 s each, the same arm built for M-A.
- **SUSTAINED control**: the synthesised tone, retained and still gating. If it
  does not yield a single hold covering ≥ 90% of its duration, the tracker is
  broken and no other arm is read.

## The test: a permutation null, not a pooled sd

`long_hold_cover` is a ratio of summed durations, so a pooled sd over a
heavy-tailed distribution is the wrong yardstick and is what sank M-D.

Instead: pool the hold sequences of both arms, permute the arm labels 2,000
times, and recompute the difference in `long_hold_cover` each time. Report the
observed difference and its position in that null.

**Significant at p ≤ 0.01, two-tailed.** The threshold is set now, not after.

## Pre-registered outcomes, all three written before the data

- **Complaint supported** — FACTORY `long_hold_cover` exceeds DIVERSE with
  p ≤ 0.01. Macro holds single pitches far more than real music does, which is
  the drone, quantified.
- **Complaint not about held tones** — FACTORY at or below DIVERSE, or p > 0.01.
  Written up as such. It would not mean the ear was wrong; it would mean this
  instrument does not see what the ear hears, and the fourth ear-ahead-of-
  instrument observation (`macro_has_no_harmony`) would become the live lead.
- **Instrument invalid** — the sustained control fails. Nothing else is read.

## The covariate that must be reported, not buried

Yesterday FACTORY sounded **64%** of the time against DIVERSE's **99.7%**. A
layer quiet a third of the time that holds one pitch when it does sound is a
different object from one that holds a pitch continuously.

`long_hold_cover` is already normalised by *sounding* time, so the covariate does
not contaminate it. It is reported beside the result anyway, because a reader
comparing this to a number computed over wall-clock time would otherwise be
comparing different quantities. Both are in the bundle.

## Data, and why it must be fresh

Yesterday's hour of isolated macro is **seen**: it was used to discover which
statistic separated. Reusing it would be the goalpost-move dressed as a re-run.

A new isolation run, `layers_active = "macro"`, two hours, with the ingest daemon
**not started** — `start_loop.sh` now refuses to start it when fewer than three
layers are active, after yesterday's run admitted macro-only audio into the pools
of the silent layers. `memory.json` gets restored from the pre-isolation
checkpoint afterwards.

Minimum 200 scored frames per arm. Two hours at a 46 ms hop is roughly 156,000,
so the binding constraint is the isolation itself, not the count.

## Registration

- Scorer: `tools/partial_hold.py`, already sealed. If the permutation null needs
  code, it goes in a **new** function and the change is `adopt`ed with a reason,
  so every number keeps a hash beside it.
- M-D′ enters `harness/measures.json` at 0 of 3 adjudications **only if** it
  passes the control and the permutation test is well formed.
- Arms read in order: SUSTAINED, DIVERSE, FACTORY. The factory arm is not looked
  at until the first two are in.

## What this cannot settle

Vertical structure. `partial_hold` tracks one dominant partial, so harmony is
invisible to it by construction. Roberto on yesterday's isolation: *"it produces
no harmonies whatsoever."* That is a separate finding and needs its own
instrument, recorded as owed under `macro_has_no_harmony`.
