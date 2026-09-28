# B8: machines that are new in kind

**22 September 2026.** Design note before code. The composed writer (B5)
lets the factory author any *arrangement* the originals' idiom allows:
rhythm, rate, filter, articulation, routing, layering, from the originals'
own fragments or the grammar. What it cannot author is a new *sound*: every
machine ends in one of three SynthDefs the architect wrote (`\playback`,
`\playbackHP`, `\playgran`), and the signal path inside them is fixed. A
factory that can only rearrange is bounded by its instrument set the way
the writer was bounded by its template until 5 Sept.

## Three rungs, in order of how much is ceded

**Rung 1, a DSP slot on the existing instruments (built today).**
`\playgran` already carries three processing stages, each defaulting to
dry: `res` (a Ringz body at `resfz`, decay `resrt`), `dly` (a comb at
`dlyt` with feedback `dlyfb`), `blur` (a lowpass on the envelope at
`blurhz`). They were measured safe on 4–6 Sept (Ringz at an effective
0.024, feedback clipped at 0.85, every stage mixed against dry so no
setting is silent). Until now only the macro overlay set them, per voice,
from the policy's `dsp_*` depths. Rung 1 gives the same stages to
`\playback` and `\playbackHP`, and gives the grammar a `dsp` slot: with
probability `dsp_slot_weight`, a written machine sets its own stage
depths, resonance, delay time and blur, bounded (res ≤ 0.5, dly ≤ 0.5,
blur ≤ 0.8, feedback ≤ 0.75), else it is dry as before. A machine can now
be a ringing thing, a comb, a smear, or a grain player, and which is the
factory's. The gate sees it: `\res,` `\dly,` `\blur,` join the shape names.

What this is: the originals' processing vocabulary handed over, like the
fragments. What it is not: a new UGen graph.

