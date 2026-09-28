#!/bin/sh
# THE OPERATOR ABLATION.
#
# The load-bearing experiment. Two self-generated criteria have already been
# measured and both failed:
#
#   E3, calibrated on Roberto's ear      rho -0.861 against his blind rankings,
#                                        and P109 says a better model of the
#                                        governor's taste is a TIGHTER cap
#   audibility, generated from output    vocabulary 9 -> 4 machines, and once
#                                        the machines were repaired it stopped
#                                        even buying sound (44 audible windows
#                                        steered vs 50 unsteered)
#
# The transfer operator is argued to differ IN KIND: it is a criterion over
# DYNAMICS rather than content, so it says nothing about what to play. That is
# an argument, not a measurement, and this measures it.
#
# Four conditions, everything else identical, scored with convergence2.py --
# which was pre-registered and committed BEFORE the operator existed.
#
#   0.00   open loop, the current default
#   0.20   light steering
#   0.35   the value used in development
#   0.50   heavy steering
#
# WHAT WOULD FALSIFY THE ARGUMENT: if vocabulary and entropy fall as
# operator_weight rises, the operator is a convergence engine like the other
# two, and the conclusion is that ALL self-generated criteria collapse the same
# way -- which is a stronger claim than the one being tested.
#
# Output through BlackHole so the machine stays silent. NOT the AirPods: SC
# opens the default input at boot and macOS drops the link to the hands-free
# profile, putting the whole transport through a 24 kHz speech codec.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECS="${SECS:-1200}"
REPS="${REPS:-1}"      # replicates per condition. n=1 is an anecdote.
OUTDEV="${OUTDEV:-BlackHole 2ch}"
STAMP=$(date +%y%m%d_%H%M%S)
OUT="$ROOT/renders/ablate_$STAMP"
mkdir -p "$OUT"

echo "operator ablation -> $OUT"
echo "four conditions x ${REPS} replicates x ${SECS}s, silent through '$OUTDEV'"

# a fresh memory for the ablation, so no condition inherits another's operator
if [ -f "$ROOT/mutable/memory.json" ]; then
  cp "$ROOT/mutable/memory.json" "$OUT/memory_before.json"
fi

PORT=57300
R=1
while [ "$R" -le "$REPS" ]; do
for W in 0.00 0.20 0.35 0.50; do
  killall -9 sclang scsynth 2>/dev/null || true
  sleep 8
  # each condition starts from the SAME empty operator, so the comparison is of
  # steering strength and not of how much history happened to accumulate
  rm -f "$ROOT/mutable/memory.json"
  python3 - "$ROOT/mutable/policy.json" "$W" <<'PYEOF'
import re, sys
p, w = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'"operator_weight": [0-9.]+', f'"operator_weight": {w}', s)
open(p, "w").write(s)
PYEOF
  echo "--- operator_weight $W  $(date +%H:%M:%S)"
  rm -f "$ROOT"/renders/live_*.log
  SCPORT=$PORT MACRO=grains_macro OUTDEV="$OUTDEV" GRAINS=grains_ev N=2400 \
    "$ROOT/tools/run_live.sh" > "$OUT/stdout_$W.log" 2>&1 &
  sleep "$SECS"
  killall -9 sclang scsynth 2>/dev/null || true
  sleep 5
  L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
  [ -n "$L" ] && cp "$L" "$OUT/windows_${W}_r${R}.log"
  [ -f "$ROOT/mutable/memory.json" ] && cp "$ROOT/mutable/memory.json" "$OUT/memory_${W}_r${R}.json"
  PORT=$((PORT + 2))
  if [ "$PORT" -gt 57390 ]; then PORT=57300; fi
done
R=$((R + 1))
done

killall -9 sclang scsynth 2>/dev/null || true
echo
echo "=== scored with the pre-registered criterion ==="
for W in 0.00 0.20 0.35 0.50; do
 for F in "$OUT"/windows_${W}_r*.log; do
  if [ -f "$F" ]; then
    echo "--- operator_weight $W  $(basename "$F")"
    python3 "$ROOT/../tools/convergence2.py" "$F" 2>/dev/null \
      | grep -E "machines used|audible|C1 terminal|observed rho|C2 permutation|M1 vocab|CONVERGED|NOT CONVERGED"
  fi
 done
done
echo "done. $OUT"
