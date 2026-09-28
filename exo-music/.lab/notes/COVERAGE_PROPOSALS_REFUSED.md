# Coverage: ONE metric, at a tight radius — not 89, and not none

> **CORRECTION, same day.** Everything below the line was written from a
> 130-window log and concluded that coverage cannot carry a bound at all. That
> was wrong, and it was wrong because the sample was too young for the regime
> that matters. Re-run on three runs of 2,000+ windows, the picture reverses at
> tight radius:
>
> | radius | factory | null | diff |
> |---|---|---|---|
> | 0.339 | 100.0% | 100.0% | +0.0 |
> | 0.226 | 73.0% | 96.6% | −23.6 |
> | 0.090 | 20.2% | 2.2% | **+18.0** |
>
> Two opposite regimes. LOOSE radius: the null wins, because a diffuse
> trajectory passes within a large ball of everything, and breadth is what a
> shuffle is good at. TIGHT radius: the factory wins by a wide margin, because
> it genuinely OCCUPIES regions rather than passing near them — which is what
> `operator_weight` buys and what destroying the path removes.
>
> So the coherence objection below is real but bounded: it applies to a coverage
> metric with a generous radius, and inverts at a strict one. Coverage IS
> measurable, at a radius around 0.09 (about 0.12 of the median anchor spacing).
>
> **What this still does not license: adopting a bound today.** Across the three
> long runs the factory's tight-radius rate is 5.6%, 20.2% and 11.2% against a
> null of 3.4%, 2.2% and 2.2%. The separation is consistently positive and the
> factory's own value varies nearly fourfold, so any bound set now would be set
> on one draw from a wide distribution — the mistake m7 and the 0.9 threshold
> both came from. The weight sweep is generating more arms; the bound should
> wait for them.
>
> Standing recommendation, revised: adopt ONE consolidated coverage metric over
> all 89 anchors at a tight radius, with the bound derived once the sweep has
> characterised the spread. Refuse the 89 as individual metrics regardless — that
> part of the argument survives untouched.

---

# (superseded) The coverage proposals encode a criterion that fights coherence

Analysis 2 Sept 2026, `tools/triage_proposals.py`. The decision is the
architect's; this is the measurement it should rest on.

## What was asked

89 `coverage_holdout` proposals, norm `n2_varied`. Each says: *I reached a region
of descriptor space I had not occupied before; anchor it, so future versions must
still be able to reach it.* Each one, adopted, mints a new charter metric.

## Three reasons to refuse, in increasing order of importance

**1. Adopting them all is not possible.** 89 new metrics on top of 8 gives a
97-entry charter. A charter that long is not a constitution, it is a log.

**2. Consolidating them into one metric does not save it.** The obvious repair --
one metric over all 89 anchors, requiring some fraction to be reached -- needs a
radius. At the median anchor spacing (0.753) the factory reaches 100% of them,
and so does a null. A bound there could not fail.

**3. The reason it must be refused: at every radius, the NULL DOES BETTER.**

    radius     factory      null
     0.753      100.0%     100.0%
     0.452       78.7%      94.4%
     0.301       27.0%      53.9%
     0.188        3.4%       7.9%

The null keeps the run's own descriptor marginal and destroys only the PATH. So a
trajectory with no navigation covers MORE of the factory's own anchored regions
than the factory does.

This is not noise, and it is not a flaw in the factory. It is what persistence
looks like: `operator_weight` is 0.35, the factory is built to linger and to let
behaviour carry across windows, and anything that lingers covers less ground than
independent draws from the same distribution.

**Therefore a coverage metric would be improved by making the factory more
random.** It would reward abandoning exactly the coherence `n3_coherent` asks
for. That is a self-generated criterion pulling against the charter it belongs
to, and this project has already watched three of those become convergence
engines from the other direction.

## What should happen instead

- **Refuse all 89**, with that reason recorded. A refusal with a reason is an
  answer, and P271's participation is only genuine if proposals can be refused.
- **Adopt the widest voice_range proposal** (#90, 8 concurrent voices), widening
  m6_texture to [2, 8]; refuse the other three as subsumed rather than wrong.
- **Fix the proposer.** Its novelty test measures distance from the run's own
  history, so it never saturates: a factory that runs forever proposes forever.
  Novelty should be measured against what is ALREADY ANCHORED, so the rate of
  proposals falls as the charter absorbs them.

## What this does not say

It does not say the factory lacks variety. `m4_vocabulary_breadth` passes at
36-39 distinct behaviours per 100 windows. It says that COVERAGE OF DESCRIPTOR
SPACE, measured this way, cannot distinguish the factory from a shuffle of
itself, and so cannot carry a bound. A different formulation of n2_varied might
work; this one cannot.
