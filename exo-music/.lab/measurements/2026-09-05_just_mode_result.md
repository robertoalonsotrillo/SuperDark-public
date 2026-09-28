# The vertical table steers. Result of the just-mode run.

*70 minutes, 374 windows, 661 voice births, 316 of them steered.
Read against `2026-09-05_just_mode_prereg.md`, which was written before the run.*

## The question

Whether `simultaneity_weight` actually moves the output, or whether snapping
every voice to a pitch the corpus holds produces corpus-typical intervals on its
own. The first attempt could not tell those apart: intervals sat at twice chance
in **both** arms.

`simultaneity_mode: just` supplies a table of 5-limit ratios the corpus has no
reason to contain, so any shift toward them cannot come from the material.

## Prediction 1 — can the corpus honour an imposed interval?

```
snap displacement   median 11.5 cents   p90 29.6   max 1200.0
                    90% under 30 cents, 93% under 50
```

**Yes.** The corpus is dense enough that asking for a pitch and getting the
nearest one it holds costs about a tenth of a semitone. This was the result that
decides how to read everything else: it means a null in the interval statistic
would have meant the steering is inert, and could not have been blamed on the
snap.

(The 1200-cent maximum is the octave randomisation, not a snap failure.)

## Prediction 2 — does the output go where the table asked?

The decisive form, comparing the ratio the table asked for against the ratio
actually achieved, octave-folded:

```
|asked - achieved|   median 9.3 cents   p90 41.9
                     85% within 30 cents of what the table asked
                     91% within 50 cents
```

**The steering works.** A steered voice lands where the table pointed, to within
about a tenth of a semitone in the median case.

The population form, over every interval sounding in every window:

```
near a JUST   table   36.0%
near a CORPUS table   28.7%
near a RANDOM table   25.6% +/- 4.6   (2000 draws, 6 members in the octave)

z(just) = +2.27      percentile of just among random tables: 98.9
z(corpus) = +0.68
```

The just table is at the 99th percentile of arbitrary six-member tables; the
corpus table, on this run, is not distinguishable from arbitrary. That is the
right direction — the imposed tuning is present in the output — but it is a much
weaker effect than the direct measurement, for a reason predicted in advance:
`VERTICAL` counts every sounding pair against the current lowest voice, while
the table only ever related one new voice to whatever was lowest at its birth.
Most of what the population statistic counts is pairs the table never touched.

## Prediction 3 — the chance baseline, which I got wrong

The pre-registration named a circular shift as the null. **That null is void.**
The statistic is a fraction over the whole set of intervals, and a circular
shift is a permutation, so the shifted value is *identical by construction*. It
returned 36.1% +/- 0.0 and z = +0.00, which reads like a crisp null result and
is an artefact of the test.

Third time in this project that a reordering has been mistaken for a control,
after the vertical census scored voice persistence as harmony and the first
novelty tool reported z = +10.27 on a shuffle. The rule that keeps being
relearned: **if the statistic does not depend on order, a reordering cannot be
its null.** The replacement varies the thing the hypothesis is about — the table
— and draws random six-member tables from the octave.

## What this licenses, and what it does not

Licensed: the vertical mechanism moves the pitch of individual voices to where a
supplied table asks, reliably, and an externally imposed tuning shows up in the
sounding output above chance.

Not licensed: that the factory has harmony. What is demonstrated is control over
a *dyad at the moment a voice is born*. Whether the resulting simultaneities
persist, relate to each other, or do anything a listener would call harmonic is
untouched by this run. The population statistic is weak precisely because the
mechanism is per-voice-birth and nothing sustains the relation afterwards.

The obvious next step, and it is a design question rather than a measurement
one: the anchor expires. A voice is tuned against whatever was lowest when it
started, and that voice may be gone seconds later, leaving the interval
stranded. Holding an anchor across a section — the way `tonic_centres` already
holds a centre — is what would turn per-birth dyads into something with
vertical continuity.

## Housekeeping

`simultaneity_mode` returns to `corpus` after this run. `just` was a contrast
arm imported precisely because the material has no reason to contain it, and it
is not a musical proposal.

Also observed over the same 70 minutes: **ACQUIRED 1, ACQFAIL 46.** The
acquisition rate has fallen from 23/hour immediately after the gate change to
about 1/hour, with refusals now dominating. That is the decay predicted when the
gate was rebuilt — the factory was filling a backlog of positions that had
always been legitimately empty and merely unreachable, and it has now filled
them. The bloat worry is closed.
