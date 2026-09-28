#!/bin/sh
# PHASE A: LET IT RUN UNTIL IT DIES.
#
# The factory has never run longer than twenty minutes. Every run to date has
# been killed by a script on a timer, so `collapse_after` -- documented in
# policy.json as "an INSTRUMENT for observing where the loop dies, not a safety
# device" -- has never once been reached. "Runs forever until it collapses" is
# the standalone requirement and it has never been tested.
#
# TWO PURPOSES, ONE RUN
#
#   1. Collapse behaviour. Where and how does it die?
#   2. The fitting set for version design. Measured across 21 runs the factory
#      produces one window every 11.2 s, so six hours is ~1,930 windows from a
#      SINGLE policy -- ~12 observations per free parameter for a 5-state HSMM,
#      with no pooling across conditions and so no contamination.
#
# PRE-REGISTERED, 25 Aug 2026, before the first run:
#
#   H1  It collapses by VOCABULARY FREEZE. Sections accumulate, recalled
#       families cannot admit anything written since, and the factory settles
#       on a fixed set. Six hours gives ~177 sections against ~10 in a
#       twenty-minute run, so the archive effect can appear for the first time.
#   H2  If it collapses by amplitude decay, or by thrash (P230, the spectral gap
#       never settling), H1 is wrong and the cause is elsewhere.
#   H3  If it does not collapse in six hours, that is the strongest single
#       result currently available and the run should be EXTENDED, not stopped.
#
#   Honest caveat recorded in advance: the cross-run accumulation this predicts
#   has never had a chance to occur, because every experiment script so far
#   begins `rm -f mutable/memory.json`. The archive has only ever held one run.
#   THIS SCRIPT DOES NOT WIPE IT -- accumulation is the thing under test.
#
# WHAT IS DELIBERATELY NOT DONE HERE
#   No condition switching, no ablation, no parameter sweep. One policy, one
#   uninterrupted run. Anything that varies mid-run makes the wake unfittable.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOURS="${HOURS:-6}"
SECS=$(( HOURS * 3600 ))
OUTDEV="${OUTDEV:-BlackHole 2ch}"
OUT="$ROOT/renders/longrun"

if [ ! -d "$ROOT/renders" ]; then
  echo "ABORT: $ROOT/renders is not a directory. The FMA drive is not mounted."
  exit 1
fi
mkdir -p "$OUT"

LOCK="$OUT/.running"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  echo "ABORT: longrun.sh already running (pid $(cat "$LOCK"))."
  exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

if pmset -g batt 2>/dev/null | grep -q "Battery Power"; then
  echo "ABORT: on battery. ${HOURS}h of continuous audio needs mains."
  echo "Override with FORCE=1."
  [ "${FORCE:-0}" = "1" ] || exit 1
fi

# Load matters more here than in a 20-minute run: buffer loading is I/O and CPU
# bound and under starvation it does not fail, it just runs slower than the
# window. On 24 Aug a starved run reached 832 of 2400 buffers in twenty minutes.
LOAD=$(uptime | sed 's/.*averages*: *//' | awk '{print int($1)}')
if [ "$LOAD" -gt 12 ]; then
  echo "ABORT: load average is $LOAD. Wait for it to settle below 12."
  echo "Override with FORCE=1."
  [ "${FORCE:-0}" = "1" ] || exit 1
fi

PORT=57400
while [ "$PORT" -le 57498 ]; do
  lsof -nP -iUDP:"$PORT" >/dev/null 2>&1 || break
  echo "  port $PORT held; trying $((PORT + 2))"
  PORT=$((PORT + 2))
done

STAMP=$(date +%y%m%d_%H%M%S)
echo "longrun -> $OUT"
echo "  ${HOURS}h  (~$(( SECS / 12 )) windows expected at 11.2 s/window)"
echo "  port $PORT   out '$OUTDEV'   started $(date +%H:%M:%S)"
echo "  memory.json is PRESERVED: accumulation is under test"
cp "$ROOT/mutable/policy.json" "$OUT/policy_${STAMP}.json"
cp "$ROOT/mutable/memory.json" "$OUT/memory_before_${STAMP}.json" 2>/dev/null || true

