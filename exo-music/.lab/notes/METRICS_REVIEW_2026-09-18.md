# The metrics, reviewed against the paper

**18 September 2026.** Prepared while the A-B-A-C-A-D sequence runs, for the
discussion Roberto asked for once it finishes. Sources: `mutable/charter.json`
(edition 6), `harness/measures.json`, `mutable/charter_proposals.jsonl`,
`tools/factory_status.py`, and *The Superdark Factory* §5.2 to §5.4, line
numbers from `SOURCES-MD/superdark-factory-full.txt`.

Nothing here is a decision. Section 7 lists the decisions the discussion has to
make, numbered so they can be answered one at a time.

---

## 1. There are two evaluation layers, and they answer different questions

This is the first thing to keep separate, because the panel shows one and the
harness runs the other.

**The charter** (`charter.json`) answers *what must not go wrong*. Ten metrics,
each serving one of four norms. It is scored over a whole run and it can stop a
change; it can never justify one. The registry says why in one line: every
charter metric has passed while the output was sonically identical, so passing
tells you nothing. This is the layer the panel shows as "CHARTER · EDITION 6".

**The harness registry** (`measures.json`) answers *what may decide a change*.
Eight measures, each with a script, a calibration, a pre-registration, and a
record of every change it has judged. A measure keeps promotion power for three
adjudications and veto power forever; saturation retires it at once. This is the
layer the comparisons run through, and it is where the paper's "seen tasks can
only block, unseen tasks can promote" (release policy) is implemented as a
budget.

Above both sits **the kernel** (`kernel.json`), which the factory cannot write:
"a kind of live-or-die button whose threat is continuously invoked" (L273). It
fired once, 1 September, on three sustained charter failures.

The paper's layering (L268 to L269): norms, articulated as metrics, given
constraints. The charter file follows it exactly. The registry is a fourth thing
the paper does not name, and it exists because the charter turned out to have
zero discriminating power on 27 August and something had to.

---

## 2. The ten charter metrics

| | serves | measures | bound | status | standing |
|---|---|---|---|---|---|
| **m1_not_silent** | n1 audible | fraction of windows with master peak < 0.004 | none | descriptive since ed. 4 | keep as description; rename (§3) |
| **m1_audible_when_driving** | n1 audible | silent fraction *among windows where section amplitude ≥ 0.01* | [0, 0.015] | live | stands; bound derived on one 8 h run, re-check on the next level fault |
| **m2_level** | n1 audible | median master peak | [0.02, 0.35] | live | stands |
| **m3_no_clipping** | n1 audible | p99 clip fraction, pre-encoder | [0, 0.02], never tolerated | live | stands, with a known blind spot (§6.3) |
| **m4_vocabulary_breadth** | n2 varied | distinct *behaviours* per 100 windows, bridges collapsed | [8, ∞) | live | stands; counts behaviours not names, the file calls this its most important line |
| **m5_not_converging** | n2 varied | convergence2 C1: last-quarter entropy / first-quarter | [0.75, 2.0] | live | stands; upper bound never exercised |
| **m6_texture** | n3 coherent | median concurrent voices | [2, 8] | live | stands *while* policy's clamp is wider than the bound; was decorative for ten runs before ed. 5 |
| **m7_spectral_gap_settles** | n3 coherent | IQR of the operator's spectral gap | [0.02, 0.45] | **suspended** since ed. 3 | must be **re-derived**, not un-suspended (§6.1) |
| **m8_in_band** | n4 its own | median spectral centroid | [400, 4000] Hz | live | stands; guards the filtering-into-nothing defect |
| **m9_turnover** | n2 varied | fraction of consecutive windows where the sounding behaviour changes | none | descriptive since ed. 6 | keep descriptive until a blind-listening bound exists (§6.4) |

Two of the ten carry no bound by design and are reported without pass/fail. One
is suspended. Seven can fail. The departure rule tolerates two failures; three
invokes the kernel; m3 alone is never tolerated.

