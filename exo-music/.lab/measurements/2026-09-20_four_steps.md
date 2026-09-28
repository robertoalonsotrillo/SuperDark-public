# Four steps, 20 September: what was done and what it found

**20 September 2026, 16:00–17:45.** The replacement programme from
`2026-09-20_five_knobs_result.md`, run in sequence as asked. Commits
0181ab6, d9c85b6, 5df27dd, 749a77c.

## 1. The attractor, characterised

`2026-09-20_the_attractor.md`. The 27 machines the ten-arm run sounded are
the whole micro supply. Selection sat at 4.73 of 4.75 bits: a uniform walk
over everything that exists. No silent invented machines; the set could not
grow. Supply frozen since 5 Sept 18:20, operator disconnected since 15 Sept.

## 2. The escape test became three locks in series

Each fix exposed the next. All three verified by direct measurement, all
three fixed in `lib/`, 25 unit checks passing, factory restarted on the new
classes.

**Lock 1, the suffix.** `operator_sees_macro` (15 Sept) appended `@slow` to
every observed state. `TransferOperator.dominantOver` looked bare names up in
suffixed cells: zero matches, nil, the mix skipped. The operator steered
nothing through its own 18 Sept repair and through `operator_weight` → 0 in
the ten-arm run, which is why that arm moved nothing. `MachineWriter.propose`
hit the same suffix at the spec lookup: 1,107 ACQFAIL, 0 ACQUIRED.

**Lock 2, the spec-blind fallback.** With the suffix stripped: `endpoint not
in specs: fma4/te`. `findGapInLayer` had looked specs up suffixed, found
nothing, and fallen through to a layer-blind `findGap` that never checked
specs. It returned the operator's strongest hole, anchored on `fma4` (182
self-transitions), which exists as an `.scd` and has no spec anywhere, along
with `fma0–3`, `grind`, `sift`. The top eight ACQFAIL pairs of the ten-arm run
all touch one of these seven.

**Lock 3, a shape metric with no resolution.** Past the lookup: refused at
the deviation gate, same pair, same template shape twice. Measured over every
refusal logged 5–20 Sept, 2,905 candidates, 1,232 distinct grammar shapes,
against the 189 machines on record:

| metric | threshold | pass |
|---|---|---|
| set Jaccard over 8 names (what ran) | 0.5 | **0 / 2,905** |
| weighted Jaccard over counts | 0.5 | 364 / 2,905 (12.5%) |
| weighted Jaccard over counts | 0.4 | 851 / 2,905 |

Pseq, Pwhite and Pn are in nearly every machine, so the set metric had five
names to differ on. The duration route was closed too: the widest hole among
174 playback machines is 0.454 in log10 and the gate needs 0.5. The channel
had been shut since 5 Sept by its own measure, threshold never touched.
Counting occurrences at the *same* threshold reopens it. The norm is
unchanged.

**Result.** `ACQUIRED 0,brbrpucr2609040130x1ht2609201724x1`: the first
machine written since 5 Sept 18:20. Run `live_260920_172413`, 73 windows,
1 acquired, 9 refused, consistent with 12.5% per attempt at one attempt per
8 windows.

**What is not yet verified live.** That `dominantOver` now returns a vector
in the running factory. The unit test proves it on suffixed cells; the live
path is the same code; selection entropy at 73 windows (0.94 of max, against
0.91 for the same span of the old run) cannot tell. A `dom`-non-nil marker on
the `OPERATOR` line goes in at the next restart.

## 3. One factory consumes the other: built, blocked

`2026-09-20_factory_consumes_factory_prereg.md`. Factory 1 is offline
(`/replica.mp3` 404, state last written 19 Sept 20:32). Built on this side:
`world_listen.py --url` and `--log-only`, `world_coupling.py` (roadmap 2.3,
circular-shift null, calibrated), `factory_consumes_factory.sh`. Transport
verified on the live mount. Found on the way: `world_listen.py` had asserted
22050 Hz against corpora that have been 44100 since 26 Aug. Unrunnable for
25 days; nothing ran it.

## 4. The five knobs are the factory's: live

`2026-09-20_knobs_to_factory_prereg.md`. One knob moves per section, inside
the range the bracketed run showed safe; no score-and-keep; the factory's
file, not the architect's. Switched on and restarted at 17:38. First move at
window 0: `operator_weight` 0.35 → 0.2422. Decision after 24 h, rule fixed.

## Restarts today

Four (16:10 lock 1; 17:17 lock 2; 17:24 lock 3; 17:38 knobs). One boot
failed on scsynth audio init and succeeded on retry, the pattern of 19 Sept.
The live log is `live_260920_173803.log`.

## Open

- Factory 1 back, then step 3's run.
- `OPERATOR` line marker for `dom`, next restart.
- After 24 h: the knob-walk decision; the acquisition rate over a day
  (expected ~1 per 64 windows) and whether the new machines are heard
  (`m4_vocabulary_breadth` was 24 for the whole ten-arm run).
