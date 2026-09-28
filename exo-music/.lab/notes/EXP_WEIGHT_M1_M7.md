# Experiment: is `self_ingest_weight = 1.0` the cause of m1 and m7?

Pre-registered 1 Sept 2026, **before arm B was run**. Written down because this
project has three times settled on a criterion after seeing the numbers, and
because both failing metrics have an obvious knob attached to them, which is
exactly the situation where motivated reasoning is cheapest.

## The claim under test

`self_ingest_weight = 1.0` means the play corpus is assembled entirely from the
self-ingested pool, with no archive material. Two consequences follow, and they
are the two metrics currently failing:

- **m1_not_silent.** The factory is silent in 21% of windows against a 0.15
  bound. The silence is NOT a level fault (gain is already 3.0) and NOT one
  broken machine: 47 separate runs, median length 1 window, spread across the
  vocabulary. The decisive observation is that during silent windows the median
  voice count is **3**, maximum **8** — voices are running and emitting nothing,
  so the factory is playing grains that make no sound. At weight 1.0 the corpus
  is drawn only from the factory's own output, which is itself 21% silent, so
  quiet material is recycled and replayed. Silence begets silence.
- **m7_spectral_gap_settles.** The gap sits in [0.1798, 0.2054] over 419 windows,
  an IQR of 0.0044 against a lower bound of 0.02. The VALUE is healthy; the
  VARIATION is dead. P227's stable failure: the operator has settled on a fixed
  point. With no unfamiliar material in the corpus there is nothing for it to
  move toward.

One cause, two symptoms.

## Arms

| arm | weight | log |
|---|---|---|
| A | 1.0 | `live_260901_163114.log` (archived as `arm_a_w100.log`) |
| B | 0.5 | new run, same corpora, same gain, same voice range |

Nothing else changes. Judges are NOT modified during this experiment; adding
mean-based judges would alter the operator and confound both readouts, which is
why that work is queued behind this and not beside it.

## Criteria, fixed now

Computed over windows **46 onward in each arm**, and truncated to the SAME window
count in both. Both exclusions are load-bearing:

- Warm-up is about 45 windows. A previous 8 h run had 40% of a short experiment
  sitting inside the transient, and every verdict was taken on a warm factory.
- Unequal lengths would let m7's IQR grow simply by observing longer, since a
  wider sample of a wandering series has a wider spread by construction.

**The claim is supported if BOTH hold:**

1. silent fraction at w=0.5 is below **0.15** (its charter bound), and
2. spectral-gap IQR at w=0.5 is at or above **0.02** (its charter bound).

**Partially supported** if exactly one moves inside its bound. That outcome does
NOT license calling the other one solved, and it specifically does not license
re-pricing the bound that stayed outside.

**Refuted** if neither moves inside its bound. In that case the weight is not the
cause and the diagnosis above is wrong, whatever it costs to say so.

**Minimum run length: 400 windows past warm-up**, about 87 minutes at 11.7 s per
window. Reading it earlier is reading the transient.

## What this cannot show

Weight 0.5 is one alternative point, not a curve. If the claim is supported, the
right follow-up is a sweep, not the assumption that 0.5 is optimal — and any
chosen value must then be justified against generation depth, which is the
quantity the loop exists to raise and which is currently stuck at 1.

## RESULT, read 2 Sept 2026

Arm B ran 8 h 11 m, 2,481 windows. `run_integrity.py --report`: clean, no sleeps,
no dropouts, no stalls. Compared over the first 389 windows past warm-up in each
arm, as pre-registered.

| | A (w=1.0) | B (w=0.5) | bound |
|---|---|---|---|
| m1 silent fraction | 0.195 | **0.141** | < 0.15 |
| m7 spectral-gap IQR | 0.0045 | 0.0039 | >= 0.02 |
| median master peak | 0.0440 | 0.0600 | |
| median voices | 4.0 | 3.0 | |

**PARTIALLY SUPPORTED**, and neither half should be overstated.

**m1 moved, and the movement is solid; the resulting level is not.** 0.195 to
0.141 is a drop of 0.056 against a standard error of about 0.019 on the
difference, so the reduction is real and the mechanism is confirmed: a corpus
drawn purely from the factory's own output was recycling its own silence. But
0.141 has a 95% interval of [0.106, 0.176], and over the FULL 2,431-window arm
the estimate is 0.139 +/- 0.014, giving [0.125, 0.153]. **The 0.15 bound lies
inside that interval even at n = 2,431.** m1 at w=0.5 is not distinguishable from
its bound and must not be reported as passing. Weight 0.5 improves the silence;
it does not clear the bound.

**m7 did not move, and the reason is that the bound is not commensurable.**
The IQR is ~0.004 in every segment of the run (0.0022 to 0.0074 across five
segments of 300-600 windows), independent of run length and of weight. The
charter's own calibration note reads: *"6h run: gap ran 0.295-0.422 at p10-p90,
IQR well inside. PASSES."* The gap today runs at about **0.81** (lambda2 ~0.19)
against ~0.34 then. That is a different operator: lambda2 of 0.19 means the
machine-to-machine chain mixes in well under one window, so its second eigenvalue
is both small and stable, and a spectrum that barely moves is the arithmetic
consequence of fast mixing, not evidence of a settled factory.

So m7 is failing against a bound calibrated on a regime the factory no longer
occupies — the same class of fault as the 0.9 drift threshold, which also pointed
at a definition that had moved. **This is NOT a licence to widen it.** The bound
has to be re-derived from what a healthy operator does in the CURRENT regime,
and the derivation has to state which pathology it discriminates, because as
written the bound cannot tell "frozen and stagnant" from "reliably fast-mixing",
and m4 (vocabulary breadth, 36-39 behaviours per 100 windows) says the factory is
plainly not stagnant.

**A separate defect found while reading this.** live_factory.scd logs
`OPERATOR win,gap,lambda2,...` and score_charter.py reads field 2, which is
**lambda2**, while the metric is named `m7_spectral_gap_settles` and its
calibration note quotes gap values. For an interquartile range the two are
interchangeable, since gap = 1 - lambda2 exactly, so no number here is wrong. But
anyone reading the charter compares 0.02 against a gap-shaped intuition while the
scorer measures the complement, and that is how a bound gets re-priced against
the wrong quantity.

A supported result also does not establish the DIRECTION of the m1 mechanism.
"Quiet grains are recycled" is a story consistent with the observation; proving
it needs the admitted grains' own levels compared against the pool they
displaced. That measurement is separate and is not attempted here.
