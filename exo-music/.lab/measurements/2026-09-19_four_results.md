# Four results in one afternoon: dwell, coverage, early warning, the kernel hole

**19 September 2026.** Four investigations run in parallel after the A-B-A-C-A-D
sequence was scored. Three of them found that something this project believed
was wrong. Recorded together because they share one shape.

---

## 1. The dwell movement was the K sweep

`version_operator.py` selected K and refit k-means **inside each arm**, then
reported `empirical dwell = len(lab)/runs` over those labels.

| | A1 | C1 | A2 | C2 | A3 | C3 |
|---|---|---|---|---|---|---|
| K the arm chose | 10 | 5 | 10 | 4 | 10 | 7 |
| dwell, per-arm fit | 5.6 | 11.5 | 4.5 | **17.8** | 4.8 | 8.5 |
| dwell, one frozen partition | 6.1 | 7.1 | 5.5 | **5.1** | 4.8 | 5.4 |

All three champion arms chose K=10; every candidate chose lower. Dwell against
its own K is close to a function of K alone: Pearson(1/K, dwell) **0.987**,
Spearman(K, dwell) −0.94, strictly monotone. Pinning K at 10 and changing
nothing else gives 5.6 / 6.5 / 4.5 / 6.0 / 4.8 / 4.8, so fixing K alone removes
nearly all of the movement.

Under the frozen partition the A-A floor is 0.67 and the candidate deltas are
+0.97, −0.36, +0.52. The one that nominally clears is C1, which is
`self_ingest_weight` — the knob the running factory never reads. A knob that
changes nothing "exceeding" while the knobs that reach code do not is the
signature of noise.

And 0.67 is itself too small. Splitting each **champion** arm at its midpoint,
same knob throughout, gives 15 pairwise spreads with median **6.50** and max
12.45. The largest candidate delta is 0.97, an order of magnitude below the
spread from cutting one unchanged arm in half. The `metrics` cell source agrees
harder: 2.9 / 2.8 / 3.0 / 3.0 / 3.0 / 3.1, deltas −0.08 / +0.00 / +0.06.

Why the cells shrink: under their own fits the candidates were described in 4 to
7 cells, one of C2's at 69% occupancy, while champions used 10. Fewer cells,
fewer label changes, fewer runs, longer `len(lab)/runs` by arithmetic.

**Fixed.** `version_operator.py` now takes `--fit-partition` and `--partition`.
A frozen partition carries K, centroids, the standardisation and theta; the
scaler is load-bearing (re-deriving it per arm moves C2 by +1.4 and flips its
sign against A2). Per-arm mode still works and now stamps its own dwell line
`NOT COMPARABLE ACROSS ARMS`. Re-sealed `82b818c0` → `b6027e47`.

**Still leaking, recorded not fixed:** the judges are an online learner and are
not frozen by any of this, so two arms on one partition are still described by
two differently-trained judge populations. A genuinely frozen readout needs
frozen judge weights, or the `metrics` source, which has no learner. And fitting
on the pool includes the arms being differenced: the partition is a description
of this run, not a prior. It is a prior only for arms that run after it.

---

## 2. Coverage is retired, before adoption

The pre-registration was mine, written 18 September. Both of its load-bearing
claims fail.

**The radius rule contradicts its own worked number.** It says `0.12 × median
nearest-neighbour spacing` and claims that is "approximately 0.09". Measured:
nearest-neighbour spacing 0.3063, so the rule gives **0.0368**. The 0.09 comes
from `0.12 × median pairwise distance` (0.7526). A factor of 2.5. At 0.0368,
factory coverage is **0.0% on every arm from 4 September onward** — a metric
that cannot fire, which is the m7 fault in new clothes.

**The +18.0 separation is one run, and it is the maximum of sixteen.** It
reproduces digit for digit on `live_260831_011908` — verified independently at
+19.1 — and the prereg presents it as a three-run finding. Across all 16 arms of
800+ windows at the same radius:

```
+19.1  31 Aug        +1.1  four arms        0.0  five arms
 +9.0   1 Sept       +2.2  three arms      -1.1 / -2.2 / -3.4  three arms
```

**Median 0.0. Three negative. No arm since 2 September exceeds +2.2.** One of
the three cited runs was never significant (p = 0.125 at 200 reps). The regime
inversion is a property of 31 August.

Two further faults, either sufficient on its own. **48 of the 89 anchors were
never reached** by ~40,000 windows across 16 arms, and 39 have no section within
0.05 anywhere in the current 3,096-section memory, so over half the metric is
dead by construction. And the statistic is a coupon-collector union count,
**monotone in window count** (3.4% at N=400 rising to 20.2% at N=2487 on one
run), so arms of unequal length are not comparable — which the prereg's "800+
windows" floor invites.

