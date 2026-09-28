# The five knobs, handed to the factory: pre-registration

**20 September 2026, written before the switch is thrown.** Item 4 of the
replacement programme in `2026-09-20_five_knobs_result.md`.

## What is handed over, and why it is safe

| key | range | the two ends measured 19–20 Sept |
|---|---|---|
| `operator_weight` | [0.0, 0.35] | 0.35 (champion), 0.0 (C1) |
| `attention_weight` | [0.0, 0.15] | 0.15 (champion), 0.0 (C2) |
| `novelty_penalty` | [0.15, 0.40] | 0.15 (champion), 0.40 (C3) |
| `temperature` | [0.6, 1.0] | 1.0 (champion), 0.6 (C4) |
| `macro_bias` | [1.0, 2.5] | 2.5 (champion), 1.0 (C5) |

Ten arms, 8,530 windows, every arm gated clean on all ten invariants, no
veto, no clipping, no silence fault. Inside these ranges the factory does not
break. That is the whole of the safety argument, and it holds at the ends;
the interior is assumed to be no worse, which is an assumption and is stated
as one.

## The mechanism

At each section boundary (about every 2.2 minutes) the factory picks one of
the five uniformly and draws a fresh value uniformly inside its range. *r* > 0.
It does not evaluate the section and keep or revert the value: that would be a
fourth scalar to climb, and the three already built each narrowed the
vocabulary (`THE_REWARD_CHANNEL.md`). The harness measures, the panel
publishes, the kernel can stop.

The values live in `mutable/factory_knobs.json`, the factory's file, applied
on top of `policy.json` after every reload. `policy.json` stays the
architect's. `knobs_to_factory` "0" in `policy.json` drops the overlay on the
next window with no restart. Every move is a `KNOB win,key,old,new,section`
line in the log.

This is the Class 3 division as the paper draws it: the input to the factory
is a norm with a bound (stay inside these ranges); how to sit inside it is the
factory's means. It is not a Class 2 probe because the architect does not
specify the value, the path, or a target the path should reach.

## What this can and cannot show

The bracketed design could only have seen effects three times larger than any
present. It compared fixed points. This compares a *path*: five knobs moving
together, hundreds of times, with the factory's own state carrying from one
value to the next. If the knobs matter as a trajectory and not as levels, this
is the design that would show it. If it shows nothing, the five are inert
inside these ranges as a path too, and that closes the question at this scale.

It cannot attribute anything to one knob. That is accepted.

## Measurement and decision rule

After at least 24 h (≥ 600 moves), the run is split at its midpoint and the
two halves compared on `m8` (spectral centroid, Hz) and `d2_turnover`, the
two measures whose within-arm drift was characterised on 19–20 Sept:

| | half-to-half, 19–20 Sept, knobs fixed |
|---|---|
| `m8` | 170 Hz |
| `d2_turnover` | 0.035 |

**Rule:** the knob-walk run moves the factory beyond its own drift if
*either* half-to-half difference exceeds **twice** the fixed-knob figure
(340 Hz, or 0.070). Otherwise the five knobs are recorded as inert at these
ranges as a path, and the question is closed at this scale.

Twice, because one draw of drift (130 Hz A–A, 170 Hz within-arm) already
spans a factor of 1.3, and a rule that fires inside that band is a rule that
fires on nothing. This threshold is chosen before data and will not move.

Secondary, reported and not decided on: the per-section charter values
against the `KNOB` path, published on the panel, for the reader.

## Integrity

The run is under the ten invariants as usual. The kernel is armed. If any
invariant fails or the kernel fires, the run is void and the switch goes back
to "0" before anything else is done. `factory_knobs.json` must be written on
every `KNOB` line; a run where the log shows moves the file does not is
void.

## To start

```
python3 - <<'EOF'   # add the switch; set_policy.py refuses new keys
...
EOF
sh tools/stop_factory.sh && sh tools/start_loop.sh
grep KNOB workdir_music/renders/<log>    # one line per section
```
