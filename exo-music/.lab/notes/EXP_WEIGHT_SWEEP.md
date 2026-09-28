# Sweep: what does self_ingest_weight cost, and what does it buy?

Pre-registered 2 Sept 2026, before the control arm ran. Two arms already exist and
are NOT re-run: their numbers were fixed before this document and are used as-is.

## The two quantities, which pull in opposite directions

- **Silence.** `m1_not_silent` is now a DESCRIPTION, not a bound (charter edition
  4), because silence tracks the section amplitude the factory chooses. But the
  earlier experiment showed the weight moves it: 0.195 at w=1.0 against 0.139 at
  w=0.5, about 3 standard errors. Whatever the charter calls it, the weight is a
  real lever on how much of the time the factory says nothing.
- **Generation depth.** Capped at 1/(1-w): 2 at w=0.5, 20 at w=0.95, unbounded
  at w=1.0. The pre-registered twenty-generation target therefore needs w >= 0.95.

So the project's own target pushes the weight up and the factory's audibility
pushes it down. This sweep is to find out how steeply, not to pick a winner.

## Arms

| arm | weight | status |
|---|---|---|
| A | 1.0 | done, `arm_a_w100.log`, 389 usable windows |
| B | 0.5 | done, `live_260902_014120.log`, 2,431 usable windows |
| C | 0.0 | **this run** — the loop OPEN, no self-material at all |
| D | 0.95 | to follow, the weight the twenty-generation target needs |

**Arm C is the control and it is the point of running it.** At w=0 the play corpus
is entirely archive material and there is no self-ingestion whatsoever, so if
silence is caused by the factory recycling its own quiet output, arm C must be
the quietest-of-silence — that is, the LEAST silent arm. If arm C is no better
than arm B, the mechanism proposed in EXP_WEIGHT_M1_M7.md is wrong and the
weight's effect on silence is something else.

That arm spends its hours not doing the thing this project is about. It is worth
it exactly once, because every other arm is uninterpretable without it.

## Criteria, fixed now

Computed over windows 46 onward, truncated to the shortest arm's usable length so
no arm is advantaged by observing longer.

Reported per arm, all of them descriptive except where noted:

1. **silent fraction** (peak < 0.004) — the descriptive quantity
2. **m1_audible_when_driving** (silent among amp >= 0.01) — the SCORED metric;
   it must stay under 0.015 in every arm, and if it does not, the arm has a
   level fault and its silence figure means something different
3. **median section amplitude** — because if the weight changes the amplitude the
   factory chooses, then the weight acts on silence THROUGH amplitude, and the
   corpus story is wrong
4. **deepest generation reached**
5. **admissions per hour and admit rate**

**The mechanism is supported** if silent fraction falls monotonically as weight
falls, C < B < A, AND median amplitude does NOT fall with it (which would mean
the weight was acting on the amplitude choice rather than on the material).

**The mechanism is refuted** if arm C is not the least silent, or if the whole
effect is explained by a shift in the amplitude the factory chooses.

**Minimum per arm: 400 windows past warm-up**, about 87 minutes.

## What this sweep cannot settle

Four points is a sketch, not a curve, and nothing here justifies interpolating
between them. It also cannot say what the RIGHT weight is: that depends on what
the twenty-generation target is worth against how much silence is acceptable,
and that is an artistic judgement, not a measurement. The sweep exists to put
numbers under the judgement, not to make it.
