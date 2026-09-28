# Attention_weight comparison — arm boundaries

**#99. Shadow comparison 1 of the 5 needed before `release_policy.v1.json`
margins can be set.** Pre-registration: `2026-09-15_attention_prereg.md`,
written 15 Sept 21:15, before any arm was read.

This file exists so the arms can be sliced correctly by someone who was not
here. Both arms live in **one log**, `live_260916_125717.log`, because the change
is a policy value and needs no restart.

## Why a hot reload and not a restart

The pre-registration specifies a hot reload. A restart would alter the trace and
the corpus, which is a second change, and `one_change_at_a_time` requires the
candidate to differ from the champion in exactly one thing. `live_factory.scd`
re-reads `policy["attention_weight"]` inside the attention block on **every
window**, so the change takes effect without touching the process.

Confirmed: no restart occurred. Same sclang, same scsynth, same ingest daemon
across the boundary. `run_integrity` clean since 12:57.

## Arms

| | champion | candidate |
|---|---|---|
| `attention_weight` | **0.0** | **0.15** |
| windows | 45 – **852** | **855** – (2 h from 15:28:48) |
| wall clock | 12:57:17 – 15:28:48 | 15:28:48 – ~17:29 |
| checkpoint | `ck_260916_152816_unlabelled` (sealed BEFORE the change) | to be taken at arm end |
| raw windows | 852 (807 after warm-up) | target ≥ 245 raw |

Windows 853–854 elapsed between recording the boundary and writing the file;
they belong to neither arm and should be excluded when slicing.

`tools/eval_run.py` has `slice_log()` for exactly this, added in commit 57b2a5c:
without it the candidate would be scored as "champion plus candidate".

## The mechanism is live, and that had to be checked

`attention_weight` had **never run** before 15 September: `attend()` keyed its
recall dictionary by suffixed machine names (`sc@slow`) that `avail` never held,
so `vec.sum` was always 0 and the block took its escape on every window. 6,570 of
8,000 trace entries were affected. Raising the knob before that fix would have
changed nothing, silently, and "attention has no effect" would have looked like a
finding.

So the arm is only meaningful if the mechanism actually engages. Checked, both
directions:

- **Champion, aw = 0.0:** zero `ATTEND` lines across 852 windows. Correct, not
  broken — `live_factory.scd:2925` reads `if (aw <= 0) { brk.value }` and exits
  the block before any recall happens.
- **Candidate, aw = 0.15:** first `ATTEND` line within 90 seconds of the reload:

```
ATTEND 860 brpucr2609040130x1@112:0.003 ma@97:0.003 fma2@97:0.002
```

Recalling machines from runs 112 and 97. This is the first time attention has
produced output inside an actual comparison arm.

## Champion arm standing

852 windows over 2 h 31 m. `run_integrity` clean. Charter **SATISFIED on 7 of 8**
metrics, `m3_no_clipping` at **0.000**. Two BLOWUP events (2.82 and 2.04, both in
window 323) with **zero VOICEBLOW**, so ordinary loud sums rather than the
filter divergence fixed earlier today — and m3 was unaffected.

Nine `CUTOFFREQ` requests landed above the 8820 Hz Nyquist hazard, all
harmlessly clipped by the fix. Before it, each would have diverged.

## Margins are UNSET

The gate will return `margins_unset` and promote nothing. That is the designed
outcome for shadow comparison 1 of 5, and it is not a failure of the arm.

## Resuming

1. Wait until ≥ 245 raw windows past 855 (about 17:29).
2. Checkpoint the candidate.
3. `eval_rig.sh run` each arm with `--win-from` / `--win-to` from the table above.
4. `eval_rig.sh compare`, then `gate` pointed at the `harness/runs/cmp_*`
   **directory**, not the JSON file — they do not compose as the usage text
   implies (#111).
5. Do not restart the factory before step 2. Each restart is counted by
   `run_not_contaminated` and four of them today were enough to block a gate.