**Rung 2, a grammar over a bounded UGen graph.** A `SynthGrammar`: source
(PlayBuf or GrainBuf on the machine's buffer) → one to three stages drawn
from a fixed set (BPF/HPF/LPF/RLPF, Ringz, CombL, FreqShift, Decimator,
PitchShift, a soft clip) with bounded parameters → the shared envelope →
Pan2 → Out. The writer emits a SynthDef source alongside the machine,
compiles it in the language, adds it to the server while it runs (as
machines are loaded now), and the machine's `\instrument` names it. Guards:
a UGen-count cap, every parameter clipped at the UGen, a dry-mix floor of
0.3 so no graph is silent, Limiter inside the def, and the same
sandbox-stream test the composer test runs, plus a short NRT render
checked for peak and for silence before the def is admitted. The deviation
gate gains a signature over the graph (which stages, in what order).

**Rung 3, ceded.** The set of stages rung 2 draws from becomes a list the
factory may propose additions to through `charter_proposals.jsonl`, with
the architect adopting or refusing as with metrics. Until then the stage
set is the architect's, stated as such.

## Why not go to rung 2 first

Because rung 1 tests the thing that decides whether rung 2 is worth
building: whether machine-authored processing survives selection, the ear
and the level bounds when it arrives per machine instead of per overlay.
If rung 1 machines are refused by the gate, never selected, or vetoed by
the ear, rung 2 would be a larger version of the same result.

## What would show rung 1 worked

Composed machines with a `dsp` slot are written, selected, audible
(`audibility.json` above 0.5), pass the master bound, and are heard by
Roberto as a different kind of thing from the dry ones. The audition tool
renders them offline for that. What would retire it: master peaks rising
with `dsp` share, or the ear finding the stages a colour rather than a
kind.

## Class 3

The stages and their bounds are the architect's constraints; which
machine gets which stage at what depth is the factory's means. Rung 3 is
where the constraint itself becomes negotiable, and it is the only rung
that moves the paradigm; rungs 1 and 2 widen the world the factory is cast
into.

## The ear's verdict, 22 September, 13:40

Four offline renders (`tools/audition.sh`), same grains, same returns:

| | machine | Roberto |
|---|---|---|
| 1 | composed, `\playback`, `cr`'s filter and routing, grammar rhythm | "sounds like 3 & 4 with reverb" |
| 2 | composed, `\playgran`, `gp`'s duration, filter, envelope, two layers | "sustained notes" |
| 3, 4 | grammar-only dry `\playback` machines of 20–21 Sept | the reference |

**Arrangement and processing are colour; the source is kind.** The one
axis on which 2 differs from 1, 3 and 4 is the SynthDef. Routing, fragments,
layers and (by extension) rung 1's stages change how a grain player sounds;
they do not make it something else. The writer already lets the factory
choose between the two sources above 0.09 s (a coin, since 5 Sept), so the
factory has two kinds and that is the whole of its choice.

Consequences:

- Rung 1 stays built (cheap, and the gate can now see stages), but its
  hypothesis is expected to fail on "kind" and is not the path.
- Rung 2 is the path, and it is promoted to the next build after the
  coupling run: the factory must be able to author a **source**, not only
  what happens after one.

## Rung 2, sharpened

A `SynthGrammar` that emits a SynthDef source per machine, compiled in the
language and added to the running server the way machines are loaded now,
and a machine whose `\instrument` names it.

Sources (one per machine, drawn): PlayBuf on the grain (today's grain
player); GrainBuf cloud (today's playgran); **Warp1** time-stretch of the
grain at a drawn rate (a held, smeared version of the material);
**PitchShift** on a looped grain (the material at a chosen interval, held);
**a resonator bank excited by the grain** (DynKlank on the grain's onset:
the grain becomes an impulse into a body); **a wavetable read from the
grain** (Osc on the buffer at a pitch: the grain as a waveform, a tone).
Each is a different relation to the material, which is what "kind" has
meant for the whole project.

After the source: zero to two of the existing stages (BPF/HPF/LPF, Ringz,
CombL, blur), the shared envelope, Pan2, Out. Guards: parameters clipped at
the UGen; a dry-mix floor of 0.3; a Limiter inside the def; a UGen-count
cap; the same sandbox stream test as machines; and a short NRT render
(`audition_machine.scd` already does this) checked for peak and for
silence before the def is admitted. The deviation gate gains a signature
over the source and stage list, so two machines on different sources are
different by construction and two on the same source still have to
separate in duration and shape.

What is the architect's: the six sources and their bounds. What is the
factory's: which source, at what parameters, in which machine. Rung 3 is
where the list of sources becomes proposable.

## Rung 2, built 24 September (offline, during the coupling run)

`lib/SynthGrammar.sc`. A machine written with probability
`synth_slot_weight` (policy, default 0, absent until the boot after the
coupling run) carries its own `SynthDef(\sg_<name>, ..).add;` at the top of
its file, ahead of the machine function, so `path.load` in the factory
registers the def on the running server the way every machine is loaded,
and the Pbind's `\instrument` names it. The def's arguments are
`\playback`'s, so a composed Pbind drives it unchanged. Source, one of six,
drawn; then zero to two stages from {hpf, lpf, ringz, combl, freqshift,
softclip}, each mixed against dry at a wet share of 0.3–0.7; then the
machine's BPF at its cutoff slot, LeakDC, a Limiter at 0.9, the shared
envelope, Pan2, Out. Every constant clipped at emission and again at the
UGen; UGen count capped at 48 (9–12 in practice); only CombL (0.5 s) and
PitchShift (window ≤ 0.25 s) take real-time memory, at most one each.

Sources and their idiom in the def: `playbuf` (today's grain player);
`grainbuf` (a mono cloud at its own grain rate, drawn from the machine's
event rate); `warp1` (the grain time-stretched 2–24×, the pointer crossing
the buffer once per pass); `pitchshift` (the grain looped at its own speed,
shifted to the machine's rate); `klank` (the grain cut to an onset of
5–80 ms into 3–6 resonators at the machine's centre, harmonic or stretched,
rings 0.2–2.5 s); `wavetable` (one period's worth of the grain read as a
loop at 40–800 Hz × rate, the slice drifting so the tone changes colour).
`grainbuf`, `warp1` and `wavetable` are held sources: the writer gives them
the cloud envelope and the cloud player's fragment pool. `klank` is not: its
exciter is the onset, and the def floors its release at its longest ring
(the first renders of klank were silent because the composition's attack
outlasted the ring).

Gate: the instrument recorded for a rung 2 machine is `sg_<source>`, so two
machines on different sources are different by construction and two on the
same source still have to separate in duration and shape; the shape names
gained the source and stage UGens.

Admission: a rung 2 machine is written to `mutable/pending/`, not
`machines/`. The factory (ACQUIRED block) runs `tools/check_machine.sh` in
the background (`unixCmd`, a second sclang, never the live server): a 30 s
NRT render through the audition chain (24 fixed grains, the three returns,
master gain 4), refused if peak > 0.95, RMS < −50 dBFS, or fewer than 20% of
100 ms frames above −60 dBFS. Pass: moved into `machines/`, `ADMITTED
win,name,peak,rms,active`, reload, `FAMILY_ADMIT`. Fail: moved to
`mutable/refused/` with the reason beside it, `REFUSED_RENDER`, the spec
forgotten so selection never sees a name with no file. `PENDING win,name`
is logged when the check starts.

Source gain, balanced against `playbuf` on `tools/sg_gain_diag.scd` (one
def per source, no stages, fixed parameters, eight events; peak / RMS):
before, playbuf 0.156 / 0.0138, grainbuf 0.073 / 0.0035, warp1 0.069 /
0.0056, pitchshift 0.072 / 0.0069, klank 0.165 / 0.0128, wavetable 0.031 /
0.0053. Scalings set at grainbuf 1.6, warp1 0.8, pitchshift 2.0, wavetable
1.5 (klank 0.12 unchanged).

`tools/test_synth_grammar.scd`, 120 machines at `synth_slot_weight` 1.0:
78 rung 2 (the other 42 are under 0.09 s and stay on playbackHP by design),
sources grainbuf 17, warp1 19, playbuf 12, klank 12, wavetable 11,
pitchshift 7; all compile, all register their def, all stream safely for 60
events; the live gate would admit 94 of 120. Two renders per source through
the admission check: 10 of 12 admitted, every source represented; the two
refused were silent compositions (amp from `te` with `me`'s envelope on a
playbuf; amp from `gp` on a wavetable), which is the check doing what it is
for. Before the gain balance it was 8 of 12 with both klank renders silent.
`test_suffix_reaches_consumers` 25/25 and `test_composer` unchanged with
the new writer at `synth_slot_weight` 0.

Not yet done: heard by Roberto (the 12 sandbox renders are under
`/tmp/synthgrammar_sandbox/renders/`, one per source is enough); deployed
(the boot after the coupling run, with `synth_slot_weight` 0.5 in
policy.json and a day-one record like the composed writer's). The admission
check applies only to rung 2 machines, which makes their gate stricter than
rung 0/1's; the refusal rate is logged so that asymmetry can be measured.
