#!/bin/sh
# Choose self_ingest_weight from measured drift, not from a guess.
#
# WHY A CALIBRATION AND NOT A NUMBER
# self_ingest_weight is THE independent variable of the self-ingestion
# experiment. At 0 there is never a generation 2 and the pre-registered twenty-
# generation test cannot run at all; too high and the pool is self-material
# within a few generations and the test measures a runaway instead of a loop.
# Neither failure is visible in advance, so the weight is measured first on
# SHORT arms and only then fixed for the real run.
#
# THE ARMS MUST NOT CONTAMINATE EACH OTHER. Each arm restores the pool from the
# generation-0 archive before it starts. Running arms back to back without a
# restore would have arm 2 inheriting arm 1's ingested grains, and the weight
# would be confounded with everything that came before it. That restore is the
# single most important line in this script.
#
# WHAT IS MEASURED
# generation_drift.py reports consecutive-generation spectral similarity per
# layer, against the pre-registered target of staying BELOW 0.9 for twenty
# generations. Runs 12-13 measured 0.936 rising to 0.958, i.e. convergence.
# What we want from each arm is the SLOPE: does similarity climb generation on
# generation, and how fast.
#
# THIS SCRIPT DOES NOT CHOOSE. It prints the three arms side by side. The weight
# is then fixed BY HAND and pre-registered before the twenty-generation run,
# because a threshold chosen from the run it will later judge is not a
# threshold. See .lab/notes/BISECTION.md for the same mistake made with a corpus gate.
#
#   sh tools/calibrate_ingest_weight.sh            # 0.05 0.10 0.25, 4 gens each
#   ARMS="0.10 0.20" GENS=6 sh tools/calibrate_ingest_weight.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
POLICY="$W/mutable/policy.json"
ARCHIVE=/Volumes/FMA/superdark/archive
POOL=/Volumes/FMA/superdark/self_corpus
CAPTURE=/Volumes/FMA/superdark/capture
OUT="$W/calibration"

ARMS="${ARMS:-0.05 0.10 0.25}"
GENS="${GENS:-4}"
# One capture chunk is capture_rotate_s (600 s). A generation needs at least one
# closed chunk, plus the ~45-window warm-up the factory needs to cohere: judging
# anything before then measures the cold start. 900 s per generation is one
# chunk plus margin.
SETTLE="${SETTLE:-900}"

mkdir -p "$OUT"

set_weight () {
  python3 - "$POLICY" "$1" <<'PYEOF'
import json, sys
p, w = sys.argv[1], sys.argv[2]
d = json.load(open(p)); d["self_ingest_weight"] = w
json.dump(d, open(p, "w"), indent=1)
print(f"    self_ingest_weight = {w}")
PYEOF
}

echo "=== calibration: arms [$ARMS], $GENS generations each, ${SETTLE}s per generation ==="
echo "    estimated wall time: $(( $(echo $ARMS | wc -w) * GENS * SETTLE / 60 )) minutes"
echo

for WGT in $ARMS; do
  echo "=== arm weight=$WGT ==="

  # RESTORE FIRST. Without this the arm inherits the previous arm's pool.
  echo "  restoring pool to generation 0 ..."
  python3 "$ROOT/tools/archive_guard.py" restore --archive "$ARCHIVE" --pool "$POOL" \
    | sed 's/^/    /'
  set_weight "$WGT"

  g=1
  while [ "$g" -le "$GENS" ]; do
    echo "  generation $g/$GENS: settling ${SETTLE}s ..."
    sleep "$SETTLE"
    python3 "$ROOT/tools/self_ingest.py" --capture-dir "$CAPTURE" --out-root "$POOL" \
      --basis-dir "$ARCHIVE" --once --delete-captures 2>&1 | tail -4 | sed 's/^/    /'
    g=$((g + 1))
  done

  echo "  --- drift, weight=$WGT ---"
  python3 "$ROOT/tools/generation_drift.py" --ring "$POOL" 2>&1 \
    | tee "$OUT/drift_w${WGT}.txt" | sed 's/^/    /'
  echo
done

echo "=== all arms, side by side ==="
for WGT in $ARMS; do
  echo "  weight $WGT:"
  grep -E "similarity|generation|VERDICT|below|above" "$OUT/drift_w${WGT}.txt" 2>/dev/null \
    | head -8 | sed 's/^/    /'
done
echo
echo "  Now FIX the weight by hand and pre-register it before the 20-generation run."
echo "  Do not let the run that will judge the threshold also choose it."
