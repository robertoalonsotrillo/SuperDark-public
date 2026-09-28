# The shared interval table has no source, and that is the finding

2 Sept 2026, from two shadow runs of the simultaneity work.

## What the shadow run was for

`Simultaneity` can offer a table of ratios that written machines draw their rates
from, so verticals relate without any voice querying another. The table has to
come from somewhere, and the honest source is the material: ratios between
pitches the factory can actually reach, so it cannot ask for an interval the
corpus cannot make.

Both candidate sources fail, for different reasons, and neither failure is
visible offline.

## Source 1: the corpus pitch column — normalised, not Hz

`descriptors.json` carries `norm.pitch`, present on 2,399 of 2,400 grains. The
first shadow run built the table from it, and the table came back `[1.0]`.

The mechanical failure hid a conceptual one. **The quotient of two normalised
coordinates is not an interval.** `norm.pitch` runs 0 to 1 after standardisation;
dividing one by another produces a number with no musical meaning at all. Had the
column been better conditioned, the table would have been non-degenerate and
wrong, which is worse. The descriptor file has no raw-Hz column to fall back on:

    top-level keys: _order, _comment, _keys, _variance_explained,
                    _pca_mean, _pca_scale, _pca_components, index, norm
    norm:           pc0 pc1 pc2 pc3 pc4 pitch clarity

## Source 2: the live detector — reports unpitched

`hasPitch` is `msg[8]`, from the analysis of the factory's **own output**, not
from the corpus. Across both shadow runs it stayed at zero: `mainpitch` was
`\unpitched` every window, `pitchratio` was 1.0 every time, and `hzSeen` never
filled. So the Hz-based table has no input either.

This also explains something older. `mainpitch` has been computed every window
since pitch entered the geometry and it has always been `\unpitched` on this
material — so the two-line fix to make the template read it changes nothing until
the detector has something to report. The template discarding the number was
never the binding constraint.

## What this means for the harmonic work

The blocker is the **analysis pipeline**, not the factory. To build an interval
table from the material, corpus analysis has to record pitch in Hz alongside the
normalised column. That is a change to the descriptor builder and a corpus
rebuild, not a change to anything running.

The alternative is the `\just` arm — small-integer ratios — which works today and
is labelled in the class as an import rather than a discovery. It is a legitimate
contrast arm. It is not the factory finding a harmonic system, and reporting it
as one would be the fifth overclaim of this kind here.

## What the shadow runs did establish

- The grammar arm runs live: `GRAMMAR on, depth 3`, machines acquired, zero
  errors across both runs, `SIMUL` lines written every window.
- The degenerate-table guard works. The first run emitted
  `\rate, Pn(Pseq([1.0], inf), inf)` — a constant, which is *less* pitch movement
  than the August template's random draw. A table now needs two distinct members
  before it is used at all, and machines fall through to the grammar otherwise.
- The intervals in that first run's `SIMUL` histogram — concentrated on 0, 5, 7
  and 12 semitones — came from the **pre-existing vocabulary**, not from the
  mechanism, because the mechanism was emitting constant rates. A histogram that
  looked like a result was an artefact. This is exactly why the observing half is
  built to run with the offering half switched off.

## Order of work

1. Record pitch in Hz at corpus build, beside the normalised column.
2. Then rebuild one corpus and re-run the shadow with `simultaneity_weight` on.
3. Only then compare interval histograms against the weight-zero baseline, which
   the live factory is now accumulating on its own.
