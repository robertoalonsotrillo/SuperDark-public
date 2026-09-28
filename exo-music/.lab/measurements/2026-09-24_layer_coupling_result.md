# Layer coupling run: result (part 1 of 2, PROVISIONAL)

**24 September 2026, 22:50.** Scored by hand (the scheduled check did not
start). Pre-registration: `2026-09-22_layer_coupling_prereg.md`; baseline:
`2026-09-22_layer_coupling_baseline.md`. Everything below is PROVISIONAL
pending Roberto's listening (rule 5, the ear's veto).

## What ran

Log `live_260924_101737.log`, booted 10:17 after a CoreAudio reset. Runner
`run_n_arms.sh`, 800 windows per arm, state
`harness/n_arms_260924_102256.json`. The run died at 17:24 at window 2387
when the Claude desktop app restarted and took its process group
(`2026-09-24_why_the_runs_died.md`). Three arms exist; C2 did not run here
and is running tonight on `live_260924_222853.log` as A C2 A (part 2).

| arm | K | windows | n | note |
|---|---|---|---|---|
| A1 | −1 | 29–823 | 795 | windows 24–28 excluded: the reload back to −1 lagged the runner by five windows |
| C1 | 0 | 828–1627 | 800 | |
| A2 | −1 | 1628–2374 | 747 | cut short by the death at 2387 |

Wall clock for the ear: C1 ran from about 12:52 to 15:20; A2 from 15:20 to
17:24. Segments in `/Volumes/FMA/superdark/segments`.

## Integrity (rule 4)

No CLOCKJUMP, no FILL_STALL, no BLOWUP in any arm; no `alloc failed` in
the server log. MASTER peak median 0.048 / 0.050 / 0.047, p99 0.422 /
0.452 / 0.425, max 0.997 / 1.116 / 0.892 pre-limiter; clip flag on 0 / 1 /
0 windows. ACQUIRED 0 / 1 / 1. m8 and d2_turnover per arm: not scored
here; `score_charter.py` on a log slice returns m8 0.000 and d2 n/a, so
the per-arm slice method in the task prompt does not work as written and
needs the segment ring; left for part 2.

## The coupling measure, per arm (`tools/layer_coupling.py`, n-null 200)

| arm | pair | max r | lag | null95 | p | MI bits | null95 | p | rest ratio | null95 | p |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1 | macro-mid | −0.328 | 0 | 0.228 | 0.000 | 0.049 | 0.020 | 0.000 | 0.789 | 1.852 | 0.630 |
| A1 | macro-micro | −0.242 | 0 | 0.223 | 0.025 | 0.027 | 0.024 | 0.025 | 0.518 | 1.396 | 0.990 |
| A1 | mid-micro | −0.200 | 0 | 0.232 | 0.080 | 0.006 | 0.019 | 0.495 | 1.019 | 1.340 | 0.395 |
| C1 | macro-mid | −0.259 | 0 | 0.210 | 0.010 | 0.029 | 0.020 | 0.010 | 0.807 | 1.653 | 0.625 |
| C1 | macro-micro | −0.235 | 0 | 0.160 | 0.000 | 0.089 | 0.015 | 0.000 | 0.600 | 1.195 | 1.000 |
| C1 | mid-micro | +0.091 | −16 | 0.193 | 0.800 | 0.010 | 0.016 | 0.145 | 0.880 | 1.482 | 0.645 |
| A2 | macro-mid | −0.296 | 0 | 0.255 | 0.005 | 0.042 | 0.028 | 0.005 | 0.224 | 1.827 | 0.950 |
| A2 | macro-micro | −0.348 | 0 | 0.242 | 0.000 | 0.109 | 0.024 | 0.000 | 0.842 | 1.423 | 0.705 |
| A2 | mid-micro | −0.222 | 0 | 0.212 | 0.035 | 0.005 | 0.022 | 0.585 | 0.834 | 1.455 | 0.770 |

Rest share per layer (macro / mid / micro): A1 0.079 / 0.081 / 0.245; C1
0.170 / 0.064 / 0.245; A2 0.084 / 0.071 / 0.226. All three silent: 0.000
in every arm.

## Rules 1 and 3 (rule 2 waits for C2)

