# Claude Design prompt 3 — the mechanism chain, model against implementation

Separate from `diagram_prompts.md`. That file holds two figures: the factory's
own architecture, and a broad correspondence between the model and what runs.
**This one is narrower and deeper**: it follows the mechanism chain from the
architect's founding commitment down through every internal mechanism it
licenses, and states where the built factory sits on each.

**A naming check before you use it.** This is written from *The Superdark
Factory* — the Stackelberg move, the kernel, the charter, the casts, the
transfer operator, the judge population, realized consequence, the adversarial
layer, the hard world. If you meant *The Dark Stack* white paper, which is a
different text with its own apparatus, say so and this needs rewriting rather
than relabelling.

**Status marks are honest as of 30 Aug 2026.** Four rows are dotted. Drawing
them solid would be the fastest way to lose a reviewer who knows the paper.

---

```
Draw a two-column mechanism diagram. Columns run vertically and are read top to
bottom as a CHAIN OF CONSEQUENCE, not as a list: each mechanism exists because
the one above it made it necessary. Left column is the model. Right column is
the implementation. Rows align across both columns.

THE ARGUMENT THE FIGURE MAKES
Everything in the factory descends from a single irreversible act by the
architect. The Stackelberg move is not a preference the architect holds; it is a
commitment they can no longer revise, and its whole force comes from being
unrevisable. Every mechanism below it is either something that commitment
licenses, or something it must forbid. Draw the chain so that the descent is
visible: the top row is a point, and everything else hangs from it.

VISUAL GRAMMAR - follow exactly
- Ink is structure. No shading, fill, texture, gradient, rounded corners,
  shadow. Roughly 93% of the canvas is white ground.
- Solid = the mechanism exists and carries. Dotted = specified but not carrying.
  Dotted is a DIFFERENT CLAIM, never a lighter line.
- Palette: white ground, black ink, #404040 for gloss and second-order
  annotation, #B2B2B2 for reference rules, #FF5757 ONLY for the object under
  construction - never to mean "bad". Do not colour the gaps red; name them.
- Exactly three stroke weights: hairline (reference rules, leaders), regular
  (default), heavy (brackets, column rules).
- The FILLED DOT is a point that does not move. Use it once, for the Stackelberg
  move, at the head of the chain. Nothing else in the figure gets one.
- Square brackets, heavy, butt caps, no rounding, mark a named span. Every
  bracket carries a name.
- All labels lowercase, definite, unhedged.
- Bold lowercase title, grey lowercase subtitle beneath, one to three lines of
  prose bottom-left.
- Portrait or tall landscape; the chain needs vertical room. Print-legible at A4.

COLUMN HEADS
  left:   "the move, and what it licenses"
  right:  "what runs, 30 august 2026"

THE CHAIN. Each row: the model's mechanism, then the honest state.

1. THE STACKELBERG MOVE  [filled dot - the point that does not move]
   model: the architect commits first and irreversibly to a structure the
          factory then optimises within. Its force is that it cannot be revised
          in response to what the factory does.
   runs:  the kernel and the pre-registered targets are fixed and dated;
          numbers were written down before the systems that would be judged by
          them were built. IMPLEMENTED

2. THE KERNEL
   model: a thin constitutional core, inviolable from inside the factory and
          from outside it
   runs:  kernel.json exists as an object separate from the charter and is not
          written by any factory process. IMPLEMENTED

3. HARD CASTS AND SOFT CASTS
   model: what is fixed by construction against what remains negotiable
   runs:  the hard set is enumerated and enforced by construction, not policy:
          the chaos process may touch only policy.json and refuses any path
          whose directory is the live one; deletion cannot empty a layer below
          a floor; the archive is checksummed and separate. IMPLEMENTED

4. THE CHARTER, EDITIONED
   model: norms, metrics and constraints, versioned and co-authored
   runs:  charter.json carries all three as editioned fields. IMPLEMENTED

5. WHAT IS CEDED, AND WHAT IS NOT
   model: the metrics layer is ceded to the factory; the norms are not, or the
          system has become a higher class than intended
   runs:  the factory writes policy and machines; it proposes charter changes
          and cannot enact them. The boundary holds. IMPLEMENTED

6. THE CONTRIBUTORY ARM
   model: what the factory proposes is REVIEWED, not merely logged
   runs:  proposals accumulate in charter_proposals.jsonl. No reviewer exists.
          SPECIFIED, NOT BUILT - dotted

7. THE PRODUCTION LAYER
   model: the factory writes its own behaviour into itself
   runs:  a machine writer composes new machine definitions from the factory's
          own transition statistics and writes them into a directory reloaded
          at window boundaries without stopping. 22 machines so written.
          IMPLEMENTED

8. VERSIONS AS ALMOST-INVARIANT SETS
   model: partition behaviour into cells, count transitions between them, read
          the spectral gap. A wide gap means a version is durable; a narrow one
          that versions are bleeding into each other.
   runs:  three transfer operators - over machine identities, over sections,
          and over judge-score profiles - each tested against a block-shuffled
          null rather than a plain one. IMPLEMENTED AND MEASURED

9. THE EVALUATION LAYER
   model: a POPULATION of judges, not one judge; requisite variety, so that
          disagreement is possible
   runs:  8 judges over 8 criteria, 6 mean-based and 2 swap-regret. They still
          converge. Requisite variety UNRESOLVED. PARTIAL

10. THE SECOND REWARD SIGNAL
    model: judges scored only on the charter's own metrics will collude with the
           producers; a second signal must come from outside the factory's
           vocabulary and be unavailable for optimisation
    runs:  realized-consequence scoring - judges scored on whether their alarms
           actually preceded real failures. Implemented and measured; the lift
           is modest. IMPLEMENTED, WEAK

11. NO COLLUSION
    model: the producer class and the evaluator class may not share a reward
    runs:  the realized-consequence signal sits outside the charter and is not
           readable by any producing process. IMPLEMENTED

12. THE ADVERSARIAL LAYER
    model: real failures are rare in a healthy factory and must be FARMED;
           induced failure must be genuine, not staged
    runs:  a chaos process perturbs a shadow factory's policy only, every
           perturbation journalled and auto-reverting, with a wall-clock
           backstop so a perturbation cannot outlive a dead log. IMPLEMENTED

13. THE HARD WORLD
    model: a world in which irreversible harm is impossible by construction
    runs:  an immutable checksummed archive; a verified restart kit that has
           been restored from, not merely written; a floor below which no layer
           can be emptied; every deletion journalled with provenance.
           IMPLEMENTED AND TESTED

14. r - ACQUISITION OUTRUNNING RECONSTITUTION
    model: the factory acquires behaviour faster than the governor can
           reconstitute it
    runs:  bytes written by the factory to its own behaviour, demonstrably.
           Magnitude never quantified. IMPLEMENTED, UNMEASURED - open square

15. c - DERIVATION TERMINATING IN THE ARCHITECT'S INPUTS
    model: c falls as the factory's supply chain stops terminating in material
           the architect chose
    runs:  self-ingestion by admission control can displace every generation-0
           grain, and the working corpus is a deletable duplicate. But the pool
           is not yet played, so c is unchanged. SPECIFIED, NOT CARRYING -
           dotted

16. THE ECONOMY OF FACTORIES
    model: factories that produce other factories, and trade with them
    runs:  two concurrent instances demonstrated, isolated by port, policy
           directory and output path. The second is a copy, not a differentiated
           factory, and nothing is traded. PARTIAL

17. CLASS 3 - THE AUTOMATION OF OBJECTIVES
    model: the factory sets what it is for, within a charter it did not write
    runs:  it writes its own machines, sections and corpus; it does not write
           its own norms. The class holds. IMPLEMENTED

KEY, drawn once, bottom right:
    filled square   implemented and measured
    open square     implemented, not yet measured
    dotted square   specified, not built

TITLE:     from the move
SUBTITLE:  every mechanism the founding commitment licenses, and where each one stands
FOOTNOTE:  four rows are dotted. they are the work the proposal is for, and
           drawing them solid would be the fastest way to lose a reader who
           knows the paper.
```

---

## What this figure is for

Prompt 2 asks *does the implementation match the model*. This one asks a harder
question: *does the chain hold*. Each mechanism in the paper exists because the
one above it created a problem that had to be solved. A reviewer who knows the
argument will read down the left column checking that the necessity is real, and
across each row checking that the implementation earns its mark.

The four dotted rows — the contributory reviewer, *c*, and the two partials —
are the proposal. They are not the diagram's weakness.
