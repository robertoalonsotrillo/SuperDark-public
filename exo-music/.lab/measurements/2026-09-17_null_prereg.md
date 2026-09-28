# Pre-registration: the null comparison — shadow comparison 3 of 5

**17 September 2026, 20:2x.** Written before the factory is started and before
any arm is read.

## Why a null, and why now

Shadow comparison 2 finished today and its own pre-registered decision rule
fired. `sonic_variety` recurrence moved **+0.002** where comparison 1 moved
**−0.0104**, and `version_operator` dwell moved **−8.1** where comparison 1 moved
**−19.4**. One measure reversed sign; the other moved in the same direction but
less far on twice the dose.

That is outcome 2 in `2026-09-16_attention_03_prereg.md`, whose conclusion was
fixed in advance:

> comparison 1's direction not reproduced, and `attention_weight` is a knob whose
> effect is not yet distinguishable from noise at these sample sizes.

**No further comparison that changes something can sharpen that.** Two deltas of
opposite sign tell you nothing until you know how big a delta is when *nothing*
changes. That number does not exist anywhere in this project.

The release policy has said so since it was authored. Margins get set
`when_set`: *"one number per promoting measure, plus a smallest-reportable-
difference below which a result is flat."* A smallest-reportable-difference is
a property of the noise, and it cannot be obtained from any comparison that
moves a knob.

## What is being measured

How far each measure drifts between two arms of the same run **when nothing is
changed at all**.

## Arms

Identical in every respect to comparisons 1 and 2 except that the knob does not
move. Same length, same reload mechanics, same single log, no restart.

| | champion | candidate |
|---|---|---|
| `attention_weight` | **0.15** | **0.15** |
| windows | 853 | 853 |
| boundary | hot reload writing the same value, no restart | |
| intent | `null` | `null` |

The reload still happens. It writes 0.15 over 0.15, so the *mechanism* of the
boundary is identical to the two previous comparisons and only the value is
held. If the reload itself perturbs the factory, this design catches it; a
design that skipped the reload would not, and would be measuring a different
thing from the comparisons it is meant to calibrate.

## The gate will pass, and that is a change made today

`inv_one_change_at_a_time` refuses two identical arms — *"two identical
configurations are not a comparison"*. That refusal is right for a promotion
attempt and backwards here. It now accepts `n == 0` **only when both arm
manifests carry `intent: "null"`**, recorded by `eval_run.py --intent` at
scoring time.

The case the rule exists for is untouched: someone who means to move a knob and
does not will have declared nothing, and still fails with the original message.
The exemption has to be bought in advance, because manifests are written before
the comparison is assembled — it cannot be claimed after seeing the result.
Tested on eight cases, including a half-declared null and a missing intent key,
both of which fail.

## Decision rule, fixed now

**Nothing is promotable from this run.** Not "nothing is promoted because
margins are unset" — nothing is *promotable*, because there is no candidate. The
two arms are the same configuration.

Let `d_null` be the absolute delta this run produces for a measure, and `d_1`,
`d_2` the deltas from comparisons 1 and 2.

1. **`d_null` ≥ `d_1`** for `sonic_variety` — comparison 1's movement is inside
   the drift and **cannot be claimed as an effect**. Recorded as such, and the
   earlier record is amended to say so.
2. **`d_null` < `d_1`** — comparison 1's movement exceeded a single draw of the
   drift. This is *not* promotion and *not* significance; it makes `d_null` a
   candidate floor for that measure, to be confirmed by further nulls.
3. **Any charter metric departs in one arm and not the other** — that is drift
   in the charter itself and is reported loudly, because both arms are the same
   factory and the charter should not be able to tell them apart.

## What one null cannot do

A single null gives **one draw** of the drift, not a distribution. It cannot
support a confidence interval, a p-value, or a claim that any measured
difference is "significant". Setting a defensible
smallest-reportable-difference needs several nulls, and this is the first.

Stated now so that a small `d_null` cannot later be read as licence to promote
comparison 1's direction.

## Procedure

```sh
sh tools/run_two_arms.sh --key attention_weight --champ 0.15 --cand 0.15 --windows 853
# then, after BOTH ARMS COMPLETE:
sh tools/score_two_arms.sh
```

`run_two_arms.sh` derives `intent=null` from `champ == cand`, so the declaration
cannot be set by hand and cannot be set by accident: the only way to obtain it
is to ask for the same value twice.