**Rule 1, attribution: NOT MET.** The prereg's prediction was that at K=0
the macro-mid and macro-micro correlations fall inside the null while the
A arms keep them negative and significant. The A arms do (A1 −0.328 /
−0.242, A2 −0.296 / −0.348, all p ≤ 0.025). C1 stays negative and
significant on both pairs (−0.259, p 0.010; −0.235, p 0.000). Removing the
top-up refill did not remove the anti-correlation, so the top-up loop is
not the whole mechanism. Per the prereg, `voices_follow inverse_density`
is the named suspect: the voice count itself is steered against density,
which couples the layers whether or not a resting layer's slot is refilled.
A side effect to note: at K=0 the macro layer rested twice as often (0.170
against 0.079 / 0.084) while mid and micro did not move, so K=0 changed
the macro layer's own behaviour, not only the coupling.

**Rule 3, not a lock: holds trivially so far.** MI below 0.11 bits on every
pair in every arm; all-three-silent 0.000. C2 is where it is tested.

**Rule 2, coupling at K=+0.5:** part 2, from `live_260924_222853.log`.

## What is claimed and what is not

Claimed: the negative coupling of A1/A2 replicates the baseline (macro-mid
−0.3, macro-micro −0.22) inside one run with a null measured in the same
run; K=0 does not remove it. Not claimed: anything about K=+0.5; anything
about how the arms sound; that inverse_density is the mechanism (it is the
next suspect, to be tested by its own arm, not assumed).

Next: part 2 scores C2 against its bracketing arms; if rule 2 holds and
rule 3 holds, the ear decides; then an arm with `voices_follow` off at
K=0 tests the suspect.

---

# Part 2: C2 at K = +0.5 (PROVISIONAL)

**26 September 2026, 20:30.** Scored by hand; the scheduled scorer of 16:15
did not run. Everything below is PROVISIONAL pending Roberto's listening
(rule 5).

## What ran

Log `live_260926_110144.log`, booted 26 Sept 11:01, commit 92c1d6b
(polyphony bound, dry defs without delay lines, pool reset; rung 2 inert at
synth_slot_weight 0). Runner `run_n_arms.sh`, state
`harness/n_arms_260926_110526.json`.

Deviation from the plan: the runner ran two arms, A and C (it labels the
candidate "C1"), and stopped. `run_n_arms.sh` sets NARMS to twice the
number of candidates, so a single candidate gets no closing A arm. The
factory went on at K = −1 after the runner's reload back at 15:54, and those
windows are scored below as a post-hoc A2. It is labelled partial and
post-hoc; the runner did not mark it.

| arm | K | windows | n | note |
|---|---|---|---|---|
| A1 | −1 | 19–818 | 800 | |
| C2 | +0.5 | 820–1618 | 799 | window 819 excluded: the reload to +0.5 lagged one window |
| A2 | −1 | 1630–2238 | 609 | post-hoc, partial; 1619–1629 still read K = +0.5 (reload lag, excluded); ends before the CLOCKJUMP at 2239 |

K confirmed from the COUPLE lines in every window scored. After 2238: a
CLOCKJUMP of 142 s at 2239 (17:52, the laptop slept on battery), the FMA
drive detached at 18:50, a CLOCKJUMP of 4,305 s at 2536. Nothing after 2238
is scored.

Wall clock for the ear: C2 ran 13:28:40 to about 15:57 (K stayed +0.5 to
window 1629). Segments in `/Volumes/FMA/superdark/segments`:
`cap_260926_132901_0136` to `cap_260926_154902_0150` are C2;
`0122`–`0134` are A1; `0152`–`0163` are A2.

## Integrity (rule 4)

| arm | CLOCKJUMP | BLOWUP | FILL_STALL | POOL_RESET | ACQUIRED | polyphony refusals | MASTER clip>0 | peak median | p99 | max |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | 0 | 1 (w435) | 0 | 0 | 1 | 3 | 2 | 0.048 | 0.416 | 2.166 |
| C2 | 0 | 0 | 0 | 0 | 1 | 2 | 0 | 0.044 | 0.332 | 0.816 |
| A2 | 0 | 0 | 0 | 0 | 0 | 1 | 3 | 0.048 | 0.421 | 1.743 |

