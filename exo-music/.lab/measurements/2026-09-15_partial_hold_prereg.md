# Pre-registration: M-D, partial hold on isolated macro

15 September 2026, 17:25, written while the isolation run accumulates and
**before** the tool exists. Companion to
`2026-09-15_macro_measure_prereg.md`, which pre-registered M-A (retired,
saturated and inverted) and M-B (descriptive, veto-only).

## Why not another spectral statistic

Four have now saturated here, and they share one shape: reduce a spectrum to a
normalised band vector, compare frames pairwise, average.

1. the pre-centring cosine recurrence
2. a block-shape statistic, 10 Sept
3. `m7_spectral_gap_settles`, which measured the operator's age
4. M-A, today, which ranked a literal loop as more varied than 600 unrelated
   FMA clips

Centring rescued the first and did not rescue the fourth. At 0.5 s resolution
the factory's frames are near-orthogonal in 32 log bands, and so is everybody
else's. **This family is closed.** `harness/measures.json` records it as such.

One statistic in this project's history did discriminate, and it was not of that
family: partial tracking. On 78 s of the delivered stream the dominant partial's
stable runs had a median of 0.03 s and a maximum of 0.36 s, with nothing reaching
half a second. That number separates, and it agreed with the ear.

## What M-D measures

On audio where **macro is the only sounding layer**:

1. Track the dominant spectral peak frame by frame, 46 ms hop.
2. A **hold** is a maximal run of consecutive frames whose peak stays within
   ±50 cents of the run's starting peak, at a level above the audibility floor.
3. Report the distribution of hold durations in seconds: median, p95, max, and
   the fraction of sounding time inside holds longer than 1.0 s.

Held-tone duration, on a layer whose job is to hold tones. It is the same
quantity the ear reports when it calls a stretch sustained, and it is not an
average of a similarity matrix.

## Why isolation makes this the right moment

M-A had to band-limit and argue about contamination because macro was never
alone. That is gone. `layers_active = "macro"` makes macro the only layer, and
the run confirms it: **93% of windows are macro-alone**, against 1.5% in an
ordinary run. There is nothing to filter and nothing to apologise for.

## Arms

- **LOOP**: one 90 s stretch of isolated macro, repeated. Floor for variation,
  and the holds in it should be identical every cycle.
- **DIVERSE**: 600 unrelated FMA clips. Real music holds pitches. This arm
  should show **long** holds.
- **SUSTAINED CONTROL**: a synthesised tone, 30 s, fixed frequency. This arm
  must show one hold of ~30 s. If it does not, the tracker is broken and no
  other number may be read.
- **FACTORY**: isolated macro from the M-C run.

The third arm is new and it is the important one. M-A had no arm that could
prove the instrument could detect the thing it was looking for at all. A measure
of held tones that cannot find a held tone in a synthesised sine is not a
measure, and this catches that before any factory number is read.

## Falsification, fixed now

- **Instrument invalid** if the sustained control does not yield a single hold
  covering at least 90% of its duration. No factory number is read.
- **Saturated** if DIVERSE and LOOP median hold durations do not differ by at
  least 3 pooled sd. Retire, as with M-A.
- **The complaint is supported** if FACTORY median hold is below the DIVERSE
  median by that same margin, on isolated macro.
- **The complaint is not about held tones** if FACTORY sits at or above DIVERSE.
  That result gets written up as such, and the ear's objection is then about
  something this instrument does not see. It does not mean the ear was wrong;
  the ear has been right three times here where the instruments were not.

## Data

Two hours of isolated macro from `live_260915_171908`, checkpointed as
`ck_260915_172223_mc-isolation-macro-only`. At 90 s per span that is 80 spans.
Minimum 200 scored frames per arm, the standing `MIN_SCORED` rule.

## Registration

- Enters `harness/measures.json` at 0 of 3 adjudications used, **only if** it
  passes the sustained control and the saturation check.
- Sealed into `harness/sealed_scorers.txt` before the first number is computed.
- Arms are read in the order SUSTAINED CONTROL, LOOP, DIVERSE, FACTORY, and the
  factory arm is not looked at until the first three are in.

## A standing note on the field order

`VOICES win,macro,mid,micro`. `SLOT win,layer,machine,n`. Macro is the **first**
count. Reading it backwards today produced a table that had to be corrected
within the hour, and it was caught only because the isolation run printed a
combination that was impossible under the wrong assumption.
