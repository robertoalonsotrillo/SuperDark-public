# Pitch is a coordinate, not a faculty

2 Sept 2026. `tools/pitch_trajectory.py` over 19 runs, 8,948 windows carrying a
six-dimensional target.

## The question

`live_factory.scd` records why pitch was added to the geometry: selection used to
be pitch-blind, "which is why nothing the factory assembled was ever harmonic or
tonal: the axis along which tonality lives was not in the geometry." Pitch is now
the sixth dimension of `dKeys`, beside five MFCC components. So the factory can
move along pitch. Does it move along pitch *differently*?

The control is the five siblings, not a shuffle. They are walked by the same
selector, over the same corpus, under the same policy, in the same runs.
Anything pitch does that pc0–pc4 do not is a property of pitch.

## The measurement

    axis    persist l1      l4      l8     step    span    drift
    ------------------------------------------------------------
    pc0          0.897   0.629   0.333   0.0300   1.000   -0.012
    pc1          0.899   0.637   0.342   0.0300   1.000   -0.032
    pc2          0.896   0.628   0.333   0.0300   1.000   -0.023
    pc3          0.895   0.625   0.322   0.0300   1.000   -0.006
    pc4          0.891   0.606   0.291   0.0300   0.980   -0.078
    PITCH        0.894   0.623   0.319   0.0300   1.000   -0.007

Pitch sits inside the spread of its siblings on every column. Its persistence is
fourth of six. Its median step is identical to three decimals. Its span is the
whole axis, like theirs. There is no pitch-specific behaviour to find.

The revisit column the tool also prints is degenerate — 0.995 for every axis and
every null, at both 12 and 60 bins, because a 0.03 step inside a bounded unit
range re-enters a visited bin almost every time it moves. It is labelled and
ignored. The first version of this test could not have detected what it was
built to look for, and that is recorded rather than removed.

## The mechanism, which makes the result unsurprising

    target = target.collect({ |v, j|
        v = v + rrand(step.neg, step) + ((c - v) * pull);
        ...

One expression, applied to every `j`. `step` varies per machine (`drift` in
weights.json) and `pull` toward the section centre is 0.25, but neither is
indexed by axis. **The walk is isotropic. Pitch is coordinate 5 and is moved by
the same rule as coordinate 3.**

So the earlier fix was real but partial. Putting pitch into `dKeys` changed which
grains are *near* a target — the distance metric now includes pitch, so a target
at a given pitch coordinate selects material at that pitch. It did not give the
factory any way to *treat* pitch as pitch.

## What this settles

A harmonic mechanism added now would be an imposition, not a description. There
is no latent tonal behaviour being missed for want of a measurement. This is the
distinction the project has had to defend four times, and the measurement was
cheap enough that guessing would have been indefensible.

It also bounds the claim the other way, which is the useful half: the factory
**can** land anywhere on the pitch axis and does, in a bounded walk pulled toward
a section centre. The material for tonal behaviour is reachable. What is absent
is any term that would prefer one pitch region to another, or relate one voice's
pitch to another's.

## What would have to change, in order of depth

1. **An anisotropic step.** One line: give the pitch component its own drift and
   pull. That alone makes the factory dwell in pitch regions while continuing to
   roam timbrally, which is the minimum condition for recurrence to be audible
   as return. Cheap, and it is a knob, so it needs a price before it is turned.

2. **The machine template must read pitch.** `mainpitch` is computed every window
   into `machineArgs` and `MachineWriter`'s emitted Pbind never reads it. The
   only pitch-affecting parameter, `\rate`, is `Pseq([1.0, 0.85+0.4.rand, 1.0])`
   — a constant drawn once when the machine is written and never revised. The
   factory measures the pitch of what it is playing and discards the number.

3. **A representation of simultaneity.** Harmony is a relation between voices
   sounding together, and no voice knows another exists; each draws its rate
   independently. Nothing in the factory can express "these two, now". This is
   the architectural item, and it is the one that would most easily become a
   convergence engine, because a score over simultaneous intervals is a scalar
   the selector could climb.

The order is deliberate. 1 and 2 make pitch behaviour *possible* and remain
describable; 3 makes it *relational* and needs the discipline that E3, the
audibility score and the transfer operator did not get.
