# Threshold provenance: what stands behind each charter bound

**17 September 2026, 02:20.** Built after two findings in one night turned out
to be the same finding twice — a number quoted as a verdict with no bound
(`clicks_per_second`), and a bound whose discrimination is simulated rather than
observed (`m1_audible_when_driving`).

Both are failures of **provenance**, not arithmetic, and neither is visible from
the charter's face. The charter reports pass or fail. It does not report how much
evidence stands behind the line it judges against.

`tools/audit_threshold_provenance.py` asks that of every metric, from the files.

## The audit, corrected twice

| metric | bound | evidence cited | observed | headroom |
|---|---|---|---|---|
| m1_not_silent | none, **by design** | multi-hour run + gap_r1 | 0.002–0.064 | — |
| m2_level | [0.02, 0.35] | multi-hour run + gap_r1 | 0.035–0.066 | 19% of upper |
| m3_no_clipping | [0.0, 0.02] | multi-hour run + 410 windows | 0–0.935 | **4674%** |
| m4_vocabulary_breadth | [8, –] | multi-hour run | 11–23 | 138% of lower |
| m5_not_converging | [0.75, 2.0] | multi-hour run + **15-run ablation** | 0.915–1.016 | 51% |
| m6_texture | [2.0, 8.0] | multi-hour run + gap_r1 | 3–5 | 62% |
| m7_spectral_gap_settles | [0.02, 0.45] | multi-hour run | 0–0.011 | 2% |
| m8_in_band | [400, 4000] | multi-hour run + gap_r1 | **383**–1802 | 45% |
| m1_audible_when_driving | [0.0, 0.015] | multi-hour run + 861 driving windows | 0–0 | **never non-zero** |
| m9_turnover | none, **by design** | 100 windows | 0.102–0.655 | — |

## The tool was wrong twice, and that is the report's main content

**False alarm 1: "no bound" flagged as a defect.** `m1_not_silent` and
`m9_turnover` have no acceptable range, and the first version listed both as
concerns. They are unbounded *deliberately*, and m9's own entry explains why:

> DESCRIPTIVE ON PURPOSE. An upper bound near 0.8 is available from the data and
> is refused: it would rest on one listener's judgement of two runs, it would be
> fitted to a distribution that contains the failure.

That is the charter declining to draw a line it cannot justify — precisely the
behaviour this audit exists to encourage. The tool inverted the finding.
`m1_not_silent` is the same: demoted to description in edition 4 because it
counted a compositional choice as a fault.

**False alarm 2: "derived from one run" for seven metrics.** The regex matched
`6h run` and reported "one run", which read as though most of the charter rested
on a single session. It does not. The derivations cite the 6 h run **and**
`gap_r1` — two runs — and `m5_not_converging` spans *"the 15-run ablation or the
6 h run"*, which is sixteen. The tool manufactured a finding out of its own
pattern-matching.

Both were caught by reading the derivations the tool was summarising. An audit
tool earns no more trust than the thing it audits, and this one needed correcting
twice in twenty minutes.

## What survives the corrections

**m8_in_band has discriminated.** It read **383.0** on `live_260915_171908`,
below its 400 floor, and was marked FAIL. A metric that has actually failed once
has demonstrated it can.

**m1_audible_when_driving has not.** Zero across 3,555 driving windows, with a
1.9 dB margin to the threshold. Live, correctly conditioned, never fired — see
`2026-09-17_m1_driving_not_vacuous.md`.

**Two bounds rest on a single reference point**: `m4_vocabulary_breadth` and
`m7_spectral_gap_settles`. m7 is SUSPENDED in any case, so only m4 is load-bearing
and thin.

**`clicks_per_second` still has no bound at all**, and has closed a question three
times. Filed as #113.

## The claim this supports, and the one it does not

It does **not** support "the charter is well-founded". Two bounds are thin, one
metric has never fired, and one heavily-used number has no threshold.

It does support something narrower and more useful: **the charter's gaps are
findable from its own files, and where it lacked evidence for a line it declined
to draw one rather than drawing a convenient one.** m9's refusal is the strongest
single piece of evidence in this audit, and it is a refusal.

Re-run it whenever a bound is added or a metric is retired:

```sh
python3 tools/audit_threshold_provenance.py
```
