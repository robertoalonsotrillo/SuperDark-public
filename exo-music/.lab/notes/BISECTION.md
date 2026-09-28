# The bisection ladder, and what it found

30–31 Aug 2026. For review.

## The short version

The sound is shellac crackle. Thirteen of the source tracks in the corpus carry
impulsive noise, and the worst of them are transfers from the *Antique
Phonograph Music Program*: 78rpm surface pops, digitised faithfully. In a 60 ms
grain a shellac pop is most of the event, and the factory plays several grains
a second, so what reaches the ear is a steady scatter of very short impulses.
That is the "super short clipping sounds".

Nothing in the playback chain was ever at fault. The ladder proves it.

## Why the earlier tests all passed

Ten measurements of the live sum came back clean while the sound was plainly
audible. They shared one flaw: each measured *brightness* somewhere, and a
click is not brightness. A click is high-frequency energy that is **locally
anomalous**, far above the high-frequency background immediately around it. A
cymbal is bright everywhere and is not a click. A shellac pop is bright for two
hundred microseconds against a quiet background and is.

Specifically:

- the clip meter sampled `Peak` with `A2K` at control rate, one sample in 64;
- the discontinuity tests compared against a 10 ms envelope, two orders of
  magnitude longer than the event;
- `audit_corpus_clicks.py`'s "reversing spike" test fired on any high-frequency
  content at all, so its verdicts were worthless in both directions. It is
  superseded by `audit_grain_transients.py` and should not be trusted again.

The detector used throughout this apparatus high-passes at 6–8 kHz, takes a
short envelope, then divides by a **running median** of that envelope. A
uniformly bright signal scores about 1 however bright it is. A transient
against a quiet background scores in the hundreds. Median and not mean, so that
the clicks cannot raise the floor meant to expose them.

## The ladder

Every rung is rendered non-realtime: no audio device, no CoreAudio, no
BlackHole, no encoder, no scheduler jitter. If the sound appears in an NRT
render then the entire realtime and streaming apparatus is exonerated at once.
Each rung adds exactly one variable to the rung above it.

```
rung                           sec  peak dB   rms dB  pinned  clicks/s   worst
-----------------------------------------------------------------------------
R0_raw_grains                 20.0    -0.49   -15.68       0      4.40    20.4
R1_single_grain_control       21.0   -27.42   -44.55       0      0.00     7.5
R2_many_grains_no_filter      21.0   -23.56   -48.29       0      7.14   394.1
R3_many_grains_filtered       21.0   -29.27   -54.04       0      9.05    29.9
R4_two_voices                 21.0   -28.41   -50.54       0      3.57    28.8
R5_four_voices                21.0   -27.48   -47.11       0      5.19    26.6
R6_four_plus_master           21.0   -27.48   -47.11       0      7.19    14.5
```

R0 is the raw grains concatenated with no engine at all. R1 plays one single
grain over and over through `PlayBuf` and an envelope. R2 changes **only which
grains play**. R3 adds the BPF, R4 and R5 add voices, R6 adds the master chain.

Read the jumps, not the rows:

- **R1 → R2 is the whole story.** The engine is identical; only the material
  changes; events go from 0.00/s to 7.14/s and the worst anomaly hits 394.
- R2 → R6 adds the filter, the summing and the master chain and changes
  nothing of consequence. Those stages are innocent.
- R0 confirms it from the other side: the material clicks with no engine
  present.
- `pinned` is 0 everywhere, so the corpus rebuild did fix the hard clipping.
  That was a real fault and a different one.
- `dc` is at the 1e-7 level, which disposes of a risk I introduced: with
  `doneAction:0` a 60 ms grain sits under a 500 ms envelope for 440 ms, and had
  `PlayBuf` held its last sample instead of zeroing, that would have stepped DC
  once per grain. It does not.

## Two ways this ladder lied before it worked

Worth recording, because both failures looked like successes.

1. **Silent renders reported as passes.** The grains are named `g00.wav`, and
   the script asked for `g0.wav`. A failed buffer allocation is not an error in
   scsynth: the buffer stays empty, `PlayBuf` reads zeros, the process exits 0
   and writes a full-length file of pure silence. Two complete runs produced
   nothing but silence and printed six success lines. `bisect_report.py` now
   refuses to present any rung whose RMS is below 1e-6.

