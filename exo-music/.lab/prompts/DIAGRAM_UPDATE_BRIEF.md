# Brief for updating the three Claude Design diagram prompts

Paste this whole file to the agent. It carries the paths, the facts and the rule
about what may not change.

## The files to edit

Absolute paths on Roberto's machine:

    /Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/.lab/prompts/diagram_prompts.md
    /Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/.lab/prompts/diagram_prompt_3_mechanisms.md

Both are already in `docs/` and versioned with the system they describe, so the
figures and the code move together — a figure that drifts from the code is how a
reviewer finds an overstated edge.

Ground truth to read before editing, in this order:

    workdir_music/mutable/charter.json        edition, metrics, bounds
    workdir_music/mutable/kernel.json         edition, armed
    workdir_music/mutable/kernel_journal.jsonl  every firing
    workdir_music/mutable/policy.json         which weights are at zero
    workdir_music/mutable/charter_decisions.jsonl  the contributory arm, exercised
    docs/*.md                                 the findings, including negative ones

Repository: https://github.com/robertoalonsotrillo/SuperDark

## What may not change

The visual grammar in each prompt stays exactly as written: ink is structure,
93% white ground, three stroke weights, six type sizes, lowercase labels, the
palette, the bracket rules. **Dotted is a different claim, never a lighter
line. Nothing goes solid in anticipation.** Only status marks, edge styles and
factual figures change.

## Corrections — `diagram_prompts.md`, PROMPT 1 (architecture)

| drawn as | should be |
|---|---|
| corpora "22050 Hz" | **44100 Hz**. The 22050 corpus on a 44100 server was itself an artefact — interpolation imaging heard as hiss. |
| "5,400 preloaded buffers", three sizes | **three corpora, 0.06 / 0.35 / 0.80 s, 2400 / 1800 / 3000 grains.** Rebuilt 3 Sept. See the section below: the previous macro length was 2.0 s and it should never have existed. |
| "FROZEN 7-dimensional descriptor space" | **6 navigated dimensions** — pc0–pc4 plus pitch. Clarity is carried but not navigated, and a raw-Hz pitch column was added 3 Sept. Still frozen at generation 0; that label is correct. |
| judges: "8 judges, 6 mean-based and 2 swap-regret" | **9 judges, plus 9 tier-two learners** — two tiers, both passing negative controls, both steering nothing |
| kernel: "a thin constitutional core, non-writable" | true, and incomplete. **It is armed and has fired twice** — 1 Sept on three sustained failures, 2 Sept on the never-tolerated clipping clause. Both stopped the factory. Draw it as a core that has acted. |
| output: "virtual audio device -> MP3 encoder" | **named pipe -> non-blocking splitter -> encoder + segmenter**. The splitter reopens when the factory restarts, so delivery survives a factory restart. |
| charter | **edition 6** |
| pool -> corpus, dotted "not connected" | still dotted, but the reason changed: it is **wired now and the weight is 0.0**. Relabel "wired, weight zero" — built and not carrying is a different claim from not built. |

**THREE CONCURRENT LAYER SLOTS — the largest structural change, and it is LIVE.**
The window loop is drawn as selecting ONE machine per window. It now maintains
one slot per timescale, each selecting from its own layer, holding for its own
dwell and sounding with its own span: macro holds ~170 s, mid ~44 s, micro ~18 s,
all three sounding TOGETHER. Before this the layers were alternatives, so a macro
behaviour meant no grains underneath it. Solid. This is the mechanism that turns
"nested control loops at different time constants" from a description of the
diagram's layout into a description of the audio.

Also not yet drawn: the **pattern grammar** (machines whose *shape* the factory
composes, not only whose numbers). It exists and is switched off. Dotted.

## What changed on 3 September, and it is most of the figure

Six things landed in one day. Four of them correct faults that had been in the
system for weeks and were invisible because the mechanism they broke had never
been switched on. A figure drawn from the old prompts would be wrong in the
architecture, not only in the numbers.

**MACRO IS A CONTROL TRAJECTORY, NOT LONG MATERIAL.** This is the conceptual
correction and everything else follows from it. The layer had been built as long
grains — 2.0 s — on the argument that grain length should match each machine's
measured event interval. That matches the wrong two quantities: event interval
is a property of RHYTHM, grain length is a property of MATERIAL, and matching
them hands a slow behaviour long samples, which makes it a sampler. Heard for
the first time on 3 Sept it was 1200 unaltered two-second excerpts at rate 1.0.
Roberto: *"macro is looking for behaviours that generate sonic or structural
continuity… this is fully unrelated to behaviour."*

The 2 s length was never proposed or approved. It first appears 31 Aug inside a
commit about shellac crackle, under a script comment reading "geometry
unchanged". It was also the largest block of unaltered recording anywhere in the
system, 40 minutes, and therefore the most exposed part of the corpus on
licensing. It is retired, not deleted. **If the figure has a "what the architect
decided" column, this belongs in it as a decision that was taken silently.**

A macro behaviour is now: a machine's own measured event interval becomes the
PERIOD of a slow trajectory over spectral centre and transposition, while the
grains underneath stay short. Draw it as a long control loop over short
material, which is what "nested control loops at different time constants"
always claimed and never was.

**A HELD NOTE CANNOT BE CONCATENATED.** Measured on 78 s of the delivered
stream: the dominant partial's stable runs had a median of 0.03 s and a maximum
of 0.36 s, none reaching half a second. Selecting grains that share a detected
pitch changed nothing, because a 0.8 s grain is a slice of polyphonic music and
six such slices are six different pieces of music. The macro layer now uses
granular resynthesis (`GrainBuf`, one buffer, slowly moving read position,
overlapping windows that sum coherently). Shadow measurement: longest held pitch
**0.36 s → 2.02 s**, 10.3% of sounding time in runs over half a second, against
zero before. **Two boxes, not one: concatenation for micro and mid, resynthesis
for macro.** They are different mechanisms and the figure has only ever drawn
one.

**THE WALK WAS ISOTROPIC.** Measured over 19 runs and 8,948 windows: pitch
persistence 0.894 against sibling dimensions at 0.891–0.899, identical step
size. Pitch was moved by exactly the rule that moves the third principal
component of a cepstrum, so there was no melodic dimension in the space at all.
Now anisotropic in two independent ways — in the METRIC (pitch weighted ×4, so
it is ~2/5 of the selection distance instead of 1/6) and in the DYNAMICS (holds,
then moves by an interval, pulled toward a drifting tonic, snapped to degrees
the corpus actually contains). **No tuning system is imposed**; the available
degrees are whatever 2,295 pitched grains across 4.6 octaves afford.

**THE VERTICAL DIMENSION IS RECORDED AND STEERS NOTHING.** There was no
coordination between voices of any kind; two voices sounding together did so by
accident. Every voice now carries the pitch it is sounding and each window logs
the set as octave-folded ratios against the lowest. The decision was to let the
factory LEARN vertical structure instead of being handed a consonance model.
`tools/vertical_census.py` tests the distribution against the same pitches
reassigned at random across windows — if they match, the factory has no vertical
structure and any harmony heard is the listener's. **That is the expected answer
today.** Dotted, and the dotted line is the honest part of the figure.

**THERE IS NO DSP.** Counted from source, every UGen in the factory:
PlayBuf ×7, GrainBuf ×3, BPF ×2, HPF ×1, LPF ×1, Pan2 ×2, EnvGen ×4,
LFNoise2 ×4, Impulse ×4, Limiter ×1. The FFT chain is analysis on the listener
bus. No reverb, delay, comb, allpass, pitch-shift, distortion, compression,
feedback or spectral processing anywhere. A voice is read-a-buffer, one filter,
pan, out. **If the figure implies a signal chain, it is implying something that
does not exist** — and the gap is worth drawing as a gap, because it is one of
the largest remaining.

**A SYNTHDEF FAULT THAT HID FOR TWO WEEKS.** `\playback` let the envelope and
the buffer disagree: the synth lives for atk+rel, `PlayBuf` had `doneAction:0`
and no loop, so a 5.1 s envelope on a 2 s buffer was two seconds of a recording
followed by three seconds of a synth outputting silence. Invisible while every
buffer was 60 ms. Not a diagram row, but it is the reason two weeks of listening
notes describe symptoms that were never about the architecture they blamed.

## What changed on 4 September

Five more, and two of them change rows the 3 September section had only just
corrected. Read this section second; where it conflicts with the one above, this
one is later.

**43% OF THE CORPUS'S "PITCH" WAS THE DETECTOR GIVING UP.** 2004.55 Hz appears
979 times in the micro corpus, 765 in mid, 1287 in macro — 42.7%, 43.3%, 44.2%
of every grain the analyser called *pitched*, at exactly the same value. That is
the tracker's upper search bound reporting failure, not a corpus sitting on one
frequency. Three things were running on it: the Hz↔coordinate map had 43% of its
range collapsed onto one frequency, so every percentile from p80 to p95 returned
the same number; `pitch_weight` 4.0 was strongly selecting for that
undifferentiated mass, so **the melodic dimension spent much of its range
selecting for analysis failure**; and the top tonic centre *was* the saturation
value. Dropped by a structural test — the maximum when it exceeds a twentieth of
the values — so 2,295 pitched grains become 1,316. **If the figure labels the
pitch dimension, it should say 6 navigated dimensions of which one is now
filtered for detector saturation.**

**THE FACTORY CAN RETURN TO A TONAL CENTRE.** Recurrence across a gap no voice
can bridge was measured *below chance* — 3.8% against 7.3% ± 1.4, z = −2.53. It
was not failing to build harmony; it was moving away from every vertical
configuration it reached, because the tonic drifted freely and sections reset it.
It now steps between five centres, spaced in log frequency and snapped to
pitches the corpus holds: **98.4, 195.1, 386.8, 760.3, 1575.0 Hz — near-octaves,
which the corpus chose and nobody imposed.** The walk reflects at the ends rather
than clipping, because a clipping random walk piles up at its boundaries: 114 of
224 tonic moves had sat on one centre.

**PER-VOICE DIVERGENCE — the largest change to what a voice IS.** There was one
global `target` and `grainPath` handed the SAME neighbourhood to every voice, so
three voices sounding together drew from one pool of ~120 grains around one
point. The machine chose *when* and *how loud*; the target chose *what material*;
and the target was shared. That is why different machines sounded alike, and it
is not a fault in the machines. Each voice now gets three properties **assigned
once at birth and held for its 40–90 s life** — a displacement in descriptor
space, a degree around the shared tonic, and a phase in the DSP trajectories,
with the resonator ringing at *that voice's* note. They are positions, not
jitter: within-machine spread is already at chance, so more randomness would make
machines *less* identifiable. **Draw the voices as displaced from a shared moving
point, not as sharing it.**

**A LAYER MAY NOW BE ABSENT.** The keeper refilled every slot the instant it
emptied, so silence in a layer was impossible by construction: over 376 windows
micro had zero voices in ONE, and that was the startup window. All three layers
sounded 99.7% of the time. Now macro rests 10% of the time, mid 25%, micro 40%.
**The three-slot row should no longer imply all three always sound.**

**THE DELIVERED SIGNAL IS MEASURED AT LAST.** The stream had been peaking at
1.067 (+0.57 dBTP) while `m3_no_clipping` read 0.0 in all 410 windows — both
correct, because the limiter holds the SAMPLE peak and the MP3 encoder then
returns samples above the ones it was handed. Ceiling 0.9 → 0.80, and the
delivered peak now measures 0.868 with zero samples at full scale.

### Two new instruments, and what they found

`tools/sonic_variety.py` and `tools/machine_variance.py` exist because every
variety metric in the charter is over machine IDENTITY and can pass while the
output is sonically identical. Their findings are the strongest material added
since the last revision, and all three are negative:

- **The factory is not repetitive relative to its material.** Recurrence 0.9928
  against its own time-shuffled null of 0.9935, z = −0.17 — and *less*
  self-similar than randomly shuffled grains from the same corpus.
- **The material is extraordinarily narrow.** Shuffled corpus grains occupy
  **4.79 of 24 spectral dimensions**; the delivered stream occupies **3.38**. The
  factory narrows an already narrow space by ~30%, and 4.79 is the ceiling until
  processing or a wider corpus raises it. **This is the single most important
  number for anyone asking why it sounds the way it does.**
- **A machine does not repeat itself.** Within-machine spread 2.859 against a
  label-shuffled 2.852, z = +0.88. Machines differ from each other reliably
  (z = +8.13) but by one fifth the size of the variation inside one. A machine is
  a distribution so wide that calling it a behaviour overstates it.

## Corrections — `diagram_prompts.md`, PROMPT 2 (comparison)

Row 6, "the contributory arm — a reviewer for what the factory proposes /
**not built. dotted**" is the important one. It is **built and exercised**: 93
proposals, 93 answered, 92 refused with a reason recorded against each
individual proposal. Solid, filled square, and it is the strongest single change
in the file.

Row 3 (`c`): the pool is wired and the weight is zero — see above.
Row 7 (evaluation): two tiers of judges now, not one.
Row 10 (economy of factories): a shadow instance now runs with its own classes,
conf, port, mutable directory, capture FIFO **and factory source**, so the two
instances can run different code. Still a copy rather than a differentiated
factory; keep "partial".
Row 11 (the world): unchanged. Still no source. Dotted.

## Corrections — `diagram_prompt_3_mechanisms.md`

Marked honest as of 30 Aug. The kernel and contributory-arm rows move for the
same reasons as above. Everything else holds.

## Rows worth adding, if a fourth figure is ever drawn

The honest negative findings are the strongest material here, and none is drawn:

- the kernel does not fire on a factory 40 dB down and 98% silent — two metrics
  fail and the tolerance is two
- `m4_vocabulary_breadth` moves the WRONG WAY under fragmentation, so the
  charter rewarded the failure the listener heard
- the target walk is isotropic: pitch is moved by the same rule as pc3, so there
  was no latent tonality to find
- 147 machines had been written from a single four-operation SynthDef
- **r is quantified at last**: 420 writes across 69 runs, of which 59% reused a
  name because the counter restarted each run. The factory destroyed 405,666
  bytes — 65% of every behaviour it had ever authored. Fixed by a run stamp and
  a persistent ledger; the loss is historical. This is the NUMERATOR of r, not
  r itself, and the figure should say so.
- **the factory's own 156 machines were all played as micro.** `layerOf` read
  `weights.json` and nothing else, and fell back to "micro" for anything absent
  from it. weights.json holds the twenty machines the architect wrote. Micro is
  not a label: it decides the corpus a machine is handed, the span it is cut at,
  and the slot it may occupy. Machines with 0.46–8.0 s event rates were handed
  60 ms grains and stopped after twelve seconds.
- **the writer had no `mid` at all.** `layer = if (dur < 0.15) {"micro"}
  {"macro"}`, and it interpolated event rates arithmetically across three orders
  of magnitude, so every bridge landed slow. Result across all 156 written
  machines: every one macro, nothing below 0.46 s. The factory had never
  authored a grain or a gesture.
- **every spare voice went to the micro slot.** The top-up loop drew from
  `currentState`, which is defined as `slotMach[micro] ? mid ? macro` and is
  therefore always the micro machine. Three slot voices then received five more
  copies of the SAME 60 ms machine, so they ran one rhythm and could not fill
  each other's gaps. Measured: median sounding run 0.06 s, median gap 0.06 s,
  74% of frames below a tenth of peak.

These four are the strongest material in the file. Each is a mechanism that was
drawn as working, was reported as working by the factory's own metrics, and was
not working. A figure whose dotted rows are its own measurements is more
convincing than one whose rows are all solid — and a figure that shows WHICH of
its own claims turned out to be false is more convincing still.

Three more from 4 September, all of the same kind — the mechanism reports healthy
because nothing checks that it exists:

- **an orphaned log handle cost 2.5 hours.** The factory reached window 710 and
  its log held twelve lines; `wlog` was called 710 times and every write went
  nowhere. `isOpen` reported true throughout, and correctly — a descriptor whose
  inode has been removed is still a valid open file pointing at nothing. The
  self-healing check tested whether the handle was CLOSED. It was orphaned. Now
  the test compares bytes written against the file size on disk.
- **the kernel guard was not running.** Nothing had watched from 19:00 on 3 Sept
  through every change of the following day, while `kernel.json` said
  `armed: true`. The kernel was armed in name only while the factory was rebuilt
  six times underneath it.
- **delivery survived a restart and the stream did not.** ffmpeg ran two hours
  across four factory restarts without respawning, so the processes really did
  survive — and on writer close the splitter called a blocking `os.open` and fed
  the encoder nothing for the two minutes SuperCollider takes to boot. Measured
  as −1267 s of clock skew over 6.3 hours. It now fills the gap with silence,
  paced against the wall clock, and has since covered three real outages exactly:
  "writer back after 135.9s, 136.0s of silence sent".

**If a fourth figure is drawn, this is its subject.** Not the architecture, but
the gap between what a system reports about itself and what is true — six
mechanisms, each of which passed its own check while failing. That is the
project's actual finding, and it is more interesting than any of the boxes.

A figure whose dotted rows are its own measurements is more convincing than one
whose rows are all solid.
