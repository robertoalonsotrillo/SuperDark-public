# The attractor is neither selection nor supply: it is the whole supply, and the supply has been frozen since 5 September

**20 September 2026.** Read from the ten-arm log `live_260919_141610.log`
(8,789 windows at the time of the copy), `mutable/{weights,written_machines,
memory,policy}.json`, `mutable/machines/`, the comment-stripped
`live_factory.scd`, `TransferOperator.sc` and `MachineWriter.sc`, and every
`ACQUIRED`/`ACQFAIL` line in the 211 window logs on the render volume.
Numbers reproduce with `tools/the_attractor.py`.

## The finding

The question was whether the invented machines are offered and refused
(selection) or never offered (supply). Neither. **Every machine that exists
sounded in this run, in every arm, at every layer.** There are no silent
invented machines to refuse.

| layer | supply | sounded this run | never sounded | last first-appearance |
|---|---|---|---|---|
| micro | 27 (11 classes, 7 hand-written runtime, 9 bridges) | **27** | none | window 255 |
| mid | 17 (5 classes, 12 bridges) | **17** | none | window 201 |
| macro | 152 (4 classes, 148 bridges) | **152** | none | window 6,309 |
| total | **196** | **196** | none | |

The "27 distinct machine names" in the brief is the micro slot, which is the
machine the event line names. It is 27 because the micro supply is 27. The
"18 real behaviours" are the 11 micro classes plus `fma0`–`fma4`, `grind`,
`sift`, every non-bridge micro machine in existence. Each of the ten arms
sounded all 27 micro and all 17 mid machines and 57–64 of the 152 macro
machines, which is what uniform sampling gives at ~80 macro picks per arm
(expected 61).

So the shape called STABLE FAILURE is not the factory refusing to leave an
attractor inside a larger space. The space *is* the attractor. The vocabulary
is small because the supply is small, it cycles in minutes because 27 micro
names at one or two windows' dwell take about 250 windows (45 min) to
exhaust, the 18 non-bridge ones 148, and it is
insensitive to its knobs because the selection is already at maximum entropy
(below). What the knobs would have to move is the supply, and the mechanism
that moves the supply has produced nothing since **5 September, 18:20**.

## 1. The 27 that sound, and how they are chosen among

Counts over 8,789 windows range 218 (`cr`) to 429 (`ry`), under 2×. Micro
entropy is **4.73 bits against a 4.75 maximum** for 27 names; per arm
4.66–4.71. The transition matrix among the 18 non-bridge micro machines has
**all 306 off-diagonal cells non-zero**, largest cell 24 against a uniform mean
of 8.5, and row entropies 4.50–4.65 bits against 4.70. χ² = 424 on 305 df, so
it is not exactly uniform, but there are no dominant cycles: the top cell
(`te→fma4`) is under 1% of transitions and 2-cycle mass is 42%, what a random
walk on 27 nodes gives. **The factory is a near-uniform random walk on its own
supply.** Nothing is being pulled toward a subset.

That is the structural result of how the pick is made (`live_factory.scd`,
stripped line numbers):

- `avail` = every key in `weights.json` plus every loaded runtime machine,
  minus `policy["banned"]`, which is empty (2740–2743). No layer filter, no
  written-vs-live distinction, no retirement, no `machine_min_deviation` gate at
  selection. All 196 are offered.
- Then 85% of the machines outside the current section's family are dropped
  at random (2850–2851). The family itself is `avail.scramble.keep(rrand(4,8))`
  for a new section, a uniform draw. `avail.size` per window: min 18, median
  34, max 58. This is the only "refusal" in the code and it is name-blind.
- The weight loop (2858–2934) computes
  `v = prevWeights[m]*100 + bias + Σ coef·delta`, clipped through
  `linlin(0,100,lo,hi)`. `bias` is 5 for every machine; `prevWeights` is last
  window's normalised `raw`, so ≈ 1/34 → contributes ≈ 3. **The 176 runtime
  machines have no entry in `weights.json`** (`spec.isNil`, 2863), so they
  get no feature coefficients at all: `v = 3 + 5` every window, and there is
  nothing for a knob to act on. Only the 20 classes carry coefficients.
  `novelty_penalty` (×0.85 at most), `macro_bias` (a uniform ×2.5 on the macro
  layer), `density_bias` (class machines only), `temperature` (1.0, a no-op)
  and `audibility_influence` (0.0, multiplied out) all act on this near-flat
  vector. Nothing self-reinforces: the ×100 carry is 3 points of an 8-point
  score, so differences shrink by ≈ 0.4 per window.
