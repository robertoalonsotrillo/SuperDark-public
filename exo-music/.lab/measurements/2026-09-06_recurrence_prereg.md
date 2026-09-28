# Does the recurrence measure discriminate at all?

Pre-registered 6 Sept 2026, before the corrected statistic was written.

## Why this exists

Task 69 asked for a measure of *sonic* repetition, because every variety metric
in the charter is over machine identity and all four can pass while the output is
sonically identical. `tools/sonic_variety.py` was built for that on 4 Sept and
has never been run against a control.

Run on 6 Sept against the hour Roberto listened to on 5 Sept (19:00–20:05, the
hour after which he said "it does not surprise me anymore"):

    recurrence  observed 0.9884   shuffled 0.9902 +/- 0.0066
    z = -0.28
    spectral participation ratio  3.06 of 24 bands

and the tool printed its verdict: *"The factory is no more self-similar than its
own material forces. Rearranging it would not help."*

That verdict was then tested against 140 unrelated FMA tracks by 140 different
artists, concatenated to the same 70 minutes:

    recurrence  observed 0.9961   shuffled 0.9968 +/- 0.0024
    z = -0.29
    spectral participation ratio  5.30 of 24 bands

**The maximally diverse reference scores HIGHER recurrence than the factory.**
The statistic is saturated: cosine similarity between L2-normalised non-negative
log-band vectors is bounded far above zero by the non-negativity alone, so every
frame of any music has a near-perfect match to every other. The measure returns
about 0.99 for anything, and its verdict text is unsupported for the same reason
a shuffled null returned z = +0.00 on the vertical census in August. This is the
fourth statistic in this project to look decisive while measuring a constant.

The participation ratio, which is not a similarity and not bounded that way, did
separate the arms: 3.06 against 5.30.

## The three arms

| arm | material | duration |
|---|---|---|
| LOOP | one 30 s FMA clip (122456) repeated 140 times | 70 min |
| FACTORY | segments `cap_260905_19*` + `200016`, 5 Sept 19:00–20:05 | 70 min |
| DIVERSE | 140 randomly drawn FMA tracks, one clip each | 70 min |

All three decoded identically: mono, 22050 Hz, same feature pipeline, same
frames, same 20–300 s match window.

## The criterion, fixed before the statistic is run

A recurrence measure is admissible only if:

1. **Ordering.** LOOP > FACTORY > DIVERSE, strictly.
2. **Separation.** `LOOP − DIVERSE` is at least 5× the larger of the two arms'
   within-arm standard errors. A measure that orders the arms by less than its
   own noise has not discriminated, it has been lucky once.
3. **Loop sanity.** LOOP is a signal whose every frame recurs exactly, so it must
   sit near the top of the statistic's range. A measure that puts a literal loop
   in mid-range is measuring something other than recurrence.

If a candidate fails any of these it is discarded and recorded here as discarded.
No bound is derived from a statistic that has not passed all three.

## What each outcome licenses

- **FACTORY near LOOP.** The factory returns to itself far more than diverse
  music does, and that excess is what a selection change can reduce. This is the
  outcome that makes tasks 70 and 71 the right work.
- **FACTORY near DIVERSE.** The factory is genuinely varied at the 20–300 s
  timescale, and the exhaustion Roberto reports lives somewhere this statistic
  does not look: grain-scale identity, gesture shape, or form above five minutes.
  Tasks 70 and 71 would then be aimed at the wrong axis and the honest next step
  is to find the timescale that does separate.

The second outcome is the one this pre-registration exists to make reportable.
Writing the criterion down first is what stops it being read as a failed
experiment and quietly rerun with a different window until it separates.

## What is NOT claimed

Nothing here says which arm *sounds* more varied. The blind-listening experiment
the charter asks for (see `m9_turnover._no_bound`) still does not exist, and
until it does, a recurrence figure is a description of the signal and not a
judgement of the music.
