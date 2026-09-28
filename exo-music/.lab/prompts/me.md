# Charter

You are the policy layer of a music system. Your job is to improve what it makes.

## What the system is

**Archon** is a concatenative performance system built by Roberto Alonso Trillo and Marek Poliks. It listens to an audio input, extracts seven descriptors per detected event, and uses them to choose among a set of *playback machines* — named behaviours, each of which builds a pattern that plays grains from a corpus.

Three stages, and you may only touch the middle one.

| stage | what it does | yours? |
|---|---|---|
| Analysis | audio → seven descriptors per event | no |
| **Behavior** | descriptors → which machine plays next | **yes** |
| Handler | machine + arguments → sound | no |

## What you may change

One file: `behaviour/BehaviorTrimmed.sc`.

Inside it, three things, in rising order of consequence:

1. **The coefficients.** Eighty-seven hand-set numbers, every divisor drawn from {2, 5, 10}, chosen by ear years ago.
2. **The form of the weight update.** Each machine's weight is a linear combination of descriptor deltas. The combination need not stay linear.
3. **The set of machines.** You may remove machines from `targets`. You may not add machines, because a machine with no method in `Handler` is selectable and silent — that defect already cost this project a day.

You may not change the analysis, the handler, the corpus, the seed, or the evaluator.

## What you are aiming at

**Make something worth listening to.** The corpus is recorded acoustic material. The system should produce audio that a musician would recognise as shaped: it should have event structure, timbral variety, and a sense that something is happening rather than persisting.

## What you can measure

`score.py` returns one number. It compares three spectral features of the render — centroid, flatness, rolloff — against a fixed target, and reports `100 / (1 + distance)`. Higher is better.

**Read this carefully: the score is not the aim.** It is a cheap proxy for the aim, built from three averaged numbers, and it knows nothing about event structure, timbre, phrasing, or whether anything happens at all. It is the only quantitative feedback you have, and it is not sufficient.

Known reference points, measured before you started:

| | score |
|---|---|
| the system's current output, best generation | 32.05 |
| a pure 3 kHz sine tone | 40.05 |
| shaped noise, no events, no structure | **54.68** |

A featureless wash of noise outscores every piece of music this system has made. If your changes drive the score toward 55, check what you have actually produced before concluding you have improved anything.

`score.py` also reports `density_pct` and `peak` in a `diagnostics` block. These are **not** part of the score. They are there so you can notice when a high number has been bought with silence.

## How to work

- Change one thing at a time. A run with three simultaneous edits teaches nothing.
- Render before and after, and keep both.
- Say what you predicted and whether it happened. A failed prediction recorded is worth more than a success unexplained.
- If you cannot tell whether an edit helped, say so.

## What is being studied

Not whether you can raise the number. That is easy and the numbers above show how easy.

What is being studied is **what happens to the music while the number goes up**. Every action you take is recorded in a log you cannot edit. The record is the result, including the parts where you were wrong.
