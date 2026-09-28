# First run with the section spread: inconclusive, and inconclusive where it counts

6 September 2026, run `live_260906_175214`, 189 windows over about 37 minutes.

## The mechanism ran

10 sections drew under best-of-4. Nine improved on their discarded first draw,
one tied, none got worse. Mean lift +45% against the +25% the sweep predicted,
and the lift held as the horizon filled from 2 occupied places to 15 — which is
the part that mattered, since early sections choose in a nearly empty box and
flatter the figure.

`FILL_STALL` 0, `UNTRACKED` 0, sclang at 0.4%, delivered stream −41.4 dB mean with
no second below −60 dBFS.

## The audio says nothing yet

Three arms rebuilt at **30 minutes each** to match the factory's three complete
segments. Matching the durations is not optional: recurrence rises with how much
past is available, so a 30 min factory against the 70 min references of the
morning would compare two different quantities.

| match window | LOOP | FACTORY | DIVERSE | position | 5 Sept |
|---|---|---|---|---|---|
| 2–20 s | 0.5192 | 0.8053 | 0.7953 | arms not separated | — |
| 5–60 s | 0.9908 | 0.8194 | 0.8008 | **0.10** | 0.10 |
| 20–300 s | 0.9915 | 0.8477 | 0.8076 | **0.22** | 0.21 |
| 60–900 s | 0.9369 | 0.8741 | 0.8408 | **0.35** | 0.33 |
| 300–1800 s | 0.8724 | 0.7987 | 0.8683 | underpowered, 8 frames | 0.74 |
| 600–3600 s | 0.8553 | 0.7910 | 0.8550 | underpowered, 8 frames | — |

**The row that carries the claim could not be measured.** A 300–1800 s window on
a 1800 s file scores eight frames, which the `MIN_SCORED` guard refuses. The 0.74
that this whole intervention was aimed at is simply absent from this table.

## What can be said

**Local variety is unharmed**, and that was a real risk. 0.10 at one minute and
0.22 at five are indistinguishable from 5 September. A spread that bought
long-range variety by shortening the factory's local coherence would have shown
here, and it did not.

**60–900 s moved from 0.33 to 0.35**, which is the wrong direction but almost
certainly noise, and in any case below the band the mechanism targets: the
horizon is 16 sections, about 33 minutes, so its effect belongs at 300–1800 s.

Nothing here is evidence that the spread worked. Nothing here is evidence that it
did not.

## What the next test needs

- **At least two hours of continuous audio.** A 300–1800 s window needs a file
  well beyond 1800 s to score a usable number of frames; at 3600 s it scores 1800.
- **Discard the first half hour.** The spread's horizon fills over 16 sections,
  so the mechanism only reaches full strength around minute 33. Measuring from
  minute 0 dilutes it with a period during which it was still warming up — the
  same mistake as the 45-window warm-up that contaminated every short run in
  August.
- **The pre-registered reading stands:** the 0.74 at 300–1800 s is the number to
  move, and the 0.10 at 5–60 s must not rise.
