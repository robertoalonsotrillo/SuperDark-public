# The path to a fully online factory

Written 2 Sept 2026, after the weight hypothesis was refuted and the silence was
traced to the life arc. The question: what would it take for this to be online
all the way down, and which parts of that are engineering, which are research,
and which would be mistakes.

## What "online" means here, in three axes

The paper's sense of online is "runs continuously in production, as a first-party
participant" — against offline, which is "computed beforehand against a
predefined notion of correctness". This factory is online on one axis, partly
online on a second, and offline on the third.

    MATERIAL      what the factory plays        -- OFFLINE, updated at restart
    EVALUATION    how it judges itself          -- ONLINE, but consequence-free
    GOVERNANCE    who may change its charter    -- OFFLINE, architect-gated

The three are not independent: making material online without evaluation having
consequence gives you drift with no correction, and giving evaluation consequence
without governance being online makes the architect the bottleneck on every
correction.

---

## Axis 1: MATERIAL — the largest gap

**Where it stands.** The three corpora are built offline from FMA tracks. Their
descriptors are computed offline against a **frozen PCA basis**. The play corpus
is assembled once at boot by `assemble_play_corpus.py`, mixing archive and pool
at `self_ingest_weight`. Self-ingestion writes new grains into a pool that the
running factory **never reads** — the pool only reaches the music at the next
restart. That restart IS the generation boundary.

So the loop closes across runs, not within one. A factory that "runs forever"
in the sense of k2_continuous currently cannot change what it plays at all.

**What online would require, in order:**

1. **Hot buffer swap.** Replace a grain's `Buffer` while the factory plays,
   without freeing one a `GrainBuf` is mid-read on. SuperCollider will happily
   crash or click on that. Needs double-buffering with a generation counter and
   deferred frees — a slot is retired, not freed, until no voice references it.
   This is engineering, and it is the precondition for everything else here.

2. **Continuous admission.** `self_ingest` already vets and admits by
   displacement; today the result sits in a pool. Once slots can be swapped
   live, admission can write straight into the play corpus. Generation depth
   then becomes a property of elapsed time rather than of restart count, and the
   twenty-generation target stops needing twenty restarts.

3. **The frozen basis is the hard one, and it may deserve to stay frozen.**
   Descriptors are projected through a PCA basis fixed at corpus build. It is
   what makes navigation coherent: the factory steers by coordinates, and if the
   coordinate system moves, everything it learned about where things are becomes
   wrong. We have already paid for this once — a sample-rate desync put 22050 Hz
   grains into a 44100 pool and the descriptors pointed at the wrong material.
   An online basis means the map redraws under the navigator.
   **A defensible middle: keep the basis frozen and treat it as part of the
   kernel** — the fixed frame the factory moves within. Then "online material"
   means new points in a stable space, not a new space. Making the basis itself
   online is a research question about representation drift, not a feature.

---

## Axis 2: EVALUATION — online already, but nothing follows from it

**Where it stands.** Nine judges, two tiers, all passing negative controls, all
observing continuously. `score_charter` computes the charter every publish cycle.
The kernel is armed. And **none of it touches the music**: judges steer nothing,
the kernel has never fired, metric departures change no behaviour.

That was deliberate and it was right — three self-generated criteria became
convergence engines here (E3, the audibility score, the transfer operator), and
a judge that steers what it also predicts manufactures its own evidence.

**What online-with-consequence would require:**

1. **Realized-consequence scoring must come first.** A judge earns influence by
   having been right about things that mattered, not by existing. Tier one
   already reports precision and lift; that is the beginning of a track record.

2. **Influence proportional to earned lift, and ablated.** A judge with 2.5x
   lift over base rate might bias selection *slightly*, with the weight starting
   at zero and rising only on evidence — the same discipline `operator_weight`
   and `attention_weight` were given. Every previous convergence engine was
   installed at full strength and measured afterwards.

3. **The grading signal must stay outside the loop.** The moment a judge steers
   the factory, its predictions are no longer independent of what it predicts.
   The paper's answer is recursion and requisite variety: tier two grades tier
   one on outcomes tier one did not control. That is why tier two had to exist
   before any of this is safe.

4. **The kernel should fire once, on purpose.** It has been armed since 1 Sept
   and never triggered. An armed guard that has never acted is untested. A
   deliberate, reversible scrapping — on a factory copy, with the condition
   induced — would tell us whether the constitutional core works at all.

---

## Axis 3: GOVERNANCE — the architect is the bottleneck

**Where it stands.** 93 proposals, 4 answered. Charter editions 1 to 5, every one
of them written by hand. `review_proposals.py` requires a human for each.

The paper is explicit that this is where the wall is: norm-setting wholesale
moves into an undefined Class 4, so the factory hits either a read-only wall or
a power-sharing arrangement. It proposes **sortition** — a rotating, seated
sample of the factory's own population (no-regret learners, swap-regret learners,
productive agents, evaluators, antagonists) participating in charter revision.

**What online governance would require:**

1. **Proposals must carry a price.** λ as novelty-forgone exists for the voice
   clamp (0.011 per window, ~14% of the factory's novelty). Unpriced proposals
   cannot be compared, and 93 of them are unpriced. Pricing is the precondition
   for any automated triage, because it converts "I want this" into "this costs
   that".

2. **The proposer must fire on failure, not novelty.** The current one fires on
   reaching a new region, which never saturates. The paper's holdouts come from
   adversarially induced conditions or production traffic that revealed
   something. We now have judges that could supply exactly that signal.

3. **A seated delegation, with the architect retaining refusal.** Sortition over
   the judge population, rotating, proposing charter amendments with prices
   attached. The architect's role becomes veto and arbitration rather than
   authorship of every line — which is power-sharing rather than abdication.

---

## What must NOT become online

- **The kernel.** k2_continuous, the identity clauses, the norms. P540: norms are
  never ceded, because ceding them is Class 4. A factory that can rewrite what it
  is has no dependencies on its world.
- **The frozen descriptor basis**, on the argument above — better understood as
  part of the kernel than as a parameter.
- **Any scalar the factory can climb.** score_charter refuses a total for this
  reason. λ is safe *only* while nothing in selection reads it.

## The honest order

1. Hot buffer swap. Everything on the material axis waits behind it, and it is
   ordinary engineering with a known hazard.
2. Continuous admission on top of it, which makes generation depth a real
   quantity rather than a restart counter.
3. Realized-consequence scoring extended into a standing track record.
4. λ extended to every clamping constraint, so proposals become comparable.
5. The proposer rebuilt on evaluator signal.
6. Only then, judge influence — from zero, ablated, with tier two grading it.
7. Sortition, last, because it presupposes priced proposals and trustworthy
   judges.

Steps 1 and 2 make the factory continuous in its material. Steps 3 to 5 make its
evaluation consequential without making it self-fulfilling. Steps 6 and 7 are
where it stops being an instrument the architect operates and becomes something
closer to what the paper describes — and each is a decision about power, not a
feature.

## What is missing from this plan

It says nothing about the music. Every step above is about the apparatus, and the
finding of 2 Sept was that the factory has been performing into a multiplier at
zero for an unknown number of runs while every metric reported health. A fully
online factory that is inaudible is a fully online failure. **The audibility work
— machine amplitude calibration against the BufRateScale change, the life arc,
the relationship between requested and delivered level — is not a detour from
this path. It is the part that decides whether the path is worth walking.**
