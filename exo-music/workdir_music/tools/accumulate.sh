#!/bin/sh
# Accumulate performance memory across many runs, unattended.
#
# Runs cost nothing but wall-clock time: everything is local, no API spend. The
# expensive part has been supervising them one at a time, so this does not.
# Launch once, check once.
#
# Output defaults to BlackHole, a virtual device, so the machine stays silent
# while the factory plays. Set OUTDEV="MacBook Pro Speakers" to listen.
# NOT the AirPods: SuperCollider opens the default input at boot, macOS drops
# the link to the hands-free profile, and the whole transport becomes 24 kHz
# through a speech codec. That cost an afternoon.
#
# memory.json is NOT deleted between runs -- accumulating it is the point. Logs
# are kept per run, unlike earlier sessions where `rm -f renders/live_*.log`
# destroyed the only record of the one condition that showed real narrowing.
#
#   ./tools/accumulate.sh 10 1200        10 runs of 20 minutes
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNS="${1:-10}"
SECS="${2:-1200}"
OUTDEV="${OUTDEV:-BlackHole 2ch}"
INDEV="${INDEV:-BlackHole 2ch}"
STAMP=$(date +%y%m%d_%H%M%S)
OUT="$ROOT/renders/accumulate_$STAMP"
mkdir -p "$OUT"

echo "accumulating $RUNS runs x ${SECS}s through '$OUTDEV' -> $OUT"
echo "memory.json is preserved between runs."

i=1
while [ "$i" -le "$RUNS" ]; do
  killall -9 sclang scsynth 2>/dev/null || true
  sleep 3
  rm -f "$ROOT"/renders/live_*.log
  echo "--- run $i/$RUNS  $(date +%H:%M:%S)"
  OUTDEV="$OUTDEV" INDEV="$INDEV" GRAINS="${GRAINS:-grains_600}" N="${N:-600}" \
    "$ROOT/tools/run_live.sh" > "$OUT/stdout_$i.log" 2>&1 &
  sleep "$SECS"
  killall -9 sclang scsynth 2>/dev/null || true
  sleep 3
  # keep the window log under a name that survives the next run
  L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
  [ -n "$L" ] && cp "$L" "$OUT/windows_$i.log"
  cp "$ROOT/mutable/memory.json" "$OUT/memory_after_$i.json" 2>/dev/null || true
  T=$(python3 -c "import json;print(len(json.load(open('$ROOT/mutable/memory.json'))['trace']))" 2>/dev/null || echo "?")
  S=$(python3 -c "import json;print(len(json.load(open('$ROOT/mutable/memory.json'))['sections']))" 2>/dev/null || echo "?")
  echo "    trace $T states, $S sections"
  i=$((i + 1))
done
killall -9 sclang scsynth 2>/dev/null || true
echo "done. $OUT"
