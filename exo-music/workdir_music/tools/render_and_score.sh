#!/bin/sh
# Render one generation with the current behaviour file, then score it.
#
# Everything is fixed except behaviour/BehaviorTrimmed.sc: the input events,
# the corpus, the random seed, the duration, the handler, and the evaluator.
# So any change in the score is attributable to the behaviour file.
#
# Usage:  render_and_score.sh <label>
# Writes: renders/<label>.wav  and prints the score as JSON.

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="${1:-run}"
OUT="$ROOT/renders/$LABEL.wav"

SCLANG="${SCLANG:-sclang}"
command -v "$SCLANG" >/dev/null 2>&1 || SCLANG=/Applications/SuperCollider.app/Contents/MacOS/sclang

# Generate the class-library config here so the script is path-portable: it runs
# on the host and inside the sandbox without edits.
cat > "$ROOT/tools/sclang_conf.yaml" <<CONF
includePaths:
  - $ROOT/lib
  - $ROOT/behaviour
excludePaths:
  - $HOME/Library/Application Support/SuperCollider/Extensions
  - /Library/Application Support/SuperCollider/Extensions
  - /root/.local/share/SuperCollider/Extensions
excludeDefaultPaths: false
postInlineWarnings: false
CONF

SEED="${SEED:-20260819}"
SKIP="${SKIP:-0}"
sed -e "s|WORKDIR|\"$ROOT\"|" -e "s|OUTWAV|\"$OUT\"|" -e "s|SEEDVAL|$SEED|" -e "s|SKIPVAL|$SKIP|" "$ROOT/tools/render.scd" > "$ROOT/renders/_render.scd"

echo "--- rendering $LABEL"
"$SCLANG" -l "$ROOT/tools/sclang_conf.yaml" "$ROOT/renders/_render.scd" < /dev/null 2>&1 \
  | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|STAGE ASSERTION|ERROR' || true

if [ ! -f "$OUT" ]; then
  echo '{"error":"NO_RENDER","label":"'"$LABEL"'"}'
  exit 2
fi

echo "--- scoring $LABEL"
# E3 is the instrument now. E1 is kept alongside because every historical number
# in this repository is an E1 number, and dropping it would make the run
# incomparable with runs 01-29 rather than merely re-based.
python3 "$ROOT/tools/score_e3.py" "$OUT"
echo "--- E1 (legacy, for continuity with runs 01-29)"
python3 "$ROOT/tools/score_e1.py" "$OUT" 2>/dev/null | head -5 || true