2. **A ladder that was not a bisection.** In the first table R1 and R2 played
   one grain while R3 played sixty-four, so the step from R2 to R3 changed the
   material and the motion together and a jump there would have been
   unattributable. The single-grain case is now a control, and every step moves
   one variable.

There was a third, in the measurement: R0 was first resampled from 22050 to
44100 by linear interpolation, which is an unfiltered upsample and manufactures
precisely the transients being counted. It scored 4.30 clicks/s of my own
making. `resample_poly` now applies the anti-imaging filter, and the corrected
figure is 4.40, so the conclusion survived. The method did not deserve to.

## Which tracks, and how it was confirmed

`audit_grain_transients.py` ranks every grain by worst local anomaly. The
damaged grains turned out to be **consecutive**, which is the tell: grains are
cut as runs of 24 from one track, so consecutive damage means whole tracks.

| corpus | grains | median | p99 | max | over 40 |
|---|---|---|---|---|---|
| `grains_lic_ev` | 2400 | 4.4 | 60.3 | 250.3 | 59 (2.46%) |
| `grains_lic_macro` | 1200 | 8.4 | 85.1 | 244.7 | 95 (7.92%) |

Seven tracks appear in **both** corpora, which is an independent confirmation
rather than one detector agreeing with itself. Looking them up in the FMA
metadata:

```
  122539  Old-Time / Historic   Complaining        Antique Phonograph Music Program
  122726  Old-Time / Historic   Fuzzy Wuzzy Rag    Antique Phonograph Music Program
  122411  -                     Experiment 6       Lithium Instrumentals
  152328  Electronic            No Title           VIVALDI
  121312  Hip-Hop               cloud cover        The Lars Demos
   47074  Electronic            We're the Resistors  Resistor Anthems
  131922  Instrumental          Snow               Cinematic
```

Eight consecutive macro grains from these sources share an identical maximum
sample step of 0.5208, which is one repeating artefact, not a spread of
material. The phonograph transfers settle the interpretation.

## The fix, and its evidence

`build_grains_onset.py` gained `--max-transient` (default 40) and
`--transient-frac` (default 0.25). It rejects a **whole track** when a quarter
of its run is impulsive. Track-level and not grain-level, because grains are
cut as consecutive runs and continuity is what fixed the radio effect; punching
holes in a run would trade one artefact for a worse one.

Rebuilt 40 tracks with the gate on, 2 rejected:

```
                  median   p99     max    over 40
  gated (960)        4.3   29.6    49.2   2  (0.21%)
  ungated (2400)     4.4   60.3   250.3  59  (2.46%)
```

The max drops by a factor of five and the p99 halves, while **the median is
unchanged**. That distinction matters: the gate removed the outliers without
dulling the corpus, which a cruder filter on brightness or peak level would not
have done.

## What this does not settle

- The gate is **calibrated on one listening problem**, not validated. 40 is a
  reasonable threshold from the distributions above, and it is a threshold I
  chose. It should be pre-registered before it is used to make any claim.
- The detector cannot distinguish damaged audio from music whose aesthetic is
  impulsive. Glitch and lowercase electronica will be rejected as damaged. For
  a corpus that is supposed to be an unchosen supply, that is a real narrowing
  and it belongs in the record, not in a footnote.
- **The corpus in use has not been rebuilt.** Everything above is measurement
  and a 40-track proof. The decision to rebuild `grains_lic_ev` and
  `grains_lic_macro` with the gate is yours, and it invalidates the descriptor
  basis and the pool, which would have to be refrozen.
- The `\playgran` octave problem is untouched. `GrainBuf` has no
  `BufRateScale`, so those grains play an octave high. That changes the music
  and is your call.

## Files

```
tools/bisect_render.scd            the NRT ladder, R1-R6
tools/bisect_report.py             measures every rung; builds R0; silence guard
tools/audit_grain_transients.py    ranks a corpus, names the tracks
tools/build_grains_onset.py        --max-transient / --transient-frac gate
workdir_music/stream/bisect/       the rendered rungs, for listening
```

To listen down the ladder, play them in order. R1 is the reference for clean.

To reproduce:

```sh
cd workdir_music
sclang -l tools/live_conf.yaml ../tools/bisect_render.scd
cd .. && python3 tools/bisect_report.py \
    --dir workdir_music/stream/bisect --grains workdir_music/grains_lic_ev
python3 tools/audit_grain_transients.py --dir workdir_music/grains_lic_ev
```
