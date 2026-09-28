# M-D fails its pre-registered rule, and the rule was wrong in two ways

15 September 2026, 18:30. Against
`.lab/measurements/2026-09-15_partial_hold_prereg.md`, written before the tool.
Data: 60 minutes of isolated macro from `live_260915_171908`, checkpointed as
`ck_260915_182047_mc-isolation-final`, preserved at
`/Volumes/FMA/superdark/measurements/mc_isolation_260915.wav`.

## The arms

| arm | holds | median s | sd s | p95 s | max s | >1 s cover | sounding |
|---|---|---|---|---|---|---|---|
| SUSTAINED (control) | 1 | **29.854** | 0.000 | 29.854 | 29.854 | 1.000 | 1.000 |
| LOOP | 15,680 | 0.0920 | 0.345 | 1.012 | 2.346 | 0.342 | 0.940 |
| DIVERSE | 157,590 | 0.0460 | 0.155 | 0.322 | 8.510 | 0.058 | 0.997 |
| FACTORY | 8,049 | 0.0920 | 0.602 | 1.426 | 9.476 | 0.532 | 0.643 |

**The control passed.** One hold of 29.854 s over 30 s, 99.5% coverage. The
tracker can see a held tone, which is the thing M-A never proved about itself.

**The pre-registered decision rule failed.** LOOP to DIVERSE median gap
−0.046 s, separation **−0.17 sd** against a required +3.0. Under the rule as
written, M-D is retired and no factory number from it may be quoted.

## Two design errors in the rule, both visible only now

**1. `LOOP` is identical to `FACTORY` by construction for this statistic.**
The LOOP arm is a 90 s stretch of the factory's own isolated macro, repeated. A
hold is a within-frame-sequence quantity, so looping the same material reproduces
the same holds. LOOP median 0.0920 and FACTORY median 0.0920, exactly. For M-A,
which measured similarity *across* spans, a loop was a meaningful floor. For a
duration statistic *inside* a stretch it carries no information at all.

The decision rule therefore tested LOOP against DIVERSE, which for this measure
is the factory against real music wearing a different label. The contrast that
means something is DIVERSE against FACTORY, and the rule never named it.

**2. Median with a pooled sd is the wrong test for heavy-tailed durations.**
Hold durations run from one frame to 9.5 s. The sd is dominated by the tail, so a
2× difference in medians normalises to 0.17 sd. Almost nothing could separate
under that statistic. The rule was unfalsifiable in the direction that mattered
and I did not see it when writing it.

## What I may not do, and why it is written here

`long_hold_cover` — the fraction of sounding time inside holds longer than 1 s —
separates hard and in the direction of Roberto's complaint:

> FACTORY **0.532** against DIVERSE **0.058**, a factor of **9.1**.

Macro-only spends over half its sounding time on one pitch, against under 6% for
600 unrelated tracks. That is the drone, quantified.

**And it cannot carry a claim.** The pre-registration names `long_hold_cover` as
a reported quantity and fixes the *decision* on median. Choosing it now, after
seeing which statistic separated, is the goalpost-moving the release policy
forbids in as many words: *"Once the numbers are in, nobody gets to move the
goalposts, including us."*

So it is recorded as an observation on data that is now **seen**, and it is
exactly the thing a re-run has to be pre-registered against.

This is the cost of the apparatus and it is the apparatus working. A number that
agrees with the ear, points the right way, and is a factor of nine, sits here
unusable because I wrote the rule badly. The alternative is a project where the
rule is whatever the data suggests afterwards.

## M-D': what to pre-register next

- **Decision statistic:** `long_hold_cover`, the fraction of sounding time in
  holds ≥ 1 s.
- **Contrast:** FACTORY against DIVERSE. Drop LOOP for this measure, and say why
  in the registration.
- **Test:** a permutation null over the hold sequence instead of a pooled sd, so
  a heavy tail cannot swallow the effect.
- **Data:** a fresh isolation run. Today's hour is spent.
- **Sounding fraction is a covariate, not a nuisance.** FACTORY sounds 64% of
  the time against DIVERSE's 99.7%. A layer that is quiet a third of the time and
  holds one pitch when it sounds is a different object from one that holds a
  pitch continuously, and the registration has to say which is being claimed.

## What M-D already establishes without a claim

The control arm passed, so the instrument works. That result stands whatever
happens to the decision rule, and it is the reason M-D' can reuse the tracker
instead of rebuilding it.

## Retirement

M-D is retired in `harness/measures.json` under its pre-registered rule, with
zero adjudications. Fifth measure retired here, and the second today. Both were
caught by their arms before any claim was made.

The four before it saturated because the *statistic* could not discriminate.
M-D is different: the statistic discriminates and the **decision rule** could
not. That is a new failure mode for this project and it is worth naming
separately, because the fix is different. A saturated statistic gets replaced.
A bad rule gets rewritten against the same statistic.

## Roberto's ear, again

While this ran he said of the isolation: *"it produces no harmonies whatsoever."*
That is a fourth observation about the output ahead of the instruments, and it is
about a dimension M-D does not measure at all. M-D tracks one dominant partial,
so vertical structure is invisible to it by construction. Whatever M-D' says
about held tones, the absence of harmony in macro-alone is a separate finding and
needs its own instrument.
