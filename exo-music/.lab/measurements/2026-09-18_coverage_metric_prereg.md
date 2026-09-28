# Pre-registration: one coverage metric, tight radius, bound UNSET

**18 September 2026.** Decision 4 of `.lab/notes/METRICS_REVIEW_2026-09-18.md`. The
radius rule is fixed here, before any bound is computed. The bound is
deliberately left unset and the conditions for setting it are stated.

## The proposal this answers

The factory has written 93 charter proposals. 89 are `coverage_holdout`: each
says the factory reached a region of descriptor space further than a threshold
from anything it had previously visited, names the norm it serves (`n2_varied`),
and proposes that region be held as a test criterion. This is P278 working as
written: a norm handed to the factory, a metric proposed back, as a holdout.

All 89 were refused as individual metrics, and that refusal stands. 89 metrics
each saying "return to this particular region" is a criterion that fights
coherence and would convert the charter into a checklist of places the factory
has already been.

What was NOT refused is the underlying quantity. `.lab/notes/COVERAGE_PROPOSALS_REFUSED.md`
records a correction made the same day it was written: on three runs of 2,000+
windows the picture inverts with radius.

| radius | factory | shuffled null | difference |
|---|---|---|---|
| 0.339 | 100.0% | 100.0% | +0.0 |
| 0.226 | 73.0% | 96.6% | −23.6 |
| 0.090 | 20.2% | 2.2% | **+18.0** |

At a loose radius the null wins, because a diffuse trajectory passes within a
large ball of anything and breadth is what a shuffle is good at. At a tight
radius the factory wins by a wide margin, because it occupies regions instead of
passing near them.

## The metric

**One** metric, over all 89 anchors, not 89 metrics.

**Test.** Fraction of the 89 proposed anchors whose ball of radius `r` contains
at least one window of the arm, where a window's position is its descriptor
vector in the frozen basis.

**Radius rule, fixed now.** `r = 0.12 × median nearest-neighbour spacing of the
89 anchors`, recomputed whenever the anchor set changes. On the anchor set of
18 September this evaluates to approximately 0.09, which is the radius the table
above was measured at.

The rule is stated as a ratio and not as the number 0.09 on purpose. A fixed
0.09 would silently change meaning if the anchor set grew denser; a ratio to the
anchors' own spacing keeps asking the same question. The choice of 0.12 is a
stipulation and is recorded as one: it is the value that produced the separation
above, and it was picked before this pre-registration instead of after seeing
several candidates.

**Norm served.** `n2_varied`.

## The bound is UNSET, and here is what would set it

Across the three long runs the factory's tight-radius rate was **5.6%, 20.2% and
11.2%** against a null of 3.4%, 2.2% and 2.2%. The separation is consistently
positive. The factory's own value varies nearly fourfold.

Any bound set on that is set on one draw from a wide distribution. That is the
mistake m7 and the 0.9 drift threshold both came from, and both had to be
withdrawn.

**Conditions for setting the bound, all required:**

1. At least **six** arms of 800+ windows, from runs not used to design this
   metric. The A-B-A-C-A-D sequence running today supplies six, and they are
   therefore SEEN by this document and may be used for the spread but not as the
   confirming sample.
2. The spread characterised: median, interquartile range, and minimum across
   those arms.
3. The bound set as a **floor only**, at a value below the observed minimum by a
   stated margin, so it asks "has coverage collapsed" and not "is coverage as
   high as the run I calibrated on". An upper bound is refused in advance for
   the reason m4's ceiling was removed: a ceiling on a variety metric penalises
   the factory for doing more of what its norm asks.
4. The per-arm shuffled null recomputed alongside, so the metric always reports
   its own separation and a saturation is visible the moment it happens.

Until all four hold, the metric is adopted as **descriptive**: computed,
reported, no pass or fail. This is the same standing `d1_silence` and
`d2_turnover` have, and it is honest about the state of the evidence.

## Why adopt it now instead of waiting

Three reasons, and the first is the one that decides it.

1. **The pre-registration exists before the bound.** If the metric is adopted
   after the sweep, the bound and the metric are chosen in the same act, having
   seen the data, which is the goalpost-moving the release policy forbids.
   Fixing the radius rule and the shape of the bound now, and computing only the
   number later, is the difference.
2. It converts 89 refused proposals into one authored record, which is what the
   paper means by a contribution being folded back into the charter (L278).
3. It is computable on every arm from today, so the spread accumulates instead
   of waiting to be produced.

## What is not claimed

That coverage is a good measure of variety. It measures whether the factory
returns to regions it has previously reached, which is one reading of `n2_varied`
and not the only one. `m4_vocabulary_breadth` reads the same norm through
behaviours and `d2_turnover` reads it through persistence; the three disagree by
construction and that is the point of having more than one.

That the 89 anchors are the right anchor set. They are where the factory went,
which makes them a record of its history and not a map of the space. An anchor
set drawn from the corpus instead of from the trajectory would ask a different
and possibly better question, and is not what this adopts.