`alloc failed` in the server log: 0. No SERVER_LOST or SERVER_DEAD. m8 and
d2 per arm: not scored; `score_charter.py` does not work on a log slice.

## The coupling measure, per arm (`tools/layer_coupling.py`, n-null 200)

| arm | pair | max r | lag | null95 | p | MI bits | null95 | p | rest ratio | null95 | p |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1 | macro-mid | +0.145 | 14 | 0.203 | 0.320 | 0.007 | 0.021 | 0.420 | 0.571 | 2.003 | 0.785 |
| A1 | macro-micro | −0.186 | 0 | 0.180 | 0.030 | 0.062 | 0.021 | 0.000 | 0.417 | 1.318 | 1.000 |
| A1 | mid-micro | −0.128 | 0 | 0.199 | 0.315 | 0.007 | 0.015 | 0.315 | 0.529 | 1.559 | 0.940 |
| C2 | macro-mid | +0.296 | 7 | 0.182 | 0.000 | 0.034 | 0.021 | 0.000 | 1.425 | 1.400 | 0.035 |
| C2 | macro-micro | −0.225 | 0 | 0.166 | 0.000 | 0.069 | 0.020 | 0.000 | 0.921 | 1.183 | 0.715 |
| C2 | mid-micro | +0.111 | −15 | 0.165 | 0.480 | 0.012 | 0.019 | 0.180 | 1.398 | 1.215 | 0.005 |
| A2 | macro-mid | −0.264 | 0 | 0.238 | 0.035 | 0.030 | 0.034 | 0.065 | 0.328 | 2.159 | 0.905 |
| A2 | macro-micro | +0.166 | 11 | 0.221 | 0.205 | 0.021 | 0.021 | 0.050 | 0.817 | 1.337 | 0.840 |
| A2 | mid-micro | −0.146 | 0 | 0.230 | 0.245 | 0.024 | 0.022 | 0.045 | 1.481 | 1.500 | 0.060 |

Rest share per layer (macro / mid / micro): A1 0.100 / 0.044 / 0.270;
C2 0.208 / 0.156 / 0.320; A2 0.095 / 0.053 / 0.274. All three silent:
A1 0.000, C2 0.010, A2 0.000.

## Rules 2 and 3

**Rule 2, coupling: NOT MET.** Macro-mid meets its half: r +0.296 (p 0.000,
at lag 7, inside one macro dwell), rest ratio 1.425 above 1 and above its
null (1.400, p 0.035). Macro-micro fails: r stays negative (−0.225,
p 0.000) and the rest ratio is 0.921, below 1 and inside its null. K = +0.5
turns the macro-mid pair and leaves the macro-micro anti-coupling where it
was.

The bracket is also weaker than the prereg assumed. On this build each A
arm holds only one of the two negative pairs: A1 keeps macro-micro
(−0.186, p 0.030) and loses macro-mid (+0.145, p 0.320); A2 keeps
macro-mid (−0.264, p 0.035) and loses macro-micro (+0.166, p 0.205). In
part 1 (24 Sept, before 92c1d6b) both A arms held both pairs at −0.24 to
−0.35. The baseline itself moved between the two runs; the polyphony bound
and the dry defs are the changes in between.

**Rule 3, not a lock: HOLDS.** MI in C2 is at most 0.069 bits on every pair
(bound 0.5); all-three-silent 1.0% (bound 3%). It rose from 0.000 in both A
arms, which is the mechanism doing what it says.

Side effect: K = +0.5 raised every layer's own rest share (macro ×2.1,
mid ×3.5, micro ×1.2 against the A mean), so C2 is thinner as well as more
coupled on macro-mid.

## What is claimed and what is not

Claimed: at K = +0.5 the macro-mid pair turns positive and above its null
with rests that coincide; macro-micro does not move; nothing locks. Not
claimed: that K = +0.5 couples the layers in the sense of rule 2; anything
about how C2 sounds; that 92c1d6b caused the baseline shift (it is the
candidate, untested).

Next: the voices_follow arm named in part 1 (K = 0, voices_follow off),
run as A C A with the runner fixed to close on an A arm, and a fresh A-only
baseline on 92c1d6b to settle where K = −1 now sits.
