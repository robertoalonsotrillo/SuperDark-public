# One factory consumes the other: pre-registration

**20 September 2026, written before any data.** Class 3 target 3, shelved on
15 Sept, reinstated by the five-knob result of 20 Sept as the nearest available
external signal. This document fixes the protocol and the decision rule. What
it does not fix is when the run starts: Factory 1 is offline at the time of
writing (`/replica.mp3` 404, `state-replica.json` last written 19 Sept
20:32, log `live_260917_203355.log`). The replica is on the other computer
and only Roberto can bring it back.

## The claim under test

That Factory 2's output follows Factory 1's output when Factory 1 is fed to
it through the world channel at `world_pull` 0.15, and does not when
`world_pull` is 0. The paper's criticism this answers: that the system is a
closed loop dressed as an open one. The other factory is the one signal
available whose statistics this factory does not generate. It is not the
world (it shares the corpus, the code and the architect), and that is
recorded as the limit of what this run can show.

## The transport, verified today

`world_listen.py --url` decodes a relay mount with ffmpeg, resamples to the
corpus rate, and embeds each second through the same `mfcc_stats` and the
same stored PCA as `analyse_mfcc.py`. Tested against Factory 2's own mount:
97 frames in 45 s, coordinates inside the corpus's 0..1 box. Two defects
found and fixed on the way: the listener asserted 22050 Hz against corpora
that have been 44100 since 26 Aug (unrunnable for 25 days; nothing ran it),
and it had no way to take a stream. The factory side (`OSCdef(\world)`,
`world_pull` at the target update, `WORLD` log line) was built 4 Sept and
has never received a packet.

## Design

Two listeners on this machine, both writing 1 Hz rows in the same space:

| listener | source | sends | logs |
|---|---|---|---|
| world | Factory 1's mount `/replica.mp3` | `/world` to sclang | `renders/world/world.csv` |
| self | Factory 2's mount `/superdark.mp3` | nothing | `renders/world/self.csv` |

Two arms, in this order, on the running factory, no restart between them:

1. **Control**, `world_pull` 0.0 (the current value). Both listeners up. The
   factory logs the world on every `WORLD` line and is not steered by it.
   Duration 300 windows.
2. **Treatment**, `world_pull` 0.15, set through `set_policy.py` so the change
   is on the record. Duration 300 windows.

Then back to 0.0. `world_pull` is the only key that changes.

## The statistic and the null

`tools/world_coupling.py`. Per axis, the maximum |r| over lags 0..60 s
(world leading) between the world series and the self series, averaged over
the five axes. Null: 500 circular shifts of the self series by an offset
drawn uniformly from [120, n−120] s, which preserves both series' marginals
and autocorrelations and destroys only their alignment. Seconds where either
side is below rms 1e-4 are dropped. Calibrated today on synthetic AR(1)
series: a pair coupled at 0.5 with 8 s lag beats the null (p = 0.000); an
independent pair does not (p = 0.74).

The 60 s lag window covers the relay's latency (seconds) plus a window
(10–20 s). It also means the statistic is not sensitive to coupling slower
than a minute, which is a limit and not a choice.

## Decision rule

Both must hold:

- treatment: observed mean |r| > 95th percentile of the null
- control: observed mean |r| ≤ 95th percentile of the null

Treatment alone can be explained by structure the relay imposes on both
mounts (buffering, reconnects, shared silence). Control alone is a null
result. If both arms beat the null, the coupling is in the transport and the
test says nothing about the factory; if neither does, `world_pull` 0.15 is
below detection at 300 windows and the next arm is 0.3, pre-registered here
as the one permitted follow-up.

## What is not claimed in advance

That coupling, if found, is musical. The statistic is spectral position in
a five-dimensional corpus space; it will register the factory drifting
toward where the other one sits, and nothing about whether that drift is
audible or interesting. That is a second question and needs a listener.

## Integrity

Every window of both arms is under the ten invariants as usual. Any fault,
restart, or clock jump in either arm voids that arm. The `WORLD` line's
`worldN` counter must advance every window in both arms; a run where it
stalls (listener died, relay dropped) is void from the stall.

## To start, once Factory 1 is up

```
sh tools/factory_consumes_factory.sh start
sh tools/factory_consumes_factory.sh status            # both up, rows advancing
# ... 300 windows ...
python3 tools/set_policy.py mutable world_pull 0.15
# ... 300 windows ...
python3 tools/set_policy.py mutable world_pull 0.0
sh tools/factory_consumes_factory.sh test              # on each arm's slice
```
