# Two Claude Design prompts — GRF 2027/28 figures

Drafted 28 Aug 2026, from the system as it actually stands, not as intended.

**Read this before pasting.** Two things in the prompts are deliberately drawn as
*not yet connected*, because they are not:

1. The factory reads `grains_lic_*` (the archive working copy). It does **not**
   read `self_corpus/grains_pool_*`. Self-ingestion builds the pool, and the
   pool is never played. The material loop is one environment variable from
   closing and is not closed. Drawn dotted.
2. `self_ingest_weight = 0`, and the world channel has no source. Both wired,
   neither carrying. Drawn dotted.

If either changes before you render, change the edge to solid — but do not
render them solid in anticipation. A reviewer who finds one overstated edge
rereads every other one.

---

## PROMPT 1 — the architecture

```
Draw a single technical system diagram of a generative music factory, for
readers who read systems papers: the register is a distributed-systems or
control-systems figure, not an illustration. It must be legible to a computer
scientist who has never heard the music.

THE CLAIM THE FIGURE MAKES
The system is a closed-loop mechanism that automates its own automation. It does
not only produce output; it produces the means of producing output — its own
corpus, its own behaviours, its own section vocabulary — and it evaluates itself
against signals it cannot edit. Draw it as NESTED CONTROL LOOPS AT DIFFERENT TIME
CONSTANTS. That nesting is the argument; make it the spine of the layout.

VISUAL GRAMMAR — follow exactly
- Ink is structure. No shading, fill, texture, gradient, rounded corners, drop
  shadows. Roughly 93% of the canvas is white ground.
- Solid line = an actual path, carrying now. Dotted line = built but not
  carrying, or expected and unprovisioned. Dotted is a DIFFERENT CLAIM, never a
  lighter line.
- Palette: white ground, black ink, #404040 for second-order annotation and
  subtitles, #B2B2B2 for reference lines, #FF5757 used ONLY to mark the object
  under construction (never to mean "bad"), #00BF63 only if something must be
  valuated positively.
- Exactly three stroke weights: hairline (reference lines, leaders, dotted
  rules), regular (default), heavy (brackets and container outlines).
- Arrowheads are filled triangles. A double head means the relation runs both
  ways. A curved shaft means the return path is not the outward path.
- Square brackets, heavy, butt caps, no rounding, mark a named span. EVERY
  bracket carries a name.
- All labels lowercase, definite, unhedged: "the charter", "a version".
- Type: one bold lowercase title, a grey lowercase subtitle beneath it, and one
  to three lines of prose bottom-left. Six type sizes maximum.
- Landscape, dense, print-legible at A4 width.

THE SUBSTRATE (fixed; the factory cannot write here)
- A real-time audio server holding 5,400 preloaded buffers.
- A class library of 20 machine behaviours.
- kernel.json — a thin constitutional core, non-writable from inside.
Bracket these together and name the span "the kernel — not writable from inside".

THE CORPUS (the material)
Three parallel grain corpora, all 22050 Hz stereo 32-bit with a 3 ms fade:
  ev     2,400 grains  @ 0.060 s   (micro / texture)
  mid    1,800 grains  @ 0.400 s   (gesture)
  macro  1,200 grains  @ 2.000 s   (shape)
Each grain carries a point in a FROZEN 7-dimensional descriptor space:
5 PCA components over MFCC statistics (coefficient 0 dropped so the metric is
timbral, not loudness-driven), plus pitch and pitch-clarity carried separately
because MFCCs cannot recover them. Label the space "frozen at generation 0 —
projected into, never re-derived".

LOOP 1 — GRAIN SELECTION (50 ms to 2 s)
target point in descriptor space
  -> k-nearest-neighbour neighbourhood
  -> nearest-neighbour ordered path through that neighbourhood
  -> sequential grain playback along the path
Annotate: ordered traversal, not shuffled — this is what produces continuity at
the grain scale.

LOOP 2 — THE WINDOW (13 to 25 s)
A descriptor-event callback drives a window loop that:
  selects the active machine from the population
  routes it to ev / mid / macro by its own measured event rate
  maintains a continuous voice population (voices are replaced as they retire,
    with jittered spans, rather than refreshed in lockstep)
  re-reads policy.json and weights.json every 10 windows
  writes one line per window to a self-healing log
Label policy.json "the ceded layer — the factory writes here".

LOOP 3 — SECTIONS (minutes)
Section recall vs. new-section formation; section mutation; a novelty detector
that writes proposals to charter_proposals.jsonl. Two transfer operators run
here: one over machine identities, one over sections, each reporting a spectral
gap as a readout of whether versioning is occurring at all.

LOOP 4 — SELF-INGESTION (10 min) — THE MATERIAL RETURN PATH
Show as a curved return, because the return path is not the outward path:
  master output -> rotated capture chunks, 600 s each, ~212 MB
  -> decode (with recovery for chunks the factory never closed)
  -> random-offset slices at all three grain lengths, NOT onset-aligned
  -> physical vetting only (silent / clipped / DC-offset / non-finite / constant)
  -> descriptor projection into the FROZEN basis
  -> ADMISSION CONTROL: a candidate is scored against the WEAKEST INCUMBENT of
     its layer and admitted only if it beats it by a margin; on admission it
     takes that incumbent's slot in place, keeping the integer index
  -> a fixed-size pool, every grain tagged with its generation
Mark the scoring terms as a bracketed span named "the admission score":
  audible + articulate + distinct + a homeostatic harmonic term
Annotate the harmonic term: "signed — rewards whatever is scarce relative to the
seed's pitched fraction, in both directions".

>>> DRAW THIS EDGE DOTTED: pool -> corpus. The pool is built and is not played.
>>> The factory currently reads the archive working copy. Label the dotted edge
>>> "not connected". This is the honest state of the system.

LOOP 5 — BEHAVIOURAL RETURN PATH
A machine writer that composes new machine definitions from the factory's own
transition statistics and writes them into a directory the factory reloads at
window boundaries without stopping. Solid — this one carries. Label it "the
factory writing machines into itself".

THE EVALUATION STACK (off the audio path; draw to one side)
- A judge population: 8 judges over 8 criteria (silence, level, clipping,
  monotony, stasis, band, texture, flatness); 6 mean-based and 2 swap-regret.
- A transfer operator over judge-score cells, with a block-shuffled null, giving
  a spectral gap read as "is versioning happening at all".
- Realized-consequence scoring: judges are scored on whether their alarms
  actually preceded real failures (silence runs, clipping, vocabulary collapse,
  amplitude decay, clock jumps) — a signal that sits OUTSIDE the charter's own
  metrics and cannot be optimised against.
- An adversarial layer: a chaos process that perturbs a shadow factory's policy
  only, with every perturbation journalled and auto-reverted.
Bracket these and name the span "the second reward signal — outside the
factory's own vocabulary".

THE GOVERNANCE COLUMN (draw as a vertical stack, top to bottom)
  kernel        fixed, non-writable          [filled dot — a point that does not move]
  charter       editioned norms / metrics / constraints; the factory proposes,
                it does not enact
  policy        ceded — written by the factory while it runs
Annotate: "norms are not ceded; the metrics layer is".

OUTPUT
master limiter -> virtual audio device -> MP3 encoder -> Icecast mount ->
listeners. Solid.

DOTTED, UNPROVISIONED — draw and label as absent
- the world channel: an input for signals from outside the factory, wired, with
  no source connected
- a reviewer for the charter's contributory arm: specified, not built

TITLE:     a factory that automates its own automation
SUBTITLE:  nested control loops, and the two return paths that make the system closed
FOOTNOTE:  the material return path is built and not connected; the behavioural
           one carries. what is dotted here is not a plan, it is a measurement.
```

