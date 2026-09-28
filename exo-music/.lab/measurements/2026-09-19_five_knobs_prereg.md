# Pre-registration: five knobs, bracketed — A-B-A-C-A-D-A-E-A-F

**19 September 2026.** Written before the factory is started, before the
partition is frozen, and before any arm is read. Supersedes the design of
`2026-09-18_three_knobs_prereg.md`, whose result is in
`2026-09-19_three_knobs_result.md` and whose central inference was withdrawn
the same day.

## Why run again at all

The 18–19 September sequence produced no usable number on the one measure that
can promote. Two failures, both now fixed:

- The audio ring was 8 GB and the run was 15.5 h, so `sonic_variety` returned
  NO AUDIO on five of six arms. The ring is now a parameter and the runner
  refuses a sequence it cannot hold.
- `version_operator` refit its partition inside each arm, so `empirical dwell`
  moved 2× to 4× on knobs that changed nothing. It now takes a partition as
  input.

And two of the three knobs were not perturbations at all: `self_ingest_weight`
is not read by the running factory, and `collapse_after`'s counter never
approached its threshold. **This run uses only knobs verified to reach code**,
by the comment-stripped audit of all 115 policy keys done today.

So the question this run exists to answer is the one never yet asked cleanly:
**does any policy knob move `sonic_variety` by more than the drift between
identical arms?**

## The design

Ten arms, every candidate bracketed by a champion arm:

```
A1  C1  A2  C2  A3  C3  A4  C4  A5  C5
```

Each boundary changes exactly one policy key — the candidate's going in, the
same key coming back out — so `one_change_at_a_time` holds at all nine. The
four A–A pairs (A1A2, A2A3, A3A4, A4A5) are nulls measured inside the same run,
on the same corpus and trace. Four draws of drift, against two last time.

853 windows per arm, matching every prior comparison. Ten arms, **about 25
hours** at the measured 10.65 s/window.

## The five knobs, in the order they will run

Ordered so the most informative run first: a sequence that dies at hour 18
keeps its completed arms, and the later ones are the more speculative.

| arm | knob | baseline | candidate | why this knob, and why this value |
|---|---|---|---|---|
| **C1** | `operator_weight` | 0.35 | **0.0** | The 15-run ablation measured a clean monotonic dose-response, sounding vocabulary 22.3 machines at op0.00 down to 16.7 at op0.50. 0.0 is that ablation's own endpoint, so the value is inherited and not invented. It also asks a question the ablation could not: the operator was repaired on 18 Sept (dead era archived, gap 0 → 0.61), so what it steers toward now is a different state space, and whether its steering still does anything is open. |
| **C2** | `attention_weight` | 0.15 | **0.0** | The only one of the five with a prior paired comparison (shadow comparison 1, 16 Sept, gated clean, promoted nothing). Running it again at the opposite end, with a working slicer and surviving audio, tests the same knob under a rig that now works. |
| **C3** | `novelty_penalty` | 0.15 | **0.40** | Reads directly on `n2_varied`, and it is the knob most likely to move `m4_vocabulary_breadth` and `d2_turnover` — two measures whose per-arm values were never correct before today's slicer fix, so their response to anything is unmeasured. |
| **C4** | `temperature` | 1.0 | **0.6** | Selection sharpness. A stipulation: 0.6 is a clear reduction that is not degenerate, and no prior measurement constrains it. Recorded as a stipulation, not as a derived value. |
| **C5** | `macro_bias` | 2.5 | **1.0** | The macro layer is where the ear has complained four times and where no measure yet reaches (`macro_has_no_harmony`, the isolation runs, the recurrence measures averaging macro against seven times its number of micro events). Also a stipulation. |

All five verified present in `live_factory.scd` after comment-stripping, one
read site each.

## The baseline

The policy as it stands at launch: `operator_half_life = 5000`, the operator's
dead era archived, charter edition 7, output device BlackHole 2ch. **This
baseline differs from comparisons 1–3 and from the 18–19 September sequence**,
and no pooling across those boundaries is licensed without saying so.

## What must be true before the first arm opens

Each of these is a refusal, not a checklist item, and the runner enforces the
first three.

1. **The ring must hold the run.** Ten arms × 853 windows × 11 s = 93,830 s of
   raw f32 stereo at 352,800 B/s = **33.1 GB**. The guard refuses unless the
   ring is at least 36.8 GB, so the splitter runs at **`--ring-gb 40`**. The SSD
   has 360 GB free.
2. **The integrity monitor must be running**, or the clock-jump abort is inert.
3. **AC power**, or `--allow-battery` with the override recorded in the state
   file.
