#!/bin/sh
# Render a PENDING rung 2 machine offline and admit it only if it sounds.
# 24 Sept 2026, B8 rung 2. A machine that authors its own SynthDef is written
# by MachineWriter to mutable/pending/, and the live factory calls this in the
# background (unixCmd). The render is non-real-time: the live server is never
# touched. On a pass the file is MOVED into mutable/machines/, where the
# factory's loader picks it up on the next window; on a fail it is moved to
# mutable/refused/ with the reason beside it.
#
#   sh tools/check_machine.sh <pending .scd> <machines dir>
# exit 0 pass, 1 fail, 2 could not render. The verdict line is written to
# /tmp/check_machine/<name>.verdict as "PASS peak rms" or "FAIL reason".
#
# Bounds (the architect's): peak of the 30 s render through the live master
# chain at or below 0.95; RMS above -50 dBFS (0.00316) so the machine is not
# silent; and at least 20% of 100 ms frames above -60 dBFS so it is not one
# blip in 30 s of nothing. The render is the audition renderer (24 fixed
# grains, the three returns, master gain 4.0), so "sounds" means sounds as the
# factory would deliver it.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
M="$1"; DEST="$2"
NAME=$(basename "$M" .scd)
OUTDIR="${OUTDIR:-/tmp/check_machine}"
# refused/ sits beside pending/, so a sandbox test never writes into the live tree
REFUSED="${REFUSED:-$(cd "$(dirname "$M")/.." && pwd)/refused}"
mkdir -p "$OUTDIR" "$REFUSED"
V="$OUTDIR/$NAME.verdict"
: > "$V"

fail() { echo "FAIL $1" > "$V"; mkdir -p "$REFUSED"; mv -f "$M" "$REFUSED/$NAME.scd" 2>/dev/null; echo "$1" > "$REFUSED/$NAME.why"; echo "REFUSED $NAME: $1"; exit 1; }

[ -f "$M" ] || { echo "FAIL no such file" > "$V"; exit 2; }

# render, 30 s, through the audition renderer
OUTDIR="$OUTDIR" sh "$ROOT/tools/audition.sh" "$M" > "$OUTDIR/$NAME.render.out" 2>&1
WAV="$OUTDIR/$NAME.wav"
if ! grep -q 'RENDER_OK' "/tmp/audition/$NAME.out" || [ ! -s "$WAV" ]; then
    fail "render failed ($(grep -E 'ERROR|AUDITION' "/tmp/audition/$NAME.out" 2>/dev/null | head -1 | tr -d '\n' | cut -c1-120))"
fi

# measure
RES=$(python3 - "$WAV" <<'EOF'
import sys, wave, numpy as np
w = wave.open(sys.argv[1]); n = w.getnframes(); ch = w.getnchannels(); sr = w.getframerate()
x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
if ch > 1: x = x.reshape(-1, ch).mean(axis=1)
peak = float(np.abs(x).max()) if x.size else 0.0
rms = float(np.sqrt(np.mean(x * x))) if x.size else 0.0
hop = sr // 10
frames = [x[i:i+hop] for i in range(0, max(1, x.size - hop), hop)]
active = sum(1 for f in frames if f.size and np.sqrt(np.mean(f*f)) > 0.001) / max(1, len(frames))
print(f"{peak:.4f} {rms:.5f} {active:.3f}")
EOF
)
set -- $RES
PEAK=$1; RMS=$2; ACTIVE=$3
awk -v p="$PEAK" 'BEGIN{exit !(p > 0.95)}' && fail "peak $PEAK above 0.95"
awk -v r="$RMS" 'BEGIN{exit !(r < 0.00316)}' && fail "rms $RMS below -50 dBFS (silent)"
awk -v a="$ACTIVE" 'BEGIN{exit !(a < 0.2)}' && fail "active frames $ACTIVE below 0.2 (one blip)"

# LEVEL TRIM, 28 Sept 2026. A rung 2 machine brings its own source, and a
# resonant one (klank, formant) renders several times louder than the grain
# sources: 0.05-0.26 rms against a median of 0.03 for the six grain sources
# (listen/rung2_260927). Stacked on the three layers that drove the master
# limiter (Roberto, 28 Sept: "clipping sometimes"). The architect's bound is a
# target rms (TRIM_RMS, default 0.03); a machine louder than it is scaled down
# at admission, never up. Recorded in the file as // TRIM.
TRIM=$(awk -v r="$RMS" -v t="${TRIM_RMS:-0.03}" 'BEGIN{g=t/r; if(g>1)g=1; if(g<0.1)g=0.1; printf "%.3f", g}')
if [ "$TRIM" != "1.000" ] && grep -q 'amp.clip(0, 0.7)' "$M"; then
    sed -i '' "s/amp.clip(0, 0.7)/(amp * $TRIM).clip(0, 0.7)/" "$M"
    printf '// TRIM %s (render rms %s, target %s)\n' "$TRIM" "$RMS" "${TRIM_RMS:-0.03}" >> "$M"
fi

mkdir -p "$DEST"
mv -f "$M" "$DEST/$NAME.scd" || fail "could not move into machines/"
echo "PASS $PEAK $RMS $ACTIVE" > "$V"
echo "ADMITTED $NAME peak $PEAK rms $RMS active $ACTIVE trim $TRIM"
# B8 rung 3 (27 Sept): score the render for n5 and let the factory PROPOSE a
# source weight; never fatal, never changes a weight (the architect adopts).
python3 "$ROOT/tools/source_evidence.py" --wav "$WAV" --machine "$DEST/$NAME.scd" \
    --mutable "$(cd "$DEST/.." && pwd)" 2>>"$OUTDIR/$NAME.evidence.err" || true
exit 0
