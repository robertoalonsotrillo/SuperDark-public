# Programme amendment, 15 September 2026

Amends the SuperDark Class 3 programme fixed 22 August 2026 and resequenced by
Roberto on 25 August. Three changes. The Class 3 commitment, the four targets'
substance, and the standalone-entity-before-microphone sequencing are all
**unchanged**.

Written because the programme note has four epistemic targets and no aesthetic
one, while September's work has been almost entirely aesthetic. From the
document's point of view that reads as drift. It was not drift, and the reason
it was not needs to be in the record instead of in my head.

---

## Amendment 1 — add Target 5: the factory has to be worth an hour

**The gap.** Targets 1 to 4 are about memory, continuity, plurality and raising
*r*. None of them says the output should be good. Yet the work of 3 to 15
September was: the macro drone, the one-colour finding, `rq` at 2.5, section
spread, held pitch, the ingest floor, and the macro measurement programme. Every
one of those started with Roberto's ear.

**Why this belongs in the programme and is not a distraction from it.** A Class 3
factory that produces one timbre for eight hours is a weak demonstration of
Class 3. The claims in targets 1 to 4 are claims about a system that makes
music; if the music is exhausted after ninety seconds, a reader is entitled to
ask what the epistemics were for. The aesthetic constraint is a condition on the
other four landing, and it has been operating as one without being written down.

**Target 5, stated so it can fail.** *Over any hour of continuous output, the
factory should remain worth listening to, and a change that damages this does
not ship whatever the instruments say.*

Criterion, in order of authority:

1. **The ear, blinded where blinding is possible.** Paired arms from sealed
   checkpoints, presented without labels. A change ships on an ear win, and an
   ear win is recorded as an ear win and never dressed as a measurement. This is
   already the position in `harness/release_policy.v1.json`.
2. **A standing veto.** No configuration ships that Roberto has described as
   unlistenable, whatever any measure reports. On 10 September the recurrence
   measures preferred, at every match window, the configuration he had called
   sonically limited. That case is the reason this veto is written down.
3. **Instruments in support, never in place.** M-D (partial hold) if it survives
   calibration; M-B (macro source-hold) as description only. Four spectral
   statistics have now saturated here, so no instrument gets authority over the
   ear on this target.

**Why the ear ranks first, as evidence and not as courtesy.** It has been right
three times where the instruments were not: the fragmentation drift, the macro
drone, and the one-colour finding. A measure that disagrees with it has a prior
against it in this project.

---

## Amendment 2 — Target 1 does not escape *c* as currently built

**The inconsistency is internal to the programme note.** Its summary of Target 1
says memory-during-performance moves outside *c* "by construction rather than by
luck". Its own body then says the opposite, and more carefully:

> if the memory reads internal state or digitally analyses its own render, the
> derivation still terminates in inputs I provisioned. The genuinely outside-*c*
> version routes feedback **through a microphone in a room**.

Everything built since is the first kind. Self-ingestion at weight 0.75 feeds the
factory's own rendered audio back into its pool through a path I wrote.
`memory.json` persists across runs through a file I wrote. Both are inside *c*.

**What the evidence has added.** Three findings bear on this and all three point
the same way:

- **m7 was measuring the operator's age.** The operator persists across runs
  through `memory.json`, so its spectral gap decays with history. Memory has been
  acting on the factory the whole time, unmeasured, and the charter could not see
  it.
- **The judges steer nothing.** All of them are no-swap-regret learners, which is
  the failure named at ¶484/¶486.
- **`attention_weight` is 0.0.** The one mechanism that would make a machine
  query accumulated memory *at event time* is built and switched off. Its own
  policy comment says why: retrieval of one's own past is imitation, and runs
  53–58 showed a self-generated score becoming a convergence engine.

So Target 1 is currently half inert and half operating without measurement.

**The amendment.** Strike "by construction rather than by luck" from the summary
of Target 1. Replace the interim claim with one the evidence supports:

> Memory-during-performance as built is **inside *c***. What it can demonstrate
> in this form is **depth**: how many generations of self-ingestion the material
> survives before it degenerates, measured against the pre-registered target. The
> escape from *c* requires the microphone, and stays where the programme already
> put it, after a fully working prototype.

**This is a correction to a summary line, not a change of direction.** The
programme's body already said this. Nothing in the sequencing moves.

---

## Amendment 3 — fix the date the prototype yields to the proposal

On 22 August the decision was to build the prototype over drafting the GRF. That
was right then. It is now 15 September and the decision has a shelf life that is
nearly up.

**The dates, to be verified against the official call before either is trusted.**
The project note records: evidence freeze ~5 October, draft complete by 17
October, submit by 31 October. Elsewhere in the working record I have been using
16 and 30 October. **Confirm which is correct; the discrepancy is unresolved.**

**The amendment, in two steps so the transition is not a cliff:**

- **5 October is the hard stop for evidence.** After that date no new number
  enters the proposal. Prototype work may continue; its results go into the
  claim record for the next release and not into the draft. This is what makes
  the Zenodo freeze meaningful: the DOI points at the state the numbers came
  from.
- **8 October, drafting becomes the only priority.** Factory work after that
  date needs an explicit decision, not momentum.

**One consequence worth stating now.** Target 3 (several factories at once) has
not started and will not be demonstrable before the freeze. It should appear in
the proposal as programme and not as result.

---

## What this amendment does not touch

- the Class 3 commitment
- the substance of targets 1 to 4
- the 25 August sequencing: standalone entity first, capable of engaging
  something like the exoharness, playing forward until it collapses, ignited by a
  Stackelberg move; real-time sound input after a working prototype
- the standing instruction to read the programme note **before** proposing a next
  step. I reconstructed it after a day of work today, which is the wrong order
  and is the reason this amendment exists at all.

## Status against the five targets, 15 September

| | target | status |
|---|---|---|
| 1 | memory updating during performance | half built; `attention_weight` 0.0; self-ingestion live at 0.75 and inside *c* |
| 2 | continuous output via Icecast | **done**; FIFO topology, runs indefinitely |
| 3 | several factories at once | not started; programme, not result |
| 4 | frontier-of-*c* repeatability, raising *r* | *r* = 0. Nearest: the kernel fired 1 Sept, the factory proposed a charter bound, the architect adopted it |
| 5 | worth an hour | **open**, and the driver of most of September |

**Not a target, and it should not become one:** the harness built on 15
September. It is apparatus for the claim record. It earned its place by catching
a saturated measure at zero cost in claims and by forcing two corrections inside
an hour. It is infrastructure.

## The highest-value unfinished item

Against the programme as amended, it is **`attention_weight`**. Raising it in
small steps (0.15, 0.3) with `convergence2.py` scoring and an ablation arm is
the move that makes Target 1 real instead of recorded. It has a pre-registered
target on file and a known failure mode to watch for.

---

**Action required outside this repo.** The programme note lives in memory and
cannot be edited from this session. This document is authoritative for the three
amendments until that note is updated to match.