4. **The version_operator partition must be fitted and frozen BEFORE this run
   starts**, on the six arms of 18–19 September, and written to a file. Every
   arm here is then scored with `--partition` against it. This is the whole
   point of the fix: the partition must be a prior, not a description of the
   arms it judges. A partition fitted on this run's own arms would repeat the
   fault in a subtler form.

## The decision rule, fixed now

For each candidate pair, per measure with promotion power:

1. **|d_cand| ≤ max over the four null pairs of |d_AA|** — inside the in-run
   drift, **cannot be claimed**.
2. **|d_cand| > that maximum** — recorded as *exceeds drift*. Not significance,
   not promotion. Four draws of drift are four draws.
3. **Any charter metric that passes in a champion arm and fails in its
   candidate** — `charter_not_regressed` blocks.

Two measures are excluded from rules 1–2 in advance:

- **`version_operator`'s analytic dwell**, as before: it moved by hundreds
  between identical arms.
- **`generation_drift`**, newly: it reads the pool ring, not the arm, and was
  identical in all six arms of the last run. It is not an arm measure and will
  be moved out of the per-arm set.

## The floors are wider than this project believed

Today's re-score of comparisons 1–3 under the corrected slicer found that the
event-line measures had been reporting **exactly zero** drift between arms,
because both arms were scoring the same whole log. Their true floors, measured:

| measure | floor as published | floor corrected |
|---|---|---|
| `m8_in_band` | 3.1 Hz | **209 Hz** |
| `convergence2` C2 | 0 | **0.847** |
| `m4_vocabulary_breadth` | 0 | 1.0 |
| `m6_texture` | 0 | 1.0 |
| `d2_turnover` | 0 | 0.021 |

The 209 Hz matches the 212 Hz measured independently in the 18–19 September
run. **Any margin set from the older comparisons would have been set far too
tight.** Stated here because it lowers what this run can expect to find: with
floors this wide and four draws to estimate them, a knob must move a measure a
long way to clear rule 2.

## The promotion budget, and a question for the architect

`sonic_variety` has spent **2 of its 3** adjudications (`section_spread`,
`full_vector`). Five candidate comparisons would need five.

This run is therefore declared a **measurement run**: margins are UNSET and
nothing is promotable, so no comparison here decides anything, and on the
registry's own logic — budget decays with *adjudications*, and an adjudication
is a number deciding something — **no budget is spent**.

That reading is stated in advance rather than after the numbers, which is the
only way it is honest. If Roberto reads it the other way, the run still yields
its measurements and the budget question is settled before any promotion is
claimed from them. **It should not be settled by whichever answer this run's
numbers happen to favour.**

## What one run cannot do

Four in-run nulls are four draws. They bound this run's drift; they do not
establish a floor for the factory.

It cannot say whether the five knobs sound different. The ear is not asked
here, and `sonic_variety` is a recurrence statistic, not a judgement.

It cannot pool with comparisons 1–3: different baseline, different operator,
different charter edition, and on the event-line measures those comparisons'
per-arm numbers were wrong until today.

It says nothing about the macro complaint. `macro_bias` is in the run because
macro is where the ear keeps objecting, but no measure here reaches macro, and
`C5` moving or not moving will not change that.

## Procedure

```sh
# 0. ring, before anything
#    (run_fifo.sh now takes RING_GB; the guard needs >= 36.8)
RING_GB=40 sh workdir_music/stream/run_fifo.sh restart

# 1. freeze the partition on the PREVIOUS run's arms
python3 tools/version_operator.py \
    --cells harness/runs/run_260919_1118*/judge_cells.npy \
            harness/runs/run_260919_112*/judge_cells.npy \
    --cell-source judges \
    --fit-partition harness/partition_260919.json

# 2. the sequence
sh tools/run_n_arms.sh --windows 853 \
    --cand operator_weight=0.0 \
    --cand attention_weight=0.0 \
    --cand novelty_penalty=0.40 \
    --cand temperature=0.6 \
    --cand macro_bias=1.0

# 3. after ALL TEN ARMS COMPLETE
sh tools/score_n_arms.sh harness/n_arms_<stamp>.json
```

The runner refuses a candidate equal to its baseline, refuses to start on
battery without the override, refuses a ring too small for the run, refuses
when the integrity monitor is down, aborts on a clock jump, ends the sequence
within one poll if the factory dies, and will not open an arm until a first
window is written.

## What would make this run void

A clock jump, a factory death, or a stall — all end it and label the completed
arms. Also, and this one is on me to check rather than on the runner: if the
frozen partition is not in place before arm A1 opens, the dwell numbers are not
comparable and the run answers a narrower question than it was written for.
