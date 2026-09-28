# The 1 September clicking verdict rested on one sample (#103)

**17 September 2026, 02:00.** Resolves the note left open in
`2026-09-16_numerical_blowups.md`:

> It does not sit comfortably beside the record from 1 September, which declared
> clicking solved at 1.01 clicks/s on the delivered stream. Either that
> measurement did not cover a blow-up event, or the rate has changed, or the two
> are measuring different things. **Unresolved.**

Three hypotheses. The third is now refuted and the first two are answered by a
fourth the note did not consider.

## Hypothesis 3 — "measuring different things" — REFUTED

`bisect_report.click_stats` high-passes at 8 kHz before looking, which raised a
fair doubt: a band-limited low-frequency excursion might be invisible to it.

Tested rather than argued. Ten 13 ms full-scale bursts of known shape were
injected into real delivered audio and the detector run, unchanged, before and
after. `tools/test_click_detector_sees_blowups.py`:

| burst | clicks/s | delta | worst ratio | counted |
|---|---|---|---|---|
| baseline, no injection | 8.47 | — | 64 | — |
| broadband | 8.83 | +0.37 | 65,588 | yes |
| 10 kHz tone | 8.83 | +0.37 | 129,967 | yes |
| 1 kHz tone | 9.07 | +0.60 | 1,845 | yes |
| **200 Hz tone** | **9.03** | **+0.57** | **6,931** | **yes** |
| DC step | 9.13 | +0.67 | 11,678 | yes |

It counts every shape, including the low-frequency one the highpass made me
doubt. The detector was never blind to blow-ups. The two measurements were
measuring the same thing.

## The fourth hypothesis: the verdict was n = 1

From the commit that closed it, `00b1e72`, 1 September 11:36:

```
DELIVERED STREAM, now              clicks/s 1.01   worst  35.3
delivered via loopback, 31 Aug     clicks/s 4.32   worst 163.0
offline render, no device at all   clicks/s 1.48   worst   9.4
```

One row. One number. One sample. And the conclusion: *"the clicking is gone."*

## What one sample is worth, measured

Thirty-eight ten-minute segments of delivered audio from 16 September,
15:13–21:23, scored with the same detector:

| | clicks/s |
|---|---|
| p5 | 0.51 |
| p25 | 3.07 |
| **p50** | **5.50** |
| p75 | 10.02 |
| p95 | 19.36 |
| max | 41.53 |

mean 7.93, sd 8.15.

**6 of 38 segments — 16% — sit at or below 1.01.**

So a single 30-second sample drawn from a stream like today's reads ≤ 1.01 about
one time in six. The 1 September figure is an unremarkable low draw from a wide
distribution, not evidence of a quiet stream. Three consecutive samples all
reading ≤ 1.01 would have had probability 0.004, and would have meant something.
One did not.

*(Two segments excluded and named: the 21:33 one is truncated because the factory
was stopped at 21:32, and the 01:51 one is the new run before sound started,
peak 0.000.)*

## What may and may not be concluded

**May:** the verdict was not supported by its evidence. A property with a
population sd of 8 was declared solved on a single draw, and no repeat
measurement was ever taken.

**May:** the detector sees blow-ups, so the two records were never in conflict
about instrumentation.

**May NOT:** that the rate on 1 September was 5.5. Today's stream is not that
stream — different corpus, different machines, and the FIFO topology postdates
it. These numbers describe 16 September and nothing else. The comparison here is
between *a claim and the sampling it rested on*, not between two streams.

**May NOT:** that the current rate is bad. There is no pre-registered bound for
clicks/s at all, which is its own gap: the figure has been quoted as a verdict
three times with no threshold behind it.

## What follows

1. `clicks_per_second` needs a **pre-registered bound**, derived from a null,
   before it is quoted as a verdict again. Until then it is description.
2. Any future "clean" claim needs **n > 1 and a stated spread**. The charter's
   own metrics are computed over hundreds of windows; this one was not.
3. The blow-up record's "Unresolved" note can be closed, replaced by the above.

## The shape of this, again

The eighth instance yesterday was a capability built and wired to nothing. This
is the neighbouring failure: **a measurement taken once and treated as a
property.** Both produce a record that reads as settled and is not, and both are
found the same way — by going back to what the claim actually rested on.
