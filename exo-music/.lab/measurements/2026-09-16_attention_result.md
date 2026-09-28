# attention_weight, shadow comparison 1 of 5 — GATED CLEAN

**16 September 2026, 20:12.** Pre-registration:
`2026-09-15_attention_prereg.md`, written before any arm was read.

The comparison ran, both arms scored, and after three rig defects were fixed it
**passed every hard invariant** and returned `MARGINS_UNSET` — the designed
outcome for a shadow comparison, not a refusal.

Re-gated later the same evening against **ten** invariants, after
`one_change_at_a_time` was wired (#110). It reads: *exactly one change:
attention_weight (repo HEAD also moved, but both arms share one log so no restart
occurred and the running code is identical)*.

This is the first comparison in the project's history to clear the gate.

```
  ok  seal_intact          ok  no_stall
  ok  checkpoint_verifies  ok  charter_not_regressed
  ok  archive_intact       ok  min_windows
  ok  run_not_contaminated ok  learning_frozen_during_isolation
  ok  one_ingest_daemon    ok  one_change_at_a_time

VERDICT  MARGINS_UNSET
  The gate ran and promotes nothing. Margins are not set, so 'clearly
  better' has no number behind it yet. Five paired comparisons in
  shadow, then set them from that data.
```

`run_not_contaminated` now reads **0 faults inside the arms (14 elsewhere in the
journal, not counted)**.

## The arms

| | champion | candidate |
|---|---|---|
| `attention_weight` | 0.0 | **0.15** |
| windows scored | 45–852 (**808**) | 900–1707 (**808**) |
| wall clock | 12:57:17 – 15:28:48 | 15:28:48 – 18:00:19 |
| duration | 2.53 h | **2.53 h**, matched |
| audio segments | 12 | 14 |
| `ATTEND` lines | **0** | **312** |

The mechanism engaged where it should and nowhere else: first `ATTEND` at window
860, none before the 855 boundary. Zero at `aw = 0.0` is correct rather than
broken — `live_factory.scd:2925` exits the block when `aw <= 0`.

No restart occurred between the arms. Same sclang, same scsynth, same ingest
daemon, integrity clean since 12:57.

## The numbers, which promote nothing

Margins are **UNSET**, so this is shadow data by design. Recorded, not claimed.

| measure | champion | candidate | delta |
|---|---|---|---|
| `sonic_variety` recurrence | 0.8580 | 0.8476 | **−0.0104** |
| `convergence2` C1 | 0.921 | 0.933 | +0.012 |
| `convergence2` M2 | 0.542 | 0.550 | +0.008 |
| `version_operator` drop after m | 0.0243 | 0.0619 | +0.0376 |
| `version_operator` dwell −1/ln\|l2\| | 59.4 | 40.0 | **−19.4** |
| `judges` | −0.0009 | −0.0010 | −0.0001 |
| `generation_drift` | 0.8833 | 0.8833 | 0.0 |
| `charter_honesty` | `{}` | `{}` | — |

`generation_drift` is identical because it is not log-scoped — it reads the pool,
not the window range. Not evidence of anything.

Both arms' charters are honest: nothing failing in either.

**No claim is made from any of these.** One shadow comparison with no margins
cannot support one, and the direction of `sonic_variety` and `version_operator`
disagree about whether the candidate is more or less settled.

## Why the gate blocked at first, and what it took to clear it honestly

```
VERDICT  BLOCKED
  - comparison: both arms read the same log. That is one run measured
    twice, not two runs compared.
  - invariant run_not_contaminated: 16 fault(s)
  - veto: recurrence_sweep: candidate arm NOT WIRED
```

`eval_compare.py:85` decides pairing as

```python
"paired": cand_m["log"] != champ_m["log"],
```

— purely on **filename inequality**. And `slice_log()`, added the same day, exists
so that two arms **can** share one log. Its docstring:

> Both arms of a hot-reloaded comparison share one window log, because the change
> is a policy value and needs no restart — which is the point, since a restart
> would alter the trace and the corpus and break the one-change rule.

So one part of the rig was built to enable what another part rejects. Two honest
readings:

**The gate is wrong.** The pre-registration specified a hot reload deliberately.
Pairing should test whether the two scored ranges are **disjoint**, which they
are (45–852 and 900–1707, with 47 windows between them belonging to neither), not
whether two filenames differ.

**The gate is right.** The arms share a factory process, a corpus, a memory, a
trace and a boot. They differ in one policy value re-read each window. Calling
that "two runs" overstates their independence, and a comparison whose arms are
that entangled may deserve to be called one run measured twice.

I did not edit the check on my own judgement. Editing a gate to turn its own
BLOCKED into a pass is the move the seal exists to prevent, and this was a choice
about what counts as evidence rather than a defect to repair.

**Roberto decided, 16 Sept: disjoint scored ranges count as paired.** The rule now
reads the range from `arm_windows.log` rather than the manifest, because the
manifest misreported its own scope until today. Overlap of even one window still
refuses; five cases tested, including two touching ranges and the old whole-log
bug.

## The other two blockers, both now fixed

**`run_not_contaminated` counted the whole journal** — 16 faults, including sclang
deaths from 15 Sept and the 10:00 SSD loss, none of which touched either arm. Now
scoped to the arms' own wall clock, recorded in the manifest as `arm_since` /
`arm_until`. Bundles written before today fall back to the whole journal **and say
so**, rather than silently passing something that was never checked.

**`recurrence_sweep` held a veto it could never satisfy.** Its own registry entry
says it is unwired *on purpose*: "takes three calibration arms (loop, factory,
diverse) and is not a per-arm scorer". But unwired reports NOT WIRED, and NOT
WIRED vetoes — so a measure structurally incapable of joining a paired comparison
vetoed every paired comparison there would ever be. It keeps its authority over
calibration and now holds none over a comparison it cannot take part in. This is
not retirement.

All three defects blocked **every** shadow comparison, not just this one.

## Two rig defects found and fixed while running this

**`--until` did not exist.** `build_arm_audio` has always taken `until=` and
nothing passed it, so `until` defaulted to *now* and a champion arm's audio ran
from its start to the present — swallowing every segment the candidate produced.
The function's own docstring names this as the thing it exists to prevent.
Seventh instance this month of a capability built and unreachable. Added to
`eval_run.py` and `eval_rig.sh`, seal adopted with the reason recorded.

**The manifest misreported its own scope.** `windows` recorded `[warm, total]`
regardless of `--win-from/--win-to`, so a sliced arm claimed the whole log. The
scoring was correct — `arm_windows.log` held the right 808 windows and the
measures read that — but the manifest overstated the range threefold, and the
manifest is what a reader opens. Caught by reading the manifest against the
sliced log instead of trusting it.

The two bundles that carried the wrong `windows` field were superseded: the arms
were re-scored under the fixed code, which costs no factory time because it only
re-reads existing log ranges. The gated bundles record `[45, 852]` and
`[900, 1707]` and carry `arm_since` / `arm_until`.

## Standing

Shadow comparison **1 of 5 is complete and gated clean**. Nothing is claimed and
nothing is promoted: margins are UNSET by design until all five are in, and these
two measures disagree about direction anyway.

Four remain. They should now run without hitting any of the three blockers, since
all three were structural and applied to every comparison rather than to this one.

`comparison bundle: harness/runs/cmp_260916_202659`
