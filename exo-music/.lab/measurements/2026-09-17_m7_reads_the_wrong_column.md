# m7 has been scoring the wrong column, and the operator has gone degenerate

**17 September 2026, 02:25.** Two findings, one definite and one observed but
unexplained. They are separate and are kept separate.

Came out of #46, "derive m7's replacement bound from a shuffled null". No bound
was derived, because the premise turned out not to hold.

## Finding 1: the metric reads `lambda2` and calls it `gap`

The factory writes, `live_factory.scd:3499`:

```
OPERATOR  winCtr, op.gap, op.lambda2, op.cells.size, dominant, op.total
```

`score_charter.read()` parses it as:

```python
p = line.split()[1].split(",")     # p[0] is the window number
gap.append(float(p[2]))            # p[1] is gap.  p[2] is LAMBDA2.
```

The window number is split off first, so `p[1]` is `gap` and `p[2]` is
`lambda2`. **`m7_spectral_gap_settles` has been computing the interquartile range
of lambda2 for its entire life.**

Its bound came from the other column. The derivation reads:

> 6h run: gap ran 0.295-0.422 at p10-p90, IQR well inside. PASSES.

That describes `gap`. The code has never scored it.

**Ninth instance of the pattern**, and a new variant: not a parameter wired to
nothing, but a metric whose name, derivation and bound describe one quantity
while its code reads the column beside it. Off by one field.

## Finding 2: both columns have gone degenerate

Measured across the last three runs with ≥ 100 windows:

| | value | range |
|---|---|---|
| `gap` (p[1]) | **0.0000** | 0.0000 – 0.0003 |
| `lambda2` (p[2]) | **1.0000** | 0.9997 – 1.0003 |
| IQR of either | **0.00000** | — |

These are consistent with each other: gap = 1 − λ₂, so λ₂ = 1 gives gap = 0.

**λ₂ = 1 means the operator has not mixed.** A second eigenvalue at unity is a
reducible or periodic chain — not a converged one. Convergence would drive λ₂
*down* and the gap *up*.

And the operator is not accumulating structure. Over 2,912 windows of the 8-hour
run of 16 September:

| | |
|---|---|
| `cells.size` | **217 → 217**, one distinct value, zero growth |
| dominant cell | **`bu` in 2,912 of 2,912 windows — 100%** |
| `total` | 38,970 → 41,881, exactly **+1.00 per window** |

One cell dominated every window of an eight-hour run, and no new cell was ever
created.

## What this does and does not change

**The suspension of m7 stands, and its stated reason no longer fits.** The
2 September note suspended it because *"a cumulative estimator converges, so the
interquartile range of its lambda2 falls with accumulation"* — gentle convergence
producing a shrinking spread. What is observed is not gentle: λ₂ is pinned at
exactly 1.0 and the IQR is exactly 0. That is degeneracy, not convergence, and
it would look identical from the metric's face.

**The gap has collapsed since the derivation was written.** It ran 0.295–0.422 on
the 2 September run and is 0.0000 now. Something changed between then and now and
nothing in the record says what.

**No bound can be derived for m7 in this state**, from a shuffled null or
otherwise. A statistic with zero variance across 2,912 windows has nothing for a
null to be compared against. #46 cannot be completed until the operator is
understood; deriving a threshold now would be fitting a line to a constant.

## What is NOT claimed

That I know why λ₂ = 1. `TransferOperator.sc` has not been read in this session,
and the eigenvalue computation, the cell keying and the stationary-vector code
are all unexamined. Candidates, none tested:

- the transition graph genuinely has disconnected components, so no single
  stationary distribution exists
- the operator is dominated by a self-loop on `bu` and the rest is unreachable
- the eigenvalue routine degenerates on a matrix this sparse or this stale
- `memory.json` carries counts from every run ever, so the live run's 2,912
  transitions are 7% of a 41,881-count history and cannot move it

That last one is worth weighing first: **a factory running for eight hours moved
the operator by one count per window against a cumulative total of 41,881.** If
the operator cannot be moved by a whole run, then whatever it measures, it is not
this run.

## Next

1. Fix the column. `p[2]` → `p[1]`, and re-score history against the real gap.
   The bound may or may not survive; that is a separate question from reading the
   right number.
2. Read `TransferOperator.sc` and establish why λ₂ = 1. Until then #46 stays
   open and m7 stays suspended.
3. Consider whether an operator that accumulates across every run without decay
   can describe any single run at all. The forgetting operator (#45) exists;
   whether it applies here has not been checked.
