# The week-long drift into fragmentation, and the ablation that has to follow

2 Sept 2026.

## What was actually wrong

Roberto, listening: "endless radio-like fragmentary shit", and "worse than the
immediately previous versions a 100%".

My first two attempts to explain it were both wrong, and the way they were wrong
is the useful part.

**Wrong once: I blamed the restart.** The factory had just restarted onto new
code, so I compared the new run against the previous one over the same window
range and found events per window up 52%. That comparison was worthless:
`REQUEST` logging is new, so only today's two runs have it. n=1 against n=1, no
baseline, and I presented it as a finding.

**Wrong twice: I blamed my own instrumentation.** I had added a `\rate` tap to
the per-event path, which is the same shape as a fault this project already has
on record. It measures 3.7 microseconds per event. And `machineArgs`, which I had
added three keys to, is only ever read by `.at(\namedKey)` — so a new key cannot
reach the handler at all. Neither is a mechanism. I reverted the factory to
known-good code anyway, which was right, but the revert was not the diagnosis.

## What the data says

Turnover and level, windows 45–400, every run long enough to score:

    date      turnover   median peak
    27 Aug       0.736        0.1970
    28 Aug       0.689        0.1040
    30 Aug       0.757        0.1125
    31 Aug       0.816        0.0230
    31 Aug       0.918        0.0380
    1 Sept       0.893        0.0430
    1 Sept       0.924        0.0470
    2 Sept       0.935        0.0520   <- the run he said he liked
    2 Sept       0.950        0.0600   <- the run he said was 100% worse

**Turnover climbed monotonically for a week, 0.74 to 0.95, while the median peak
fell about 10 dB.** Turnover is "the machine changes between consecutive
windows": at 0.95 it changes in nineteen windows out of twenty, where on 27
August it held for two or three.

The two runs he compared are 0.935 against 0.950 and 0.052 against 0.060 —
statistically indistinguishable. What changed today is that he listened closely,
not that the factory broke. The regression is a week old.

The timeline fits one change. `voices` was widened from [2,4] to [1,8] on 1
September, and turnover steps from ~0.80 to ~0.89 exactly there. With up to eight
concurrent voices each drawn from a *different* machine through `recent`, more
voices mechanically means more distinct material sounding at once, and the
vocabulary has grown every run so there is more to switch between.

None of this is new information to the project. `_voice_span_history` in
policy.json already records the identical complaint — "very similar highly
fragmentary material, the variety and richness we were producing earlier is
gone" — and run 34 measured fewer transitions as the strongest positive predictor
of his preference, rho +0.674. The system drifted back into the condition that
note was written about, and nothing was watching the number.

## The four levers, changed together

Changing one at a time attributes the cause and leaves the factory sounding wrong
for days. Changed together it sounds right sooner and attributes nothing. The
architect chose together, so the ablation is pre-registered here instead of left
as an intention.

    voices_max            8    -> 4       fewer simultaneous distinct machines
    voice_span            20   -> 34 s    ~3 windows, so material persists
    section_windows_min   6    -> 12      longer sections
    section_windows_max   18   -> 30
    section_pull          0.25 -> 0.45    target holds a region longer
    master_gain           3.0  -> 4.5     +3.5 dB against the ~10 dB fall

## The ablation, pre-registered

Restore ONE lever at a time to its previous value, in this order, one run each of
at least 400 post-warm-up windows, scoring turnover and median peak with
`tools/compare_arms.py` against the control distribution:

1. `master_gain` back to 3.0 — level is separable from structure and should be
   tested first, because if the fragmentation was partly inaudibility then
   nothing else needs to move.
2. `section_pull` back to 0.25.
3. `section_windows_min/max` back to 6/18.
4. `voice_span` back to 20.
5. `voices_max` back to 8 — last, because it is the one the timeline implicates,
   so it is the one whose restoration should reproduce the fault.

If restoring (5) alone brings turnover back to ~0.95, the widening is the cause
and the other four were unnecessary. If it does not, the cause is distributed and
the single-lever story was wrong.

## The standing failure this exposes

Nobody was watching turnover. It moved 0.74 to 0.95 across a week, through
several charter editions and a kernel arming, and no metric in the charter
measures it — m4 counts vocabulary breadth, which a fragmentary factory scores
WELL on. A factory that switches material every window has high breadth and high
turnover and sounds like a radio being tuned.

**m4 rewards exactly the failure the listener heard.** That is a stronger
statement about the charter than the depth hole, and it should be recorded as
one: the charter has no metric that would have caught this, and one of its
metrics moves the wrong way.