- The actual pick (3033–3072) is per layer: `pool = avail` filtered by
  `layerOf`, then `pool.wchoose(prevWeights)`. Because the pool is normalised
  within the layer, any factor that is uniform across a layer (`macro_bias`,
  the operator's zero on non-micro cells) cancels here.

There is no bias toward machines with transition counts in `memory.json`;
`memory.json`'s section families and transitions feed `pickSection`, not the
machine weights. Invented machines do not start at zero weight; they start at
`bias` like everything else.

## 2. The "~253 that don't" do not exist

The panel's "~280 machines ever invented" is `renders/vocabulary.json`, a
running set of every string that has ever appeared in the machine field across
20,411 publish cycles. It decomposes as:

| what the string is | count |
|---|---|
| a base class | 20 |
| a live name with the `@slow` suffix appended (post-`operator_sees_macro` duplicate) | 57 |
| a `br:a>b` pseudo-name from an older log format | 33 |
| a ` 2` Finder-copy duplicate (`brgpgl15 2`, `brhmdr3 2`, ...) | 21 |
| a runtime machine on disk today | 134 |
| a bridge name in an old log, no longer on disk | 15 |
| **total** | **280** |

Distinct real machines ever: 20 classes + 176 on disk + 15 gone = **211**, of
which **196 exist and 196 sounded**. The 42 bridges on disk that are absent
from `vocabulary.json` (e.g. `brbuhm6`, 103 macro windows this run) are absent
because the panel reads the micro field only; they are macro machines. The
panel count is a count of strings, not of machines, and the ~253 gap is an
artefact of suffixes, duplicates and format changes.

## 3. Why `operator_weight` 0.35 → 0.0 changed nothing

It could not have. The operator block (2940–2958) does

```
dom = op.dominantOver(avail);
if (dom.isNil) { brk.value };
```

and `TransferOperator.dominantOver` (`TransferOperator.sc:304`) builds its
vector with `cells.indexOf(m)` for each `m` in `avail`. Since
`operator_sees_macro = 1`, every observed state is
`(machine ++ "@" ++ bucket).asSymbol` (3151) and the bucket is the constant
`slow` (`2026-09-18_the_operator_carries_a_dead_state_space.md`). All 27 cells
are `x@slow`; `avail` holds bare names. `indexOf` returns nil for every
machine, the vector sums to zero, `dominantOver` returns nil, and the block
exits **before the mix**. `operator_second` (0.4) sits inside the same block
and is equally unreachable. The log confirms the cell names:
`OPERATOR 1,0.6129,0.3871,27,sc@slow,...`.

So the operator is inert not because it predicts too well and not because it
does not discriminate, but because its steering vector never matches a name.
Before the suffix existed the bare cells did match, which is why the 15-run
ablation could measure a dose-response (22.3 → 16.7 sounding machines). The
18 September prune of the 190 bare cells did not cause this; it only removed
the last cells that could have matched. It is worth saying what a working
operator would do: the live chain's stationary distribution is 0.024–0.051
over 27 micro cells (uniform 0.037, max/min 2.2), and zero on every mid and
macro machine. Mixed at 0.35 it would tilt micro picks by a factor of at most
~2 and leave mid and macro untouched. It is a mild steer toward a near-uniform
distribution over a space the factory already covers uniformly.

## 4. Invention: 0 acquired since 5 September, two locks in sequence

New machines are written by `MachineWriter.propose` (called at 3211, every
`acquire_every = 8` windows), which writes `machines/<name>.scd` and
`written_machines.json` and calls `loadMutable`, so a successful write would
enter `avail` at the next window. This run called it **1,099 times and
acquired nothing**. Every failure is the same: `endpoint not in specs:
fma2@slow/grind@slow`. `findGapInLayer` (`MachineWriter.sc:504`) looks up
`specs[a]` with the suffixed cell name, finds nothing, falls back to
`findGap`, and `propose` then refuses the pair at line 607 for the same
reason. Same defect as the operator, one class over.

Across all 211 logs, the last `ACQUIRED` is
`brmapu2609051820x1` in `live_260905_182008.log`. Since then:

| period | ACQUIRED | ACQFAIL reason |
|---|---|---|
| 5 Sept 18:20 – 17 Sept | 0 | `duration ... within minDeviation 0.25 AND shape within minShapeDeviation` |
| 18 Sept (after the cell prune) – now | 0 | `endpoint not in specs: x@slow/y@slow` |

The first lock is real saturation: the 174 `playback` machines span
0.013–11.4 s with no neighbour gap on the log axis wider than 0.454 and **no
duration anywhere in 0.02–11 s that is ≥ 0.25 dex from every existing one**.
A proposed bridge can only pass on shape, and none did in twelve days. The
second lock replaced it on 18 September and is total regardless of duration.
`written_machines.json` was last modified 5 September 17:49; the newest bridge
on disk is stamped `2609051705`. The supply has been the same 196 machines for
fifteen days of runs.

## Answer

Selection is not refusing anything: `avail` is the whole supply, the pick is
name-blind, and the run sounded 196 of 196. Supply is not withholding
anything: there is nothing on disk that was not offered. **The attractor is
the supply itself, and the supply is frozen because invention has failed on
every call for fifteen days**, first on a saturated duration line, then on a
name suffix the writer cannot see through. A ten-arm knob sweep on the
selector was a sweep over a uniform distribution's parameters.

## One cheap test

Two, one per lock, both reversible and neither touching code:

1. **Drop one hand-written micro `.scd` into `mutable/machines/`** (the
   `fma*` files are the template; a duplicate of `sift.scd` under a new name
   is enough). Prediction: `LOADED_MACHINE` at the next reload, first
   `SLOT micro` within ~150 windows, then ~1/28 of micro windows for the rest
   of the run. If it sounds, supply is confirmed as the lever and selection as
   passive. If it does not, this record is wrong.
2. **Set `operator_sees_macro = 0` for one arm.** Cells revert to bare
   names, `dominantOver` and `findGapInLayer` match again. Prediction: the
   `ACQFAIL` reason flips from `endpoint not in specs` to `duration ... within
   minDeviation`, and `operator_weight` becomes a live knob (the pre-suffix
   dose-response returns). That distinguishes the suffix lock from the
   saturation lock without writing a bridge.

The fix itself is one line in each of two places: strip `@…` from the cell
name before the spec and `avail` lookups (`TransferOperator.dominantOver`,
`MachineWriter.findGapInLayer`/`propose`), or stop appending a constant.

## What is not claimed

That a larger supply would sound better, or that the 27 micro machines are
musically indistinct. This record is about counts and code paths, not the ear.

That the selector is exactly uniform. χ² rejects that; the claim is that it is
within 0.02 bits of uniform per window and has no dominant cycles.

That the saturation lock (5–17 Sept) is the only reason no bridge was written
in that period. The `shape` half of the test was not read closely; the claim
is that duration alone could not pass and the log says nothing passed.

That `operator_sees_macro` was set on 15 September. The 18 September record
says so; `policy.json.bak_pre_mc` (9 September) already carries `1`. The date
does not change the mechanism.

That the arm boundaries used here (the `reloads` field, 850/860 windows) are
the harness's exact 853-window arms. The per-arm numbers are insensitive to a
few windows either side.

The log was still being appended when copied (8,789 windows; the file on the
volume had 8,813 event lines by the time the invention tally ran). The extra
windows are the tail of arm 11 and change no count above except the last
`ACQFAIL` total (1,099 in the copy, 1,103 on the volume).

## Reproduce

```sh
python3 tools/the_attractor.py /Volumes/FMA/superdark/renders/live_260919_141610.log
# per-log invention tally
cd /Volumes/FMA/superdark/renders
for f in live_*.log; do echo "$f $(grep -c '^ACQUIRED' $f) $(grep '^ACQFAIL' $f | sed 's/^ACQFAIL [0-9]*,//; s/[:0-9].*//' | sort | uniq -c | tr '\n' ';')"; done
# the two lookups that never match
python3 tools/strip_sc_comments.py workdir_music/tools/live_factory.scd | sed -n '2940,2958p;3151p'
grep -n 'indexOf(m)' workdir_music/tools/live_classes/TransferOperator.sc
grep -n 'endpoint not in specs' workdir_music/tools/live_classes/MachineWriter.sc
```
