# Pre-registration: the reward channel

16 September 2026, 01:00. Written before the mechanism has produced a single
line, because it goes live at the next restart.

## Why this one is different from every other measure here

Every measure in this project is mine. I chose the statistic, I chose the
threshold, and it is computed after the fact. Exo's continual-release proposal
names the one signal that escapes that and says why it is worth more:

> Before starting a task, live or during a trial, Exo writes down what it
> expects… When the task ends, the evaluation rig writes what actually happened.
> The gap is the score.
> … it arrives the moment the task ends, it needs no human label, and it's
> measured against clocks and bills the agent doesn't control.

It is recorded as **owed** in `harness/measures.json` and named in the programme
amendment of 15 September as the piece that would give the factory a signal the
architect did not author.

## What the factory now predicts

At the close of each window it writes

    FORECAST <win+1>,<p_audible>,<live_voices>,<slots_filled>

a probability that the **next** window will be audible, formed from the
audibility it has learned for the machines currently in its slots, damped when
nothing is live.

The outcome is already in the log: `MASTER`'s peak against **0.004**, the same
threshold `m1_not_silent` uses. So this adds a prediction and nothing else. The
factory does not get to choose the outcome or the threshold.

## How it is scored, fixed now

- **Brier score** of the factory's forecasts against the binary outcome.
- **Against a base-rate forecaster** that always predicts the run's mean
  audibility. Skill = base Brier − factory Brier; positive means better.
- **A shuffled null**, 2,000 draws, pairing each forecast with a random window's
  outcome. This catches a forecast that looks skilled only because audibility is
  autocorrelated.
- **Significant at p ≤ 0.05.**

Windows whose peak exceeds 2.0 are **dropped and counted**. Those are numerical
blow-ups, not audio, and counting one as a successful prediction of audibility
would reward the factory for exploding.

## The three outcomes, all written in advance

- **SKILLED** — skill > 0 and p ≤ 0.05. The factory anticipates its own
  audibility better than the base rate. It has some model of its own
  consequences.
- **NO SKILL** — otherwise. Honest and uninformative. This is the same verdict
  `judges.py` reached about its own ensemble and reported plainly, and it would
  be a real finding: the machines have no useful model of what they are about to
  do.
- **CONSTANT** — forecast sd below 1e-6. The factory emits one number for every
  window, so the Brier score describes its base rate and nothing else. That is a
  broken forecast, not a calibrated one, and it invalidates the arm rather than
  scoring it.

## Self-checked before use

Three synthetic logs, 400 windows each:

| generator | verdict | skill |
|---|---|---|
| forecast tracks outcome | **SKILLED** | +0.156 |
| constant 0.5 forecast | **CONSTANT** | −0.016 |
| random forecast | **NO SKILL** | −0.103 |

The instrument distinguishes the three cases it is required to distinguish.

## Nothing steers on this, and that is deliberate

The forecast is written, scored and read. It does not enter selection.

Wiring it in would make it a self-generated criterion, and runs 53–58 measured
exactly that becoming a convergence engine: what sounds gets weighted up, gets
selected more, keeps sounding. The reward channel is a **readout of whether the
factory knows itself**, not a lever. If it ever becomes a lever that is a
separate decision with its own pre-registration and its own ablation.

## What would make this claim void

If `audib[]` is itself derived from recent audibility in a way that makes the
forecast a lagged copy of the outcome, then skill would be autocorrelation
wearing a forecast's clothes. The shuffled null is the guard, and the honest
check before quoting any skill figure is to confirm that `audibility.json` is
updated on a slower clock than the window. **That check has not been done and
must precede any claim.**