killall -9 sclang scsynth 2>/dev/null || true
sleep 10
rm -f "$ROOT"/renders/live_*.log

SCPORT=$PORT MACRO=grains_macro OUTDEV="$OUTDEV" GRAINS=grains_ev N=2400 \
  "$ROOT/tools/run_live.sh" > "$OUT/stdout_${STAMP}.log" 2>&1 &
FACTORY=$!

# A HEARTBEAT, so a death is dated rather than merely discovered. Every five
# minutes: window count, whether it moved, amplitude, spectral gap, vocabulary
# so far. If the window count stops moving the factory has died and the time is
# in the file -- which is the whole point of the run.
LAST=0
STALL=0
ELAPSED=0
while [ "$ELAPSED" -lt "$SECS" ]; do
  sleep 300
  ELAPSED=$((ELAPSED + 300))
  L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
  if [ -z "$L" ]; then
    echo "$(date +%H:%M:%S)  no log yet" >> "$OUT/heartbeat_${STAMP}.log"
    continue
  fi
  NW=$(grep -c '^MASTER ' "$L" 2>/dev/null) || NW=0
  AMP=$(grep '^MASTER ' "$L" | tail -1 | cut -d, -f2)
  GAP=$(grep '^OPERATOR' "$L" | tail -1 | cut -d, -f3)
  VOC=$(grep -E ',(runtime|class),' "$L" | cut -d, -f3 | sort -u | wc -l | tr -d ' ')
  SEC=$(grep -c '^# SECTION' "$L" 2>/dev/null) || SEC=0
  ACQ=$(grep -c '^ACQUIRED' "$L" 2>/dev/null) || ACQ=0
  if [ "$NW" -eq "$LAST" ]; then STALL=$((STALL + 1)); else STALL=0; fi
  printf "%s  t=%5ss  win=%5s (+%s)  amp=%s  gap=%s  vocab=%s  sections=%s  acquired=%s%s\n" \
    "$(date +%H:%M:%S)" "$ELAPSED" "$NW" "$((NW - LAST))" "$AMP" "$GAP" "$VOC" "$SEC" "$ACQ" \
    "$(if [ "$STALL" -gt 0 ]; then echo "   STALLED x$STALL"; fi)" \
    >> "$OUT/heartbeat_${STAMP}.log"
  LAST=$NW
  # Three consecutive dead heartbeats is fifteen minutes without a window. That
  # is death, not slowness. Stop and keep the evidence rather than logging
  # silence for another five hours.
  if [ "$STALL" -ge 3 ]; then
    echo "$(date +%H:%M:%S)  COLLAPSED: no new window in 15 min. Stopping." \
      >> "$OUT/heartbeat_${STAMP}.log"
    break
  fi
  kill -0 "$FACTORY" 2>/dev/null || {
    echo "$(date +%H:%M:%S)  FACTORY PROCESS GONE at t=${ELAPSED}s" \
      >> "$OUT/heartbeat_${STAMP}.log"; break; }
done

killall -9 sclang scsynth 2>/dev/null || true
sleep 5
L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
[ -n "$L" ] && cp "$L" "$OUT/windows_${STAMP}.log"
cp "$ROOT/mutable/memory.json" "$OUT/memory_after_${STAMP}.json" 2>/dev/null || true
ls "$ROOT/mutable/machines"/br*.scd > "$OUT/acquired_${STAMP}.txt" 2>/dev/null || true

echo
echo "================ LONG RUN ================"
echo "windows:  $(grep -c '^MASTER ' "$OUT/windows_${STAMP}.log" 2>/dev/null)"
echo "sections: $(grep -c '^# SECTION' "$OUT/windows_${STAMP}.log" 2>/dev/null)"
echo "acquired: $(grep -c '^ACQUIRED' "$OUT/windows_${STAMP}.log" 2>/dev/null)"
echo
tail -20 "$OUT/heartbeat_${STAMP}.log"
echo
echo "score:  python3 ../tools/convergence2.py $OUT/windows_${STAMP}.log"
echo "done.   $OUT"
