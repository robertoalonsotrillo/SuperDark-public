# The harness

15 September 2026.

## The question this answers

Exo splits an agent in two. Below the line, the **exoharness**: identity, an
append-only event log, artifacts, secrets, sandbox lifecycle, none of it
alterable by the agent. Above the line, the **executor**: prompt assembly, model
calls, tool dispatch, memory, the turn loop, all of it swappable. The canonical
agent mounts its own source at `/workspace/exo` and can rebuild and restart
itself, and the docs say why that is safe: "everything above the substrate is
fair game for the agent to modify, because the event log, secrets, and snapshots
below it guarantee a way back."

SuperDark has the same shape and the opposite settlement. There is no way back,
so nothing above the substrate may be rewritten. The machines recombine
parameters inside a template only the architect writes. **We are keeping
non-revisability.**

That decides what a harness is for here. In Exo the harness exists so that
self-modification can be permitted. Here it exists so that the **claim record**
can be trusted. It protects the numbers from the architect, not the factory from
itself. The Darwin Gödel failure that Exo's release proposal cites, an agent
editing its own scorer, is not available to a factory that cannot write files.
The failure that IS available has already happened three times in a softer form:
a spectral measure saturated, and every verdict computed with it silently
changed meaning.

## What was already here

Most of a harness existed without the name.

| Function | Already built |
|---|---|
| tripwire and block | `kernel_guard.py` on `kernel.json`, dry-run until `--arm`, bounded to stop-and-record, never deletes or widens a bound |
| rollback for the corpus | `archive_guard.py`: pool, checksummed read-only archive, FMA source with a fixed RNG seed |
| out-of-band watch | `run_integrity.py`, writing to `/tmp` on the internal disk, refusing to repair anything |
| margins from shadow data | `charter_honesty.py`, `charter_headroom.py`, ten runs before arming |
| versioned policy | charter editions 1 to 6, archived |
| append-only record | `charter_decisions.jsonl`, `kernel_journal.jsonl`, `charter_proposals.jsonl` |
| a sealed scorer | `frozen/score_e1_frozen.py`, with the principle already stated in `frozen/README.md` |

`run_integrity.py` states the harness argument without using the word: "A
watchdog that silently repairs a run produces a log with an unmarked seam in it,
which is worse than a run that stopped, because the seam is then read as
continuous data." Exo reaches the same place from the other direction: "You can
rewind state; however, you can't rewind history."

**And on 15 September all three watchers were switched off.** The kernel last
journalled on 6 September, nine days earlier, with `armed: true` in its config
and nothing invoking it. `run_integrity` was not running. The publisher had been
dead long enough that the public panel was serving a snapshot 2.6 days old. A
component that is configured is not a component that is running, and this is the
third time that sentence has had to be written in this project.

## What was added

    harness/
      sealed_scorers.txt        which files the rig is made of
      measures.json             promotion and veto power, per measure
      release_policy.v1.json    what counts as a win, written before the candidate
      checkpoints/              the rollback objects
      runs/                     evaluation bundles
      harness_journal.jsonl     restores and other events, append-only
    frozen/
      MANIFEST.json             sha256 of every sealed scorer
      SEAL_LOG.jsonl            every adopted change, with its reason
    tools/
      checkpoint.py             create / list / verify / diff / restore
      seal_rig.py               seal / verify / status / adopt
      measure_registry.py       status / check / use / owed
      eval_rig.sh               validate / schema / run / compare / gate
      eval_run.py, eval_compare.py, eval_gate.py

### The checkpoint

The object the factory has never had. `archive_guard` makes the corpus
recoverable; nothing made the *state* recoverable. `memory.json`, `policy.json`,
the charter, the weights and the machines are overwritten in place, so the
operator a measurement describes stops existing at the next window. That is why
m7 turned out to be measuring the operator's **age**, and why 10 September could
not attribute anything: three changes went live together with a restart and a
reassembled corpus, and the result document had to say in as many words that no
movement was attributable to any of them.

A checkpoint carries the policy layer, the operator, the substrate, `git HEAD`
plus a dirty flag, the sha256 of `live_factory.scd` and every `lib/*.sc`, and
the hash of each corpus manifest. `diff` then says exactly what changed between
two states, which is what the one-change-at-a-time rule needs to be enforceable
instead of aspirational.

