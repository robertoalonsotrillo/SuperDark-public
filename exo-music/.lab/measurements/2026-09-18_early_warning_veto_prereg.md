# Pre-registration: the early-warning triple becomes a veto

**18 September 2026.** Decision 7 of `.lab/notes/METRICS_REVIEW_2026-09-18.md`.
Written before any bound is computed and before the A-B-A-C-A-D sequence closes,
so the bound cannot be chosen after seeing which value would have passed.

## What exists today

`factory_status.py` computes, per run, at three scales (30, 90, 240 windows):

- variance of master peak, early against late
- lag-1 autocorrelation of master peak, early against late
- the same pair for the operator's spectral gap
- ensemble disagreement across the nine judges, published with its permuted
  control

The paper names these three as the early-warning signals for catastrophe
(L257: "variance, autocorrelation, and ensemble disagreement"). They are shown
raw, with no threshold, on the stated reasoning that a warning the factory can
see and optimise toward stops being a warning.

## What changes, and what does not

The panel keeps showing them raw. Nothing about the display changes.

What is added is a **veto-only** entry in `harness/measures.json`, consulted at
gate time in a paired comparison. Veto-only means it can block a change and can
never justify one, which is the same standing as `score_charter`,
`charter_honesty`, `judges` and `convergence2`.

The factory cannot see the gate. The gate runs after an arm, from bundles, on
the architect's side. So this does not put a threshold anywhere the factory
could optimise against, and the display stays thresholdless for the same reason
it always was.

## The decision statistic

**Critical slowing down is variance AND autocorrelation rising together.** Either
alone indicates nothing; the panel already says so. So the statistic is the
joint rise, and a one-sided one, because a *fall* in both is a system settling
and is not the pathology.

For a series `x` over an arm, at scale `w`:

```
r_var = variance(late w) / variance(early w)
r_ac  = ac1(late w) - ac1(early w)
JR(w) = min( log(r_var), r_ac / s_ac )
```

`JR` is the joint rise at scale `w`. Taking the **minimum** of the two
normalised components is what makes it a conjunction: a large variance ratio
with flat autocorrelation scores low, and so does the reverse. `s_ac` is the
null's standard deviation of `r_ac`, so the two components are comparable before
the min is taken.

The arm's statistic is `JR = max over w in {30, 90, 240}` of `JR(w)`, computed
on master peak and on spectral gap separately, giving two numbers per arm.

## The null, and where the bound comes from

**The bound is derived from a null, not from any run's observed value.** This is
the discipline that m7, m4's old ceiling and the 0.9 drift threshold all broke,
and it is the reason those three had to be withdrawn.

Null construction, per series, per arm:

1. Take the arm's own window series.
2. Draw a **circular block bootstrap**, block length 30 windows, preserving
   short-range structure while destroying the early-to-late trend that `JR` is
   built to detect. A plain shuffle is wrong here: it would destroy the
   autocorrelation whose *change* is half the statistic, so the null would be
   trivially beaten and the bound would be meaningless.
3. 2,000 replicates. Record `JR` for each.
4. The bound is the **99th percentile** of the null distribution.

A block bootstrap under the null of "no trend" is the right family because the
alternative being tested is specifically a trend in two second-order moments.

## The decision rule, fixed now

For a candidate arm, per series:

- `JR_candidate <= bound`: passes. No veto.
- `JR_candidate > bound` **and** `JR_champion <= bound`: **VETO**. The change
  moved the factory into critical slowing down and the champion was not there.
- `JR_candidate > bound` **and** `JR_champion > bound`: no veto, and a
  **recorded warning**: the factory is in the region under both arms, which is
  not attributable to the change and is a fact about the factory that should be
  investigated on its own.

Reported for both master peak and spectral gap. A veto on either blocks.

## Calibration required before it enters the registry

`measures.json` states the rule: "A measure with no recorded calibration cannot
promote, whatever its budget says." This one can only veto, so the budget does
not apply, and a veto that fires wrongly is still a measure that stops work. So:

1. **Negative control.** Run the statistic against arms already scored and
   gated clean (comparisons 1 to 3, and the two nulls of 18 September). It must
   NOT veto them. If it does, the bound or the statistic is wrong.
2. **Positive control.** Synthesise a series with a known approach to a fold
   (an AR(1) with its coefficient ramped from 0.2 to 0.95 over the arm, variance
   rising with it) and confirm the statistic fires. Without this the veto could
   be structurally unable to trigger, which is the `m1_audible_when_driving`
   condition and the reason `charter_honesty` exists.
3. **Saturation check.** Four spectral statistics have saturated in this project
   and every one was caught by calibration arms. If `JR` on 140 unrelated FMA
   tracks scores in the same range as the factory, the statistic does not
   discriminate and does not enter.

## What would retire it

A veto that fires on arms Roberto judges healthy by ear, twice. Or a
demonstration that `JR` tracks arm length instead of arm behaviour, which is the
failure m7 had: check by computing `JR` on the first and second halves of one
long clean arm and confirming it does not rise with n.

## What this does not do

It does not act on ensemble disagreement. The third signal of the paper's triple
is published with a permuted control and is not in this statistic, because the
judge population changed composition on 3 September and a statistic spanning
that boundary would be measuring the population and not the factory. It is owed,
and it is a separate pre-registration.

It also does not alert, page or email. It blocks a change at gate time and does
nothing else.
