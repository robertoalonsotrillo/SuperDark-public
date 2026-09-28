# What the factory asks for, and the denominator for saying so

**16 Sept 2026, 12:57.** Tasks #109 and #107, built together because neither is
useful alone.

## Why #109 is not "clip it at the writer"

The task as filed said to bound what written machines may request, in
`MachineWriter.sc`. The audit says that is the wrong fix, because the request
that broke the filter **is not in the machine layer at all**.

Every path I can read statically:

| source | ceiling | reaches 9680 Hz? |
|---|---|---|
| 174 of 176 written machines | `linlin(1200, 6000, 300, 2400)` × 1.7 = 4080 | no |
| the other two | `linlin(0, 10000, 300, 4000)` × 1.7 = 6800 | no |
| `fma1` | 2400 × (1 + travel 0.0931) = 2623 | no |
| `live_factory:4078` | `c0 × 2.2`, `macro_cut_lo` = 220, so 484 | no |
| `Handler:537` | `rrand(200v, 800v) × 6`, `v ≤ 0.7` → 3360 | no |
| `Handler:691` | `rrand(100v, 400v) × 4` → 1120 | no |

The probe measured `cutoff=9680.0` on every event, to the decimal, with
`rq=4.0` — the SynthDef's declared default, meaning the pattern set no `rq` at
all. The value is real and its source is not in the source.

Clamping harder at the writer would have hidden that a second time. A bound with
no record is why this took a day: the value that broke the filter was never
written down anywhere, so every attempt to find it was a search through code for
something that might not be in it.

So #109 is built as a **visibility channel**, not a tighter clamp. The Nyquist
clip already makes the value safe; this records that it was asked for.

```
CUTOFFREQ <win>,cutoff=,rq=,rate=,buf=,n=,<slots>,<currentMachine>
```

Fires on any `\playback` request outside [20, 8000] Hz — reporting at 8000 and
not 8820, so the margin is visible and not only the breach. Deduplicated on the
rounded value, because a voice holding an out-of-envelope cutoff for nine
seconds is one fact rather than eighteen.

## The channel corrected itself within two windows

First version also watched the low side on the grain path. It fired twelve times
in two windows, at 6, 7, 8, 9, 10 and 12 Hz: `fenv` sweeps up from near zero at
every cloud onset, so the check tripped on ordinary behaviour. A channel that
reports the ordinary buries the exceptional, which is the fault it exists to
cure. Low-side watching stays on `\playback`, where `cutoff` is a discrete
requested value and 6 Hz would be a genuine anomaly. Now reads zero.

**That is a finding in itself.** BPF was being handed centre frequencies of 6 Hz
at every cloud onset. The clip makes that 20 Hz. Before the clip it went in raw,
and a 2-pole filter at 6 Hz against 44100 Hz is ill-conditioned in the same
direction as the Nyquist end — a second latent hazard, found by accident, at the
opposite end of the range from the one that was hunted all day.

## #107, the denominator

```
SLOTS <win>,<macro>,<mid>,<micro>
```

on every window. Until now the BLOWUP line was the only per-window record of
which machine held which slot, which made every claim built on it
unfalsifiable. "macro=dr on 186 of 186 blow-ups" was reported as a localisation
earlier today; with no base rate it said nothing, and `dr` was not the diverging
voice. A field that appears only in the failure case cannot tell a cause from
the ordinary state of things.

It also records the slot's **assigned** machine, which is not a sounding voice —
window 262 carried `macro=dr` with zero macro voices live. Logging it every
window makes that difference visible instead of a trap.

## State

`live_260916_125717`, running from 12:57. Gates: compile OK (283,887 chars),
both probes build to 2625 bytes, grain path builds, control arm passes. Zero
errors, zero FILL_STALL, one ingest daemon, SLOTS writing on every window,
CUTOFFREQ at zero.

## What is still open

The requester of 9680 Hz. The channel will name it the next time it happens,
which is the point — the question moved from unanswerable to pending, and that
is the whole of what this change buys.
