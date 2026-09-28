# m3_no_clipping is not mis-priced. It has been catching a real numerical blow-up for weeks.

16 September 2026, 01:00. Found while waiting for an unrelated arm, by asking
why `charter_honesty` reports that `m3_no_clipping` **never** passes.

## The chain, end to end

**1. The factory's internal bus reports impossible peaks.**

Across the last twelve runs, 1,423 scored windows:

| | |
|---|---|
| windows with `MASTER` peak > 2.0 | **12 (0.84%)** |
| largest reported peak | **1.48 × 10²⁵** |
| others | 2.19e18, 1.94e18, 1.04e18, 5.18e13, 4.06e11 … |

A normalised bus peak above 2.0 is not audio. These are numerical explosions.

They arrive in **consecutive pairs** (windows 24/25, 30/31, 83/84, 159/160,
244/245), so twelve windows are about **six distinct events**, each lasting
roughly twenty seconds.

**2. Every one coincides with a clip spike.** The `clip` column, which is
`clipReports / masterReports` per window, reads 0.133 to 0.879 in exactly those
windows and 0.000 almost everywhere else. Clip is nonzero in only 1.8% of the
windows of `live_260915_182133` and 0.0% of several other runs.

**3. It reaches the listener.** Segment `cap_260915_190813_0018.wav`, which
covers the blow-up at window 239:

- peak **1.0000**, digital full scale
- 437 samples at or above 0.999
- in **two bursts**, each about **13 ms** (564 and 590 samples), at 415.4 s and
  456.7 s, both within a minute of the blow-up window

So the internal explosion is clamped at ±1.0 somewhere downstream and delivered
as a short burst of full-scale, hard-clipped audio. That is an audible click.

The same segment's overall RMS is 0.0134 while the blow-up neighbourhood runs
0.0275, twice as loud.

## What this settles

**`m3_no_clipping` is a standing defect detector and it has been working.**
`charter_honesty`'s verdict reads "m3_no_clipping: NEVER passes -- mis-priced or
a standing defect". It is the second. The bound [0, 0.02] on the p99 of clip
fraction is not too tight; the factory really does clip, about six times per
ninety-minute run.

This corrects the temptation to widen the bound. `kernel.json` names that move
as "the failure that would make this entire file theatre", and here is a case
where the metric was right and the instinct to re-price it would have buried a
real fault.

**It also means the charter has been honestly failing a metric for weeks and
nobody diagnosed why.** m3 is a `never_tolerated` clause. The kernel has been
armed with a permanently-failing never-tolerated metric, which is worth stating
plainly in the claim record.

## What this does NOT settle

**These are clicks, not the "pure noise sections".** On 11 September Roberto
reported "all of a sudden it goes into pure noise". A 13 ms burst is a click; it
is not a section. Those were attributed to `rq` being declared 4.0 and never
passed, fixed on 14 September. The blow-ups continued after that fix, seven of
them in `live_260915_182133` on 15 September, so **the two are separate faults**
and only one of them is fixed.

It also does not sit comfortably beside the record from 1 September, which
declared clicking solved at 1.01 clicks/s on the delivered stream. Either that
measurement did not cover a blow-up event, or the rate has changed, or the two
are measuring different things.

**RESOLVED 17 Sept**, and by none of those three. The detector was tested against
injected 13 ms bursts of five shapes and counts every one, including a 200 Hz
tone, so it was never blind to blow-ups. The actual answer is that the 1
September verdict rested on **a single sample**: one row, one number, and the
conclusion that clicking was gone. Measured across 38 segments on 16 September
the rate has median 5.50 and sd 8.15, and 16% of single samples fall at or below
1.01. That figure was an ordinary low draw, not a quiet stream. See
`2026-09-17_clicking_verdict_reexamined.md`.

## The cause is not yet localised

Machines present during a blow-up, best rates per window of presence:

| layer | machine | blow-ups / windows present |
|---|---|---|
| macro | `brbudr9` | 2 / 11 |
| micro | `brpugl2609051356x1` | 2 / 11 |
| micro | `brtebrrysc…x12609051311x4` | 2 / 21 |
| macro | `brcpbu9` | 4 / 57 |
| macro | `gp` | 4 / 61 |
| mid | `brdrcp9` | 4 / 123 |

Suggestive and **not conclusive** at six events. The three highest rates are all
`br*` machines, which are the factory's own written and bridged machines, and a
plausible reading is that self-written signal chains occasionally go unstable.
`gp` at 4/61 is an architect machine and cuts against that reading.

Six events is not enough to attribute anything. The honest next step is to
instrument rather than guess.

## What to do, in order

1. **Instrument, do not guess.** Log the per-voice amplitude at the moment
   `masterPeak` exceeds 2.0, so the next blow-up names its own voice. A few
   lines, and it converts six ambiguous events into attributable ones.
2. **Clamp at the source.** Whatever clamps to ±1.0 downstream is doing it after
   the damage. A `.clip2(1.0)` or a soft saturator on the master bus turns a
   13 ms full-scale burst into something bounded, without hiding it: the clip
   column still counts it.
3. **Do not widen m3's bound.** It is telling the truth.
4. **Re-examine the 1 September clicking result** against a run known to contain
   a blow-up.

Recorded as tasks. Nothing here changes the running factory tonight; the
attention comparison is mid-arm and a change would make it unattributable.
