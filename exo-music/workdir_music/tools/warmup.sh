#!/bin/sh
# IS WARM-UP CAUSED BY THE OPERATOR STEERING ON NO DATA?
#
# Measured 27 Aug on a cold start: the factory takes ~45 windows, about eight
# minutes, before it coheres. Roberto, listening: "I got like 5' of pure radio
# effect and it has now moved into other behaviours."
#
#   window   spectral gap   cells   observations
#        1        0.000         0        0
#       16        1.000         8       15     <- no dominant behaviour at all
#       26        1.152        13       25
#       46        0.752        15       45
#
# operator_weight is 0.35 from window 0, so for the first minutes a third of
# every selection decision is blended toward a stationary distribution estimated
# from nothing. That is one hypothesis. The other is that warm-up is intrinsic --
# sections and vocabulary simply take time to accumulate, and the operator is
# incidental.
#
# WHY IT MATTERS BEYOND THE FIRST EIGHT MINUTES. A 20-minute run is ~105 windows
# and warm-up is ~45, so roughly 40% of every short experiment this project has
# run was transient: all fifteen ablation runs, all six bridge-control runs. And
# convergence2.py's C1 compares the FIRST QUARTER against the last, so C1 has
# been partly measuring the factory becoming coherent rather than converging.
# If the operator is the cause, ramping its weight with observation count fixes
# warm-up AND removes that confound from every future short run.
#
# It does NOT matter for the stream. Roberto: "we want it to run forever, it'll
# either be warm or die." A factory that runs forever starts once; warm-up
# belongs to ignition, and to the cost of dying.
#
# PRE-REGISTERED, 27 Aug 2026, before the first run:
#
#   ARMS      op0.00  operator_weight 0.0, cold
#             op0.35  operator_weight 0.35, cold   (the current default)
#
#   PRIMARY   windows until the spectral gap first falls below 0.8 and STAYS
#             below for 5 consecutive windows. The gap is computed in both arms
#             -- the operator observes regardless of whether it steers -- so the
#             measure is available even where its weight is zero.
#
#   READING   If op0.00 coheres markedly sooner, the operator causes warm-up and
#             the fix is to ramp its weight with observation count.
#             If both take ~45 windows, warm-up is intrinsic to accumulation and
#             the operator is exonerated. That is the more likely outcome and it
#             is worth stating first so the result is not read as a surprise.
#             If op0.00 is SLOWER, the operator helps a cold factory and the
#             whole premise is wrong.
#
#   n=2 per arm. Two runs do not settle anything; this is a direction check.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECS="${SECS:-1200}"
REPS="${REPS:-2}"
OUTDEV="${OUTDEV:-BlackHole 2ch}"
OUT="$ROOT/renders/warmup"

[ -d "$ROOT/renders" ] || { echo "ABORT: renders/ does not resolve"; exit 1; }
mkdir -p "$OUT"
LOCK="$OUT/.running"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  echo "ABORT: warmup.sh already running (pid $(cat "$LOCK"))"; exit 1
fi
echo $$ > "$LOCK"; trap 'rm -f "$LOCK"' EXIT INT TERM
if pmset -g batt 2>/dev/null | grep -q "Battery Power"; then
  echo "ABORT: on battery. FORCE=1 to override."; [ "${FORCE:-0}" = "1" ] || exit 1
fi
[ -f "$OUT/policy_before.json" ] || cp "$ROOT/mutable/policy.json" "$OUT/policy_before.json"

set_w() {
  python3 - "$ROOT/mutable/policy.json" "$1" <<'PYEOF'
import re, sys
p, w = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'"operator_weight": [0-9.]+', f'"operator_weight": {w}', s)
open(p, "w").write(s)
PYEOF
}

PORT=57460
R=1
while [ "$R" -le "$REPS" ]; do
  for W in 0.00 0.35; do
    NAME="op$W"
    [ -f "$OUT/windows_${NAME}_r${R}.log" ] && { echo "--- $NAME r$R done"; continue; }
    killall -9 sclang scsynth 2>/dev/null || true
    sleep 8
    # COLD START IS THE POINT. Memory must be empty in every run, or the second
    # run of an arm inherits the first's accumulated coherence and measures
    # nothing.
    python3 - "$ROOT/mutable/memory.json" <<'PYEOF'
import json, sys
json.dump({"_comment": "reset: warm-up experiment requires a cold start",
           "sections": [], "transitions": {}, "trace": [], "operator": {}},
          open(sys.argv[1], "w"))
PYEOF
    rm -f "$ROOT/mutable/machines"/br*.scd
    set_w "$W"
    while lsof -nP -iUDP:"$PORT" >/dev/null 2>&1; do PORT=$((PORT + 2)); done
    echo "--- $NAME  r$R  $(date +%H:%M:%S)  port $PORT"
    rm -f "$ROOT"/renders/live_*.log
    SCPORT=$PORT MACRO=grains_clean_macro OUTDEV="$OUTDEV" INDEV="BlackHole 2ch" \
      GRAINS=grains_clean_ev N=2400 \
      "$ROOT/tools/run_live.sh" > "$OUT/stdout_${NAME}_r${R}.log" 2>&1 &
    sleep "$SECS"
    killall -9 sclang scsynth 2>/dev/null || true
    sleep 5
    L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
    if [ -n "$L" ]; then
      NW=$(grep -c '^MASTER ' "$L" 2>/dev/null) || NW=0
      if [ "$NW" -ge 60 ]; then cp "$L" "$OUT/windows_${NAME}_r${R}.log"; echo "    accepted: $NW windows"
      else cp "$L" "$OUT/REJECTED_${NAME}_r${R}.log"; echo "    REJECTED: $NW windows"; fi
    fi
    PORT=$((PORT + 2))
  done
  R=$((R + 1))
done
killall -9 sclang scsynth 2>/dev/null || true
cp "$OUT/policy_before.json" "$ROOT/mutable/policy.json"
echo
python3 "$ROOT/tools/score_warmup.py" "$OUT"
