# Does the vertical table steer, or does snapping do the work?

*Pre-registered 5 Sept 2026, before the run. Written first so the criterion
cannot drift into whatever the data turns out to show.*

## The question

`simultaneity_weight` is live at 0.5 and a new voice takes a ratio from the
table above the lowest voice currently sounding. The first attempt to measure
its effect could not conclude:

```
non-unison intervals on a table member    control 39.2%   treatment 38.6%
chance rate for three windows of +/-0.03            18.0%
```

Both arms sit at twice chance and are indistinguishable from each other. That is
exactly what the Simultaneity header warned about: the table is built from
**quantiles of the corpus's own pitch distribution**, and every voice is snapped
to a pitch the corpus holds whether the table steers it or not. So
corpus-typical intervals appear in both arms by construction, and a null result
has two readings that the measurement cannot separate:

1. the steering is inert, or
2. the steering works and snapping erases it.

## The design

Switch the table to `simultaneity_mode: just`, which is Simultaneity's existing
contrast arm — a **labelled import**, 5-limit ratios that are not derived from
this corpus and that the material has no reason to contain.

```
corpus (n=7)   quantiles of the corpus's own fundamentals, folded to one octave
just   (n=7)   1.0  9/8  5/4  4/3  3/2  5/3  15/8
```

**n=7, not the default 4, and this is the load-bearing choice.** At n=4 the two
tables are `1.0 1.114 1.246 1.427` against `1.0 1.125 1.25 1.333`. Two of those
pairs differ by 1.0% and 0.3% — 17 and 6 cents — which is below what survives
snapping, so three quarters of the comparison would have been noise. At n=7 the
just table reaches 3/2, 5/3 and 15/8, which are far from the corpus quantiles
and give the test something to detect.

## What is added to make it conclusive

`VSNAP <win>,<want Hz>,<achieved Hz>,<cents>` at every voice birth, in both
arms. This records what the steering ASKED FOR against what the corpus could
supply. Without it the two readings of a null cannot be told apart.

## Pre-registered predictions

Fixed now, in this order of decisiveness:

1. **`VSNAP` median absolute displacement.** If it is small (say under 30 cents)
   the corpus can honour an imposed interval, and any null in the interval
   distribution means the steering is inert. If it is large (over 100 cents) the
   snap is overriding the intention and the vertical arm cannot work as built,
   whatever the interval histogram says. **This is the result that decides how to
   read everything else, so it is stated first.**
2. **Share of non-unison intervals within 30 cents of a `just` member**, against
   the same statistic computed for the corpus table. If the table steers, the
   just-mode run should favour just members over corpus members. If the two are
   equal, the table is not reaching the output.
3. **Chance baseline**, computed the same way from a circular shift of the
   interval sequence, so "twice chance" means something.

## What would make me wrong about the whole approach

If `VSNAP` shows small displacement AND the just-mode intervals still do not
favour just members, then the table is genuinely inert and the fault is in the
steering path, not the confound I have been blaming. That is the outcome that
costs me the current explanation, and it is the one worth watching for.

## What this run is NOT

Not a musical proposal. 5-limit just intonation is imported here as a contrast
arm precisely because the corpus has no reason to contain it; it should sound
like an imposition. `simultaneity_mode: corpus` is the setting the factory runs
under and this reverts to it after the measurement.
