# B8 rung 3, first half: the factory proposes its own source weights

**27 September 2026.** Built offline; live from the next rung 2 admission
(the admission check runs in its own process, so no restart was needed).

## Class 3 check

- Architect's: the norm (n5_new_in_kind, charter edition 8), the six sources,
  the proposal rule, and the act of adopting or refusing.
- Ceded: the evidence and the proposal. The factory scores each admitted
  render and proposes a weight change when its evidence disagrees with the
  current weights.
- Still set from outside: the weights themselves until a proposal is adopted;
  the source list (the second half of rung 3: proposing new sources).

## The factory's reading of n5

`tools/kind_distance.py`. A generic distance from the corpus DISAGREED with
the ear: warp1, heard as the originals, scored highest (broadband flatness
from the reverb returns). What separated Roberto's twelve verdicts was pitch
structure above the corpus, harmonicity z + peakiness z:

| render | pitch | ear |
|---|---|---|
| grainbuf x10 | +3.63 | new |
| klank x42 | +3.37 | new |
| pitchshift x24 | +2.21 | new |
| klank x34 | +1.60 | new |
| wavetable x5 | +0.88 | new |
| wavetable x6 | +0.71 | new |
| playbuf x11 | −2.32 | reference |
| playbuf x2 | −2.53 | reference |
| warp1 x30 | −2.85 | same |
| warp1 x12 | −2.92 | same |
| pitchshift x22 | −3.73 | same |
| grainbuf x1 | −3.79 | same |

12 of 12 by sign. POST HOC: the two features were chosen after reading the
verdicts. It is a hypothesis about what the ear calls new in kind, not a
validated metric. Test: Roberto judges the next live rung 2 machines blind
to the score; the score predicts his verdict or it is dropped.

## The proposal path

- `tools/source_evidence.py`, called by `check_machine.sh` after every PASS:
  appends to `mutable/source_evidence.jsonl`; when a source has 4+ scored
  renders and its mean over the last 8 disagrees with its weight (positive
  but at or below the mean weight: x2, cap 4; negative but at or above it:
  x0.5, floor 0.25), appends an open `source_weight` proposal to
  `charter_proposals.jsonl`. One open proposal per source.
- `tools/decide_source_proposal.py --list | N adopt|refuse "reason"`: the
  architect's act. Adopt changes the weight, bumps the charter edition with
  a note, logs the decision.
- Dry run on the twelve renders (twice, to pass the floor): 0 proposals. The
  factory's evidence agrees with the weights set from the ear.

## Also (deploys at the next boot)

`synth_slot_weight` becomes a seventh factory knob, bounds [0.1, 0.8].
