# λ for a music factory: novelty as the unit of account, not as a bound

A design, not an implementation. It answers two questions at once, which is the
reason to believe it: **how does a music-making factory post a price**, and **what
do we do with the novelty measure that failed as a metric**.

## The problem with novelty as a metric

The 89 coverage proposals asked to anchor regions the factory had reached, each
as a bound. Measured against a null:

| radius | factory | null |
|---|---|---|
| 0.339 | 100.0% | 100.0% |
| 0.226 | 73.0% | 96.6% |
| 0.090 | 20.2% | 2.2% |

At a loose radius the factory is WORSE than a shuffle of itself, because it
lingers and a diffuse walk covers more ground. At a tight radius it is far
better, because it genuinely occupies regions. So novelty-as-coverage is either
vacuous or perverse depending on a radius nobody has a principled way to pick,
and a bound built on it would reward the factory for becoming more random —
against `n3_coherent`, which asks for the opposite.

The mistake is the FORM, not the quantity. Novelty is a good thing to measure and
a bad thing to bound.

## The problem with λ in a factory that refuses a total

The paper: *"λ's value is the marginal worth of that constraint at the factory's
current operating point; it is a kind of a shadow price, defined only where the
factory stands and produced as a by-product of operating there. It reaches the
committee as a speculative price posted by the factory."*

A shadow price is normally the derivative of an objective with respect to
relaxing a constraint. This factory has no objective by construction —
`score_charter` refuses to emit a total, because three self-generated scalars
became convergence engines. **So there is no gradient to take, and the textbook λ
does not exist here.**

## The proposal: price constraints in novelty forgone

Both problems solve each other. Novelty needs a job that is not bounding;
λ needs a currency that is not an objective.

> **λ(c) = the expected novelty the factory forgoes, per window, by obeying
> constraint c at its current operating point.**

Concretely, for a constraint that CLAMPS a choice:

1. At each decision, the factory already forms a candidate set — machines in
   `avail`, grains passing `vet`, a voice count before the policy clamp.
2. Some candidates are excluded by the constraint. Measure which.
3. Score each excluded candidate by its novelty **at the tight radius**, the
   regime where the factory demonstrably beats its own null: distance in
   descriptor space to the nearest region it already occupies.
4. λ(c) is the mean novelty of what the constraint excluded, per window.

Units: novelty per window. Not utility, not reward — the factory's own currency,
in the only terms it has.

## Why this is worth doing

**It is genuinely a shadow price.** It is the marginal worth of relaxing the
constraint, measured where the factory currently stands, and it changes as the
factory moves. A constraint that forbids nothing the factory wants costs 0. One
that forbids exactly what it is reaching for is expensive. That is what a shadow
price means.

**It cannot become a convergence engine.** λ is not something the factory
maximises: nothing in selection reads it. It is a report the factory posts about
what its constraints cost, and the architect reads. That is precisely the paper's
"speculative price posted by the factory" reaching a committee — and it is why
this is safe where E3, the audibility score and the transfer operator were not.

**It makes adoption comparable.** Today the 89 proposals and the 4 voice-range
proposals are incommensurable — they are all just requests. Priced, they become
a list with magnitudes, and refusing a cheap constraint is obviously different
from refusing an expensive one.

**It uses the novelty measure at the radius where it works.** The tight radius
was already established empirically; here it is load-bearing rather than
arbitrary, because we need "how new is what you were denied", not "did you cover
the space".

## What can and cannot be priced

**Priceable: constraints that clamp a choice.** `m6_texture` via voices_min/max;
`self_ingest_weight`; `master_gain`; the transient gate on admission. Each
excludes candidates the factory would otherwise have taken, and the exclusion is
observable.

**Not priceable: constraints that describe an outcome.** `m2_level`,
`m3_no_clipping`, `m8_in_band`, `m1_audible_when_driving` do not forbid a choice;
they report what happened. There is no excluded candidate set, so there is no
opportunity cost, so **λ is undefined for them and must be reported as undefined
rather than as zero.** A price of zero says "this constraint is free"; an
undefined price says "this is not the kind of thing that has a price". Conflating
them is how a metric becomes decorative.

That division is itself informative: it says which parts of the charter are
governing the factory's choices and which are only watching its results.

## First implementation, deliberately narrow

Price ONE constraint — the voice clamp — because it is the one the factory has
already complained about four times. The factory logs its desired voice count
before the clamp and the count after; λ is then the novelty-weighted rate at
which the clamp binds. If λ is near zero, the four voice-range proposals were
asking for something worthless and the widening we just adopted cost nothing. If
λ is large, the clamp was expensive and the proposals were the factory reporting
a real constraint on its work.

Either answer is worth having, and neither is available today.

## What this does not settle

It does not say what a λ is WORTH — that a constraint costs 0.3 novelty per
window does not say whether to relax it. Pricing informs a judgement; it does not
replace one. The paper is explicit that λ reaches a committee, and the committee
still has to decide.

It also assumes novelty in the frozen descriptor basis is a reasonable proxy for
musical novelty. That is an assumption about the descriptor space, not a result,
and it should be stated wherever a λ is quoted.
