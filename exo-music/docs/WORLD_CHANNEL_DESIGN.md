# The world channel

*Drafted 4 Sept 2026. The transport and the source are built; the consumption
rule is specified and NOT enabled, because it is the one decision here that
changes what the factory sounds like.*

## Why this is the only input worth adding

Everything the factory currently reacts to is something the factory produced.
The corpus is fixed and I chose it; the descriptors are computed from its own
output; the operator's memory is its own transition history; self-ingestion eats
its own grains. The measurements reflect that. `novelty.py` reports micro
exploration at z = −4.49 against an undirected walk, `sonic_variety.py` reports
the delivered stream occupying 3.38 of the 4.79 spectral dimensions its own
corpus spans, and the target walk is isotropic in all six coordinates.

There is a criticism of this project that none of those numbers can answer: that
the whole system is a closed loop dressed as an open one, and that any structure
heard in it was put there by the corpus and the architect. The world channel is
the only proposed component that could falsify it, because it is the only signal
whose statistics I do not control.

`OSCdef(\world)` has existed since 25 Aug. `world`, `worldAt` and `worldN` are
declared. Nothing has ever sent to the port, and nothing reads the variables.

## What arrives

`world_sim.py` sends `/world f f f f f f` at 1 Hz to sclang's language port.

Six channels, matching the six descriptor coordinates, so the mapping is
positional and explicit. Nothing learns the mapping; a learned mapping would let
the coupling be attributed to the learner instead of to the world.

### The statistics are chosen to be UNLIKE the factory's own walk

This is the load-bearing design decision. If the world signal looked like the
target walk, no measurement could tell whether the factory was following it or
simply doing what it already does, and the experiment would be unfalsifiable
from the start. The walk is bounded, reflecting, isotropic and effectively
memoryless. So the world is given three properties it lacks:

| property | the factory's walk | the world signal |
|---|---|---|
| spectrum | white, step-to-step independent | **1/f**, long-range correlated |
| stationarity | stationary by construction | **drifting** means over hours |
| continuity | continuous, bounded step | **jump events**, rare and large |

A trajectory that acquires 1/f structure, or that shows a discontinuity within
seconds of a world jump, is showing the world's fingerprint and not its own. A
trajectory that does neither is not coupled, whatever the weight says.

### Synthetic first, real later, and the reason is not convenience

A real feed (seismic, weather, an exchange) makes the eventual claim stronger and
makes the experiment untestable in the short term, because its events arrive when
they arrive. The simulator produces jump events on demand, so the coupling
measurement can be run against a known ground truth before anything depends on
it. `world_sim.py --source real:<feed>` is the intended second step and the wire
format does not change between them.

## How it would reach the sound

**Not enabled.** `world_weight` defaults to 0.0 and at 0 the factory is
bit-identical to today.

The proposed rule is an additive displacement of the target, applied after the
walk's own step and before the neighbourhood lookup:

```
target[j] = (target[j] + world_weight * (world[j] - 0.5) * 2).clip(0, 1)
```

Three candidates were considered and this is the weakest of them, deliberately:

1. **Additive displacement of the target** (proposed). The null is exactly
   today's behaviour, the effect size is one number, and the coupling is
   measurable as a lagged correlation between `world[j]` and `target[j]`.
2. **Biasing the walk's step direction.** Subtler and harder to null, because
   the bias interacts with the reflecting boundary in a way that changes the
   stationary distribution even at small weights.
3. **Modulating policy values** (voice count, rest probability). Rejected: it
   would put an exogenous signal in control of governance quantities the factory
   is supposed to be proposing for itself, which confuses two arguments.

### This is the fifth convergence engine and must be treated as one

Four self-generated criteria in this project have become convergence engines: E3,
the audibility score, the transfer operator, and the coverage proposer. Each was
installed at full strength and measured afterwards. A smooth exogenous signal
with a large weight is the same failure with a new name — the factory would
follow the world and lose its own dynamics, and the result would sound more
coherent while being less alive.

So the deployment is bounded before it starts:

- `world_weight` clipped to [0, 0.25]. Above that the world moves the target
  further per second than the walk does, and the factory is being driven.
- **Staleness cut-off.** If `Main.elapsedTime - worldAt > 5`, the displacement
  is zero. A dead sender must not freeze the target at its last value, which
  would be a silent failure of exactly the kind this project keeps producing.
- The factory's own variability is a **release criterion**, not an observation:
  if per-minute CV of median run length drops below the 3.47 measured on 3 Sept,
  the weight comes back down.

## What gets measured, and the pre-registered result

Written before the run, so the criterion cannot drift:

1. **Lagged cross-correlation** between each `world[j]` and `target[j]`, at lags
   0–60 s. **With `world_weight = 0` this must be null**, and that negative
   control is run first. A non-null result at weight 0 means the measurement is
   broken and nothing after it counts.
2. **Jump response.** Time from an injected world discontinuity to a
   corresponding discontinuity in the target, and whether one appears in the
   delivered audio at all. This is the one that decides whether the channel
   reaches the listener or stops at the log.
3. **1/f acquisition.** Spectral slope of the target trajectory, weight 0 versus
   weight > 0. The walk is white, so any negative slope that appears is imported.
4. **Variability retained**, as above.

## What this would license us to say

With the negative control passing and a measurable jump response: *an exogenous
signal reaches the audio*, and the factory is coupled to something outside its
own corpus. That is a modest claim and it is one no current measurement in this
project can make.

It would NOT license "the factory listens to the world", and it would not make
the output about the world. The signal displaces where in a fixed corpus the
factory draws from. Saying more than that would be the vocabulary-count
overclaim of August, in a new dimension.

## Status

- `tools/world_sim.py` — the source. Built, and its statistics verified against
  the claims above rather than assumed: spectral slope **−1.01** against a white
  control's +0.00, lag-60 autocorrelation **+0.366** against −0.021, a 0.35 kick
  producing a +0.317 step, and the output bounded in [0, 1].
- `OSCdef(\world)` — the receiver. **Verified end to end on the live factory**,
  4 Sept: 25 packets sent to LANGPORT 57120, `worldN` climbing 8 → 17 → 25 with
  staleness at 0.45 s while sending and 174 s after it stopped. The August
  failure was the port, not the design.
- The `WORLD` log line already existed at line 2540 and logs the world vector,
  the packet count, the staleness AND the target beside it — which is exactly
  the raw material the cross-correlation test needs. I nearly added a second,
  worse one, having missed it with a case-sensitive grep. Recorded because it is
  the same failure as everything else on this list: the work existed and the
  wiring or the knowledge of it did not.
- consumption in the walk — **specified above, not written.** Roberto's call,
  since it decides what the factory sounds like, and by his own framework
  choosing how strongly an exogenous signal moves the objective is a Class 2
  decision that should not be made by whoever happens to be editing the file.

### To run the acceptance test

```
# 1. the negative control FIRST, with world_weight still 0
python3 tools/world_sim.py --port <LANGPORT from the factory> \
        --jump-every 300 --log /tmp/world_sent.csv
# 2. let it run an hour, then cross-correlate WORLD's w_t against its target
#    under a circular-shift null. This MUST come back null.
```

A non-null result at weight 0 means the measurement is broken and nothing after
it counts.
