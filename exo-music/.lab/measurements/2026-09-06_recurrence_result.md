# The factory varies locally and repeats globally

Result, 6 Sept 2026. Criteria fixed in `2026-09-06_recurrence_prereg.md` before
the statistic was written.

## The old measure was reporting a constant

`sonic_variety.py` as built on 4 Sept returned, on 70 minutes each:

| arm | recurrence | participation ratio |
|---|---|---|
| FACTORY (5 Sept 19:00–20:05) | 0.9884 | 3.06 |
| DIVERSE (140 unrelated FMA tracks) | **0.9961** | 5.30 |

140 artists who have never heard each other scored as MORE self-similar than the
factory. Cosine between L2-normalised non-negative log-band vectors cannot fall
far below 1, so the statistic spent its range on "this is music". Its printed
verdict — *"rearranging it would not help"* — was unsupported.

Fixed by centring the features on the run's mean spectrum, which turns the cosine
into a correlation over bands. `--raw` reproduces the old figures and is marked
in the tool as unfit for a claim.

## The corrected measure is admissible

At the 20–300 s window, three arms of identical length and pipeline:

| arm | recurrence | block SE |
|---|---|---|
| LOOP (one 30 s clip ×140) | 0.9926 | 0.0002 |
| FACTORY | 0.8484 | 0.0056 |
| DIVERSE | 0.8111 | 0.0059 |

1. **Ordering** LOOP > FACTORY > DIVERSE ✓
2. **Separation** LOOP − DIVERSE = 0.1815, against 5×SE = 0.0295 ✓
3. **Loop sanity** a literal loop sits at the top of the range ✓

Admissible on all three. Note that the shuffled null inside the tool is *not*
what carries this: its standard deviation is 0.08, so z never reaches
significance for any arm. The calibration arms are doing the work, and the z line
should be read as decoration.

## The finding: position climbs with timescale

Position is `(FACTORY − DIVERSE) / (LOOP − DIVERSE)`. 0 means as varied as 140
unrelated artists; 1 means a loop. Raw recurrence rises with window length for
every signal, so only the position is comparable across rows.

| match window | LOOP | FACTORY | DIVERSE | factory position |
|---|---|---|---|---|
| 2–20 s | 0.6648 | 0.8157 | 0.7970 | arms not separated |
| 5–60 s | 0.9917 | 0.8216 | 0.8032 | **0.10** |
| 20–300 s | 0.9926 | 0.8484 | 0.8111 | **0.21** |
| 60–900 s | 0.9612 | 0.8805 | 0.8411 | **0.33** |
| 300–1800 s | 0.9033 | 0.8922 | 0.8606 | **0.74** |
| 600–3600 s | 0.8824 | 0.9453 | 0.8263 | underpowered, 8 frames |

Monotone, and it spans most of the axis. **At one-minute scale the factory is as
varied as 140 unrelated artists. At half-hour scale it is three-quarters of the
way to a loop.**

The 2–20 s row is the loop failing correctly: inside a single 30 s clip there is
nothing repeating at a 2–20 s lag, so LOOP scores *below* both other arms and the
row cannot calibrate. The 600–3600 s row scored eight frames on a 3570 s file and
is discarded; the first sweep reported it as 0.9453, above a literal loop, and a
`MIN_SCORED` guard now refuses it.

## What this settles

This is outcome 1 of the pre-registration, but not at the timescale the tasks
assumed. The factory does return to itself more than diverse music does, and the
excess is entirely at long range. That is precisely the report it was measured
against — Roberto, 5 Sept, after an hour of listening: *"I can identify most
behaviours, it has reached the point where it does not surprise me anymore."*
Minute to minute the factory surprises. Over half an hour it has shown its hand.

## What this un-settles

Tasks 70 and 71 were both written as **local** interventions:

- **70, per-voice divergence** gives each voice its own target offset, pitch and
  processing, which decorrelates voices *within a window*. The 5–60 s position is
  already 0.10; there is very little there to win.
- **71, layer dropout driven by the repetition measure** removes a layer for a
  stretch. Also local, and for the same reason unlikely to move a half-hour
  figure.

Neither is aimed at the number that is bad. The mechanism that produces long-range
return is the one that governs where the factory goes over tens of minutes: the
bounded target walk in descriptor space, the operator's stationary distribution,
and the section former. `novelty.py` already measures the walk's coverage of that
space and was built for exactly this question.

Choosing the replacement for 70 and 71 is a Class 2 decision and is Roberto's.
Not taken here.
