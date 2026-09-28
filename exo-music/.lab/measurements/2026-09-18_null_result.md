# The null: what moves when nothing changes — shadow comparison 3 of 5

**18 September 2026, 08:5x.** Read against `2026-09-17_null_prereg.md`, whose
decision rule was fixed before the factory started.

## The run

Both arms `attention_weight = 0.15`, 853 windows each, hot reload writing the
same value, one log, no restart. Ran 01:03–06:16 through dawn without incident:
zero fill-stalls, blow-ups, voice-blows, server losses or clock jumps inside
the arms. Gate: all ten invariants, and `one_change_at_a_time` returned *"no
change, and both arms declared intent=null"* — the exemption built yesterday,
behaving as specified. Bundle `harness/runs/cmp_260918_084817`.

**Scoring it took two attempts, and the first was wrong in a way worth
recording.** `eval_rig.sh` had not been taught the `--intent` flag, rejected
the call, and produced no bundle; `score_two_arms.sh` then took the newest
bundle that *did* exist — yesterday's — and the gate reported "exactly one
change: attention_weight" for a null. That is the `ls -dt` trap the script's
own header warns about, reached by a path the header did not name. The stale
bundle was deleted, the wrapper passes the flag, and the scorer now refuses any
bundle older than its own start rather than falling back.

## The deltas, side by side

| measure · field | **null** | cmp 1 (0.15→0.3) | cmp 2 (0.15→0.3) |
|---|---|---|---|
| `sonic_variety` recurrence | **−0.0080** | −0.0086 | +0.0020 |
| `version_operator` dwell −1/ln\|λ₂\| | **+696.4** | −19.4 | −8.1 |
| `version_operator` empirical dwell | +4.0 | 0.0 | −0.6 |
| `version_operator` θ from null | +0.0112 | −0.0044 | −0.0066 |
| `generation_drift` 0→1 | 0.0000 | 0.0000 | 0.0000 |
| `judges` | −0.0012 | −0.0001 | −0.0012 |

## Against the pre-registered rule

**`sonic_variety`.** |d_null| = 0.0080, |d_1| = 0.0086. Formally outcome 2 —
comparison 1 exceeded one draw of the drift — by **0.0006**. That is the honest
number and it does not support the honest sentence "comparison 1 had an
effect": two arms that differed in *nothing* moved 93% as far as two arms that
differed in the knob. Read with comparison 2's reversal, `attention_weight`'s
effect on `sonic_variety` is **at the noise floor** from two independent
directions. The rule is honoured as written, and the candidate floor it names is
recorded: **0.008**, pending more nulls.

**`version_operator` dwell (−1/ln|λ₂|).** |d_null| = **696.4** against |d_1| =
19.4 and |d_2| = 8.1. Both real comparisons are inside the drift by a factor of
thirty-five or more. This field cannot carry a margin.

**Charter drift between identical arms:** `m1_not_silent` +0.002, `m2_level`
−0.004, `m8_in_band` +3.1. Three metrics tell two identical factories apart by
those amounts; all far inside their bounds. These are the charter's own floors.

## The finding that was not pre-registered

The analytic dwell is **−1/ln|λ₂|**, a hyperbolic transform. In the null the
champion's |λ₂| was ≈ 0.969 and the candidate's ≈ 0.9986 — a difference of
0.03 in the eigenvalue — and the transform turned it into 32.1 versus 728.5.
As |λ₂| → 1 the field goes to infinity, so its noise is unbounded exactly where
the operator is most stable. The *empirical* dwell, counted from the trace,
moved 6.8 → 10.8 across the same two arms.

`version_operator` is one of three measures with promotion power. Its headline
field is unusable for that purpose, and its empirical field is the one that
should carry it. This is a change to `harness/measures.json` and possibly to
`release_policy.v1.json`, and it is not made here; it is filed.

`version_operator` builds its own chain over judge-score cells from the window
log. It does not read the machine operator in `memory.json`, so the operator
prune scheduled for today does not address this.

## What one null cannot do, restated

One draw. The 0.008 floor for `sonic_variety` is a single sample of the drift,
and the release policy's smallest-reportable-difference needs several. Nothing
here is significance and nothing here licenses promoting or rejecting
`attention_weight`; it says that two comparisons' movements are of the same
size as no comparison at all.

## Standing after three of five

| # | what | outcome |
|---|---|---|
| 1 | attention 0.15→0.3 | gated clean; two measures moved opposite ways |
| 2 | attention 0.15→0.3 | gated clean; direction not reproduced (pre-reg rule) |
| 3 | **null** | gated clean; cmp 1 and 2 are at the noise floor |

Margins remain UNSET. Two comparisons are still owed before they can be set,
and at least one more null before the floor is more than one draw.
