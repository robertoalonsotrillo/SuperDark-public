# The composed writer, day one

**23 September 2026, 13:30.** Run `live_260922_123225`, booted 22 Sept 12:32
after the repository cleanup, 8,337 windows (24.9 h) at scoring time. What
went live at that boot: the three reverb returns, reversed grains, and the
writer composing each slot from the originals' fragments or the grammar,
with routing, articulation and 1–3 layers (commits 303f77b, 74728a0).
Scored by hand (the scheduled check did not start); same tools.

## Integrity and stream

No CLOCKJUMP, no FILL_STALL. 8 BLOWUP windows, all caught by the master
bound: MASTER peak median 0.048, p99 0.417, max 4.449 pre-limiter; 6
windows of 8,337 with a clip flag (0.07%). `m3_no_clipping` 0.000, pass.
The returns did not raise the delivered level in any way the bound saw.
Stream 200 throughout; one tunnel outage of about 50 minutes overnight
(encoder respawned 751 times until it returned), and two `autossh`
instances found running side by side, to be reduced to one at the next
boot.

## What the factory wrote

8 machines in 1,043 attempts (0.8%); refusals almost all "within
minShapeDeviation 0.5 of an existing playbackHP machine" (1,021), which is
the micro layer's crowded neighbourhood. Sandbox prediction was 75–99%
admission; live, the writer aims at the starved layer and the starved layer
is the crowded one. The rate is a property of the gate's target, and it is
the same rate as before the composer (2 in 183 windows on 21 Sept), so the
composer did not open the gate, it changed what passes through it.

Composition across the 8: dur 5 fragment / 3 grammar; rate 2 / 6; cutoff
3 / 5; pan 3 / 5; amp 1 / 7; out 4 / 4; env 3 / 5. Layers: four at 1,
four at 2. Originals drawn from: gp 5, cr 4, te 2, an 2, dr 2, hp, gl, pu.

## Were they heard

Every one of the 8 was selected, 17 to 144 slot picks each (the earliest
three: 137, 144, 141). `audibility.json` has no entry for any of them: the
learned score is keyed by the machine names selection sees, and these are
in the log as picked, so the audibility writer is not seeing written
machines. That is the seventeenth built-and-inert instance and it is
recorded here; it was also true of every machine written since 5 Sept.

`m4_vocabulary_breadth` 33 for the run (24 for the whole ten-arm run of
19–20 Sept): the first movement of that measure since the attractor was
characterised.

## The new drift floor

Halves by window (4,168 / 4,169):

| | first half | second half | Δ |
|---|---|---|---|
| m8 (Hz) | 1613.6 | 1658.5 | 45 |
| d2_turnover | 0.638 | 0.635 | 0.003 |
| m4 | 31 | 34.5 | 3.5 |

Against the dry factory's within-arm drift of 170 Hz / 0.035, this factory
is steadier by a factor of 4–10 over a run three times longer. No verdict
is attached to that; it is the floor the coupling run's arms are measured
against. Operator mixed on all but 1 window; 48 cells (27 on 20 Sept).

## What is not claimed

That the composed machines sound different in kind: the ear said on 22
Sept that they do not, that the source is what makes kind, and rung 2 is
the response. That 8 per day is the right rate. That the audibility gap
affects selection today: with B7 not yet booted, written machines sit at a
flat 5 whatever their audibility.

## Next

Boot with `layer_coupling` (−1, no change), B7 (inherited weights), rung 1
(per-machine stages), one autossh. Then the coupling run. Fix the
audibility writer's keying for written machines at the same boot.
