# The blow-up, found: BPF bandwidth past Nyquist

**16 Sept 2026, 12:45.** Root cause of every numerical blow-up in this project's
recorded history, found by the voice probe on its first episode, reproduced
offline, fixed, and the fix verified before restart.

## The cause

`live_factory.scd:1757`, in `\playback`, as it has shipped:

```supercollider
sig = BPF.ar(sig, cutoff, rq.clip(0.5, 2.5));
```

`rq` is **bandwidth divided by centre frequency**. So `rq.clip(0.5, 2.5)` bounds
the *ratio* and bounds the *bandwidth* not at all. At 44100 Hz, Nyquist is 22050,
and `cutoff * 2.5` passes it whenever

> **cutoff > 8820 Hz**

above which BPF's coefficients leave the stable region and the filter diverges.
`cutoff` is the one parameter on that line that was never clipped.

## The probe caught it in thirteen minutes

```
VOICEBLOW 38,peak=3.9219e+17,cutoff=9680.0,rate=-0.8,amp=0.08,rq=4.0,buf=1934,rel=0.8
```

A voice at **amp 0.08** emitting **3.9e17**. `9680 * 2.5 = 24200`, which is
2150 Hz over Nyquist.

**WHO ASKED FOR 9680 IS STILL UNKNOWN.** An earlier version of this paragraph
named `brstgp5`, on the strength of its `centre * 1.7` line. That was the third
time in one day I read the BLOWUP/VOICEBLOW slot label as the identity of the
sounding voice, and it is wrong again. The audit:

| source | ceiling | reaches 9680? |
|---|---|---|
| `brstgp5`, `brdrcp9` | `centre ≤ 2400`, × 1.7 = **4080** | no |
| `fma1` | `centre ≤ 2400`, × (1 + travel 0.0931) = **2623** | no |
| 174 of 176 written machines | same `linlin(1200, 6000, 300, 2400)` | no |
| the other two | `linlin(0, 10000, 300, 4000)`, × 1.7 = **6800** | no |
| `live_factory:4078` | `c0 × 2.2`, and `macro_cut_lo` = 220, so **484** | no |
| `Handler:537` | `rrand(200v, 800v) × 6`, `v ≤ 0.7`, so **3360** | no |
| `Handler:691` | `rrand(100v, 400v) × 4`, so **1120** | no |

Nothing reachable by static reading requests 9680 Hz. Every VOICEBLOW line
reported that same value to the decimal, with `rq = 4.0` — which is the
SynthDef's **declared default**, meaning the pattern never set `\rq` at all.

So the divergence mechanism is established and reproduced, and the requester is
not. The two are separate questions and only one is answered. The remaining one
is what #109 is now for, and it is not answerable by reading more source: it
needs the request logged at the moment it is made, next to the machine that made
it.

## Reproduced and fixed offline

`test_bpf_bandwidth.scd`, same grain throughout, rq pinned at 2.5, arm A the
shipped line and arm B the fix:

| cutoff | bandwidth | A (current) | B (fixed) |
|---|---|---|---|
| 1000 | 2500 | 0.0608 | 0.0608 |
| 4000 | 10000 | 0.0502 | 0.0502 |
| 8000 | 20000 | 0.0513 | 0.0513 |
| 8800 | 22000 | 0.0568 | 0.0498 |
| **8900** | **22250** | **6.29e12** | 0.0498 |
| 9680 | 24200 | **1.35e18** | 0.0494 |
| 18000 | 45000 | **9.78e28** | 0.0440 |

The boundary is Nyquist exactly: 22000 is safe, 22250 diverges. Arm A's overall
peak is 1.98e29; arm B's is 0.0608. Below 8 kHz the arms agree to four decimals,
so the fix changes nothing that currently works.

1.35e18 at cutoff 9680 against the live probe's 3.9e17 at the same cutoff — same
order, different grain.

## The fix

Both BPF call sites. Line 1757:

```supercollider
sig = BPF.ar(sig, cutoff.clip(20, 18000),
             rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
```

and line 1857, the grain path, where `rq` is left at its default of 1.0 and the
cutoff is an *envelope*, so nothing constrains where it lands:

```supercollider
sig = BPF.ar(sig, fenv.clip(20, 18000));
```

20000 rather than 22050 leaves a margin, because the coefficients are already
ill-conditioned approaching Nyquist and not only beyond it.

## Why this took all day

Six explanations were proposed and refuted before the probe was built: corrupt
grains, reverb feedback, NaN propagation, polyphony accumulation, `\amp` out of
range, the DSP stage. Each was killed by evidence that was cheap to gather and
that existed before the proposal was made.

**And BPF was cleared once, wrongly.** `test_bpf_gain.scd` swept cutoff from 0 Hz
to 8 kHz at **rq 0.5**, and reported a peak gain of 0.61× — never above unity.
I chose 0.5 believing the narrowest setting was the highest-Q and so the most
dangerous. The hazard runs the other way: rq 0.5 at 8 kHz is a bandwidth of
4000 Hz, nowhere near Nyquist. I tested the safe corner thoroughly and concluded
the component was safe. The sweep also stopped at 8 kHz, 820 Hz short of the
threshold.

Two lessons, both about test design rather than about the factory:

1. A sweep that does not visit the dangerous corner is not a clearance, and
   "I tested it" is not the same claim as "I tested the case that breaks it".
2. The probe found in thirteen minutes what six hypotheses did not find in a
   day. Instrumenting the thing costs less than reasoning about the thing.

## What this retires

`2026-09-16_blowup_named.md` attributed the blow-ups to `dr` and to polyphony.
Both are wrong and that record carries its own correction. The `macro=dr` field
was the slot's *assigned* machine, and the voice actually diverging belonged to
whichever machine's cutoff trajectory had wandered above 8820 Hz — `brstgp5`
here, and on the earlier evidence not `dr` at all.

The master sanitiser (#102) stays. It bounded 1e25 to 16.0 and kept full-scale
bursts off the stream while the cause was unknown, which is exactly what a
backstop is for. It is no longer the only thing standing between a divergent
filter and the listener.

## State

Restarted 12:45 as `live_260916_124531`, checkpointed before restart. Gates
passed: compile OK with the class path (279,307 chars), the probed-and-fixed
SynthDef builds to 2183 bytes, the grain-path clip builds. One sclang, one
scsynth, one ingest daemon. `LAYERS_ACTIVE macro mid micro`.

The voice probe stays in. It earned its place, and it is now a standing detector
for any single voice that passes full scale, whatever the reason.
