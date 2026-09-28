# Three knobs, bracketed: result

> **CORRECTION, 19 September, same day, before the reading below was acted on.**
> The section "What can be said" claimed empirical dwell moves on all three
> knobs and offered two readings. Both readings are wrong, because two of the
> three knobs changed nothing the running factory computes.
>
> **`self_ingest_weight` is not read by the running factory.** Its only mention
> in `live_factory.scd` is a comment at line 1735 which says, in as many words,
> "self_ingest_weight unread". It is read by `start_loop.sh` once before boot to
> assemble the play corpus, and by `self_ingest.py` once at daemon start.
> `run_n_arms.sh setkey()` rewrites `policy.json` and nothing else, with no
> restart by design. Arm C1 changed a key nothing was reading. Dwell still went
> 5.6 to 11.5.
>
> **`collapse_after` is a bound that was never approached.** `silentWindows`
> increments on a report below amp 0.00005 and resets to zero on any louder one.
> Measured over the whole run: 53 such reports, longest consecutive run **3**,
> against a threshold of 600 and then 300. Arm C3 moved a comparison whose
> outcome could not change. Dwell still went 4.8 to 8.5.
>
> So C1 and C3 were neutral arms without being designed as such, and the
> planned neutral-knob experiment is partly already run. The honest reading is
> the third one, which the pre-registration did not anticipate: **empirical
> dwell varies by 5 to 13 windows between arms whatever is done, and the null
> floor of 1.1 taken from the two A-A pairs understates its own variability.**
>
> A mechanism is available. `version_operator.py` selects K per arm (lines
> 260-277) and refits `kmeans(Xs, k, seed=0)` per arm, and empirical dwell is
> `len(lab)/runs` over those labels. **No two arms are measured on a common
> partition.** A statistic whose state space is re-estimated inside each arm
> cannot be differenced across arms, which is the same class of fault as m7
> measuring the operator's age.
>
> Nothing below is retracted as a measurement. The per-arm table stands. What is
> withdrawn is the inference from it about dwell, and with it the "exceeds
> drift" entry for dwell in the decision table.
>
> Owed, replacing the neutral-knob arm as first priority: re-score the six arms
> on a partition fitted once on the pooled windows and frozen, and separately
> with `--cell-source metrics`. Both use data already in hand and need no run.


**19 September 2026.** Sequence `n_arms_260918_115004`, run 18 Sept 11:51 to
19 Sept 03:14, six arms of 853 windows, one log `live_260918_115036.log`, no
restart. Pre-registration: `2026-09-18_three_knobs_prereg.md`. Scored under
seal `2026-09-19T10:06:01` after the slice fix below; bundles
`cmp_260919_1119xx` to `cmp_260919_1122xx`.

## Two defects found by scoring this run, both fixed before these numbers

**The audio ring could not hold the run.** 8 GB is 6.3 h of raw f32 stereo;
the sequence was 15.5 h. Five of six arms had no audio by scoring time.
`sonic_variety` returned NO AUDIO on every pair. The runner now refuses a
sequence its ring cannot hold (`run_n_arms.sh`, commit 958dca6).

**`slice_log` sliced one of the log's two line formats.** Event lines carry
their window in the second comma field with no space; the slicer split on
whitespace and kept all 7,131 of them in every arm. m4, m6, m8, m9,
`m1_audible_when_driving`, `convergence2` and `judges` scored the whole log in
every arm of every hot-reloaded comparison since 16 September. Fixed, re-sealed
(commit e35ff0f). **Comparisons 1 to 3 and the 18 Sept null carry whole-log
values on those measures and should not be quoted on them.** Their
`sonic_variety` and `version_operator` numbers were sliced correctly.

## Per-arm values, corrected slice