**Where each bound came from.** m2, m3, m4, m5, m8: the 6 h run of 26 August and
the 20-minute controls. m1_audible_when_driving: simulated level faults against
861 windows of the 2 September run. m6: a proposal the factory made at window
139 (the one adopted proposal). m7: the 26 August run, which is the chain that
is now dead (§6.1). The file is careful to say when a bound was fitted to the
run it was meant to judge, and to refuse that where it was offered (m9, m4's old
ceiling).

---

## 3. Why there are two m1s

`m1_not_silent` was the original metric. On 2 September it was found to measure
a compositional habit and not a fault: silence tracks the section amplitude the
factory chooses, 34.8% of windows silent near amplitude 0 and 0.2% at amplitude
≥ 0.01. So it was **demoted** to a description, its bound removed, and a
conditional version, `m1_audible_when_driving`, was added in the same edition to
carry the norm. Both were kept because the silence is part of the work and worth
reporting, and because the demotion is more legible with the old metric still on
the page than with it deleted.

The prefix collision is a naming accident from that day. It does no harm to the
scoring (the keys are distinct strings) and some harm to the reader. Options in
§7.

---

## 4. The harness measures

| | what it measures | power | judged so far | note |
|---|---|---|---|---|
| **sonic_variety** | spectral recurrence across a match window, centred (a correlation) | promote, 2 of 3 spent | section_spread, full_vector | its uncentred ancestor saturated; only the paired form may be read |
| **recurrence_sweep** | position on the diverse-to-loop axis, five windows | calibration only | 2 | not wired into arms on purpose; the ear disagrees with it on macro |
| **version_operator** | spectral gap and dwell of the transfer operator over judge-score cells | promote, 1 of 3 spent | version_readout | analytic dwell moves by hundreds between identical arms; empirical dwell is read instead (pre-registered 18 Sept) |
| **generation_drift** | descriptor displacement across self-ingestion generations | promote, 1 of 3 spent | self_ingest_weight | permutation null T = 0.9996 |
| **score_charter** | the ten above | veto only | | |
| **charter_honesty** | whether a charter bound *can* fail given policy | veto only | | the check that caught m6 decorative |
| **judges** | nine judges plus nine tier-2 learners over window features | veto only | | steer nothing; their scores define version_operator's cells |
| **convergence2** | selection entropy, terminal ratio, permutation p | veto only | | the veto for the attention experiment |

Five measures have been **retired**, four of them by saturation on first
calibration (a literal loop scoring as more varied than 600 unrelated tracks,
three times over) and one because its decision rule could not fail. The
registry's own reading: every saturated measure was a normalised band vector
compared pairwise and averaged, and the one statistic that did discriminate was
partial tracking. That family is the one to build from.

---

## 5. What the factory contributes, and what it may not

This is the question about "how the factory is modifying those or establishing
its own evaluation mechanisms", answered against the paper.

**What the paper allows.** The metrics layer is "the easiest ground within a
charter to cede to the factory's contributory arm" (L278); "if you hand it a
norm, it will propose a metric to represent that norm" (L278); the evaluatory
layer may keep "continuously adding holdout test criteria to a given charter"
(L278). Norms are not cedable: "A factory that constructs its norms wholesale
moves us into the undefined Class 4" (L280). The kernel is read-only from inside.

**What is built.**

1. **The proposals channel.** `charter_proposals.jsonl`, 93 entries. The factory
   writes a proposal when it reaches a region of descriptor space further than a
   threshold from anything previously visited (`coverage_holdout`, 89 of them)
   or when it uses a voice density outside the current bound (`voice_range`, 4).
   Each names the norm it serves and a rationale. This is L278 implemented
   literally: a norm handed over, a metric proposed back, as a holdout.
2. **Adoption is a governance act.** One proposal adopted, 92 refused. The
   adoption was m6's widening to [2, 8] in edition 5, and it turned a decorative
   metric into a measured one. The 89 coverage proposals were refused as
   individual metrics because a criterion "reached somewhere new, hold it" fights
   coherence at a loose radius; the same analysis on 2,000-window runs found that
   at a tight radius (0.09) the factory occupies regions a shuffled null does not
   (20% against 2%), so ONE consolidated coverage metric is measurable and its
   bound is waiting on the weight sweep. That is a refusal with a route back,
   which is what the paper's "converts a world-finding into authored record"
   (L278) needs.
