# M-A saturated and inverted. M-B says the macro layer holds one machine per span.

15 September 2026. Against
`.lab/measurements/2026-09-15_macro_measure_prereg.md`, written before the tool
existed. First measurement to go through the harness rig.

## M-A: retired on the arms, before any factory claim

| arm | spans | mean | sd | p05 | p95 |
|---|---|---|---|---|---|
| LOOP | 199 | **0.99558** | 0.00000 | 0.99558 | 0.99558 |
| DIVERSE | 199 | **0.98223** | 0.02592 | 0.92750 | 1.00427 |
| FACTORY | 199 | 0.99814 | 0.00897 | 0.98097 | 1.00461 |

Required separation: LOOP to DIVERSE, at least +3.0 pooled sd. Observed:
**−0.73 sd**. Wrong sign and an eighteenth of the required size.

A literal loop scores as *more varied* than 600 unrelated FMA clips, and the
factory as more varied than both. Everything sits between 0.982 and 0.998. The
measure has essentially no dynamic range on this material.

**Run twice.** The first calibration used a diverse arm of 15 spans and could be
dismissed as underpowered. The second used 600 clips, 199 spans, built as 30 s
excerpts so each 90 s span holds three unrelated tracks. That construction
biases DIVERSE **upward**, and it still scored below a literal loop. The
inversion is not an artefact of a thin arm.

### What the inversion actually says

Within any ninety seconds, a piece of recorded music holds a roughly stable
spectrum frame to frame. Granular noise does not. So this statistic measures
local spectral **stability**, and by that criterion the factory is highly
unstable, which is the opposite of the complaint it was built to test.

The pre-registration named this outcome in advance: "If M-A puts the factory in
the same position as the full-mix measure, then the complaint is not about
within-span spectral variation and this is the wrong instrument. That result
gets written up as a failure of the measure, not as evidence that the ear was
mistaken." That is what happened, and this is that write-up.

### The fourth one, and now a rule

Saturated spectral statistics in this project, in order:

1. the pre-centring cosine recurrence (140 unrelated artists scored *more*
   repetitive than the factory)
2. a block-shape statistic, 10 Sept (diverse 0.9993 against factory 0.9984)
3. `m7_spectral_gap_settles`, which measured the operator's age
4. **M-A**, today

Four failures with one shape. **Any statistic that reduces a spectrum to a
normalised band vector and compares frames pairwise will saturate on this
material.** Centring fixed the first one and did not save this one, because at
0.5 s resolution the factory's frames are genuinely near-orthogonal in 32 log
bands, and so are everybody's.

The next macro measure must not be from that family. The one existing
measurement that did discriminate was partial-tracking: on 78 s of the delivered
stream the dominant partial's stable runs had a median of 0.03 s and a maximum
of 0.36 s, with nothing reaching half a second. That number separates, it
matches the ear, and it is the family to go back to.

**The cost of this finding was one afternoon, because the arms ran before the
factory number was read.** Nothing was claimed from M-A and nothing needs
retracting. It is retired in `harness/measures.json` with its arms recorded.

## M-B: the macro layer holds one machine per span

From `SLOT win,layer,machine,n` on the macro layer of `live_260910_002430`,
8.1 hours:

- 256 holds over 248 spans of 90 s, so **1.03 macro machine assignments per
  span**
- hold length: median 1 window (11 s), maximum 14 windows (154 s)
- distinct machines per span: median 1, maximum 2
- **239 of 248 spans (96.4%) see exactly one macro machine**

With `voice_span_macro` at 90 s, roughly one assignment per span means one macro
voice occupying the whole span. This is the direct answer to the standing
question recorded as task 80, and it is quantified support for the complaint of
8 September.

**Two caveats, both load-bearing.** `SLOT` is written on assignment and not every
window, so this counts assignment events rather than sounding time. And M-B has
no loop arm and no diverse arm, because a slot log has no external comparison.
It enters the registry **veto-only, permanently**, alongside `score_charter`. It
can show that macro holds one source for a span. It can never be why a change
ships.

## M-C: the measurement that is now owed

The pre-registration recorded that isolation by voice count fails on ordinary
runs: macro is alone in **1.5%** of windows, longest run 33 s, against a
`MIN_SCORED` of 200. (Those figures are corrected. The first pass read `VOICES`
as `win,micro,mid,macro` when the log writes `win,macro,mid,micro`, so the
number first reported, 1.7%, was micro alone. The correction makes the case
slightly stronger.) Roberto's correction is the right one and it changes the
plan. **The method is sound. What fails is waiting for isolation to happen.**

Under `macro_bias` 2.5, `rest_micro` 0.40 and `rest_mid` 0.25, isolation is a
rare accident instead of a condition of the experiment. So produce it: set micro
and mid voice counts to zero and let the factory play macro alone for two hours.
`policy.json` hot-reloads, so this may not need a restart at all. Two hours
gives 80 clean spans with no contamination to argue about and no band-limiting
workaround.

Combined with a partial-tracking statistic instead of a band-vector one, that is
the experiment the complaint deserves. It is recorded as owed in
`harness/measures.json`.

## What this says about the harness

This is the first measurement to go through the rig, and the rig did its job in
a way the old workflow would not have.

- The pre-registration was written and sealed **before** the tool existed, so
  the falsification condition was fixed before any number appeared.
- The arms ran before the factory arm was read, so the saturation was caught at
  zero cost in claims.
- `measure_registry.py` retired M-A the moment it failed, and the retirement
  carries its numbers, so a future session cannot quietly resurrect it.
- M-B was entered veto-only rather than being allowed to look like evidence for
  a change.

Compare 6 September, when the same class of failure was found only after a
measure had already been used, and every verdict computed with it had to be
voided.
