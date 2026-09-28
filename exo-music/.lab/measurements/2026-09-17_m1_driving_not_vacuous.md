# m1_audible_when_driving is not vacuous. It is untriggered. (#51)

**17 September 2026, 02:10.** Task #51 asked whether
`m1_audible_when_driving` is near-vacuous. The answer is no, for a reason the
task did not anticipate — and what is true instead is worth more than what was
suspected.

## The suspicion, and why it was reasonable

The metric reads **0.000** against a bound of **[0, 0.015]** on every run that
can score it, and has never once failed. That is the signature of a metric that
cannot fail. It is conditional — *of the windows where the factory drove output,
how many produced no sound* — and a metric conditioned on a rare event is
vacuous in practice however carefully its bound was derived.

## The denominator is healthy — suspicion refuted

Across the last twelve runs, 7,737 windows:

| | |
|---|---|
| windows where the factory is driving (`amp ≥ 0.01`) | **3,555** |
| as a share of all windows | **46.0%** |
| runs with enough driving windows to score (≥ 50) | 6 of 12 |

The condition is met in nearly half of all windows. This is not a rare event, and
the metric is not conditioned into irrelevance. The six runs that could not be
scored were simply short — 5 to 102 windows — and `UNDECIDED` on a 51-window run
is the rig refusing to score what it has not measured, which is correct.

## The numerator has never moved

Across all **3,555 driving windows**, the number that were silent is **zero**.
Not small. Zero. The metric has never taken any value but 0.0000.

So why has it never fired? Not because it cannot:

| | master peak |
|---|---|
| minimum among **driving** windows | **0.00500** |
| p0.1 | 0.01100 |
| median | 0.07900 |
| silence threshold | **0.004** |

The quietest driving window sits **1.9 dB** above the threshold. The gap is thin,
not structural. And non-driving windows *do* cross it — 43 of them, reaching
0.00000 exactly — so the measurement path can produce a silent reading. It just
never does when the factory is driving.

`corr(section amplitude, master peak)` among driving windows is **+0.066**:
essentially none. Driving harder does not make it louder, which is worth knowing
on its own.

## What this actually is

**A standing detector that has not yet detected anything.**

That is exactly the position `m3_no_clipping` was in until yesterday, and m3 was
*vindicated*: it had been correctly reporting a real broken transport for weeks
while I proposed re-pricing it as over-sensitive. A detector that never fires is
not thereby useless; it is untested.

The difference is that m3 fired and was right, so it has a demonstrated
discrimination. This one has none. It is live, cheaply computed, correctly
conditioned, and **its ability to discriminate rests entirely on a simulation**.
Its own derivation says so:

> Derived from one 8 h run. The sensitivity table is arithmetic on that run's
> peaks, not an observation of a factory actually running 12 dB down, so it
> predicts what a fault would look like rather than reporting what one did look
> like. Re-check when a genuine level fault next occurs.

## One discrepancy worth recording

That derivation states the observed rate as **0.23% ± 0.32%** on the 2 September
run, and sets the bound at 1.5% to sit above it. Today's twelve runs give
**exactly 0.00%** across 3,555 driving windows.

The observed rate has moved from "small but non-zero" to "identically zero" and
nothing in the record explains why. Candidates, none tested: the master limiter
and sanitiser added on 16 September raise the floor; the corpus and machine
population have both turned over; or the 2 September figure was itself a small
sample. **Unresolved, and flagged rather than guessed at** — the lesson of the
clicking verdict, resolved two hours ago, is exactly that a number quoted from
one run should not be trusted to describe a different one.

## Verdict on #51

**Not vacuous.** The condition fires 46% of the time; the bound is derived and
documented; the margin to the threshold is 1.9 dB and therefore crossable.

**But untriggered, and its discrimination is simulated rather than observed.**
It should stay in the charter, and it should not be cited as evidence that the
factory is audible when driving — it is evidence that no *detected* failure of
audibility has occurred in 3,555 opportunities, which is a weaker and truer
claim.

The honest one-line status: *live, correctly conditioned, never fired, never
tested against a real fault.*
