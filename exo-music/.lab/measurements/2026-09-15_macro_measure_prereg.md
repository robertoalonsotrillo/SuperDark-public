# Pre-registration: a macro-attributable measure

15 September 2026. Written **before** the tool exists and before any number is
produced. Sealed into the rig at the same time.

## The complaint, stated so it can be wrong

Roberto, 8 September: the macro layer "just keeps producing endless sustained
drone layers, the behaviour is sonically limited." 10 September, after
spectrograms: the factory has one colour it modulates in density and level.

On 10 September the recurrence measures were run against three configurations
and preferred, **at every match window**, the configuration Roberto had called
unlistenable. The result document named the reason and the remedy:

> The measure is over 0.5 s frames of the full mix, and macro is roughly 13% of
> audible events against micro's 87%, so a macro-specific complaint is close to
> invisible in it.

and

> Isolate macro-attributable stretches using the slot log and measure that layer
> on its own terms, instead of averaging it against seven times its number of
> micro events. Until that exists, no number here can adjudicate a macro
> question.

This pre-registers that measure.

## Isolation by voice count: what ordinary runs yield

Isolate audio where macro is the **only** sounding layer, using `VOICES
win,micro,mid,macro`, and measure recurrence on those stretches.

**CORRECTED 17:25, same day.** The first version of this table read the `VOICES`
fields in the wrong order. The log writes `VOICES win,macro,mid,micro`; the
analysis assumed `win,micro,mid,macro`, so what was reported as "macro alone"
was in fact **micro alone**. Caught only because the isolation run printed
`VOICES 2,2,0,0` while `SLOT` showed macro and `MASTER` showed sound, which is
impossible under the assumed order. Corrected figures below; the originals are
kept beside them, because a table that quietly changes is worse than a wrong one.

| run | windows | macro present | macro alone | longest alone-run | (as first reported) |
|---|---|---|---|---|---|
| `live_260910_002430` (8.1 h) | 2,776 | 82.1% | **1.5%** (42) | 3 windows, ~33 s | 1.7%, ~44 s |
| `live_260915_155738` | 337 | 82.2% | **0.9%** (3) | 1 window, ~11 s | 1.2%, ~22 s |

The conclusion is unchanged and slightly stronger: less isolation, not more.

Forty-two windows across eight hours, in runs with a median of one window. The
`MIN_SCORED = 200` guard exists precisely because a 600–3600 s match window once
scored 8 frames and put the factory above a literal loop. An ordinary run yields
a twentieth of what that guard requires.

**The method is sound. What fails is waiting for isolation to occur.** Under the
current policy (`macro_bias` 2.5, `rest_micro` 0.40, `rest_mid` 0.25) macro is
almost never alone, so isolation is a rare accident instead of a condition of
the experiment. The correct response is to stop waiting and produce the
condition:

> **The isolation run (M-C).** Set micro and mid voice counts to zero in
> `policy.json` and let the factory play macro alone for two hours. `policy.json`
> hot-reloads, so this may not even need a restart. That gives genuinely
> isolated macro audio, 80 spans per hour, with no contamination to argue about
> and no band-limiting workaround.

That is the measurement the complaint actually deserves, and it is now the
primary plan. The two measures below are what can be computed **today**, from
7.9 GB of audio already on disk, without touching the running factory. M-A in
particular is an interim instrument with a stated bias, and it should be read
as one. If M-C runs and disagrees with M-A, M-C wins.

Saying this here is the point. The alternative was to build the isolation
anyway, score 46 windows, and quote the number.

## M-A: macro-band within-span variation (audio)

**What it measures.** Band-pass the delivered audio to the macro band, 220–3600
Hz (`macro_cut_lo` / `macro_cut_hi`, the only layer with filter bands). Inside
each 90 s window (`voice_span_macro`), take 0.5 s frames, log-band spectra,
centre before normalising, and compute the mean pairwise **distance** between
frames. High means the band changes within a span. Low means it does not.

**Why within-span and not across-run.** The 10 September finding was that each
macro voice was a different grain, so the run covers the corpus while a listener
inside any ninety seconds hears one unchanging tone. The complaint is local. A
measure averaged over a run cannot see it, which is what went wrong the first
time.

**The contamination, stated.** Micro and mid also put energy in 220–3600 Hz, and
they are seven times more numerous. Band-limiting therefore does **not** isolate
macro; it weights toward it. The contamination adds foreign variation, so it
biases M-A **upward**, toward finding variety. A low reading is therefore strong
evidence and a high reading is weak. That asymmetry is the reason this is worth
running at all, and any result must be reported with it.

**Calibration arms, all three, before any factory number is believed.**

- **LOOP**: one 90 s factory stretch repeated. Must score at the floor.
- **DIVERSE**: 140 unrelated FMA tracks cut into 90 s spans. Must score high.
- **FACTORY**: the arm under test.

Three spectral statistics have already saturated here. The original cosine
recurrence scored 140 unrelated artists as *more* repetitive than the factory. A
block-shape statistic built on 10 September gave the diverse arm 0.9993 against
the factory's 0.9984 and was reported unusable in the same answer that produced
it. **If LOOP and DIVERSE do not separate by at least 3x the within-arm standard
deviation, M-A is declared saturated, retired in `harness/measures.json`, and no
factory number from it is quoted.**

**Pre-registered prediction.** The complaint predicts M-A places the factory
closer to LOOP than the full-mix recurrence measure does, on the same audio.

**How this is wrong.** If M-A puts the factory in the same position as the
full-mix measure, then the complaint is not about within-span spectral variation
and this is the wrong instrument. That result gets written up as a failure of
the measure, not as evidence that the ear was mistaken.

**Minimum data.** 200 scored spans per arm, the existing `MIN_SCORED` rule. At
90 s per span that is 5 hours per arm. There are 7.9 GB of captured audio, 40
segments of 10 minutes, spanning the 10 September 8.1-hour run and today's.

## M-B: macro source-hold (log, no audio)

**What it measures.** From `SLOT win,layer,machine,n` on the macro layer: how
many windows one machine holds a macro slot, and how many distinct machines
appear inside a 90 s span. This is the direct test of the standing question
recorded as task 80, whether macro sustains one grain for 90 s in a dark band.

**What it cannot do.** There is no external arm for it. A loop and 140 FMA
tracks have no slot log. **M-B is therefore descriptive and enters
`harness/measures.json` with veto power and no promotion power, permanently**,
on the same footing as `score_charter`. It can show that macro holds one source
for a span. It can never be the reason a change ships.

## Registration

- `promotion_budget` 3, per `harness/measures.json`. M-A starts at 0 used.
- Both scorers go into `harness/sealed_scorers.txt` and are hashed before the
  first number is computed.
- Arms are run in the order LOOP, DIVERSE, FACTORY, and the first two are read
  before the third is looked at.
- If M-A survives calibration it adjudicates one change and one only in this
  cycle: `macro_full_vector` 0 against 1, two hours per arm, both arms from
  sealed checkpoints. That comparison is what 10 September said a clean
  attribution needs and could not have.

## What this does not settle

Whatever M-A says, the ear keeps aesthetic authority. The release policy records
an ear win as a first-class reason to switch and never dresses it as a
measurement. This measure exists so the instrument and the ear can be compared
at all, which on 10 September they could not be.
