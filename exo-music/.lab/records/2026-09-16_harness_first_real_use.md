# The harness's first real use, on a real change

**16 Sept 2026, 13:35.** The Nyquist fix (#106) put through `eval_rig.sh` end to
end: champion on the blow-up run, candidate on the fixed run, compare, gate.

Until today the rig had only ever been verified against itself. This is the
first time it has been asked to judge a change to the factory.

## Verdict: BLOCKED

```
  ok    seal_intact              28 scorers
  ok    checkpoint_verifies      both arms verify
  ok    archive_intact           the pool can be restored by file copy
  FAIL  run_not_contaminated     16 fault(s)
  ok    no_stall                 zero stalls in both arms
  ok    charter_not_regressed    no metric that passed for champion fails for candidate
  FAIL  min_windows              candidate: 161 windows scored, need 200
  ok    learning_frozen_during_isolation
  ok    one_ingest_daemon        1 process

VERDICT  BLOCKED
  - invariant run_not_contaminated: 16 fault(s)
  - invariant min_windows: candidate 161, need 200
  - veto: recurrence_sweep: candidate arm NOT WIRED
  - veto: sonic_variety: candidate arm NO AUDIO
```

Margins are UNSET, so nothing could have been promoted regardless. The value
here is entirely in what it refused and why.

## It caught me three times before it caught anything else

**1. The seal had been broken for four hours.** `validate` failed on the first
call: `tools/eval_run.py` was modified at 09:37:50 today by commit 57b2a5c,
adding `slice_log()` so each arm is scored on its own windows. Legitimate change,
clear rationale, in git — and the `adopt` was never run. So every number produced
between 09:37 and 13:17 was unattributable and nothing said so. Verified the
working copy identical to the commit, then adopted with the gap recorded in
`SEAL_LOG.jsonl` rather than quietly re-sealing.

**2. Four of the 16 contamination faults are mine, from this afternoon.**

```
2026-09-16T12:24:53  DOWN  sclang
2026-09-16T12:42:38  DOWN  sclang
2026-09-16T12:55:22  DOWN  sclang
2026-09-16T12:57:03  DOWN  sclang
```

Those are the four restarts Roberto flagged while they were happening. The rig
counts each as a contamination event, and together they are a material part of
what blocked the gate. The cost of that churn is now a number in a bundle rather
than a note in a conversation.

**3. `min_windows` failed on arithmetic I should have done first.** The candidate
ran 206 windows, the protocol discards 45 as warm-up, 206 − 45 = 161 against a
floor of 200. The arm needs about 245 raw windows. I ran it at 202 believing 200
was the target.

## A gap the gate did NOT catch

I predicted the gate would flag `one_change_at_a_time`, because the candidate
differs from the champion in four things: the Nyquist fix, the voice probe, the
request channel and the SLOTS line. Only the first touches audio.

It did not flag it. `one_change_at_a_time` is a **separate policy field with no
check wired to it** — the nine hard invariants are `seal_intact`,
`checkpoint_verifies`, `archive_intact`, `run_not_contaminated`, `no_stall`,
`charter_not_regressed`, `min_windows`, `learning_frozen_during_isolation`,
`one_ingest_daemon`. The rule exists in the policy text and nothing enforces it.

That is the same class of fault as every other one found today: a rule that is
written down, believed to be operating, and not wired to anything. It is the
fifth this project has hit.

## An interface bug in the rig

`eval_rig.sh compare` prints JSON to stdout with a preamble line; `eval_rig.sh
gate --comparison` expects a **directory** containing `comparison.json`. The
usage text presents them as a pipeline and they do not compose. `compare` does
write `harness/runs/cmp_*/comparison.json`, so the gate works when pointed at
that directory, but nothing says so.

## What the comparison actually showed

`charter_honesty` is the measure that carries the fix:

| | champion | candidate |
|---|---|---|
| `charter_honesty` | `{m3_no_clipping: 1.0}` | `{}` |

The champion's charter was dishonest on m3 at the saturated maximum. The
candidate's is empty — nothing failing. `charter_not_regressed` passed.

Separately, scored outside the rig: the live run reached **charter SATISFIED** at
115 windows with `m3_no_clipping` at **0.000**, the first time m3 has passed.

## Two measures could not report

`recurrence_sweep` is NOT WIRED in both arms, and `sonic_variety` returned NO
AUDIO for the candidate because the arm-audio selector requires a segment
*starting* inside the arm and the run was still young. Both hold promotion power,
so both veto. A bundle that omits a measure looks exactly like one that ran it
and found nothing, which is why they veto rather than abstain.

## Standing

The fix is confirmed by the charter and by 200+ windows with every fault channel
at zero. It is **not** confirmed by the rig, and those are different claims. The
rig blocked, correctly, and the blocking reasons are mostly about how I ran the
comparison rather than about the change itself.

A clean re-run needs: no restarts, ~245 windows, and enough elapsed time for a
segment to open and close inside the arm.
