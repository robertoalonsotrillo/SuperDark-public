# Cross-layer coupling: the baseline is not zero, it is negative

**22 September 2026.** Step 1 of the nesting programme
(`.lab/notes/NESTING_THE_THREE_TIMESCALES.md`): the measure that has to exist
before any coupling is built, computed on data already recorded. Tool:
`tools/layer_coupling.py`. Calibrated on synthetic series: independent
layers with their own run structure read as null; a planted macro→micro rest
coupling at lag 2 is found at lag 2 with p = 0.

## The measure

Three voice-count series per window (`VOICES win,macro,mid,micro`).
Pairwise: max |r| over lags −16..+16 windows, mutual information at lag 0
over {rest, one, more}, and the rest ratio P(b silent | a silent) / P(b
silent). Null: circular block bootstrap of the second series, blocks of 20
windows (above macro's dwell of 6–16), 200 draws; the 95th percentile is
the bar.

## The result, five runs, 19–22 September

| run | windows | macro–mid r (null95) | macro–micro r (null95) | mid–micro r (null95) | rest ratio macro→mid | macro→micro | all three silent |
|---|---|---|---|---|---|---|---|
| 260919_141610 (ten arms) | 8,922 | **−0.291** (0.076) | **−0.249** (0.062) | −0.121 (0.060) | 0.43 | 0.77 | 0.0001 |
| 260920_174945 | 1,929 | **−0.257** (0.143) | **−0.222** (0.133) | −0.072 (0.132) | 0.56 | 0.65 | 0.0005 |
| 260921_093819 | 1,118 | **−0.367** (0.194) | **−0.232** (0.158) | +0.173 (0.155) | 0.85 | 0.65 | 0.0009 |
| 260921_130422 | 1,461 | **−0.313** (0.179) | **−0.172** (0.129) | −0.137 (0.130) | 0.58 | 0.71 | 0.0007 |
| 260921_190106 | 5,666 | **−0.301** (0.092) | **−0.219** (0.081) | −0.155 (0.082) | 0.81 | 0.69 | 0.0002 |

Every macro pair is anticorrelated at lag 0, two to four times the null bar,
p = 0 in all five runs. Mutual information macro–mid and macro–micro beats
its null by 10–25× (0.03–0.085 bits against 0.002–0.018). The rest ratios
are below 1: when macro is silent, mid and micro are *less* likely to be
silent than usual. All three silent at once happens about one window in
5,000; independence at these rest shares would give one in 600.

**The layers are coupled, and the coupling is negative.** The note of 19
Sept expected near zero because no rest decision reads another layer. That
was true and beside the point.

## The mechanism

`live_factory.scd`, the top-up loop after the per-slot rest logic:

```
while { live.size < nVoices } {
    ...
    lay = if (vi < layerNames.size) { layerNames[vi] }
          { fill[(vi - layerNames.size) % fill.size] },
```

`nVoices` (1–8, set per section) is one budget over all three layers. Each
layer's slot rests on its own timer (`rest_macro` 0.35, `rest_mid` 0.25,
`rest_micro` 0.40, with `rest_*_min/max` durations), and a resting voice
leaves `live`. The top-up then sees `live.size < nVoices` and refills by
*count*, not by which layer is missing: with macro resting and two voices
live, `vi = 2` and the refill goes to `layerNames[2]`, micro. A hole in macro
or mid becomes an extra micro (or mid) voice for as long as the rest lasts.

That is the conserved budget of the note's option 2, already built, never
named, and running with the sign that produces exactly the ear's report:
macro and mid silences are audible because micro fills them; micro's own
rests (29% of windows, the most of any layer) are covered by the others'
refills and read as continuous.

## What this changes in the nesting design

1. **There is no uncoupled baseline to build on.** K = 0 in the note meant
   "today's factory"; today's factory is at a negative K. The first
   mechanism step is to make the top-up respect a resting layer, so its
   slot stays empty for the rest's duration: that is the zero of the axis,
   and it is a one-line change with an audible consequence (thinning during
   rests instead of substitution).

2. **The knob is already there, unnamed.** One exposed scalar,
   `layer_coupling` in [−1, +1]: −1 is the present behaviour (a rest is
   fully compensated by the other layers), 0 is no compensation, +1 raises
   the other layers' rest probability while one rests (co-articulation, the
   nesting the ear asked for). The mechanism is the top-up loop plus the
   rest probability, both existing; K selects between them. At K = −1 the
   factory is byte-for-byte what it is now, so every run recorded so far is
   the K = −1 arm.

3. **The proposal kind stays as planned.** The factory proposes a
   quantisation of `n3_coherent` over this measure; the norm stays
   Roberto's; K is what the factory may then move within a range the
   architect sets. That is the Class 3 form, and it is unchanged by the
   sign of the baseline.

## What is not claimed

That negative coupling is wrong. It is what keeps the stream from going
silent, and the all-three-silent rate (one window in 5,000) is a property
someone may want. The point is that it was a choice nobody made, and now it
is named and measurable.

That the anticorrelation is entirely the top-up. `voices_follow
inverse_density` raises `nVoices` when the measured level drops, which
would add a second negative path (quiet → more voices). Separating the two
needs the K = 0 arm.

That the mid–micro pair is coupled. It sits at or near its null in four of
five runs; the one positive reading (+0.173, p = 0.035) is one draw.

## Next

Pre-register the coupling experiment: `layer_coupling` in policy, the
top-up made layer-aware, three arms (−1, 0, +0.5) through the A-B-A rig,
decision on this measure with the ear's veto standing. Written before any
code, per the order the note fixed.
