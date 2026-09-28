# Five knobs, bracketed: result

**20 September 2026.** Sequence `n_arms_260919_141544`, 19 Sept 14:16 to
20 Sept 15:59, ten arms of 853 windows, one log `live_260919_141610.log`, never
restarted, zero integrity faults across 25h43m. Pre-registration:
`2026-09-19_five_knobs_prereg.md`. Scored under seal `2026-09-19T13:08:41`,
bundles `cmp_260920_1612xx` to `cmp_260920_1631xx`. Every arm had audio; this
is the first bracketed sequence where `sonic_variety` scored every pair.

## The result

**Nothing moved.** Five knobs, one of them the transfer operator switched off
entirely, and no measure with promotion power moved beyond the drift between
arms where nothing changed.

| knob | `sonic_variety` | `dwell` (frozen partition) |
|---|---|---|
| `operator_weight` 0.35 → 0.0 | −0.0007 | −2.90 |
| `attention_weight` 0.15 → 0.0 | +0.0023 | +1.00 |
| `novelty_penalty` 0.15 → 0.40 | −0.0071 | +0.50 |
| `temperature` 1.0 → 0.6 | −0.0012 | 0.00 |
| `macro_bias` 2.5 → 1.0 | −0.0036 | +1.70 |
| **four nulls (A–A)** | −0.0090, +0.0121, −0.0122, +0.0067 | −2.80, +0.60, −0.30, +1.20 |

The largest knob effect on `sonic_variety` is 0.0071. The null floor is 0.0122.
Ratio 0.58; the rule needs more than 1.0 to register at all. All nine pairs
gated MARGINS_UNSET, no veto, all ten invariants passing.

Per-arm charter values, which is where the finding actually sits:

```
arm    m4 vocab  m6 voices  m2 level    m8 Hz   d2 turn
A1        24.0       5       0.052    1602     0.610
C1        24.0       5       0.048    1614     0.620    <- operator OFF
A2        24.0       5       0.057    1515     0.620
C2        24.0       5       0.048    1478     0.620
A3        24.0       5       0.051    1499     0.633
C3        24.5       5       0.051    1514     0.634
A4        25.0       5       0.056    1629     0.642
C4        23.5       5       0.055    1519     0.608
A5        24.0       5       0.049    1515     0.612
C5        25.0       6       0.052    1739     0.628
```

**`operator_weight` 0.35 → 0.0 changed `m4_vocabulary_breadth` by zero.** The
15-run ablation measured 22.3 machines at op0.00 against 16.7 at op0.50, a clean
monotonic dose-response on this knob. Switching the operator off now moves
nothing. Either the 18 Sept repair (dead cells archived, gap 0 → 0.61) removed
the effect, or the ablation measured the dead operator's damage and not the
live operator's steering.

## What the run established about the factory

**The vocabulary is small and fully cycled in minutes.** Across 8,768 windows
the factory sounded 27 distinct machine names, 9 bridges, 18 behaviours. Every
one was first seen by window 147. The panel reports about 280 machines ever
invented; this run played 27.

**The factory drifts more within an arm than between arms.** Each arm split at
its midpoint:

| | m8 | d2_turnover |
|---|---|---|
| half-to-half, one arm, same policy | **170 Hz** | **0.035** |
| arm-to-arm, identical policy (A–A) | 130 Hz | 0.030 |

An 853-window arm is not a stationary unit. The factory wanders on a timescale
shorter than the measurement, so the bracketed design has no fixed baseline.

## What the run established about the design

The four nulls give `sonic_variety` a null sd of 0.0118. To resolve an effect of
the size actually observed:

| effect | paired repeats per knob | machine time |
|---|---|---|
| 0.020 | 3 | 15 h |
| 0.010 | 11 | 56 h |
| 0.005 | 44 | 223 h |

This design could only have detected effects three times larger than any
present. **Both bracketed sequences, 18–19 and 19–20 September, were
structurally incapable of answering the question they were built for.** Two
draws of drift on 18 September were already enough to compute that, and it was
not computed. Recorded as my error.

## The reading

A closed set of 18 behaviours, recycled for hours; spectral character wandering
±170 Hz for no cause; insensitive to five knobs including its steering
operator; operator gap 0.61, wide. The paper names this shape **stable
failure**: "the factory's dynamics have both settled into some undesirable
attractor and are resisting leaving." The `operator_weight` result fits: the
attractor holds without the operator.

Offered as a reading. What would refute it: the 253 silent invented machines
turn out to be unplayable or refused for cause (then the vocabulary is what it
is and the factory is stable, not stuck); or a structural change moves the
vocabulary where the knobs could not (then the attractor is real and escapable).

## What is withdrawn from the programme

Knob sweeps through the bracketed rig, at this arm length and these effect
sizes. Another sequence buys one more draw of drift.

The metrics work queued from the 18 Sept review — edition 8, m7 re-derivation,
coverage — is paused. The instrument cannot resolve the object at this scale
and polishing it does not change that.

## What replaces it

1. Characterise the attractor from data in hand: the 18 machines, their
   transition graph, and whether the 253 silent machines are refused at
   selection or never offered. In progress.
2. One structural escape test: force a silent invented machine into the pool
   and watch whether it persists.
3. Factory 1 consuming Factory 2 — the nearest available external signal, and
   the shelved target 3 of the Class 3 programme.
4. Hand the five knobs to the factory, bounded to the ranges this run showed
   safe. Every arm gated clean; that is the safety data. *r* above zero.

## What is not claimed

That the five knobs do nothing at any value. They do nothing detectable at
these values against this factory's own drift.

That stable failure is proven. It is the reading that fits, and item 1 above is
what would settle it.

That the 25 hours were wasted. They produced the first `sonic_variety` numbers
on a bracketed sequence, four draws of drift instead of two, the within-arm
non-stationarity result, and the safety envelope for handing the knobs to the
factory. What they did not produce is what they were designed for.
