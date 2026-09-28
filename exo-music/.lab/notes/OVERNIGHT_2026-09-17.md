# Overnight, 17 September 2026

Written at 02:15 while the work runs, so it exists whether or not I am still
executing when it finishes.

## The thing that went wrong last night, and what was done about it

On 15 September an overnight comparison was driven by hand: start the champion,
come back in two hours, flip the knob. The hand never came back. Arm B never
started, arm A became a nine-hour run, the comparison was lost.

**It happened again tonight before anything else did.** You said you were going
to sleep; my next action was four hours later, at 01:49. The gap is not
carelessness, it is that **my being awake was load-bearing**, and it should not
have been.

So the first thing built tonight was `tools/run_two_arms.sh`, which removes the
dependency. It starts the factory, waits out each arm by window count,
checkpoints, hot-reloads the knob with no restart, waits out the second arm,
checkpoints again, and writes the boundaries to a state file. **Once launched it
needs nobody.**

It also refuses, which matters more than the sequence: it will not restart
mid-comparison, will not flip the knob into a factory that has died, will not
stop the factory at the end, and aborts with the champion arm intact and honestly
labelled rather than producing a candidate arm of silence.

Then `tools/score_two_arms.sh`, which does the same for the last mile — one
command, reading ranges and epochs from the state file, handling the three
pitfalls that cost six invocations last night. It refuses to score anything whose
state is not `COMPLETE`.

## What is running

**Shadow comparison 2 of 5**: `attention_weight` 0.15 → 0.3, 853 windows per arm.

| | |
|---|---|
| launched | 01:54 |
| champion | 0.15, windows 6–858, ETA **04:25** |
| candidate | 0.3, hot reload, ETA **~06:55** |
| state file | `harness/two_arms_260917_015453.json` |
| at 02:13 | 111/858, zero errors, zero stalls, zero excursions |

**When it finishes, one command scores it:**

```sh
cd ~/Desktop/COWORK_OS/SUPERDARK/exo-music
sh tools/score_two_arms.sh
```

If it says `NOT COMPLETE`, the run was interrupted; the state file says where it
stopped and the champion arm is still valid on its own.

## Four findings, all of them corrections

### #103 — the 1 September clicking verdict rested on one sample

The blow-up record left this "Unresolved" with three hypotheses. The answer is a
fourth. Hypothesis 3 — that the detector and the blow-ups were measuring
different things — is **refuted by test**: ten injected 13 ms full-scale bursts
of five shapes are all counted, including a 200 Hz tone, so the 8 kHz highpass
was never the blind spot it looked like.

The real answer is **n = 1**. Commit `00b1e72` closed the question on one row,
one number, `clicks/s 1.01`, and concluded the clicking was gone. Across 38
segments of delivered audio the rate is median **5.50**, sd **8.15**, and **16%**
of single samples fall at or below 1.01. That figure was an ordinary low draw.

Stated carefully: this does **not** claim the rate was 5.5 on 1 September.
Today's stream is not that stream. The comparison is between a claim and the
sampling it rested on.

### #51 — `m1_audible_when_driving` is not vacuous, it is untriggered

The suspicion was that a conditional metric reading 0.000 forever is conditioned
on a rare event. It is not: the condition fires in **46%** of windows. But the
numerator has never moved — **zero silent windows in 3,555 driving ones** — and
not because it cannot: the quietest driving window sits **1.9 dB** above the
threshold, and non-driving windows do cross it.

So it is a standing detector that has never fired, which is exactly where
`m3_no_clipping` was until it was vindicated. The difference is that m3 fired and
was right. This one's discrimination is simulated, as its own `_untested` note
admits.

One discrepancy **flagged rather than guessed at**: its derivation states 0.23%
observed on the 2 September run; today gives exactly 0.00%. Nothing explains the
move.

### The provenance audit, in which my own tool was wrong twice

`tools/audit_threshold_provenance.py` asks what evidence stands behind each
charter bound. It produced **two false alarms**, both caught by reading the
derivations it was summarising:

1. It flagged `m1_not_silent` and `m9_turnover` as having "no bound" — a defect.
   They are unbounded **deliberately**, and m9 explains why: *"an upper bound
   near 0.8 is available from the data and is refused: it would rest on one
   listener's judgement of two runs, it would be fitted to a distribution that
   contains the failure."* That is the charter declining to draw a line it cannot
   justify. The tool inverted the finding.
2. It reported "derived from one run" for seven metrics because its regex matched
   `6h run`. The derivations cite the 6 h run **and** `gap_r1`, and
   `m5_not_converging` spans a 15-run ablation.

What survives: `m8_in_band` has actually failed once (383.0, below its 400
floor), so it discriminates. Two bounds rest on a single reference point.
`clicks_per_second` has none at all — filed as **#113**.

### #46 — m7 scores the wrong column, and the operator has gone degenerate

Started as "derive m7's replacement bound from a shuffled null". No bound was
derived, because the premise does not hold.

**The metric reads `lambda2` and calls it `gap`.** `live_factory` writes
`OPERATOR win, gap, lambda2, cells, dominant, total`; `score_charter` splits the
window number off and then takes `p[2]`. `p[1]` is gap. m7 has scored lambda2 for
its entire life, while its bound came from the gap column — *"6h run: gap ran
0.295-0.422"*. **Ninth instance of the pattern**, and a new variant: not a
parameter wired to nothing, but a metric whose name, derivation and bound
describe one quantity while its code reads the column beside it.

**And both columns are now degenerate.** gap = 0.0000, lambda2 = 1.0000, IQR of
either exactly 0. λ₂ = 1 means the chain has *not* mixed — convergence would push
λ₂ down and the gap up. Over the 8-hour run: `cells.size` 217 → 217 with zero
growth, the dominant cell was **`bu` in 2,912 of 2,912 windows**, and `total`
grew exactly 1.00 per window against a cumulative 41,881 carried across every run
ever.

That changes the suspension's stated reason, which described gentle convergence.
Degeneracy looks identical from the metric's face and is not the same thing.

**Not claimed: why λ₂ = 1.** `TransferOperator.sc` is unread. The candidate worth
weighing first is that a whole eight-hour run moved the operator by 2,911 counts
against a total of 41,881 — if a run cannot move the operator, the operator does
not describe that run. Filed as **#114**.

## Standing

Committed and pushed: `7104f80`, `16e0ca3`, `f3f6193`, `223ef90`, `17b6a8b`, `e060ca1`, `2bfe701`.

Nothing was claimed tonight. Four records were corrected, two tools I wrote
tonight were corrected, and one comparison is running unattended to completion.

New tasks opened: **#113** (clicks/s has no bound), **#114** (fix m7's column,
then establish why λ₂ = 1). **#46** is blocked rather than done, and says so.

The honest summary of the night: **the instruments were turned on their own
author again, and on the tools built to audit them, and both needed correcting.**
