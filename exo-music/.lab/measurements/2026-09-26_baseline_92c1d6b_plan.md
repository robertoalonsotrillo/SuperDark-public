# Baseline on 92c1d6b: plan, written before the data

**26 September 2026, 21:00.** Log `live_260926_205648.log`, booted 20:56
on commit a10cf5e (code of 92c1d6b; the commits since touch only the
runner, start_loop's override and records). Alignment check overridden
(`2026-09-26_alignment_override.md`).

Policy, unchanged for the whole run: layer_coupling -1.0,
knobs_to_factory 0 (the five knobs at the architect's values, as in the
coupling runs), voices_follow inverse_density, dsp_slot_weight 0.5,
synth_slot_weight absent (rung 2 inert).

## Why

Part 2 of the coupling run showed the A arms of 26 Sept holding only one
negative macro pair each, where every run from 19 to 24 Sept held both.
Before the voices_follow arm or rung 2, the baseline on this build has to
be known.

## What is scored

Windows 19-818 and 819-1618 as two A arms (an A-A null inside one run):
`tools/layer_coupling.py --n-null 200` per half; rest shares; integrity
(CLOCKJUMP, BLOWUP, POOL_RESET, alloc failed, MASTER); m8 and d2 half to
half. A CLOCKJUMP voids the half it falls in.

## Reading, fixed now

- Both halves negative and significant on macro-mid and macro-micro: the
  26 Sept A arms were noise, the part 1 baseline stands.
- Either half positive or null on a macro pair: the baseline moved with
  92c1d6b, and the voices_follow arm is designed against this run, not
  against 22 Sept.
