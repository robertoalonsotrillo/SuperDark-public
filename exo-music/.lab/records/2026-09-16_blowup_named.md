# The numerical blow-up, named

**16 Sept 2026.** Run `live_260916_112101.log`, 235 windows, the first run with
both the master sanitiser and the BLOWUP instrumentation live.

Task #101 asked the instrumentation to name the voice. It has.

## What the instrumentation returned

109 BLOWUP events. Every one of them:

| field | value |
|---|---|
| macro machine | `dr`, on all 109 |
| windows | 169, 172, 173, 174 — one episode of about a minute |
| peak | 15.999999046326 on 107 of 109; 9.69 and 6.18 on the other two |
| recurrence | none in the 45 minutes since |

`mid=pu` on all 109; micro varies (`ry`, `sc`, `brrysc2609031456x1`), which is
what says micro is a passenger rather than a participant.

`15.999999046326` is `clip2(8.0)` on each of two channels, mixed. The sanitiser
is holding. Before it, the same instrument reported 1e18 to 1e25.

## Three hypotheses, all refuted

**Corrupt grains.** Scanned all 15,760 wav files under `workdir_music`. The live
pools — `grains_play_{ev,mid,macro}`, `grains_lic_{ev,mid,macro}` — peak at
0.9990 without exception, which is exactly the `write_grain` attenuation
ceiling. Nothing over 1.0, no NaN, no inf. The only files at 1.0 are in
`grains_clean_ev` and `grains_clipped_ev`, both historical corpora not in the
live path. Refuted.

**Reverb feedback.** `live_factory.scd:2456` sets
`~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]`.
All four are literally bus 0. Neither `HDVerb` nor `FreezeVerb` is instantiated
anywhere in the live path — the three buses `dronePlayer` writes to are aliases
for the master input. Refuted. (A real defect in `FreezeVerb` surfaced while
checking this; it is recorded below and in task #105, and it is *not* this bug.)

**NaN or inf propagation.** The peaks are finite. `CheckBadValues` would have
flagged a non-finite sample and `Select` would have substituted `DC.ar(0)`,
giving a peak of 0 rather than 16. The excursion is a large finite number.
Refuted.

## What it is

Summation, with no gain staging anywhere between the voices and the master
limiter.

`dronePlayer` sounds **three parallel layers** through `Ppar`, all into bus 0.
Each layer's synth is freed only by its envelope, so it lives
`atk.max(0.03) + rel` = `1.2 + dur`. Events arrive every `Pwhite(dur*0.4, dur)`.
Lifetime therefore exceeds interval, and voices pile up:

| dur | life | mean interval | overlap/layer | × 3 layers |
|---|---|---|---|---|
| 3.0 | 4.20 | 2.10 | 2.00 | 6.0 |
| 6.0 | 7.20 | 4.20 | 1.71 | 5.1 |
| 9.0 | 10.20 | 6.30 | 1.62 | 4.9 |

At the short tail of the `Pwhite`, `dur = 3` gives 3.5 overlapping per layer,
10.5 voices. At `body = 0.39` — the top of
`avgrms.linlin(0.0, 1.0, 0.12, 0.39)` — that is **4.09 coherent**, four times
full scale from `dr` alone.

Coherent and not √n because `\cutoff` for this machine is
`avgcent.linlin(0, 10000, 90, 700)` and its two `Pseries` keep it inside
[90, 1050] Hz. Ten voices band-limited to a narrow low register, drawn from one
shuffled pool, add close to linearly.

4.09 is not 8.0, and this is where the account stops being a single cause. `dr`
supplies the largest single contribution; the BLOWUP lines record 5 or 6 live
slots, so mid (`pu`) and micro and the remaining macro slots supply the rest.
The window 169–174 episode is the stretch where `avgrms` stayed high enough to
hold `body` near its ceiling while the `Pwhite` kept drawing short intervals.

So: no runaway. An architecture in which every voice writes to bus 0 at its own
requested amplitude, and the only thing standing between them and the output is
the master limiter.

## What this means for m3

m3 reads 0.681 on this run. Four windows out of 235 clip — 1.7%. m3 is a p99, so
it fails whenever more than 1% of windows touch clipping at all, at any severity.
This is the rate-tripwire behaviour established on 15 Sept (1.1% clipping at
0.30 → p99 0.0000 pass; 1.5% → 0.2490 fail).

**Correction, entered the same day.** An earlier draft of this paragraph read
"one minute of trouble in four hours". That was wrong and it flattered the
factory. The run began 11:21:01 and these 235 windows span **49 minutes**, about
12.5 s per window; the episode covers windows 169–174, roughly 75 seconds. So it
is one minute of trouble in **fifty**, not in four hours — a rate two orders of
magnitude worse than the sentence implied.

The measure is still a rate tripwire rather than a severity measure, and that is
still the fact the re-pricing has to price. But 1.7% of windows clipping inside
one hour is not an over-sensitive metric catching a freak event. It is close to
the 1.2% tripwire because the underlying rate is genuinely near it.

That is a fact about the measure, not an argument for widening it. It is the
input to the re-pricing decision (step 2), which is Roberto's.

## Side finding, recorded so it is not lost

`Synths_Local.sc`, `FreezeVerb`:

- line 86, `temp - LPF.ar(temp, lpf);` computes and discards. The `lpf`
  parameter does nothing and there is no damping in the chain.
- line 87, `wet = wet + temp` sums 16 unity-magnitude `AllpassN` stages with no
  normalisation. `HDVerb` does `.sum * 0.25` over its 16.
- no `LeakDC`. `HDVerb` has one at line 49. Sixteen feedback stages at
  `decay = 10` with no DC removal.
- line 78 passes `predelay` unclipped into a `DelayN` of maxdelay 0.2, while the
  declared default is 1. `HDVerb` clips its predelay at line 21.

Dormant today because the buses are all [0]. A landmine the moment reverb is
wired up. Task #105.

## Next

Task #104: divide `body` by the expected overlap so the layer sums to its
intended level rather than overlap-times it. That is a fix rather than a bound —
the sanitiser stops a blow-up reaching the stream, this stops it happening.

It changes level, so it changes `m2_level`, and it is pre-registered before it
carries any claim.
