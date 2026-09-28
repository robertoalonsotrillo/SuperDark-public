# A spectral readout for the versioning strand

Design note and pre-registration, 6 September 2026. Nothing built yet.

## The proposal, as put

> Build the transfer operator over cells defined as profiles of judge scores
> across the charter's metrics, keep the running histogram of cell-to-cell
> transitions, and read the spectral gap. A wide gap means versions are durable
> and well defined; a narrow one means they are bleeding into each other.

The strand is right and the readout it asks for does not exist. Four things have
to change before it is built, and one thing has to be written down before we look.

## 1. The gap runs the other way

With eigenvalues `1 = λ₁ ≥ |λ₂| ≥ …` and gap `g = 1 − |λ₂|`:

- **Wide gap** → mixing time `≈ 1/g` is short → the chain forgets its starting
  cell within a few steps → there is no durable structure anywhere in the state
  space. This is versions bleeding into each other.
- **Narrow gap**, `λ₂ → 1` → slow mixing → the state space decomposes into
  nearly-invariant sets the chain rarely moves between. These are metastable
  states, and metastable is what "durable and well defined" means.

This is the standard Markov-state-model result: the count of eigenvalues near 1
is the count of nearly-invariant sets (Deuflhard & Schütte, PCCA+). Installed as
proposed, the readout would report versions at their most durable exactly when
the factory is bleeding fastest.

There is a fair alternative reading and it should be named rather than dismissed.
If the claim is that the factory has **one** identity and the question is whether
that identity is crisp, then a wide gap does say so: a single stationary
distribution reached quickly from anywhere. But "versions" in the plural, and
"bleeding into each other", is the metastability picture, and that is the narrow
gap.

**Neither is the readout the strand needs.** The gap is one number about mixing
speed. Versioning asks two questions, and two derived quantities answer them:

| question | quantity |
|---|---|
| how many versions are there? | count of eigenvalues with `|λᵢ| > θ` |
| how long does one last? | dwell time `−1 / ln|λ₂|`, in windows |

Report those. The gap is a by-product, and on its own it is ambiguous between
"one crisp version" and "no versions at all".

## 2. The cells cannot be raw metric profiles

Ten charter metrics at three bins each is 3¹⁰ = 59,049 cells. A long run yields a
few thousand windows. The transition matrix would be almost entirely empty and λ₂
would be sampling noise wearing a spectral name.

The machine operator works because its numbers are the other way round: 211 cells
against 28,155 observed transitions, about 133 per cell. That is the ratio to aim
for, so the cell count has to land in the low hundreds.

Two facts make this achievable. Most charter metrics **pass constantly** — a
metric that never changes contributes no information and multiplies the cell
count. And the metrics are **correlated**, because several read the same
underlying loudness and density. So cells should be built either from the three
or four metrics with real variance, or from the leading principal components of
the metric vector, binned. Which of the two is an empirical question: measure the
per-metric variance across the runs on disk first, and let that choose.

## 3. Persistence is the point and also the trap

m7 does not measure the factory. It measures the operator's **age**: the operator
persists across runs via `memory.json`, so its IQR decays with accumulated
history and m7 drifts whatever the factory does. That cost has been paid once and
the same trap is open here, because for versioning, persistence across runs is
not incidental — a version that cannot span runs is not a version.

So this is a decision, not a default:

- **Per-run operator.** Clean, no age confound, and no cross-run versioning,
  which is most of what the strand wants.
- **Persistent operator with the age controlled.** Report λ₂ against transitions
  seen, as a curve rather than a scalar, and compare only at matched history.
  Harder, and the only version of this that answers the question asked.

The second is the right one. It has to be built with the control in it from the
start, because retro-fitting a control to a scalar that has already been quoted
is what happened to the 0.9 drift threshold, and that number is still uncitable.

## 4. The null

The statistic is order-dependent, so a **shuffled cell sequence** — order
destroyed, marginal preserved — is a legitimate null here. That is worth stating
explicitly because it is the fourth null in this project and three of the first
three were wrong: the circular shift was invalid precisely because the statistic
it was applied to was order-*invariant*.

If observed λ₂ does not differ from shuffled λ₂, the readout is describing the
marginal distribution of metric profiles and saying nothing about versioning.

## 5. Leave the judges out

The proposal routes the cells through **judge scores**. The judges are the one
component here that has been shown not to work: nine of them plus nine tier-2
learners, both tiers passing their negative controls, both steering nothing, the
best beating chance by a margin that has never been comfortable. ¶484/¶486 named
operator cells as the wrong state space *because* the judges were no-swap-regret
learners.

Cells built on **measured metric values** need none of that. The judges would
insert a learned, weakly performing layer between the factory and the version
readout, adding a failure mode and no information. If the judges are wanted in
the picture, they belong as a separate arm to be compared against the direct
cells, never as the only path to them.

## What is pre-registered, before anything is built

The honest outcome to fix in advance is the negative one.

**An earlier attempt to find latent structure in this wake failed cleanly.** A
hidden-state model scored held-out log-likelihood per symbol of −3.0437 against
−3.0087 for a unigram: the latent state was *worse* than no latent state. There
is little sequential regime structure in this wake to cluster, and metastability
analysis asks that same question by another route.

So, fixed now:

1. **"One version, fast mixing, no durable structure" is an acceptable result**
   and will be reported as a finding, not treated as a failed build. It would say
   the factory does not decompose into versions readable off its own wake.
2. The threshold θ for counting eigenvalues near 1 is set **before** the spectrum
   is inspected, from the shuffled null: θ is the 95th percentile of |λ₂| under
   shuffling. Choosing θ after seeing the spectrum would let any spectrum yield
   any number of versions.
3. If the result is negative, the versioning strand rests on the **authored** half
   of P290 — the architect's commitment against further alteration — and not on
   anything read off the wake. That is a weaker claim than the proposal currently
   makes, and it would have to be written that way.

## Cost

`TransferOperator` already computes λ₂, the gap, the stationary distribution, and
since 5 September a sparse path. This is a second instance over a different
alphabet, plus a cell definition, plus the null and the age control. The code is
small. The measurement of per-metric variance that chooses the cell definition,
and the matched-history comparison, are the work.