| | A1 | C1 siw .5 | A2 | C2 vmax 5 | A3 | C3 collapse 300 |
|---|---|---|---|---|---|---|
| m2 median peak | .056 | .048 | .051 | .042 | .048 | .055 |
| m4 behaviours / 100 | 24.0 | 24.0 | 23.5 | 23.0 | 23.5 | 23.0 |
| m6 median voices | 6 | 5 | 5 | 4 | 5 | 5 |
| m8 centroid Hz | 1647 | 1592 | 1746 | 1616 | 1534 | 1775 |
| m9 turnover | .609 | .609 | .605 | .596 | .626 | .610 |
| convergence2 C1 | 1.000 | 1.000 | .938 | 1.000 | 1.000 | 1.000 |
| convergence2 M2 | .59 | .57 | .57 | .58 | .60 | .60 |
| version_operator empirical dwell | 5.6 | 11.5 | 4.5 | 17.8 | 4.8 | 8.5 |
| judges beat base | −.0009 | −.0009 | −.0010 | −.0009 | −.0009 | −.0009 |

`m1_audible_when_driving` is 0.0 in every arm. `generation_drift` is 0.8842 in
every arm because it reads the pool ring, not the arm; it is not an arm measure
and is dropped from the per-arm set from here.

## Decision rule, as pre-registered

Per measure: a candidate's movement counts only if `|d_cand| > max(|d_A1A2|,
|d_A2A3|)`. Recorded as *exceeds drift*, never as significance or promotion.

| measure | null floor | siw .5 | vmax 5 | collapse 300 |
|---|---|---|---|---|
| m2 | .005 | −.008 **exceeds** | −.009 **exceeds** | +.007 **exceeds** |
| m4 | 0.5 | 0 | −.5 | −.5 |
| m6 | 1 | −1 | −1 | 0 |
| m8 | 212 | −55 | −130 | +241 **exceeds** |
| m9 | .021 | 0 | −.009 | −.016 |
| C1 | .062 | 0 | +.062 | 0 |
| M2 | .03 | −.02 | +.01 | 0 |
| **empirical dwell** | **1.1** | **+5.9 exceeds** | **+13.3 exceeds** | **+3.7 exceeds** |

Charter: no metric that passes in a champion fails in its candidate, all three
pairs. Gate: all ten invariants pass on all five pairs. Verdict on every pair
is BLOCKED, by `sonic_variety: NO AUDIO` alone.

## What can be said

**Empirical dwell moves on all three knobs, by 2× to 4×, while the three
champion arms sit at 4.5 to 5.6.** It is the one measure with promotion power
that survived the ring, and it was pre-registered on 18 Sept as the reading to
take from `version_operator` in place of the analytic dwell.

Three different knobs all lengthening the factory's stay in a version state
admits two readings, and this run cannot separate them:

1. A property of the factory: any perturbation of policy slows its version
   turnover, whatever the perturbation.
2. An artefact of the operator: a policy change alters the judge-score cells
   that define version states, and the operator reads the alteration as a
   longer dwell.

The second is testable. A null arm with a *neutral* knob change, a policy key
the factory reads but that has no acoustic consequence, would show whether
dwell responds to the change or to the sound. That is the next comparison.

**m2 exceeds on all three**, in different directions (down for the first two,
up for the third). The floor is .005 and the movements are .007 to .009. This
is barely over and is recorded as such.

**m8 exceeds on `collapse_after` alone**, +241 Hz against a floor of 212 Hz,
which is also barely over, and in the arm that follows the widest null swing
(A2 to A3, −212).

Everything else is inside drift and cannot be claimed.

## What cannot be said

Anything about `sonic_variety`. No pair has audio in both arms.

Anything about whether the three knobs sound different. The ear was not asked
and the audio is gone.

That the dwell movement is an effect. Two draws of drift are two draws; the
rule says *exceeds*, and it is written that way on purpose.

## What is owed from this run

1. A neutral-knob null arm to separate the two readings of dwell (above).
2. Re-scoring comparisons 1 to 3 and the 18 Sept null under the corrected
   slice, and a note in each result record saying which measures changed.
3. The ring at 24 GB or the arms shortened before any sequence of this length
   runs again.
4. `generation_drift` moved out of the per-arm measure set in `measures.json`;
   it belongs to a run, not an arm.
