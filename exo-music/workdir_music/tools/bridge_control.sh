#!/bin/sh
# DOES THE TARGETING DO ANYTHING, OR IS IT THE PERTURBATION?
#
# In the 24 Aug ablation the `acquire` condition scored the HIGHEST audibility
# of any condition, 83.4% against 68.0% for its exact control `op0.35`, and
# recovered 2.3 machines of the vocabulary the operator had cost. On that basis
# 37_Response_From_The_Factory_Chat.md claims the operator works as a GENERATOR
# and not only as a diagnostic.
#
# It scored that while sending TWELVE OF SIXTEEN bridges to `bu` and getting
# exactly one bridge in sixteen to sound. A mechanism that wastes three quarters
# of its output on one machine and still wins is not obviously being helped by
# its aim. The alternative reading is that any new machine arriving into a
# narrowing vocabulary would do as well, and that the targeting is decorative.
#
# TWO ARMS, differing by one string in policy.json:
#
#   gap      acquire_mode="gap"      most negative standardised residual
#                                    against independence, over endpoints with
#                                    >= 5 observations
#   random   acquire_mode="random"   two adequately-observed cells, uniformly,
#                                    ignoring the operator entirely
#
# Both at operator_weight 0.35 and acquire_every 12, matching the ablation's
# `acquire` condition exactly, so this is comparable to it.
#
# PRE-REGISTERED, 25 Aug 2026, before the first run:
#
#   If `random` matches `gap` on audibility and vocabulary, the targeting
#   contributes nothing measurable and the generator claim must be struck from
#   document 37 before it reaches the proposal.
#
#   If `gap` beats `random`, the claim survives -- and note it would then have
#   survived a test it could not have passed yesterday, because yesterday's
#   findGap was picking `bu` on a base-rate artefact.
#
#   Primary outcome: fraction of written bridges that SOUND. Secondary:
#   audibility, vocabulary, rho. Three replicates each, n=3 per arm.
#
# 6 runs x 20 min = ~2h. Silent through BlackHole is NOT used here; the runs go
# to the speakers only if OUTDEV says so. Default is BlackHole so it is silent.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECS="${SECS:-1200}"
REPS="${REPS:-3}"
OUTDEV="${OUTDEV:-BlackHole 2ch}"
OUT="$ROOT/renders/bridge_control"

# Guards, all four from failures on 23-24 Aug. See tools/overnight.sh for the
# incident each one records.
if [ ! -d "$ROOT/renders" ]; then
  echo "ABORT: $ROOT/renders is not a directory. The FMA drive is not mounted."
  exit 1
fi
mkdir -p "$OUT"

LOCK="$OUT/.running"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  echo "ABORT: bridge_control.sh already running (pid $(cat "$LOCK"))."
  exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

if pmset -g batt 2>/dev/null | grep -q "Battery Power"; then
  echo "ABORT: running on battery. Override with FORCE=1."
  [ "${FORCE:-0}" = "1" ] || exit 1
fi

echo "bridge control -> $OUT"
echo "2 arms x $REPS replicates x ${SECS}s  (~$(( 2 * REPS * SECS / 3600 ))h)"
DONE=$(ls "$OUT"/windows_*.log 2>/dev/null | wc -l | tr -d " ")
echo "already complete: $DONE of $(( 2 * REPS ))  -- resumable"
[ -f "$OUT/policy_before.json" ] || cp "$ROOT/mutable/policy.json" "$OUT/policy_before.json"

set_mode() {   # $1 acquire_mode
  python3 - "$ROOT/mutable/policy.json" "$1" <<'PYEOF'
import re, sys
p, m = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'"acquire_mode": "[a-z]+"', f'"acquire_mode": "{m}"', s)
s = re.sub(r'"operator_weight": [0-9.]+', '"operator_weight": 0.35', s)
s = re.sub(r'"acquire_every": [0-9]+',   '"acquire_every": 12', s)
open(p, "w").write(s)
PYEOF
}

pick_port() {
  P=$1
  while [ "$P" -le 57498 ]; do
    if ! lsof -nP -iUDP:"$P" >/dev/null 2>&1; then echo "$P"; return 0; fi
    echo "    port $P held; trying $((P + 2))" >&2
    P=$((P + 2))
  done
  echo "ABORT: no free UDP port in 57400-57498." >&2
  return 1
}

PORT=57400
R=1
while [ "$R" -le "$REPS" ]; do
  for MODE in gap random; do
    if [ -f "$OUT/windows_${MODE}_r${R}.log" ]; then
      echo "--- $MODE  r$R  already done, skipping"
      continue
    fi
    killall -9 sclang scsynth 2>/dev/null || true
    sleep 8
    # every run starts from an EMPTY operator and the ORIGINAL vocabulary, so
    # no arm inherits the other's history or the other's written machines
    rm -f "$ROOT/mutable/memory.json"
    rm -f "$ROOT/mutable/machines"/br*.scd
    set_mode "$MODE"
    PORT=$(pick_port "$PORT") || exit 1
    echo "--- $MODE  r$R  $(date +%H:%M:%S)  port $PORT"
    rm -f "$ROOT"/renders/live_*.log
    SCPORT=$PORT MACRO=grains_macro OUTDEV="$OUTDEV" GRAINS=grains_ev N=2400 \
      "$ROOT/tools/run_live.sh" > "$OUT/stdout_${MODE}_r${R}.log" 2>&1 &
    sleep "$SECS"
    killall -9 sclang scsynth 2>/dev/null || true
    sleep 5
    MINW=60
    L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
    if [ -n "$L" ]; then
      NW=$(grep -c '^MASTER ' "$L" 2>/dev/null) || NW=0
      if [ "$NW" -ge "$MINW" ]; then
        cp "$L" "$OUT/windows_${MODE}_r${R}.log"
        echo "    accepted: $NW windows"
      else
        cp "$L" "$OUT/REJECTED_${MODE}_r${R}_$(date +%H%M%S).log" 2>/dev/null || true
        echo "    REJECTED: only $NW windows (< $MINW)"
      fi
    else
      echo "    REJECTED: no log at all."
    fi
    ls "$ROOT/mutable/machines"/br*.scd > "$OUT/acquired_${MODE}_r${R}.txt" 2>/dev/null || true
    # ADVANCE THE PORT. This line was in overnight.sh and I dropped it here, so
    # every run rebound 57400 immediately after killing the previous server on
    # it. The probe reports it free -- it genuinely is -- but the newly booted
    # server sometimes inherits the dying one's shutdown and quits with exit
    # code 0, before loading a single buffer. That cost `random` r1: a clean
    # exit, no error, an empty log. Never reuse a port back to back.
    PORT=$((PORT + 2)); [ "$PORT" -gt 57498 ] && PORT=57400
  done
  R=$((R + 1))
done

killall -9 sclang scsynth 2>/dev/null || true
rm -f "$ROOT/mutable/machines"/br*.scd
cp "$OUT/policy_before.json" "$ROOT/mutable/policy.json"

echo
echo "============ BRIDGE CONTROL, pre-registered ============"
python3 "$ROOT/tools/score_bridges.py" "$OUT" "$ROOT/.."
echo "done. $OUT"
