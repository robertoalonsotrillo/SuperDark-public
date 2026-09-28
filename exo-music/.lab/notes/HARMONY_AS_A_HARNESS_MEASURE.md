# Harmony: a harness measure, and no fifth norm

**18 September 2026.** Decision 5 of `.lab/notes/METRICS_REVIEW_2026-09-18.md`. A
design note, not a pre-registration. The pre-registration comes after the
statistic is chosen and calibrated.

## Where this came from

Roberto, listening to the macro isolation run of 15 September: *"it produces no
harmonies whatsoever."* It is filed in `measures.json` under `owed` as
`macro_has_no_harmony`, with the note that M-D tracks ONE dominant partial, so
vertical structure is invisible to it by construction.

It is the fourth observation in this project where the ear arrived before any
instrument. The other three are the fragmentation heard on 2 September that
every metric passed, the macro complaint of 10 September that the recurrence
measures average away, and the configuration Roberto rejected by ear that
`recurrence_sweep` scores best at every window.

## Why it is a measure and not a norm

The charter has four norms and none of them is about vertical structure.
n3_coherent is the nearest, and it is about holding together over time.

Adding a fifth norm would say: this factory SHOULD produce harmony. That is a
claim about what the work is for, and the paper is explicit that norms are the
layer which cannot be ceded (L280: "A factory that constructs its norms wholesale
moves us into the undefined Class 4"). Only Roberto can write one, and he
declined to, which I think is right: "should produce harmonies" does not survive
being stated as a requirement for a factory whose material is grains of other
people's recordings and whose charter already refuses to install an aesthetic
preference as a measurement.

What remains is worth measuring anyway. A measure in the harness answers "did
this change move the vertical dimension" without asserting which direction is
better. It gets veto power at most, never promotion, and it never enters the
charter.

## What to build, and what not to

**Do not build another band-vector statistic.** `measures.json` is unambiguous:
four have saturated here and all four shared one shape, a spectrum reduced to a
normalised band vector, compared pairwise, averaged. The registry's instruction
is "Do not build another measure of that family."

**Build in the partial-tracking family.** It is the one that discriminated: on
78 s of the delivered stream the dominant partial's stable runs had a median of
0.03 s and a maximum of 0.36 s, and that family separates and matches the ear.

Two candidate statistics, both extensions of the existing tracker from one
partial to several:

### Candidate A: interval content of co-sounding partials

Track the strongest `k` partials per frame (k = 4 or 6). For each frame, compute
the pairwise frequency ratios and bin them by interval class in cents. The
statistic is the concentration of that distribution on small-integer ratios
across the arm.

Reads harmony as consonance. Its weakness is that it presumes consonance is
what "harmony" means here, which for this material may be wrong.

### Candidate B: co-sounding stability

Track the strongest `k` partials per frame. The statistic is the median
duration over which a SET of partials persists together, against the median
duration of any single partial persisting alone.

Reads harmony as simultaneity that holds. A factory producing a chord has sets
that persist; one producing successive independent tones has single partials
persisting while sets churn. This is closer to what the isolation run sounded
like and it inherits the duration machinery already built for M-D.

**Preference: B**, with A computed alongside as a descriptive companion. B asks
the question the ear raised (nothing holds together vertically) and it does not
smuggle in a theory of which intervals are good.

## The calibration this must pass before it exists

The same three the registry requires, and the second one is where M-D failed:

1. **Saturation check.** LOOP, FACTORY, DIVERSE arms. If a literal loop does not
   separate from 140 unrelated FMA tracks, the statistic does not discriminate
   and it does not enter. This has killed four measures.
2. **A decision rule that can fail.** M-D's statistic discriminated and its RULE
   could not: a median with a pooled standard deviation is unfalsifiable for
   heavy-tailed durations, and LOOP was identical to FACTORY by construction
   because LOOP is a repeat of the factory's own output. So the contrast here is
   **FACTORY against DIVERSE**, LOOP dropped for the same reason, and the null
   is a permutation over the frame sequence and not a pooled standard deviation.
3. **A sounding-fraction covariate.** FACTORY sounds 64% of the time against
   DIVERSE at 99.7%. Any duration statistic must condition on sounding frames or
   it measures silence.

## What this does not settle

Whether the factory should be able to produce harmony, which is the composition
question underneath the measurement question. A measure can report that the
vertical dimension does not move; it cannot say whether the machines have any
mechanism by which it could. `Simultaneity` is wired to `raw_hz` and the vertical
dimension steers voice degree, so a mechanism exists; whether it can produce
sustained co-sounding sets at macro rates is an open question this measure would
help answer and would not answer alone.