`restore` **refuses while the factory is running**, for the reason
`run_integrity` gives. `--force` exists and is recorded.

### The seal

Every scorer that can produce a proposal-quotable number is hashed into
`frozen/MANIFEST.json`. `eval_rig.sh` verifies the seal before any number is
computed, and refuses if it is broken.

A sealed scorer is not forbidden from changing. It is forbidden from changing
**quietly**. `adopt` records the old hash, the new hash and the reason into
`SEAL_LOG.jsonl`, and prints the consequence: every measurement taken before
that line used the old text, so any of them still quoted needs its hash beside
it. `seal` refuses to re-seal over an unadopted change.

One consequence is deliberate and worth stating: the rig extracts numbers from a
scorer's **existing** stdout, by a regex in `measures.json`. A sealed scorer that
grows a `--json` flag for the rig's convenience is a sealed scorer that changed.
The rig adapts to the measure; the measure does not adapt to the rig.

### The measure registry

Exo's rule: "Seen tasks can only block a candidate. Only unseen tasks can
promote one," because a candidate carrying the champion's whole history "can
score high by remembering, not by being better."

Every measure in SuperDark is a seen measure. Each was built, and then every
change after it was made while watching it. **This project has been promoting
changes on seen measures since late August.**

A flat ban would leave nothing able to promote anything, so the registry uses a
budget: three adjudications, then the measure keeps veto power and loses
promotion power. Spending a budget is the signal that new measurement is owed.
Saturation retires a measure immediately whatever its budget, and a measure with
no recorded calibration arms cannot promote at all.

Standing at the time of writing: four measures can still promote, three are
veto-only by construction, three are retired. `score_charter` is veto-only
permanently, because every charter metric has passed while the output was
sonically identical.

Two measures are recorded as **owed**: a macro-isolated measure, because the
recurrence measures average macro against seven times its number of micro events
and so cannot adjudicate a macro question at all; and the reward channel.

### The release policy

Written before the next candidate exists, which is the whole point: "Once the
numbers are in, nobody gets to move the goalposts, including us."

Seven hard invariants, four tripwires, a one-change-at-a-time rule with a named
exception path, and a list of reasons to switch in which **an ear win is a
first-class reason**. That is not a courtesy. The ear has been right three times
where the instruments were not, and on 10 September the recurrence measures
preferred, at every match window, the configuration Roberto had called
unlistenable. An ear win is recorded as an ear win and never dressed as a
measurement.

**Margins are UNSET**, and the policy says why. Exo's proposal ends on the same
open question. Setting a number now would be a guess dressed as a threshold, and
this project has already been bitten by exactly that when the 0.9 drift
threshold turned out not to be commensurable with the estimator that replaced
it. So the gate runs in **shadow**: it computes everything, writes the bundle,
and returns `margins_unset`. It promotes nothing. Changes still ship on
judgement. The difference is that the bundle says so.

### The first lap

Following the proposal's build order, one champion/candidate pair was taken
through the whole loop by hand. It **rejected**, for six independent reasons at
once:

- both arms read the same log, so it is one run measured twice
- seven of seven hard invariants unverified, because they are not wired yet
- six measures NOT WIRED, and each one with veto power blocked on that

All three are correct. The plumbing works and the gate is not polite about it.

The lap also produced an unplanned finding. The two arms ran twenty seconds
apart and `m8_in_band` differed by 14.4 Hz, `m9_turnover` by 0.002, because the
window log grew between them. That is the concrete case for Exo's
**sealed-before-test** rule: a champion that keeps working while the evaluation
runs is a moving bar.

## What the rig caught in its first day, and what it did not

Kept because a harness that is never audited becomes decoration.

**Caught by the rig, at zero cost in claims:**

- **M-A saturated and inverted.** A literal loop scored as more varied than 600
  unrelated FMA clips. The arms ran before the factory arm was read, so nothing
  was claimed and nothing needed retracting. Compare 6 September, when the same
  class of failure surfaced only after the measure had been used.
- **M-D's decision rule could not falsify.** A pooled sd over heavy-tailed hold
  durations normalised a 2× difference in medians to 0.17 sd. A new failure
  mode: the statistic discriminated and the rule could not.
