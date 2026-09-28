# Six explanations eliminated. The voice probe is live.

**16 Sept 2026, 12:35.** Run `live_260916_123243`, restarted with the probe in
`\playback`.

## What has been eliminated, and by what

Each of these was a mechanism I proposed. Each was killed by evidence that was
cheap to gather, and in every case the evidence existed before the proposal.

| explanation | refuted by |
|---|---|
| corrupt grains | all 48,162 grains in every pool, live and historical, cap at **0.9990** — the `write_grain` ceiling. Includes the 32,402 on the SSD I missed on the first pass. |
| reverb feedback | `live_factory.scd:2456` sets all four reverb buses to **`[0]`**. Neither `HDVerb` nor `FreezeVerb` is in the live path. |
| NaN / inf | peaks are finite. `CheckBadValues` would substitute `DC.ar(0)` and the peak would read 0, not 16. |
| polyphony accumulation | BLOWUP windows average **1.11** macro voices against 2.01 elsewhere. One blew up at **macro = 0**. Windows 337–338 ran macro = 8 without blowing up. Offline render at the worst corner peaks **0.487**. |
| BPF gain | swept 0 Hz to 8 kHz at rq 0.5, the highest-Q setting obtainable. Peak gain **0.61×**. Never above unity, including at cutoff 0. |
| `\amp` out of range | every `\amp` across 177 written machines is `Pwhite(body*0.6, body)` with `body ≤ 0.32`, or carries an explicit `.min(0.5)`. |
| the DSP stage | `dres`, `ddly`, `dblr`, `dall` are all `.clip(0.0, 1.0)` at `live_factory.scd:3978-3981`. |

## What that leaves

A **single voice** exceeds 8.0 while every parameter feeding it is in range and
the only gain element in its path measures below unity. Those two facts cannot
both be true, so one of the measurements is wrong or something outside the list
is contributing. Guessing which has now failed six times.

## The probe

`\playback` reports its own peak and the exact parameters it was handed whenever
one voice passes full scale, and the sclang side stamps the machine that asked:

```
VOICEBLOW <win>,peak=,cutoff=,rate=,amp=,rq=,buf=,rel=,<slots>,<machine>
```

Threshold 1.0, because a single voice should never approach full scale when amp
is bounded at 0.70 across every machine. Rate-limited to one line in four and
400 total, so a voice ringing for nine seconds cannot bury the distinct events.

Gates passed before restart: `.compile` OK with the project class path loaded
(277,124 chars); `test_voice_probe.scd` builds the probed SynthDef to bytes,
with the unprobed definition as a control arm.

## One thing I got wrong in the stop

`pkill -f "MacOS/sclang"` and `caffeinate` left **scsynth orphaned holding port
57110**, because its path contains neither string. The restart then failed with
"port already in use" while `pgrep scsynth` reported nothing, since I was
matching the wrong pattern in the check too. Killed by PID and restarted clean.

The stop procedure should match `Resources/scsynth` as well. Worth fixing in
whatever script owns it, because a half-stopped factory that looks stopped is
the same class of fault as a configured-but-not-running change.

## State

One sclang, one scsynth, one caffeinate, one ingest daemon — `one_ingest_daemon`
holds. `LAYERS_ACTIVE macro mid micro`. Zero errors, zero FILL_STALL, integrity
clean since 12:32.

Previous episodes fell at windows ~169 and ~262, so the first `VOICEBLOW` should
arrive inside an hour if the pattern holds. If none arrives while `BLOWUP` does,
that is itself informative: it would mean the excursion is not inside a
`\playback` voice at all.
