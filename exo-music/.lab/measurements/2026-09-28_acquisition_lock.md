# Why new machines were rare: the acquisition lock, 28 Sept 2026

Live boot `live_260927_133543` (7.5 h): 312 acquisition attempts, 1 machine written. 302 refusals were near-copies of playbackHP machines, every refused candidate below 0.09 s. Rung 2 needs >= 0.09 s, so no new synth could be drawn at all. Roberto heard the new synths "but not that often" (27 Sept first listen).

## Cause (three layers, found in order)

1. starvedLayer sent every attempt to the layer with the fewest machines; a refusal adds nothing, so it stayed starved. Fixed (layer stall after acquire_stall_limit refusals), but not the binding cause: findGapInLayer falls back to the layer-blind gap.
2. A refused pair is not retired, so the strongest gap is retried every attempt. Fixed (a pair refused acquire_stall_limit times rests until any admission). Not binding either: the next gaps are in the same short region.
3. Binding: the bridge's duration was interpolated strictly between its endpoints (mix 0.35-0.65), so the writer could not leave the convex hull of what already plays (named 3 Sept, never fixed). The played vocabulary is dense below 0.09 s.

## Test (`tools/test_stall_lock.scd`, sandbox copy of mutable/, gap mode, live grammar and source weights, 96 attempts, same seed)

| arm | admitted | rung 2 |
|---|---|---|
| as on 27 Sept | 2 | 1 |
| layer stall + pair rest | 3 | 1 |
| + reach 1.0 | 14 | 7 |
| + reach 2.0 | 29 | 15 |

## Change

- `acquire_reach` [0, 2]: the mix runs from -reach to 1 + reach in log duration. A factory knob; starts at 1.0.
- `acquire_stall_limit` [4, 48]: layer stall and pair rest. A factory knob; starts at 12.
- `acquire_max_per_hour` 3: the architect's ceiling on renewal (a constraint, not a knob), logged as ACQCEIL when it binds. At the live attempt rate (about 42 an hour) and reach 1 the writer would otherwise admit about 6 an hour.

Class 3 check: how the writer renews (reach, stall) is ceded as means inside architect bounds; how fast the vocabulary may grow is the architect's constraint. Offline only; live verification at the next boot (expected: ACQUIRED lines with rung 2 sources, ACQCEIL binding some hours).
