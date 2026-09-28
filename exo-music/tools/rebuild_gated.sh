#!/bin/sh
# Rebuild all three corpora with the transient gate ON.
#
# Builds to _g dirs and does NOT touch the live corpora. Swapping is a separate,
# reversible step, because the gate is new and an unverified corpus should never
# silently replace the one every prior measurement was taken on.
#
# Geometry and seed are UNCHANGED from the 27 Aug licensing rebuild, so the only
# variable is the gate. Grain counts are preserved: the builder counts ACCEPTED
# tracks, so a rejection draws the next track instead of leaving a hole.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
IDS=/Volumes/FMA/fma/clean/clean_vetted.txt
AUDIO=/Volumes/FMA/fma/fma_large
SEED=20260827

build () {  # name grain per_track tracks
  echo "=== $1  (grain ${2}s, runs of $3, $4 tracks) ==="
  rm -rf "$W/$1_g"
  python3 "$ROOT/tools/build_grains_onset.py" --ids "$IDS" --audio "$AUDIO" \
    --out "$W/$1_g" --grain "$2" --per-track "$3" --tracks "$4" --seed $SEED \
    --max-transient 40 --transient-frac 0.25
  python3 "$ROOT/tools/analyse_mfcc.py" --dir "$W/$1_g"
  echo
}

build grains_lic_ev    0.06 24 100
build grains_lic_mid   0.4  12 150
build grains_lic_macro 2.0   8 150

echo "=== transient comparison: gated vs live ==="
for c in grains_lic_ev grains_lic_mid grains_lic_macro; do
  python3 "$ROOT/tools/audit_grain_transients.py" --dir "$W/${c}_g" --list-worst 0 | head -5
  python3 "$ROOT/tools/audit_grain_transients.py" --dir "$W/$c"      --list-worst 0 | head -5
done
echo "=== done, nothing swapped ==="