- **Two corrections inside an hour**, both because a number was checked against
  the source rather than remembered.

**Caught by a person, with the rig silent:**

- **The isolation run was feeding the channels it measured.** Self-ingestion kept
  running through a macro-only run and admitted macro audio into the pools of the
  layers that were silent. Roberto caught it fifty minutes in. Seven invariants
  existed and not one covered "the experiment must not feed the thing it
  measures". Now `learning_frozen_during_isolation` does.
- **Four ingest daemons**, one per `start_loop.sh` invocation, racing on
  admission. Now `one_ingest_daemon`.
- **The macro-only run was musically empty.** "It produces no harmonies
  whatsoever." No instrument here measures vertical structure at all.

**Caught by reading the code, with everything green:**

- **`attention_weight` had never run.** `attend()` keyed its recall by the
  operator's composite symbol while the caller looked up plain machine names, so
  6,570 of 8,000 trace entries could never match and the block escaped on every
  window. Raising the weight would have done nothing, silently, and the honest
  conclusion would have been "memory has no effect".
- **`FILL_STALL` returned 15 times** while the charter passed on all eight
  metrics, the panel was fresh and `run_integrity` reported clean.

The pattern across the second and third groups is one thing: **the rig is good at
checking numbers and blind to mechanisms that are not running.** Four mechanisms
have now been found built and inert. The countermeasure is not another metric, it
is the habit of grepping for the consumer before experimenting on a knob.

## What is still missing

1. ~~The hard invariants are not wired.~~ **Done 15 Sept.**
   `tools/eval_invariants.py` calls the real tools; nine invariants now, after
   `learning_frozen_during_isolation` and `one_ingest_daemon` were added from
   the day's two incidents.
2. ~~Six of seven measures are NOT WIRED.~~ **Done 16 Sept.** Six carry `cmd`
   and `parse`, each regex verified against real captured stdout before use.
   `recurrence_sweep` stays unwired on purpose: it takes three calibration arms
   and is not a per-arm scorer. `version_operator` remains.
2b. **No measure has promotion power left to spend cheaply.** Four can still
   promote and each has a budget of three. The registry makes the cost visible;
   it does not create new measurement.
3. **`mutable/` still collapses the split.** `kernel.json` sits beside
   `policy.json` and `memory.json` with the same permissions. There is no line
   in the filesystem between substrate and policy. Splitting it means touching
   paths the running factory reads, so it waits for a restart.
4. **The reward channel does not exist.** Nothing here has the factory commit a
   prediction before a window and get scored against it. It is the only feedback
   in the design not authored by the architect, and it needs factory-side
   instrumentation, so it waits for a restart too.
5. **No fine-grained rewind.** A checkpoint is a coarse, manual rollback point.
   Exo has two independent axes, sandbox filesystem and conversation log, and
   SuperDark has neither in the fine-grained sense. State this in the proposal
   as a limitation with a named remedy: an append-only event log beside
   `memory.json`, replayable to an index.

## For the proposal

Do not claim a harness. Claim the split, name what is built, name the gap.

The useful thing to say is that the two systems answer the same question in
opposite directions and both answers are coherent. Exo guarantees a way back so
that everything above the substrate may be rewritten. SuperDark freezes
everything above the substrate because there is no way back. Measured against
Dark Stack ¶128, where darkness is the revisability of a plan and not model
opacity, SuperDark is the darker system, and for a reason that has nothing to do
with the absence of an LLM.

Exo's proposal ends on an open question: "Where does the evaluator ultimately
live: fully outside Exo or as a protected primitive inside the exoharness?" A
frozen-executor system is the clean case for answering it, because the failure
that motivates putting the evaluator outside cannot occur. That is a finding
this project can hand back.

## References

- exoharness/exo discussion #201, *Continual release design proposal*, 6 Aug 2026
- exoharness.ai docs: Exoharness & Executor, Data Model, Lifecycles, Time Travel,
  The Canonical Agent
- `.lab/measurements/2026-09-10_full_vector_result.md`
- `.lab/notes/THE_KERNEL_IS_BROAD_BUT_NOT_DEEP.md`
- `frozen/README.md`
