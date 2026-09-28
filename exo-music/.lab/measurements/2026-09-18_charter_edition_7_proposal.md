# Charter edition 7: two renames and one adopted metric

**18 September 2026.** Written while the A-B-A-C-A-D sequence runs, to be
applied after it closes. Decisions 1 and 3 of `.lab/notes/METRICS_REVIEW_2026-09-18.md`,
taken by Roberto on 18 September.

A charter edition is a factory version (P269: "Every change to the input is a
new charter"). This document is the authored record of what edition 7 changes
and why, written before the edit so the reasoning cannot be reconstructed after
seeing what the numbers did.

---

## Change 1: descriptive metrics get their own prefix

| from | to |
|---|---|
| `m1_not_silent` | `d1_silence` |
| `m9_turnover` | `d2_turnover` |

**Why.** Both were demoted to descriptions on purpose and carry no bound:
`m1_not_silent` in edition 4, because it counted silence unconditionally and
silence tracks the section amplitude the factory chooses; `m9_turnover` in
edition 6, because the only bound available would have been fitted to a
distribution containing the failure it was meant to catch. An `m` prefix on a
metric that cannot pass or fail invites a reader to look for a verdict that was
deliberately withheld.

The collision between `m1_not_silent` and `m1_audible_when_driving` is a
separate accident of the same day, and the rename resolves it as a side effect.

**What this is not.** It does not change what either quantity measures, how it
is computed, or whether it is reported. Both keep their place on the panel. The
edit is to the key and the label.

**Scope.** `mutable/charter.json`, `tools/score_charter.py`,
`tools/factory_status.py`, `workdir_music/stream/panel.js`. The scorer is
sealed, so this requires an adopt with a stated reason. Any number quoted
against the old keys stays valid: the statistic is unchanged and the seal log
will say so.

---

## Change 2: `m3b_delivered_peak`, adopted, never tolerated

**Test.** True peak of the delivered mount, 4x oversampled, over a capture of at
least 120 s, as computed by `tools/delivered_peak.py`.

**Bound.** `[0.0, 1.0)`, exclusive at the top. Never tolerated, beside
`m3_no_clipping`.

**Why this bound is not fitted.** Every bound in this file that had to be
withdrawn was set from a run's own observed value: m7's interquartile range,
m4's old ceiling, the 0.9 drift threshold. Full scale is not that kind of
number. It is a property of the medium: a converter reconstructing a waveform
above 1.0 clips, whatever the factory happens to have produced. The bound is
therefore derived from the format and not from a distribution, and it cannot
drift with the factory's behaviour.

**Provenance of the hole it closes.** Over the hour of 3 September 17:41 to
18:42 the delivered mount reached true peak 1.067 (+0.57 dBTP) with six samples
at or above full scale, while `m3_no_clipping` read 0.0 in all 410 windows. Both
readings were correct. The limiter holds the sample peak at its ceiling and m3
measures that signal; the encoder then returns samples above the ones it was
handed. `master_ceiling` was lowered from 0.9 to 0.80 on the measured overshoot
factor of 1.184, and the delivered peak then measured 0.868 with zero samples at
full scale.

**Why never tolerated.** m3 is the clause that stopped the factory on
2 September. A never-tolerated bound that is blind on the listener's side of the
encoder is a hole in the governance layer, and the hole has been open since
3 September with the instrument to close it sitting unadopted in `tools/`.

**What must be true before it is adopted.**

1. A fresh measurement of the delivered mount at the current ceiling, at least
   120 s, recorded in this file as the pre-adoption reading.
2. `charter_honesty` run against it. If `master_ceiling` at 0.80 makes a
   delivered peak of 1.0 structurally unreachable, m3b is decorative in exactly
   the way m6 was for ten runs, and that has to be recorded here and not
   discovered later. The expected answer is that it is NOT decorative, because
   the ceiling is a policy value the factory's own limiter enforces and codec
   overshoot is not bounded by it; that expectation is written down so it can be
   wrong.
3. A stated cadence. Unlike the other nine, m3b needs a network capture and
   cannot be computed from the window log. Proposed: measured once per scored
   arm, and by `run_integrity.py` on the same clock as its other probes.

**What is not claimed.** That 0.868 is safe with margin for every encoder
setting or every listener's converter. The claim is only that the delivered
signal is now measured, bounded, and inside the bound at the last reading.

---

## Lineage entry to be written

```json
{
  "edition": 7,
  "from": 6,
  "by": "Roberto Alonso Trillo",
  "when": "<at edit>",
  "change": "m1_not_silent -> d1_silence, m9_turnover -> d2_turnover; m3b_delivered_peak adopted, never tolerated",
  "because": "an m-prefix on a metric with no bound invites a verdict that was deliberately withheld; and m3, the never-tolerated clause, has been blind to the delivered signal since 3 Sept",
  "prereg": ".lab/measurements/2026-09-18_charter_edition_7_proposal.md",
  "left_failing": []
}
```

`left_failing` is written at the edit from what the sequence's arms report, and
is not predicted here.