3. **Judges that steer nothing.** Nine judges, six mean-based and three
   swap-based, per L251's requisite-variety ratio. They were all no-swap-regret
   learners on 3 September, which is the failure L192 names ("cannot find
   anything outside of what was already committed to"); the population was
   rebalanced and they remain deliberately disconnected from selection. Their
   only output is the cell definition for `version_operator`.
4. **The early-warning triple.** Variance, autocorrelation and ensemble
   disagreement (L257) are computed per window and shown raw with no threshold,
   on the stated reasoning that a warning the factory can see and optimise
   toward stops being a warning.

**What is not built**, and the paper says why it matters more than any of the
above: a signal from outside the loop. "Judges that measure outcomes (and only
outcomes), answer to signals in the world" (L151). "The signal that grades an
evaluator must sit outside the loop that evaluator judges" (L256). "A
realized-consequence score requires true regressions and real failures" (L260).
The charter's own `_absent_and_why` says the same thing in its own words: every
metric is a metric over the factory's own output, because constraint c4 records
that there is no world. The registry lists `reward_channel` as owed since 15
September, with an audibility-lag check pre-registered on the 16th before any
skill figure may be quoted.

So the honest summary of "the factory's own evaluation mechanisms" is: it
proposes metrics, it does not adopt them; it runs judges, they do not steer; it
computes early warnings, nothing acts on them. Every one of those is a deliberate
stop short of the paper's full loop, and the stop is at the same place each time:
the absence of a signal the factory did not generate.

---

## 6. What does not stand, or stands with a caveat

### 6.1 m7 must be re-derived on the live chain, not un-suspended

The bound [0.02, 0.45] was derived on the 26 August chain, which the 18
September record shows to be the *dead* component of the operator (gap 0.3265,
inside the quoted 0.295 to 0.422). The live chain's gap is 0.61, above the bound.
Un-suspending would fail a healthy factory against a bound belonging to a
different chain. The half-life is wired and `operator_half_life = 5000` is in
force, so the "replacement_requires" clause in the charter is now met; a
pre-registered re-derivation over ~300 windows is #46.

### 6.2 m6 stands only while policy is wider than the bound

The file says it. `charter_honesty` checks it. Worth restating because C2 of the
current run sets `voices_max` to 5, inside the bound's [2, 8], for 853 windows;
m6 is not decorative during that arm (the clamp is [1, 5], the bound [2, 8], the
metric can still fail low) but its upper half is unreachable, which is a
different kind of caveat and should be recorded when the arm is scored.

### 6.3 m3 reads the wrong side of the encoder

Documented on 3 September: m3 = 0.0 in every window of an hour whose delivered
stream reached +0.57 dBTP. The delivered peak is measured by
`tools/delivered_peak.py` and is not a charter metric. Since m3 is the
never-tolerated clause, the governance layer has a hole on the listener's side.
Adopting the delivered peak is a governance act and belongs in this discussion.

### 6.4 m9 has no bound and should not get one from the data it describes

The file refuses a bound of ~0.8 because it would be fitted to a distribution
that contains the failure. The bound has to come from turnover measured on runs
judged blind. That experiment does not exist.

### 6.5 The register of "owed"

