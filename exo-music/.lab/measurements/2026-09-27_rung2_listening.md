# Rung 2: the ear's verdict on the twelve test renders

**27 September 2026, Roberto**, against the two playbuf renders (the
factory's own grain player) as reference. Renders: `listen/rung2_260927/`,
from `tools/test_synth_grammar.scd` on current code (ALL PASS, 12 of 12
admitted).

| source | render | heard |
|---|---|---|
| pitchshift | brgpte…x22 | playbuf plus noise, or just pitch-shifting |
| pitchshift | brhpso…x24 | different |
| klank | brdrst…x42 | completely different spectral register, melodic contour |
| klank | brhpht…x34 | different; sustained, flute-like harmonies |
| grainbuf | brcrpu…x1 | similar style, different DSP |
| grainbuf | brhmsc…x10 | different spectral register, mostly silent |
| wavetable | brhmcp…x6 | different sound, sine-like |
| wavetable | brhtgp…x5 | like the other wavetable, different from the originals |
| warp1 | brluhm…x30 | similar to the originals |
| warp1 | brstgl…x12 | similar to the originals |

Reading: klank and wavetable are new in kind (4 of 4); pitchshift and
grainbuf split (1 of 2 each); warp1 is colour (0 of 2). This is the first
time since 22 Sept that the ear has heard the factory's vocabulary grow in
kind. Rung 1's verdict was "processing is colour, the source is kind"; the
sources that make pitch from the grain (resonators, a period loop) are the
ones heard as new.

## What changed

- `SynthGrammar.pickSource`: weighted draw over the six sources; policy
  `synth_source_weights` "playbuf 1 grainbuf 1 warp1 0.5 pitchshift 1
  klank 3 wavetable 3". Weights, not bans: warp1 stays in the vocabulary.
  Tested: 9,500 draws land at the set proportions; absent weights fall back
  to uniform.
- `synth_slot_weight` 0.3 -> 0.5.
- Deployed at the boot of 27 Sept, about 11:05.
