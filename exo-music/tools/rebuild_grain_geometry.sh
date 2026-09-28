#!/bin/sh
# REBUILD THE THREE CORPORA AT 0.06 / 0.35 / 0.8 s.
#
# WHY 2.0 s IS BEING RETIRED, AND WHO CHOSE IT.
#
# Not Roberto. 2.0 first appears on 31 Aug in abab9f7, a commit about shellac
# crackle and interpolation imaging, carried in under a script comment reading
# "geometry unchanged". It was never proposed, never pre-registered, and never
# given a rationale block in policy.json the way macro_continuity and macro_bias
# were. It sat unheard for eleven days because MACRO was empty on every run.
#
# The argument behind it, written into live_factory.scd, was that grain length
# should match each machine's measured EVENT INTERVAL -- 0.013 s to 11.4 s across
# the vocabulary -- because 0.5 s grains smeared the fast machines and 0.06 s
# grains left the slow ones as isolated clicks. That reasoning matches the wrong
# two quantities. Event interval is a property of RHYTHM; grain length is a
# property of MATERIAL. Matching them means a slow behaviour is handed long
# samples, which makes it a sampler rather than a slow behaviour.
#
# Heard for the first time on 3 Sept, that is exactly what it was: 1200 unaltered
# two-second excerpts, played at rate 1.0 through a four-operation SynthDef.
# Roberto: "I'm listening to several seconds of the original audio, why!!!!!!"
# and "full fragments of audio, this is a complete fucking disaster." It is also
# the largest block of unaltered recording anywhere in the system -- 40 minutes --
# which makes it the most exposed part of the corpus on licensing.
#
# 0.8 s is short enough that no grain carries a recognisable phrase, and long
# enough to hold a gesture, an attack-and-decay, a sung syllable. 0.35 s replaces
# 0.4 for the same reason at the gesture scale. 0.06 s is unchanged: at that
# length the grain is below the threshold of source identification already, and
# micro_continuity 0.9 exists to fuse consecutive grains into a timbre.
#
# CONTINUITY WILL NOT COME FROM GRAIN LENGTH ANY MORE. It has to come from
# overlap and from a slow control trajectory over short material -- which is what
# a macro BEHAVIOUR is, as against macro material. That is the next piece of work
# and it is why this rebuild is a precondition rather than a fix on its own.
#
# GRAIN COUNTS ARE RAISED WHERE THE GRAIN GOT SHORTER, so the macro layer holds
# a comparable amount of distinct material to navigate: 1200 grains at 2.0 s was
# 40 minutes, and 1200 at 0.8 s would be 16. At 20 per track over 150 tracks the
# macro corpus is 3000 grains and 40 minutes, so the descriptor space it walks
# through is if anything richer, made of pieces too short to quote.
#
# Builds to _n dirs and swaps NOTHING. Verification, then a separate swap.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
IDS=/Volumes/FMA/fma/clean/clean_vetted.txt
AUDIO=/Volumes/FMA/fma/fma_large
SEED=20260827          # unchanged, so the only variable is geometry

build () {  # name grain per_track tracks
  echo "=== $1  (grain ${2}s, runs of $3, $4 tracks) ==="
  rm -rf "$W/$1_n"
  python3 "$ROOT/tools/build_grains_onset.py" --ids "$IDS" --audio "$AUDIO" \
    --out "$W/$1_n" --grain "$2" --per-track "$3" --tracks "$4" --seed $SEED \
    --max-transient 40 --transient-frac 0.25
  python3 "$ROOT/tools/analyse_mfcc.py" --dir "$W/$1_n"
  echo
}

build grains_play_ev    0.06 24 100      # 2400 grains, 2.4 min   UNCHANGED
build grains_play_mid   0.35 12 150      # 1800 grains, 10.5 min
build grains_play_macro 0.8  20 150      # 3000 grains, 40 min

echo "=== geometry check ==="
python3 - "$W" <<'PY'
import sys, os, glob, struct, statistics as st
W = sys.argv[1]
def dur(p):
    b = open(p, 'rb').read(64)
    sr = struct.unpack('<I', b[24:28])[0]
    bits = struct.unpack('<H', b[34:36])[0]
    ch = struct.unpack('<H', b[22:24])[0]
    return (os.path.getsize(p) - 44) / (sr * ch * bits / 8)
for d in ("grains_play_ev_n", "grains_play_mid_n", "grains_play_macro_n"):
    fs = sorted(glob.glob(os.path.join(W, d, "g*.wav")))
    if not fs:
        print(f"  {d:24} MISSING"); continue
    xs = sorted(dur(p) for p in fs)
    print(f"  {d:24} n={len(fs):5}  {xs[0]:.3f}-{xs[-1]:.3f}s  "
          f"median {st.median(xs):.3f}  total {sum(xs)/60:.1f} min")
PY

echo
echo "=== nothing swapped. review, then run --swap ==="