From `measures.json`: a macro-isolated measure (recurrence averages macro
against seven times its number of micro events), a macro isolation run to
produce the condition, M-D' pre-registered against `long_hold_cover` on fresh
data (#96), something for harmony (macro "produces no harmonies whatsoever",
and M-D tracks one partial so cannot see it), the reward channel, and the
reward channel's audibility-lag check. Plus from the task list: a bound for
`clicks_per_second` (#113), which has been quoted as a verdict without one.

---

## 7. Decisions for the discussion

1. **The two m1s.** (a) Rename `m1_not_silent` to `m0_silence` or `d1_silence`
   so the descriptive metrics carry a prefix of their own; (b) leave the keys and
   fix only the panel label; (c) fold the description into
   `m1_audible_when_driving`'s reported detail and drop the row. Any of these is
   an edition bump.
2. **m7.** Authorise the ~300-window pre-registered re-derivation on the live
   chain (#46), to run *after* the current sequence so it is not a second change
   inside it.
3. **Delivered peak as a charter metric.** Adopt it beside m3 as
   `m3b_delivered_peak` with the never-tolerated flag, bound from
   `delivered_peak.py`'s existing runs; or leave m3's scope as written.
4. **Coverage.** Adopt the single tight-radius coverage metric once the sweep
   has characterised its spread; decide the radius rule now (0.12 of median
   anchor spacing) so the bound is the only thing waiting.
5. **Harmony.** Whether a vertical measure is owed at the charter level (a norm,
   which only Roberto can write) or the harness level (a measure). The file has
   no norm that a harmony metric would serve; n3 coherent is the nearest.
6. **The reward channel.** The paper's strongest claim is that everything above
   is the wrong side of L256 until this exists. What counts as a world signal for
   a factory whose only listener is a stream mount: listener count, listen
   duration, the relay's own logs, a second factory's ingestion of this one's
   output. Each is weak; the question is whether any is admissible.
7. **Whether to move the early-warning triple from display to veto.** The panel
   shows it raw. The paper (L257) treats it as the catastrophe detector. A veto
   with a pre-registered bound is the cautious middle.

---

## Decisions taken, 18 September 14:5x, by Roberto

All seven were put to him one at a time while C1 of the A-B-A-C-A-D sequence
ran. None of the resulting work starts until the sequence closes, because a
scorer or charter change inside a comparison is a second change.

| # | decision | consequence |
|---|---|---|
| 1 | **Rename the descriptive metrics.** `m1_not_silent` → `d1_silence`, `m9_turnover` → `d2_turnover`. | Charter edition 7. Keys change in charter.json, score_charter, factory_status, panel. Re-seal. |
| 2 | **Re-derive m7 on the live chain, after the sequence.** | ~300 windows, half-life 5000, bound from a shuffled null over the cell sequence. Re-enters as `m7b` so numbers from the old chain stay attributable to it. Pre-registration first. (#46) |
| 3 | **Adopt the delivered peak as `m3b_delivered_peak`, never tolerated.** | Bound from `delivered_peak.py`'s existing runs. Joins m3 in `never_tolerated`. Edition 7 with #1. |
| 4 | **Adopt one consolidated coverage metric now, bound UNSET.** | Radius rule fixed: 0.12 of median anchor spacing (≈0.09). One metric over the 89 anchors. The bound waits for the weight sweep to characterise the spread. Pre-registration on file before any bound. |
| 5 | **Harmony is a harness measure, not a norm.** | A vertical measure (interval content or partial co-occurrence) enters the registry with veto power at most. The charter keeps four norms. Partial-tracking family, not band-vector. |
| 6 | **Three reward signals admitted: listen duration, a second factory's ingestion, listener count.** | All three weak and admitted as weak. The audibility-lag check (pre-registered 16 Sept) runs before any skill figure is quoted from any of them. Listener count carries the least weight at current numbers. |
| 7 | **Early-warning triple moves from display to veto.** | Bound on variance and autocorrelation rising *together*, derived from a null, entered in `measures.json` as veto-only. The panel keeps showing it raw. |

Order of work after the sequence: 3 and 1 together (one edition bump), then 7
and 4 (registry entries with pre-registrations), then 2 (needs its own 300
windows), then 5 and 6 (each needs a design note first).

## What this review does not do

It does not score anything. It does not propose new bounds. It reads what the
files say against what the paper says and lists where they disagree or where the
files themselves say they are incomplete. The numbers in §2 are the bounds as
written on 18 September; the sequence running today may change what some of them
are worth, and that is a reason to hold the discussion after it and not before.
