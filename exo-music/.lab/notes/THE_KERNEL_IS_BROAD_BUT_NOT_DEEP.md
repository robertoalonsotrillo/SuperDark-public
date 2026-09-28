# The kernel is broad but not deep

2 Sept 2026. Written after `tools/rehearse_kernel_real.py`, which replays the real
arm logs through the real scorer and the real `decide()` with plausible faults
applied, one at a time.

## The first rehearsal proved too little

`rehearse_kernel.py` manufactured a run that was silent AND clipping AND
single-machine AND out of band. The kernel fired, citing six failures against a
tolerance of two. That established the mechanism is reachable. It established
nothing about whether the mechanism is useful, because no real failure looks
like that. This project's actual faults have been narrow and deep: a
multiplier at zero, a frozen operator, a sample-rate mismatch, a loopback device
dropping blocks. Each was one thing, wrong by a lot, for days.

## What the second rehearsal found

Real logs, real charter (edition 5, tolerance 2, never-tolerated `m3_no_clipping`).

    plausible fault             metrics failing in both      kernel
    ------------------------------------------------------------------
    as they actually ran        none                         no
    gain -6 dB                  none                         no
    gain -12 dB                 m2, m1_audible_when_driving  no
    gain -20 dB                 m2, m1_audible_when_driving  no
    vocabulary collapse to 4    m4                           no
    vocabulary collapse to 2    m4                           no
    operator frozen             none                         no
    clipping at 0.05            m3                           FIRES
    -12 dB AND vocabulary 4     m2, m4, m1_audible           FIRES

The never-tolerated clause works: one metric, fires immediately. Good.

Then I pushed the gain fault further, because −20 dB failing the same two
metrics as −12 dB was suspicious:

    fault      m1_not_silent   m2_level          m1_audible_when_driving   fires
    -----------------------------------------------------------------------------
    as it ran  21% silent      0.0395  (pass)    0.000  (pass)             no
    -12 dB     36% silent      0.0099  FAIL 2x   0.015  FAIL 1.0x          no
    -20 dB     50% silent      0.0040  FAIL 5x   0.069  FAIL 4.6x          no
    -40 dB     98% silent      0.0004  FAIL 50x  0.946  FAIL 63x           no

**At −40 dB the factory is silent in 98% of windows and the kernel does not
fire.** Vocabulary is 38.5 behaviours per hundred windows, convergence 0.948,
texture 3.0 voices, centroid 1102 Hz — every one of them passing, because none of
them measures level. The charter reports a healthy factory that cannot be heard.

## Why it does not fire

Three reasons, compounding.

> **MEASURED, 3 Sept, and the claim below was too strong.** I wrote that m2 and
> m1_audible_when_driving "are not independent: both are functions of master
> peak" and used it to explain the hole. `tools/m1_redundancy.py` over 17 runs
> says something more precise:
>
> - m1_awd is **exactly 0.0 in 10 of 17 healthy runs**, so it is near-vacuous in
>   normal operation — it measures whether the factory is broken, not what it is
>   doing.
> - Where it moves at all, corr(m2, m1) = **+0.660** over 7 runs. Correlated,
>   not deterministic.
> - Under degradation they **do separate**: at −12 dB only m2 fails. They fail
>   together only from −20 dB down.
>
> So the two are not one quantity, and the doc was wrong to say so. The
> CONSEQUENCE survives intact and is what matters: at every depth from −20 dB
> down, both fail and neither adds a third, so the count sits at exactly the
> tolerance no matter how deep the fault goes.
>
> The measurement also found the genuinely redundant pair, which is not this one:
> the OLD unconditional `m1_not_silent` tracks m2 inversely and almost
> deterministically across all 17 runs (m2 0.027→0.117 as silence 0.176→0.058).
> That is why restoring it as delivered-silence would have added a third metric
> and no third dimension, and why the restoration measures **requested**
> amplitude instead.

**1. Tolerance counts metrics, and audibility has only two failable ones.**
`n1_audible` holds four metrics. `m3_no_clipping` passes when the fault is
quietness, since a quiet signal does not clip. `m1_not_silent` was made
DESCRIPTIVE in edition 4 — it reports a fraction and cannot fail by
construction. That leaves `m2_level` and `m1_audible_when_driving`, and they are
not independent: both are functions of master peak. **One fault trips two
correlated metrics, spends the entire tolerance budget, and stops there.**

The edition-4 amendment is mine. I converted `m1_not_silent` to descriptive
because its bound was a description of past behaviour and not a criterion. That
reasoning still holds. The consequence I did not see is that it removed the only
metric that would have made a third failure available.

**2. Nothing in the charter measures depth.** A metric 2% outside its bound and a
metric 5,000% outside it are the same event to `decide()`. `m2_level` at 0.0004
against a floor of 0.02 is not a departure from a norm, it is the absence of the
thing the norm names.

**3. The descriptor metrics are level-blind by construction.** m4, m5, m6 and m8
are computed from per-event log fields that a gain change does not touch. This
is partly an artefact of the rehearsal — I scaled `MASTER` peak only. It is also
true of the real fault: the `BufRateScale` change altered delivered amplitude
while leaving centroid, vocabulary and voice count exactly as they were. The
artefact reproduces the failure mode faithfully, which is the one piece of luck
here.

## This is not hypothetical

The finding of 2 Sept is that the factory has been performing into a multiplier
at zero for an unknown number of runs while every metric reported health. That
run would have scored the way the −40 dB column scores: two failures, within
tolerance, kernel quiet. **The guard was armed through the exact failure it
exists to catch, and the rehearsal shows it would have stayed quiet.**

## What would fix it, and what each fix costs

Three candidates. None should be adopted by me; the charter is the architect's,
and every edition so far has been hand-authored for that reason.

**(a) A depth clause.** Any metric outside its bound by a factor of *k* invokes
the kernel regardless of how many metrics fail. Against the table above:

    k = 10x   fires at -40 dB, silent at -20 dB
    k =  5x   fires at -20 dB (m2 is 5.06x), silent at -12 dB

I decline to pick *k*. Picking it against a case I constructed is how a
criterion drifts, and `superdark_preregistered_targets` exists to stop exactly
that. It is a stipulation and should be recorded as one, the way
`tolerated_failing_metrics: 2` is.

**(b) Count norms, not metrics.** A norm whose failable metrics all fail in the
same direction is an identity failure, not a departure. Cleaner conceptually,
awkward here: `m3_no_clipping` sits under `n1_audible` and fails in the opposite
direction, so the rule needs a directional qualifier to be usable.

**(c) Restore a failable silence metric.** Give `m1_not_silent` a bound derived
from a null instead of from past behaviour — the objection in edition 4 was the
provenance of the bound, not the existence of the metric. This makes three
failures available under `n1_audible` and the existing tolerance does the rest.
It is the smallest change and the one that reverses my own error.

## What this does not resolve

`m1_audible_when_driving` may be near-vacuous for a reason unrelated to any of
this: `amp` is `Amplitude.kr` on the output bus, so a metric that correlates
delivered level with delivered level says nothing. It happens to move correctly
under a synthetic gain scale, which is not evidence that it moves correctly under
a real one. That check is still open and it is upstream of option (c).
