# Baseline on 92c1d6b: result

**27 September 2026, 02:10.** Plan: `2026-09-26_baseline_92c1d6b_plan.md`
(readings fixed before the data). Log `live_260926_205648.log`, booted
26 Sept 20:56. K = −1, knobs_to_factory 0, rung 2 inert, throughout.

## Integrity

| half | windows | CLOCKJUMP | BLOWUP | POOL_RESET | alloc failed | ACQUIRED | polyphony refusals | clip>0 | peak median | p99 | max |
|---|---|---|---|---|---|---|---|---|---|---|---|
| H1 | 19–818 | 0 | 0 | 0 | 0 | 1 | 3 | 1 | 0.048 | 0.463 | 1.697 |
| H2 | 819–1618 | 0 | 1 (w1474, peak 2.30) | 0 | 0 | 0 | 6 | 3 | 0.048 | 0.387 | 2.302 |

Both halves valid. Power on AC from about 22:00; no sleep.

## Coupling (`tools/layer_coupling.py`, n-null 200)

| half | pair | max r | lag | null95 | p | MI bits | null95 | p | rest ratio | null95 | p |
|---|---|---|---|---|---|---|---|---|---|---|---|
| H1 | macro-mid | −0.308 | 0 | 0.244 | 0.005 | 0.026 | 0.023 | 0.040 | 0.242 | 2.048 | 0.955 |
| H1 | macro-micro | −0.191 | 0 | 0.186 | 0.045 | 0.041 | 0.021 | 0.005 | 0.858 | 1.364 | 0.770 |
| H1 | mid-micro | +0.087 | −12 | 0.244 | 0.690 | 0.004 | 0.018 | 0.665 | 0.672 | 1.397 | 0.930 |
| H2 | macro-mid | −0.246 | 0 | 0.233 | 0.020 | 0.024 | 0.022 | 0.045 | 0.577 | 1.718 | 0.835 |
| H2 | macro-micro | −0.139 | 0 | 0.187 | 0.265 | 0.012 | 0.017 | 0.200 | 1.180 | 1.428 | 0.250 |
| H2 | mid-micro | −0.095 | −11 | 0.231 | 0.680 | 0.007 | 0.016 | 0.320 | 0.756 | 1.397 | 0.890 |

Rest share (macro / mid / micro): H1 0.090 / 0.058 / 0.291; H2 0.091 /
0.095 / 0.244. All three silent 0.000 in both.

## Drift, half to half (`score_charter.py` on each half with the log header)

m8 1693.1 → 1662.8 Hz (Δ 30); d2_turnover 0.633 → 0.639 (Δ 0.006); m4
34.5 → 35.5. Inside the composed writer's floor of 23 Sept (45 Hz /
0.003 over 25 h). Note: score_charter works on a slice once the log's
header lines (before the first window) are prepended; the "does not work
on a slice" line in the coupling records was the header missing.

## Reading (the plan's second case)

Either half null on a macro pair: **the baseline moved with 92c1d6b.**
H2 loses macro-micro (−0.139, p 0.265); H1 holds it at the edge (−0.191,
p 0.045). Macro-mid holds in both (−0.31, −0.25).

Across the four A arms on this build (26 Sept A1 and partial A2, H1, H2):
macro-mid negative and significant in 3 of 4, macro-micro in 2 of 4, both
in 1 of 4. Before 92c1d6b (five runs 19–22 Sept, part 1 A1 and A2) both
pairs held in every arm, macro-micro at −0.17 to −0.35. The anticoupling
is still there and weaker, macro-micro most: at 800 windows it sits near
its null bar.

## Consequence for the next arm

The voices_follow arm (K = 0, voices_follow off) is designed against this
run. Its test has to be on macro-mid, the pair that still clears its null
at 800 windows; a macro-micro verdict needs longer arms (1,600 windows or
more) or it will read noise as an effect. Candidate cause of the weakening,
untested: the polyphony bound (48 voices) caps the dense sections the
voice top-up used to fill.

## Addendum, 09:20: the whole run to window 4018, and at 1,600 windows

| block | windows | macro-mid r (p) | macro-micro r (p) | mid-micro r (p) |
|---|---|---|---|---|
| H3 | 1619–2418 | −0.229 (0.050) | −0.345 (0.000) | −0.185 (0.210) |
| H4 | 2419–3218 | −0.342 (0.000) | −0.231 (0.015) | −0.199 (0.080) |
| H5 | 3219–4018 | −0.257 (0.020) | −0.234 (0.020) | −0.150 (0.310) |
| L1 | 19–1618 | −0.281 (0.000) | −0.154 (0.030) | −0.087 (0.375) |
| L2 | 1619–3218 | −0.282 (0.000) | −0.294 (0.000) | −0.194 (0.005) |

No CLOCKJUMP to window 4054. At 1,600 windows both macro pairs are
negative and significant in both blocks; at 800, macro-mid in 5 of 5 and
macro-micro in 4 of 5. **Revised reading:** the anticoupling holds on
92c1d6b. What varies is macro-micro from stretch to stretch (−0.14 to
−0.35); 800-window arms are too short to judge it, 1,600 are enough. The
"baseline moved" reading above was one 800-window half. Arms are 1,600
windows from here.