A circularity, recorded rather than asserted: the anchors were minted from the
factory's early history and the table was computed on runs of that same era.
Minimum anchor-to-window distance is 0.014–0.018 on those three runs and
0.029–0.110 on all thirteen later ones.

`tools/coverage_metric.py` is kept so that finding it does not read as an
oversight, with a `_do_not_wire` note in the registry.

---

## 3. Early warning enters as a veto

The one thing today that survived its calibration, and it was strengthened in
the process.

| set | n | fired |
|---|---|---|
| factory arms, 16 logs, 31 Aug to 19 Sept | 40 | **0/40** |
| unrelated FMA, 306 artists per arm, geometry-matched | 140 | **1/140 = 0.71%** |
| ramped AR(1) fold | 30 | **30/30** |
| no-trend control | 30 | 0/30 |
| variance-only rise (no autocorrelation rise) | 30 | 3/30 |

0.71% against a nominal 1% for a p99 bound is the bound doing what it promises,
not a defect. Rank separation from the fold 0.996. The 3/30 on a variance-only
rise is the `min()` conjunction correctly refusing half a signal.

**The negative control in my pre-registration was wrong** and was replaced: it
named two arms that are consecutive slices of one log. Forty arms across sixteen
logs is the real control. One of those forty sits only 0.030 from its own bound,
so the veto is closer to firing on historical factory material than the two-arm
control suggested.

**It is specific, not sensitive.** Because the bound is bootstrapped from the
arm's own series, a trending arm inflates its own bound. Detection is
near-certain at the registered alternative and about even at φ₁=0.80. A passing
JR is weak evidence of absence. Expected spurious block rate ~1.4% of gates.

**Calibrated on master peak only.** Unrelated music has no transfer operator, so
no spectral-gap series exists for it and none was invented. The gap series
inherits the finding; it is not tested. Recorded in the registry entry.

The saturation check had to be reformulated to be capable of failing: read
literally, diverse JR spans [−1.617, +1.536] and factory JR spans
[−1.541, +1.420], so "scores in the same range" holds and the measure would be
condemned — on a statistic that has no absolute scale, because its bound moves
with each arm. Exceedance rate and rank separation are the commensurable
quantities and both can fail.

---

## 4. The kernel hole is still open, and edition 7 did not close it

`restore_m1.py` proposed a metric on **requested** amplitude to give `n1_audible`
a third failable metric against a level fault. Measured against
`rehearse_kernel_real`'s own degradations:

```
baseline quiet-request rate 0.0259
  -6 dB / -12 dB / -20 dB / -40 dB / vocab4 / freeze / clip.05
  -> 0.0259 every time, delta 0.000000
```

Bit-identical under every fault. The reason is structural and correct: requested
amplitude is **upstream of the gain path**, in the same level-blind family as
m4, m5, m6 and m8. It would add a fourth metric under `n1_audible` that passes
while the factory is 40 dB down and inaudible. **No third failure. The kernel
still does not fire.**

Two further reasons not to adopt it as written. Its bound would be on `rate`
while its permutation null tests `longest` — the file's own docstring says the
shuffle cannot change the rate — so the null is honest and bears on a different
statistic. And the spread forbids a scalar bound: across 46 runs, rate median
0.0434, min 0.0083, max 0.4429, **53× min to max**, one outlier carrying the
tail. The file's own instruction (bound above the `no` runs, below the `YES`
runs) requires `0.0723 < b < 0.0238`, which is unsatisfiable. Also: `--derive`
scores 46 of 209 logs and does not say so.

**Recommended against.** The quantity is worth keeping — a factory that asks for
nothing is a failure mode worth watching — but under its own key, bounded on the
statistic its null actually tests, and not presented as closing this hole.

**What would close it** is depth, not count. m2_level reads 0.0004 against a
floor of 0.02, fifty times out, and no number of level-blind metrics converts
that into a third failure. Adding metrics to reach a count treats the tolerance
arithmetic as the fault.

Bookkeeping: `restore_m1.py --commit` would `KeyError` on `m1_not_silent`, since
edition 7 renamed it to `d1_silence`. That is luck, not design. The migration
must add a **new** key: `d1_silence` is delivered silence, the proposal is
requested silence, and overwriting one with the other would destroy the
edition-4 and edition-7 provenance.

---

## The shape these share

Four measures, four ways of being wrong about a number:

- **dwell** moved because its state space was re-estimated inside each arm
- **coverage** rested on the maximum of sixteen presented as three
- **m7**, earlier, measured the operator's age
- the proposed **m1** would pass under the fault it was written to catch

Each was found by asking what the measure does when nothing has changed. That
question is cheap and this project has now had to ask it five times.
