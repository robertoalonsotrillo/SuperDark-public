# m7 measures the operator's age, not the factory's coherence

Established 2 Sept 2026. This is a finding about a charter metric, so it is
written down before anything is changed, and the change itself is the
architect's to make.

## What m7 claims to test

`m7_spectral_gap_settles`: interquartile range of the operator's spectral gap,
acceptable [0.02, 0.45], norm `n3_coherent`. Its calibration note reads: *"P227
stable failure is a gap frozen wide; P230 thrash is a gap that never settles.
This is the one metric taken directly from the paper's own pathology names. 6h
run: gap ran 0.295-0.422 at p10-p90, IQR well inside. PASSES."*

## What it actually tests

Three facts, each checked rather than argued:

1. **The operator accumulates without decay.** `TransferOperator.sc`:
   `row[cell] = (row[cell] ? 0) + 1`. No forgetting term anywhere.
2. **The operator survives run boundaries.** `saveMemory` writes `op.counts` into
   `memory.json` (live_factory.scd:256) and `loadMemory` restores it. The counts
   are cumulative over EVERY RUN THE FACTORY HAS EVER DONE.
3. **Confirmed on a live run.** A factory restarted minutes earlier reported
   **137 operator cells while it had played 4 distinct machines.** The operator
   was carrying 133 behaviours this run had never touched.

A cumulative estimator converges. Its eigenvalues stop moving as n grows,
whatever the system underneath does. So the interquartile range of lambda2 falls
monotonically with the operator's accumulated history — and since that history
now spans dozens of runs, the IQR sits near zero and will go lower.

**m7 therefore cannot keep passing on a factory that runs forever.** It is m6's
fault inverted: m6 could never fail because policy pinned it inside its bound;
m7 cannot keep passing because its statistic decays with age by construction.
Both are metrics that describe the apparatus instead of the work.

## What was tried, and why it stopped

`tools/rederive_m7.py` rebuilds the operator offline from the window log and
compares against the factory's own logged lambda2 before doing anything else.
It fails that check: **r = +0.20, median |difference| = 0.40**. The script says so
and refuses to go on, which is correct — the reason for the mismatch is exactly
fact (2) above. The window log records this run's machines; the operator holds
every previous run's as well, so the sequence needed to reconstruct it is not in
the log at all.

**No bound can be derived from existing logs.** Re-pricing m7 from data that
cannot reproduce the quantity would repeat the mistake that produced it.

## What a replacement needs

Not a wider bound. A different statistic, and it has to be produced by the
factory because only the factory has the operator's input sequence.

- a SECOND operator with exponential forgetting, observing the same cells,
  **steering nothing** (weight 0, exactly as `section_operator_weight` is held),
  so its variability describes recent behaviour and is age-invariant;
- both its lambda2 and its observation count logged, so a thin estimate is
  visible as thin;
- a bound derived from a **shuffled null** over the cell sequence — what the
  statistic does when there is no sequential structure — so that the metric
  discriminates "coherent" from "nothing" instead of encoding one run's numbers.

Until that exists, m7 should be marked UNDECIDED rather than FAIL. Reporting a
failure against a bound known to be unmeasurable is not honesty, it is noise
that trains the reader to ignore red.

## The pattern this belongs to

Third instance of one failure: a bound calibrated against a quantity whose
meaning later moved.

- m6_texture — policy pinned voices inside the bound; ten passes out of ten by
  arithmetic. Repaired by widening the POLICY, not the bound.
- the 0.9 drift threshold — runs 12-13 measured a different quantity; the new
  estimator floors above it.
- m7 — the operator's history grew past the regime the bound was set in.

The common cause is that each bound was written from an observed run rather than
from a null. A bound derived from a null states what the metric discriminates;
a bound derived from a run states only what that run happened to do.
