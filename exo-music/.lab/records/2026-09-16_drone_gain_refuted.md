# The gain-staging explanation is wrong. Two refutations, both mine.

**16 Sept 2026, 12:40.** Shadow test for task #104, plus a control I should have
run before writing the earlier record.

## What I claimed this morning

That `dronePlayer`'s envelope lifetime exceeds its event interval, so voices pile
up — up to ~10 concurrent, adding near-coherently in a narrow low band to ~4×
full scale — and that this, plus the other layers, reached the 8.0 clip bound.

I wrote it up with a table and filed task #104 to divide `body` by the overlap
factor. Then I tested it, because it was going to change the factory's level.

## Refutation 1: the offline render

`workdir_music/tools/test_drone_gain.scd`. Three arms, NRT, same buffers,
`\playback` copied verbatim from `live_factory.scd:1637` so the arms differ in
gain staging and nothing else. Parameters set to the worst corner my own
arithmetic identified: `dur = 3.0` (shortest, worst overlap), `body = 0.39`
(ceiling), `dark = 90` (the band where addition should be most coherent).

| arm | what | peak | RMS | dBFS | %>0.99 |
|---|---|---|---|---|---|
| A | current | **0.487** | 0.0415 | −27.6 | 0.0000 |
| B | overlap-normalised | 0.185 | 0.0202 | −33.9 | 0.0000 |
| C | B + per-layer limiter | 0.197 | 0.0205 | −33.8 | 0.0000 |

**Arm A is the current code at the corner that was supposed to break it, and it
peaks at 0.487.** It does not blow up. The coherent-addition assumption behind
the 4.09 figure is wrong: the voices use different buffers, rates and pans, and
the BPF attenuates the broadband grain material, so they add incoherently.

Arm B would have cost **6.3 dB of level** to fix a fault it does not fix. Run 40
raised `dr` ×3 precisely because it measured −54.7 dBFS and was inaudible; B
would have handed most of that back for nothing.

*Caveat on the test itself:* the arms drew `rrand` without a fixed seed, so event
counts differ (90 / 84 / 89 over 60 s). That is sloppy and it would matter for a
close comparison. It does not matter here, because the result is not close —
arm A never approaches the bound.

## Refutation 2: the live data, which was there all along

The `VOICES` line records macro, mid and micro voice counts per window. I never
looked at it against the BLOWUP windows before proposing the mechanism.

| layer | BLOWUP windows | all other windows |
|---|---|---|
| macro | mean **1.11**, max 3 | mean **2.01**, max 8 |
| mid | mean 2.00, max 4 | mean 2.23, max 8 |
| micro | mean 0.89, max 1 | mean 0.72, max 2 |

Blow-ups happen when there are **fewer** macro voices sounding, not more.
Window 262 blew up with **macro = 0**. Windows 337 and 338 ran macro = 8, the
run's maximum, and did not blow up.

Polyphony accumulation is not the mechanism. It is close to the opposite of the
mechanism.

## What this leaves

A **single** voice is producing an excursion past 8.0. One `\playback` synth
with `amp ≤ 0.39` reading a buffer bounded at 0.999 should not exceed ~0.39, so
there is roughly 20× of gain appearing inside the synth. The only gain element in
`\playback` is `BPF.ar(sig, cutoff, rq.clip(0.5, 2.5))`, and `cutoff` is the one
parameter in that line **not** clipped.

That is the next thing to instrument, and it should be instrumented rather than
reasoned about, which is the lesson of the two refutations above.

## A caveat on the earlier record that I have to enter

`2026-09-16_blowup_named.md` reports `macro=dr | mid=pu` on 186 of 186 events and
treats it as a localisation. **There is no base rate for that pair.** The BLOWUP
line is the only per-window record of slot machines in this log, so nothing says
how often `dr | pu` occurs anyway. If it is the factory's ordinary state, 186 of
186 means nothing.

Window 262 makes this concrete: it is labelled `macro=dr` while `VOICES` records
zero macro voices. The label is the slot's **assigned** machine, not a sounding
voice. So the field may not mean what the record assumed.

Instrumenting the slot machines on every window, not only on blow-ups, is the
fix for that and is worth doing regardless.

## Status of #104

**Not shipped.** Reverted to pending, rewritten to record that the mechanism it
names is refuted. The shadow test is kept — it is what stopped a 6.3 dB
regression going live on a hypothesis that two independent checks then killed.
