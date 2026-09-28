# λ₂ = 1 because the operator has two sealed worlds, split by `@slow`

**17 September 2026.** Answers the open half of #114, left as *"Not claimed: why
λ₂ = 1. `TransferOperator.sc` is unread."* It is read now, and the answer comes
from the operator's own stored counts, not from the code alone.

## The finding

The transition graph has **exactly two strongly connected components, and both
are closed** — no edge leaves either one:

| class | cells | counts |
|---|---|---|
| plain | 190 | 28,079 |
| **every cell suffixed `@slow`** | 27 | 15,994 |

Transitions **within** a regime: 44,073. Transitions **across**: **0**.

Two closed classes means two independent stationary distributions, so the
transition matrix has eigenvalue 1 with multiplicity 2. Computed directly from
`mutable/memory.json`, the top five |eigenvalues| are:

```
[1.0, 1.0, 0.6735, 0.5, 0.4997]
```

λ₂ = 1 exactly, so `gap = 1 - λ₂ = 0` exactly. Not a numerical artefact, not a
degenerate estimator: **the chain is reducible, and the operator is reporting
that correctly.**

All 27 `@slow` stems also exist unsuffixed — `an` and `an@slow`,
`brcrhm2609051311x1` and `brcrhm2609051311x1@slow`, and so on for all 27. The
same machine is two states that can never reach each other. This is the same
`@bucket`-in-the-machine-path confusion recorded as #97; it survives inside the
operator's key.

## Two hypotheses I raised and killed first

Recorded because both were plausible and both were wrong, and the refutations
were cheap.

1. **"Unobserved rows are filled uniform, so the fill is distorting λ₂."**
   Refuted: **all 217 rows are observed.** The uniform fill never executes. Worth
   more than the refutation, though, is what it implies — see below.

2. **"The observed rows are self-loops, so the chain sits still."** Refuted by
   measurement. Replicating `TransferOperator`'s exact power iteration in numpy
   over constructed matrices:

   | matrix | λ₂ | gap |
   |---|---|---|
   | one observed row, pure self-loop | 0.9954 | 0.0046 |
   | one observed row, 90% self-loop | 0.8951 | 0.1049 |
   | 5 rows, strong self-loops | 0.9870 | 0.0130 |
   | **the actual operator** | **1.0000** | **0.0000** |

   And in the actual data the median self-loop probability is **0.032**, the
   maximum is **0.500**, and **no row is a pure self-loop.** The chain is not
   sitting still; it is running in two separate rooms.

   The tell that killed it: observed λ₂ ranges 0.9997–**1.0003** across runs.
   A value above 1 is impossible for the second eigenvalue of a stochastic
   matrix, so 1.0000 was an exact structural 1 with iteration noise, not a
   self-loop's approach to 1.

## A twelfth built-and-inert instance, and a precise one

`TransferOperator.sc:143`:

```supercollider
// row-stochastic. An UNOBSERVED row is uniform rather than zero, so the
// chain stays irreducible and the stationary distribution is defined.
```

The comment states a guarantee: irreducibility. The mechanism that would deliver
it fires **only on unobserved rows**, and there are none. So the safeguard is
inert, the guarantee does not hold, the chain is reducible, and the stationary
distribution is **not** unique — which is exactly what the comment promises
cannot happen.

New variant of the pattern: not a parameter wired to nothing, and not a metric
reading the wrong column (#114's first half), but **a correctness guarantee whose
trigger condition never occurs.** It reads as a proof and functions as a comment.

## What this changes

**m7 stays suspended, and now for a stated reason.** Its bound came from a run
where `gap` ran 0.295–0.422. A gap of 0 is not a converged chain and not a
degenerate estimator; it is a chain that has been cut in two. No threshold should
be derived until the cut is repaired, because the statistic is not measuring
mixing at all.

**The operator's accumulation is a separate problem and still stands.** 44,073
transitions carried across every run, growing +1 per window, so an eight-hour run
moves it by 7%. Repairing reducibility does not repair that.

## Not claimed

- That `@slow` is the *only* thing that splits the chain. Two classes is what the
  present data shows; a third could appear with another suffix regime.
- Which fix is right. Stripping the suffix from the operator key, keying on
  (machine, bucket) as an explicit pair, or letting the forgetting operator (#45)
  decay the sealed class are all open. Choosing needs the musical intent behind
  `@slow`, which is Roberto's call, not a code question.
- That repairing this makes m7 pass. It makes m7 *meaningful*; whether the gap
  then lands inside [0.02, 0.45] is an empirical question for after the repair.

## Reproduce

```sh
python3 - <<'PY'
import json, numpy as np
op = json.load(open("workdir_music/mutable/memory.json"))["operator"]
cells = sorted(set(op) | {c for r in op.values() for c in r}, key=str)
i = {c: k for k, c in enumerate(cells)}
M = np.full((len(cells),)*2, 1/len(cells))
for c, row in op.items():
    r = np.zeros(len(cells))
    for b, v in row.items(): r[i[b]] = v
    if r.sum(): M[i[c]] = r/r.sum()
print(np.sort(np.abs(np.linalg.eigvals(M.T)))[::-1][:5])
PY
```
