# Pre-registration: three knobs, bracketed — A-B-A-C-A-D

**18 September 2026, 09:5x.** Written before the factory is started and before
any arm is read.

## Why this design

Three comparisons in, the null showed the drift between two identical arms
(`sonic_variety` 0.0080) is the same size as the movement the real comparisons
produced (0.0086, 0.0020). Any comparison from here needs a drift estimate taken
in the same run, and one knob per five-hour boot will not reach five paired
comparisons this month.

So three candidates in one unbroken run, each bracketed by a champion arm:

```
A1  C1  A2  C2  A3  C3
```

Every boundary changes exactly one policy key — the candidate's knob going in,
the same knob coming back out — so `one_change_at_a_time` holds at each step.
The A–A pairs are nulls measured inside the same run, on the same corpus and
trace.

## The baseline

The policy as it stands after this morning's operator repair: dead cells
archived, `operator_half_life = 5000`, output device BlackHole 2ch (VB-Cable
reports mono after a reboot; the device is a silent sink and the stream reads
the FIFO, so this changes nothing measured). **This baseline differs from
comparisons 1–3**, whose operator carried 61% dead history. That is recorded
here so nobody pools across it without saying so.

## Arms, in order

| arm | knob | baseline | candidate | why this value |
|---|---|---|---|---|
| A1 | — | | | |
| **C1** | `self_ingest_weight` | 0.75 | **0.5** | one third less reliance on its own past. #47 swept this knob against silence and depth; 0.5 is inside the swept range and clearly off the baseline |
| A2 | — | | | |
| **C2** | `voices_max` | 8 | **5** | #31 widened the range to [1, 8] from a narrower one; 5 is the midpoint and should move `m6_texture` and the voice trace visibly if anything does |
| A3 | — | | | |
| **C3** | `collapse_after` | 600 | **300** | half the tolerance for silence before collapse is declared; changes how long the factory may sit in the states it veers into |

853 windows per arm, matching comparisons 1–3. Six arms, roughly 14 hours.

`operator_weight` (0.35) is held for a second run: four knobs is ~19 hours, and
it is the one knob whose meaning changed this morning — before today it was
steering toward a state space the factory had left.

## Decision rule, fixed now

**Nothing is promotable.** Margins are UNSET and stay UNSET until five paired
comparisons exist; this run supplies three plus two nulls, so the count reaches
six and eight. What can be *set* afterwards is the smallest-reportable-
difference, from the nulls — the rule for that is in the release policy and is
not rewritten here.

For each candidate pair, per measure with promotion power:

1. **|d_cand| ≤ max(|d_A1A2|, |d_A2A3|)** — the movement is inside the in-run
   drift and **cannot be claimed as an effect**.
2. **|d_cand| > max(|d_A1A2|, |d_A2A3|)** — the movement exceeded both in-run
   draws of drift. Recorded as *exceeds drift*. Not significance, not promotion:
   two draws of drift are two draws.
3. **Any charter metric that passes in a champion arm fails in a candidate
   arm** — `charter_not_regressed` blocks, and the knob is recorded as having
   moved the factory out of its own charter at that value.

`version_operator`'s analytic dwell (−1/ln|λ₂|) is **excluded from rule 1–2**:
the null showed it moves by hundreds between identical arms. Its empirical dwell
is read instead. This is a change to how a promoting measure is read, made in
advance, and will be carried into `measures.json` separately.

## What one run cannot do

Two in-run nulls are two draws. They bound this run's drift; they do not
establish a floor for the factory. The baseline changed this morning, so the
0.008 floor from the 18 Sept null belongs to the old operator and is not
assumed to carry.

## Procedure

```sh
sh tools/run_n_arms.sh --windows 853 \
    --cand self_ingest_weight=0.5 --cand voices_max=5 --cand collapse_after=300
# after ALL 6 ARMS COMPLETE:
sh tools/score_n_arms.sh harness/n_arms_<stamp>.json
```

The runner refuses a candidate equal to its baseline (a null is run declared,
through `run_two_arms.sh --champ X --cand X`, never by accident), refuses to
start on battery, aborts on a clock jump, and refuses the previous run's log.
