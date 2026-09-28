# FILL_STALL is back, 15 times, and the cause is a name collision

15 September 2026, end of session. Run `live_260915_182133`, 453 windows,
15 `FILL_STALL` and 15 `UNTRACKED`. Found only because the run was inspected
before the factory was stopped; the window log, the charter and the panel all
looked healthy.

## The pattern is exact

| | |
|---|---|
| layer | **micro**, all 15 |
| machine | always a name ending `@slow` |
| `live` | always 5 |
| `nVoices` | 6, 7 or 8 |
| `UNTRACKED` | `UNTRACKED <name>@slow Nil` |

Windows 105–107, 115, 138–144, 262, 271–273. Three clusters in 453 windows.

## The cause

`policy["operator_sees_macro"]` is 1. At `live_factory.scd:2954`:

```supercollider
currentState = (currentState.asString ++ "@" ++ bucket).asSymbol;
```

This widens the **operator's** alphabet so the macro slot enters as one of four
duration buckets (`fast`, `mid`, `slow`, `rest`, `unk`). It was added on 3
September, and for the operator it is correct.

But `currentState` carries two jobs. It is an operator symbol, and it is the
**fallback machine handle** in the voice-fill loop:

```supercollider
m = m ? ( ... ? currentState);
```

After line 2954 that handle is `fma3@slow`, which is not a machine. `stateMachine`
returns Nil, `fireVoice` logs `UNTRACKED` and adds nothing to `live`, and the
fill loop cannot reach `nVoices`.

**One variable, two meanings, and the second one broke when the first was
widened.**

## Why it costs voices and not the run

This is precisely the failure of 6 September: window 1579 asked for eight
voices, a machine returned something that was not an `EventStreamPlayer`, and
the unbounded `while (live.size < nVoices)` never terminated. sclang pegged a
core at 98.7%, 42,619 `UNTRACKED` lines, sixteen minutes of −91 dB dead air.

The guard added then tests **progress** instead of the machine:

```supercollider
if (live.size == before) { wlog FILL_STALL; nVoices = live.size; };
```

So today the same fault cost fifteen voices and a log line each. The run
continued to 453 windows with `MASTER` non-zero throughout. The guard worked
exactly as designed, and it is why this is a note instead of an incident.

## The fix, not applied

Separate the two meanings. Keep an unsuffixed `currentMachine` for the machine
path and let the suffixed symbol be the operator's alone. It is a small change
and it is **not being made now**, because the factory is stopped and it could
not be run-tested before the session ended. Shipping an unverified change at the
end of a session is the thing this project's whole apparatus argues against.

`tools/syntax_check.scd` will confirm it compiles; only a live run confirms it
works.

## What this says about the instruments

Nothing measured this. The charter passed, the panel was fresh, `run_integrity`
reported clean, and the eight charter metrics were inside their bounds while the
factory was quietly failing to reach its requested voice count on 3% of windows.

`FILL_STALL` is a tripwire in `harness/release_policy.v1.json` under `no_stall`,
and that invariant reads the count for both arms of a comparison. It would have
blocked a release. It did not page anyone during a run, because nothing watches
the window log for it live. **That is the gap: `run_integrity.py` watches for
sleep, disk loss and FIFO saturation, and not for this.** Adding `FILL_STALL` to
its watch list is the obvious next move and costs a few lines.
