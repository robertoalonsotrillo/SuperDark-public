# Novelty pressure on where a section goes

Built 6 September 2026, in answer to the recurrence result of the same day. Not
yet run live: the machine's audio subsystem needs a reboot.

## The fault

`.lab/measurements/2026-09-06_recurrence_result.md`. Against a loop and 140
unrelated FMA artists as calibration arms, the factory's position on the
diverse-to-loop axis, by match window:

| 5–60 s | 20–300 s | 60–900 s | 300–1800 s |
|---|---|---|---|
| 0.10 | 0.21 | 0.33 | **0.74** |

It varies locally and repeats globally. Its spectral participation ratio is 4.69
bands against 5.36 for the diverse arm, so the corpus is not the constraint: the
factory revisits a space it already has.

## Where the repetition is made

Half an hour is the **section** scale. On the 7.9 h run of 4 Sept: 229 sections
in 28,572 s, one every 125 s, so half an hour is about fourteen of them.

A section's centre came from one line:

```supercollider
\centre -> Array.fill(dKeys.size, { rrand(0.15, 0.85) }),
```

A uniform point in a six-dimensional box, drawn independently every time, with no
knowledge of where the run has already been. 155 of the 229 sections on 4 Sept
were drawn this way; the other 74 were deliberate recalls. Uniform draws in a
bounded box land near each other often, and nothing was watching.

The quantity needed to fix it was already being computed. The `novelty_threshold`
block has measured nearest-neighbour centre distance since 26 August — and only
ever logged it.

## What was built

Best-of-K at the one site where a new centre is drawn. Draw `section_spread_k`
candidates, keep whichever is furthest from the last `section_spread_horizon`
places this run has occupied. The draw and its support are unchanged, so every
calibration resting on the centre distribution still holds, and at K=1 the
behaviour is the old behaviour bit for bit.

Three things it deliberately does not do:

- **It does not touch the per-window walk.** That already produces one-minute
  variety at position 0.10, and a repulsion applied every window would fight
  `section_pull` and dissolve the section as a unit.
- **It does not touch recall.** 35% of sections return to a remembered region via
  the transition table, and that is how the factory has a memory a listener can
  hear. This stops the other two thirds landing on top of it by accident.
- **It does not consult the archive.** `sections` holds 1,575 centres from 93
  performances. Measured against all of it, a new section would be pushed into
  whatever corner the archive has never touched and would exhaust within an hour.
  The fault is within a run, so the memory the pressure consults is that long.

Recalled sections are appended to the occupancy list too. Returning to a place is
occupying it, and without that the pressure would push new centres apart while
the factory walked back to a remembered region unnoticed.

## Why K is 4

Criteria fixed before the sweep, in `tools/test_novelty_pressure.py`.

| K | median gap | vs K=1 | per-dim sd | vs uniform 0.2021 | returns |
|---|---|---|---|---|---|
| 1 | 0.3899 | — | 0.2033 | +1% | 34.7% |
| 2 | 0.4434 | +14% | 0.2097 | +4% | 35.2% |
| **4** | **0.4883** | **+25%** | **0.2164** | **+7%** | **34.4%** |
| 8 | 0.5293 | +36% | 0.2240 | +11% | 34.7% |
| 16 | 0.5646 | +45% | 0.2306 | +14% | 34.6% |

The two criteria pull opposite ways. Spread rises with K, and so does an **edge
bias**: best-of-K inside a box favours the walls, because a candidate near a face
has fewer directions from which a neighbour can crowd it. The coverage criterion
prices that at 0.02 of standard deviation, which admits 4 and refuses 8.

That 0.02 was chosen, not derived. Moving it moves the answer, and it should be
moved by an argument about the corpus, never to admit a larger K.

**Reflecting the neighbours in the faces of the box does not fix the bias.** It
is the standard correction and it is provably inert here: the image of a
neighbour across a wall differs from it in one dimension, at `|c+p-2w|` against
`|c-p|`, and the difference is `2*(min(c,p) - w)`, non-negative everywhere inside
the box. The image is never nearer than the point it mirrors. Mirrors help on a
periodic domain; this one reflects, and reflection pushes away.

## How to tell whether it is working

Three checks, in order, and the first two are about the mechanism rather than the
music.

1. **`SPREAD` lines appear in the window log**, one per new section, carrying
   `window, section, K, horizon size, first draw's distance, chosen distance`.
   The first draw is logged beside the chosen one on purpose: at K=1 they are
   equal by construction, and if they stay equal at K=4 the selection is not
   selecting. PatternGrammar went two weeks unwired for want of exactly this.
2. **The chosen distance exceeds the first draw's**, on average by roughly the
   +25% in the table.
3. **`recurrence_sweep.py` against the loop and diverse arms**, on an hour of the
   new stream. The number to move is the 0.74 at 300–1800 s. The 0.10 at 5–60 s
   must not rise: a factory that spreads its sections at the cost of local
   variety has traded one fault for another.

Only the third is evidence about the sound. The first two say the code runs.

## Naming

`section_spread_k` and `section_spread_horizon`, not `novelty_*`, because the
policy file already holds `novelty_penalty` (damps a recently played **machine**)
and `novelty_threshold` (flags a section far from the archive and changes
nothing). Three unrelated mechanisms under one prefix would be explained with the
wrong one inside a month.
