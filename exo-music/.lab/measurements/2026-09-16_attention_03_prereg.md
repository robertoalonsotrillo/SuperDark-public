# Pre-registration: attention_weight 0.3 — shadow comparison 2 of 5

**16 September 2026, 21:0x.** Written before any arm of this comparison is read.
Extends `2026-09-15_attention_prereg.md`, which already anticipated it:

> 0.3 is a later arm if 0.15 survives.

**0.15 survived.** Shadow comparison 1 gated clean on all ten hard invariants,
`charter_not_regressed` passed, and both arms' charters were honest. Surviving is
not the same as winning — nothing was promoted and nothing was claimed — but the
condition the earlier pre-registration named has been met.

## What is being tested

Whether *more* recall changes the factory more, and in the same direction.

Comparison 1 gave two measures pointing opposite ways: `sonic_variety` said the
candidate was less recurrent (0.8580 → 0.8476), `version_operator` dwell said it
settled less (59.4 → 40.0). With one comparison and no margins that is noise as
easily as signal. Doubling the weight is the cheapest available test of whether
either direction is real: **if 0.15 → 0.3 moves the same measures the same way
and further, the direction is probably real; if it moves them back, or moves
different ones, comparison 1 was noise.**

This is a monotonicity check, not a promotion attempt.

## Arms

Both from the one log, hot-reloaded, no restart — the same design decision as
comparison 1 and for the same reason: a restart would move the trace and the
corpus alongside the knob.

| | champion | candidate |
|---|---|---|
| `attention_weight` | **0.15** | **0.3** |
| windows | **1708 – 2515** | from the reload + 45 warm-up, **808 windows** |
| length | 808 scored, matched | 808 scored, matched |

The champion is **unspent 0.15 data**: comparison 1 scored 900–1707, and windows
1708 onward have never been read. This is not the same arm re-used. It is the
same *configuration*, scored on windows no comparison has touched.

Disjoint from comparison 1's candidate by construction, and disjoint from this
comparison's own candidate by the reload boundary.

## Decision rule, fixed now

Margins are UNSET, so **the gate will return `MARGINS_UNSET` and promote
nothing**. That is expected and is not a result.

What this comparison is allowed to conclude:

1. **Monotone and consistent** — `sonic_variety` falls further and
   `version_operator` dwell falls further, both beyond comparison 1's deltas
   (−0.0104 and −19.4): recorded as *direction consistent across two weights*,
   still not a claim, and it becomes evidence toward setting margins.
2. **Non-monotone** — either measure reverses: recorded as *comparison 1's
   direction not reproduced*, and `attention_weight` is a knob whose effect is
   not yet distinguishable from noise at these sample sizes.
3. **Any charter metric that passed for 0.15 fails for 0.3** — `charter_not_regressed`
   blocks, and 0.3 is recorded as a configuration that costs something the
   charter protects.

No other reading is permitted from this comparison.

## What would make it void

- a restart between the arms (they would no longer share a boot, and the code
  could differ)
- any `run_integrity` fault inside either arm's wall clock
- fewer than 200 scored windows in either arm after the 45-window warm-up
- `ATTEND` lines appearing before the reload boundary, which would mean the
  champion arm was not at 0.15 throughout

## Why not go straight to a bigger jump

0.3 is the value the earlier pre-registration named, before any of comparison 1's
numbers existed. Choosing a different value now, after seeing those numbers,
would be choosing the test to suit the data. The pre-registered value stands.
