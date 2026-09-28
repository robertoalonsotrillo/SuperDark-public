# Two development plans, running in parallel

**22 September 2026.** Two lines of work, each with its own origin, kept
apart so neither absorbs the other. Status is as of this date; the record of
each item is in `.lab/measurements/` under its date.

## Plan A: the programme (paused on 19 Sept for the knob run, resumed 20 Sept)

Origin: the metrics review of 18 Sept, the four-step replacement programme of
20 Sept after the five-knob result, and Roberto's silence observation of
19 Sept. Class 3 throughout: norms and constraints are the architect's, means
are the factory's.

| item | status |
|---|---|
| A1. Characterise the attractor | done 20 Sept (`2026-09-20_the_attractor.md`) |
| A2. Escape test: the three locks (suffix, spec-blind fallback, shape metric) | done 20 Sept; supply open again |
| A3. Factory 1 consumes Factory 2 (Class 3 target 3) | built and pre-registered 20 Sept (`2026-09-20_factory_consumes_factory_prereg.md`); blocked on Factory 1 being up on the other machine |
| A4. Hand the five knobs to the factory | live since 20 Sept; the 24 h decision is withdrawn (its thresholds were the dry factory's) and will be re-derived on the composed factory |
| A5. Cross-layer coupling measure, then nesting of the three timescales (#130) | measure built and run 22 Sept (`2026-09-22_layer_coupling_baseline.md`): the layers are already coupled, negatively, by the voice top-up refilling a resting layer's slot from the others. `layer_coupling` built and pre-registered 22 Sept (`2026-09-22_layer_coupling_prereg.md`), default -1; deploys at the boot after B6 closes; then A-C1-A-C2-A at 800 windows with the knob walk paused |
| A6. Kernel depth: n1_audible cannot reach three failures on a level fault (#129) | not started |
| A7. Metrics work paused 20 Sept: charter edition 8, m7 re-derivation, coverage retired | paused; resumes once the composed factory has a drift floor |
| A8. Re-score comparisons 1-3 under the corrected slice (#127) | pending |
| A9. Record the read-but-inert policy keys, fix audit_inert_mechanisms.sh (#128) | pending; the inert-mechanism count is now sixteen |
| A10. Acquisition rate under the new gate | superseded by Plan B: the gate opened to 99% on the composed writer's new axes and will tighten as composed machines accumulate; watched daily |

## Plan B: the machines (Roberto, 22 Sept: the hard-coded set steers the sonic result)

Origin: the reading of `Handler_Local.sc` against the written machines on
22 Sept. Every written machine was one dry Pbind whose five numeric slots
were grammar terms; the originals define the idiom (routing, envelope,
layering, state machines, cadence) and selection weights them by hand-set
bias and coefficients. The vocabulary could grow in number and never in
kind. And the routing was inert: all four bus variables were [0].

| item | status |
|---|---|
| B1. Real send buses and reverb returns; the originals' routing live | done 22 Sept, with the bus-2 collision fixed (74728a0) |
| B2. Reversed grains play (startPos follows the sign of rate) | done 22 Sept |
| B3. Fragments of the originals, extracted mechanically | done 22 Sept (`tools/extract_fragments.py`, 156 usable of 160) |
| B4. Grammar gains routing, envelope profile, layer count | done 22 Sept |
| B5. Writer composes per slot from fragment or grammar; composition on the ACQUIRED line | done 22 Sept, live since 12:19 |
| B6. First-day measurement of the composed writer: integrity, master level with returns, what was written and of what, whether it was heard, new drift floor | scheduled 23 Sept 13:00 |
| B7. Selection: written machines get a flat bias 5 while the originals carry hand-set bias and feature coefficients; section families damp everything outside them by 85% | built 22 Sept: a written machine inherits the mean of its endpoints' bias, coefficients and range at birth (mechanical); selection reads them. Deploys at the boot after B6. Family damping left as is; revisit with A5's proposal kind |
| B8. Machines that are new in kind | design note `B8_MACHINES_NEW_IN_KIND.md` (three rungs). Rung 1 built 22 Sept: res/dly/blur stages on \\playback and \\playbackHP, grammar `dsp` slot, dsp_slot_weight 0.5, gate sees the stages; 159/300 in test. Deploys at the boot after B6. Ear verdict 22 Sept 13:40: processing is colour, the source is kind (a composed playgran read as "sustained notes", a composed playback with cr's routing as "3 & 4 with reverb"). Rung 2 (a SynthGrammar over six sources: PlayBuf, GrainBuf, Warp1, PitchShift, DynKlank on the grain, Osc on the grain) promoted to the next build after the coupling run. **Built 24 Sept, offline, during the coupling run** (`lib/SynthGrammar.sc`, writer, factory wiring, `tools/check_machine.sh` admission render, `tools/test_synth_grammar.scd` 10/12 renders admitted, every source represented); the sixth source became a BufRd period loop instead of Osc (Osc needs wavetable format). Gated by `synth_slot_weight`, absent from policy.json until the boot after the coupling run. Renders for the ear under `/tmp/synthgrammar_sandbox/renders/` |
| B9. Fragment weight and the gate: fragment_weight 0.5 and the 0.5 shape threshold are both untested against the ear. Listen before tuning | `tools/audition.sh` renders any written machine offline (live SynthDefs, returns, grains); four renders handed to Roberto 22 Sept 13:20. Heard 22 Sept: see B8. fragment_weight and the gate untouched for now; the ear's finding was about kind, not about these |

## How the two relate

B changed the factory A measures. A4's decision and A7's edition 8 wait for
B6's drift floor. A5 (nesting) and B7 (selection) touch the same code path
(selection at the section boundary) and should be designed together, not
shipped separately. A3 is independent of B and waits on hardware.

## Standing constraints

Class 3 for every proposal. Pre-register before a number carries a claim.
Restart only with a reason; a restart voids any running 24 h window. Keep the
laptop on mains with the lid open; the FMA volume must stay mounted (renders,
corpora, segment ring live there).

## Status, 26 September 2026 (checked against the repo)

Plan A:
- A4: `knobs_to_factory` is "0" in the working policy.json and "1" in every
  commit since 20 Sept. The coupling prereg set it to 0 for the sequence and
  said "restored after"; nothing restored it. The five knobs have sat at the
  architect's values since the coupling run began. Restoring it is the
  architect's call and has not been made.
- A5: both parts scored (`2026-09-24_layer_coupling_result.md`). Rule 1 not
  met (K=0 leaves the negative coupling); rule 2 not met (K=+0.5 couples
  macro-mid only); rule 3 holds. The A arms of part 2 no longer hold both
  negative pairs: the baseline moved after 92c1d6b. Open: a fresh A-only
  baseline on 92c1d6b, then the voices_follow arm (K=0, voices_follow off)
  as A C A. `run_n_arms.sh` now closes on an A arm and settles 12 windows
  after each reload (43f8801).
- A6, A8, A9: unchanged. The inert-mechanism count reached seventeen on
  23 Sept (the audibility verdict, below).

Plan B:
- B6: done 23 Sept (`2026-09-23_composed_writer_day_one.md`): 8,337 clean
  windows, 8 machines written in 1,043 attempts, all selected, m4 33, new
  drift floor 45 Hz / 0.003 half to half. Found and fixed: audibility.json
  unwritten since 22 Aug (a shadowed `played`). Checked 26 Sept: 184
  machines in it, 157 of them written machines, so the keying works.
- B7: in `live_factory.scd` since 22 Sept; live in every boot since 23 Sept.
- B8 rung 1: first boot emptied the real-time pool (63a588c, 23 Sept); a
  second fault on 25 Sept led to 92c1d6b: dry `\playback` defs, stages only
  in `\playbackFX`/`\playbackHPFX` when drawn, polyphony bound 48, pool
  reset on the first `alloc failed`. Live, dsp_slot_weight 0.5; 0 alloc
  failures on 26 Sept.
- B8 rung 2: built 24 Sept (11ba674); inert, `synth_slot_weight` absent
  from policy.json (default 0). Rung 3 not started.
- B9: unchanged, waiting on the ear.

How they relate now: A5's next arm and B8 rung 2 both need a clean
baseline on 92c1d6b first; one A-only run serves both.

## 27 September 2026: back to building

Roberto, 27 Sept: runs had displaced development since about 20 Sept.
Order agreed: (1) B8 rung 2 on, (2) knobs back to the factory, (3) memory
that updates in performance or several factories at once. Measurement
runs in the background; nothing waits on a run.

- B8 rung 2 LIVE from boot `live_260927_102701` (10:27): synth_slot_weight
  0.3. Re-tested first on current code (after 92c1d6b): 111 written, all
  compile, all 76 rung 2 machines register their def, 12 of 12 renders
  admitted, every source represented. Two renders per source for the ear in
  `listen/rung2_260927/`. Live rate is set by the writer's acquisitions
  (about 8 a day on 23 Sept), so expect one or two rung 2 machines a day.
- Also in this boot: the K=0 allocation fix (inert at K=-1).
- 27 Sept 11:05: rung 2 re-weighted by the ear (`2026-09-27_rung2_listening.md`):
  klank 3, wavetable 3, playbuf/grainbuf/pitchshift 1, warp1 0.5;
  synth_slot_weight 0.5. Boot `live_260927_110018`.
- 27 Sept 11:08: knobs_to_factory back to 1 (A4 live again; it had been left
  at 0 by the coupling runs since about 24 Sept). Step 2 of 3 done.
- 27 Sept 11:59: step 3, memory that forgets (`2026-09-27_memory_forgets.md`):
  memory_half_life 200 on the section transition table. Boot
  `live_260927_115847`, with rung 2 (weighted, 0.5) and knobs to factory.
- 27 Sept 12:40: B8 rung 3 first half live (`2026-09-27_rung3_source_proposals.md`): the factory scores each admitted rung 2 render for n5 and proposes source weights; architect adopts with tools/decide_source_proposal.py. synth_slot_weight becomes a seventh knob at the next boot. GRF Table 1 updated (Primitive, Charter rows).
- Next: second half of rung 3 (the factory proposes NEW sources from an architect's catalogue, trialled offline through the admission render); blind listening test of the n5 proxy on the first live rung 2 machines; A3 when the second machine is up.
- 27 Sept 19:50: rung 3 second half done. Catalogue trial (pluck, formant,
  fm, freeze; 4 forced machines each) gave proposals #94 formant and #95
  pluck. Blind listening (16 codes, 2 hidden playbuf refs) agrees with the
  n5 proxy 13/16, AUC 0.83 (`2026-09-27_blind_n5_result.md`). Architect
  adopted both (charter edition 10, b83b66e); live from the next
  acquisition attempt, no reboot. Public ribbon (three layers) fixed.
- Open after 27 Sept. Plan B: first live rung 2 and catalogue machines to
  the ear; formant level (two renders at the 0.85 ceiling); rung 3 grammar
  of sources (the factory composes sources, the architect keeps the
  catalogue); B9 fragment_weight and gate. Plan A: A5 K=0 rerun (fix in
  code, unmeasured); A3 when the second machine is up; A6, A8, A9; A7
  (m7 re-derivation) now that the factory composes; A5 nesting with B7
  family damping, designed together.
