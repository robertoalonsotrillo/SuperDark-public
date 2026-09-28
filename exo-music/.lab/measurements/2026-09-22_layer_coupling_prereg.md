# Layer coupling K: pre-registration

**22 September 2026, written before the run.** Step 2 of the nesting
programme. Baseline: `2026-09-22_layer_coupling_baseline.md`. Measure:
`tools/layer_coupling.py`. Mechanism: `layer_coupling` in `policy.json`,
built today in `live_factory.scd` (compiles; deploys at the next boot, which
waits for the composed writer's 24 h window to close on 23 Sept 13:00).

## The knob, and why its zero is not today

`layer_coupling` K in [−1, +1], read every window, no restart needed.

| K | top-up | rest decision | what it is |
|---|---|---|---|
| −1 | a resting layer's share of `nVoices` is refilled from the other layers (by count, then fallback) | unchanged | the factory as it has run since the top-up was written; every log so far is this arm |
| 0 | the target is `nVoices` minus the number of resting layers; a resting layer's slot stays empty; a chosen layer that is resting is swapped for the next non-resting one | unchanged | no compensation: a rest thins the texture |
| +K | as at 0 | while another layer rests, this layer's rest probability at its next decision becomes p + K(1 − p), clipped at 0.95 | rests tend to coincide |

A `COUPLE win,K,resting,target,nVoices` line is written every window, so
the arm a window belongs to and what the loop was told are in the log.

## Arms

Bracketed, through `tools/run_n_arms.sh`, K the only key that moves:

    A (−1)  →  C1 (0)  →  A (−1)  →  C2 (+0.5)  →  A (−1)

800 windows per arm (2.6 h), five arms, about 13 h. `knobs_to_factory` is
set to "0" for the whole sequence and restored after, so the five knobs sit
at the architect's values and do not move between arms; the factory's own
knob file is left as it is. The composed writer stays on; it is the same
factory in every arm.

Why 800: the null bar for max |r| at n ≈ 1,100 was 0.16–0.19 and the K = −1
signal is −0.22 to −0.37, so 800 windows separates a full-strength effect
from its null with room, and the A arms give the in-run drift of the
measure itself.

## Decision rules, fixed now

On `tools/layer_coupling.py` per arm, block 20, 200 null draws, seed as in
the tool.

1. **Attribution (C1 against A).** At K = 0, macro–mid and macro–micro
   max |r| fall inside their null bars (p > 0.05) in the C1 arm while the
   two A arms around it keep p < 0.05 with negative r. If C1 stays negative
   and significant, the top-up is not the whole mechanism (the
   `voices_follow inverse_density` path is the named suspect) and the
   experiment stops there with that finding.

2. **Coupling (C2 against A).** At K = +0.5, macro–mid and macro–micro r
   are positive and above the null bar (p < 0.05), and the rest ratios
   macro→mid and macro→micro exceed 1 and their null bar.

3. **Not a lock.** In C2, mutual information stays below 0.5 bits on
   every pair, and the share of all-three-silent windows stays below 3%.
   Above either, K = +0.5 is a lock and the next arm, if any, is +0.25.

4. **Integrity.** All ten invariants on every arm; any CLOCKJUMP voids the
   arm it falls in, and only that arm (an amendment to the 24 h rule,
   recorded here before any data: an arm is 2.6 h and a nap of minutes
   does not touch the statistic; the run is void only if fewer than two A
   arms and both C arms survive).

5. **The ear's veto stands.** Roberto listens to C1 and C2 before any
   number is quoted as a result; a statistic that rises while the result
   sounds worse is re-examined, per the note of 19 Sept.

## What is not decided by this run

Which K the factory should sit at. That is the Class 3 step: expose K to
the factory with a proposal kind over this measure against `n3_coherent`,
inside a range the architect sets. This run establishes that the range is
live and what its ends do; it does not pick a point on it.

Whether the mid–micro pair should be coupled at all. It sits at its null
today and the mechanism does not target it separately.
