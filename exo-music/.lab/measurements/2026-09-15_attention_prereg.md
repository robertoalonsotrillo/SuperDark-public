# Pre-registration: attention_weight, and the first time it can do anything

15 September 2026, 21:15. Written before any arm is read. Shadow comparison #1
toward setting the release policy's margins.

## Attention has never run

`attend()` builds its recall dictionary keyed by `trace[i][\machine]`. The
caller looks those keys up in `avail`, which holds plain machine names:

```supercollider
vec = avail.collect({ |m| rec[m] ? 0 });
if (vec.sum <= 0) { brk.value };
```

With `operator_sees_macro` at 1, the trace's machine field carried the
**operator's** composite symbol. 6,570 of 8,000 entries read `sc@slow`,
`te@slow`, `brhpgl2609040130x2@slow`. `avail` never holds such a name, so every
lookup returned 0, the sum was 0, and the block took its escape on every window.

**Raising `attention_weight` before today would have changed nothing, silently.**
The honest-looking conclusion would have been "attention has no effect on the
factory", and it would have been an artefact of a name collision.

Fourth mechanism in this project found built and inert, after
`self_ingest_weight` going unread, `PatternGrammar` sitting unwired, and the
ingest daemon watching an empty directory for two and a half days. The pattern is
consistent enough to be a rule: **grep for the consumer before experimenting on a
knob.**

Fixed today, in two parts. `currentMachine` is taken before the suffix so new
entries are playable, and `tools/migrate_trace_names.py` stripped the suffix from
the 6,570 historical ones. Verified live: `ATTEND 0 fma2@76:0.002 cr@98:0.002
fma1@98:0.002`, recalling machines from runs 76 and 98. That is the first time
the mechanism has produced output.

One side finding: stripping the suffix took the trace's distinct machine names
from 48 to 27. The bug had nearly doubled the apparent vocabulary, and every
suffixed entry was `@slow` — the macro slot's duration never left that band.

## What is being tested

Whether blending recall of the factory's own past into machine selection changes
what it does, and whether it does so without collapsing the vocabulary.

This is Target 1 of the programme, in the form the amendment of today allows:
**depth, inside *c***. Self-ingestion and `memory.json` both run through paths I
wrote, so this does not escape *c*, and the claim is about whether accumulated
memory acts at all.

## Arms

| | |
|---|---|
| **champion** | `attention_weight` 0.0, `ck_260915_211222_attn-champion-aw0` |
| **candidate** | `attention_weight` 0.15, checkpointed before it starts |
| duration | 2 hours each, first 45 windows discarded as warm-up |
| everything else | identical, and `checkpoint.py diff` must show exactly one key changed |

0.15 is the first step the policy comment names, not a value chosen to succeed.
0.3 is a later arm if 0.15 survives.

## The failure mode this is watching for, named in advance

Runs 53–58 measured a self-generated criterion becoming a convergence engine:
what sounds gets weighted up, gets selected more, keeps sounding. Attention is
retrieval of the factory's own past, and **retrieval of one's own past is
imitation**. The policy comment on `attention_weight` says exactly this.

So the veto is `m5_not_converging`: `convergence2.py` terminal ratio C1, the
last-quarter M2 over the first-quarter M2, acceptable [0.75, 2.0]. If the
candidate takes m5 outside that bound while the champion is inside it, the
candidate is blocked and no other number matters.

## What counts as a win

1. **The mechanism acts.** `ATTEND` lines present, and the machine distribution
   of the candidate differs from the champion's by more than run-to-run noise.
   This is the minimum; without it the arm says nothing.
2. **No convergence.** m5 inside bounds, and `m4_vocabulary_breadth` not lower
   than the champion's.
3. **An ear win**, blinded where possible. Per Target 5 of the amended
   programme, this is a first-class reason and is recorded as an ear win, never
   dressed as a measurement.

## What would falsify the interesting version

If the candidate's machine distribution is indistinguishable from the champion's
at 0.15, then a 15% blend is too small to act and the honest report is that the
mechanism works and the weight is below threshold. That is a result about the
parameter, not about memory.

If m5 fails, the convergence prediction from runs 53–58 is confirmed at a higher
level, which is a finding worth more than a passing arm.

## Margins are UNSET, so this runs in shadow

`harness/release_policy.v1.json` records margins as UNSET and says why: a
threshold guessed now repeats the 0.9-drift mistake. So `eval_rig.sh gate` will
return `margins_unset` and promote nothing. The change ships on judgement if it
ships, and the bundle records that it did.

**This is shadow comparison #1 of the five needed** before margins can be set
from data. Running it through the rig rather than by hand is what makes it count.

## Procedure

1. champion arm, 2 h, from its sealed checkpoint — **running since 21:12**
2. checkpoint the candidate, set 0.15, 2 h
3. `eval_rig.sh run` per arm, `compare`, `gate`
4. `measure_registry.py use <measure> --change chg_260915_attention` for whatever
   adjudicates, which spends budget and is the point of the budget
5. write the result whichever way it goes

## A standing note

`attention_temperature` is 0.15 and untouched by this. Changing two things is
what made 10 September unattributable.