---

## PROMPT 2 — the comparison

```
Draw a two-column correspondence figure, columns horizontally aligned, sharing
one set of row labels down the left. This is a comparison between a theoretical
model and its partial implementation. The figure's job is to make the GAPS as
legible as the matches — a reader should be able to see, per row, what exists,
what partly exists, and what does not.

LEFT COLUMN:  "the model"  — the Superdark Factory paper and the exoharness
RIGHT COLUMN: "what runs"  — the implemented system, 28 August 2026

VISUAL GRAMMAR — follow exactly
- Ink is structure. No shading, fill, gradient, rounded corners or shadow.
  Roughly 93% white ground.
- Heavy horizontal rules separate row groups; hairline rules within a group.
- Solid = exists and carries. Dotted = specified but not carrying. Dotted is a
  different claim, never a lighter line.
- Palette: white ground, black ink, #404040 for gloss, #B2B2B2 for reference
  rules, #FF5757 ONLY on the rows where implementation is the current object of
  work (never as "bad"). Do not colour the gaps red — name them in words.
- Three stroke weights only. Six type sizes only. All labels lowercase.
- Each row's right cell ends with a small status mark, defined in a key:
    filled square   = implemented and measured
    open square     = implemented, not yet measured
    dotted square   = specified, not built
- Landscape, print-legible at A4.

ROWS — left cell is the model's commitment, right cell is the honest state.

1. class of automation
   model: automation of objectives, not merely of tasks — the factory sets what
          it is for, within a charter
   runs:  the factory writes its own machines, sections and corpus; it does not
          write its own norms. implemented, measured

2. r — acquisition outrunning reconstitution
   model: the factory acquires behaviour faster than the governor can
          reconstitute it
   runs:  a machine writer emits new machine definitions into a directory the
          running factory reloads. bytes written to its own behaviour.
          implemented; magnitude not quantified

3. c — derivation terminating in the architect's inputs
   model: c falls as the factory's supply chain stops terminating in material
          the architect chose
   runs:  self-ingestion can displace every generation-0 grain, and the archive
          is a duplicate the system is allowed to eat. but the pool is not
          played yet, so c is unchanged. SPECIFIED, NOT CARRYING — dotted

4. versions as almost-invariant sets
   model: partition behaviour into cells, count transitions, read the spectral
          gap; a wide gap means versions are durable, a small one that they are
          bleeding into each other
   runs:  three transfer operators built — over machine identities, over
          sections, and over judge-score cells — each tested against a
          block-shuffled null. implemented, measured

5. the charter, editioned
   model: norms, metrics and constraints, co-authored; the metrics layer is
          ceded, the norms are not, or the system is a higher class
   runs:  charter and kernel exist as separate objects; the factory writes
          proposals, it does not enact them. implemented

6. the contributory arm — a reviewer for what the factory proposes
   model: proposals are reviewed, not merely logged
   runs:  not built. dotted

7. the evaluation layer, and its second reward signal
   model: judges scored only on the charter's metrics will collude with the
          producers; a second signal must come from outside the factory's input
   runs:  realized-consequence scoring implemented — judges scored on whether
          their alarms preceded real failures. measured lift is modest and the
          judge population still converges: requisite variety unresolved.
          implemented, partly measured

8. the adversarial layer
   model: failures are rare in a healthy factory and must be farmed; producers
          and evaluators may not collude
   runs:  a chaos process perturbs a shadow factory's policy only, journalled,
          auto-reverting, with a wall-clock backstop. implemented, measured

9. a hard world — irreversible harm impossible
   model: the space of destructive acts is bounded by construction, not by
          policy
   runs:  an immutable checksummed archive plus a verified restart kit; a floor
          below which a layer cannot be emptied; every deletion journalled with
          provenance. implemented, measured

10. an economy of factories
    model: factories that produce other factories, and trade with them
    runs:  two concurrent instances demonstrated, isolated by port, policy
           directory and output path. but the second is a copy, not a
           differentiated factory. partial

11. the world
    model: the factory is coupled to signals it does not generate
    runs:  the channel exists and has no source. dotted

TITLE:     the model, and what runs
SUBTITLE:  a correspondence between the superdark factory and its implementation
FOOTNOTE:  four rows are dotted. they are the proposal's work, and drawing them
           solid would be the fastest way to lose a reviewer.
```

---

## If you want a third figure later

The one measurement that would carry a GRF panel on its own is the generation
drift curve: consecutive-generation spectral similarity against the
pre-registered target of below 0.9 for twenty generations, with the runs 12–13
noise-seeded baseline (converged by generation 4 at 0.936) drawn as the dotted
counterfactual. That figure cannot be drawn yet — it needs the loop closed and
many generations run. It is the strongest possible evidence figure and it is
empty today, which is itself worth knowing when planning the timeline.
