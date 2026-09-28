#!/bin/sh
# OVERNIGHT: five conditions x three replicates, unattended, silent.
#
# Two weaknesses stated in the GRF evidence document, addressed together:
#
#   "most results rest on one run per condition"
#   "the system has never acquired a behaviour from anything"
#
# CONDITIONS
#
#   op0.00   open loop. The current default, and the control.
#   op0.20   the transfer operator's dominant eigenvector lightly steering
#   op0.35   the value used in development
#   op0.50   heavy steering
#   acquire  operator at 0.35 AND the factory WRITING MACHINES INTO ITSELF every
#            12 windows, bridging transitions it has never made
#
# The first four test the argument that a criterion over DYNAMICS escapes the
# trap that two criteria over CONTENT fell into (E3 at rho -0.861 against the
# ear; audibility taking the vocabulary from nine machines to four and then
# costing sound once the machines were repaired).
#
# The fifth tests whether a factory that grows its own vocabulary mid-performance
# widens or dilutes. Both are plausible and it has never been run.
#
# Scored with convergence2.py, pre-registered and committed before any of this
# existed. Three replicates so a sign flip can be distinguished from a draw --
# n=1 was the flaw convergence2 was written to criticise, and it was then
# repeated within the hour.
#
# ~5 hours. Silent through BlackHole; NOT the AirPods, which SC drops to a
# 24 kHz hands-free profile by opening the default input at boot.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECS="${SECS:-1200}"
REPS="${REPS:-3}"
OUTDEV="${OUTDEV:-BlackHole 2ch}"
# a FIXED directory, not a timestamped one, so the run is RESUMABLE. Roberto is
# travelling and closes the lid in two hours; caffeinate stops idle sleep but not
# lid-close sleep. Any condition-replicate already on disk is skipped, so
# re-running this command tomorrow continues rather than restarts.
OUT="$ROOT/renders/ablation"

# renders/ is a SYMLINK to /Volumes/FMA/superdark/renders. When the external
# drive is not mounted the symlink dangles, run_live.sh dies writing _live.scd,
# and the loop cycles through every condition failing instantly and then sleeping
# its full twenty minutes. It did that for sixteen hours overnight on 23 August.
# Fail loudly at the start instead.
if [ ! -d "$ROOT/renders" ]; then
  echo "ABORT: $ROOT/renders is not a directory."
  echo "The FMA drive is probably not mounted. Everything here writes there."
  exit 1
fi
mkdir -p "$OUT"

# EXACTLY ONE LOOP MAY RUN.
#
# On 24 August two instances ran concurrently for forty minutes, started two
# minutes apart, one by hand and one by the agent. They fought over three shared
# resources at once:
#
#   mutable/policy.json  each rewrites it per condition, so a run recorded as
#                        op0.35 may have been sounding under op0.50's policy
#   the server port      "failed to open UDP socket: address in use"
#   renders/live_*.log   each deletes and rewrites the other's log
#
# A contaminated run still produces a perfectly normal window count -- one of
# them logged 90 windows and would have sailed past the >= 60 guard below. That
# guard cannot see this failure. Refusing to start is the only defence.
LOCK="$OUT/.running"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  echo "ABORT: overnight.sh is already running (pid $(cat "$LOCK"))."
  echo "Two loops corrupt each other's policy, port and logs. Kill it first:"
  echo "  pkill -f tools/overnight.sh"
  exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

# Refuse to start on battery. Buffer loading is I/O and CPU bound, and under
# power starvation it does not fail, it just runs slower than the window, which
# produces a short run rather than an error.
if pmset -g batt 2>/dev/null | grep -q "Battery Power"; then
  echo "ABORT: running on battery. ~$(( 5 * REPS * SECS / 3600 ))h of audio needs mains power."
  echo "Override with FORCE=1 if you really mean it."
  [ "${FORCE:-0}" = "1" ] || exit 1
fi

echo "overnight -> $OUT"
echo "5 conditions x $REPS replicates x ${SECS}s  (~$(( 5 * REPS * SECS / 3600 ))h)"
DONE=$(ls "$OUT"/windows_*.log 2>/dev/null | wc -l | tr -d " ")
echo "already complete: $DONE of $(( 5 * REPS ))  -- resumable, safe to interrupt"
[ -f "$OUT/policy_before.json" ] || cp "$ROOT/mutable/policy.json" "$OUT/policy_before.json"
ls "$ROOT/mutable/machines"/*.scd > "$OUT/machines_before.txt" 2>/dev/null || true

set_policy() {   # $1 operator_weight   $2 acquire_every
  python3 - "$ROOT/mutable/policy.json" "$1" "$2" <<'PYEOF'
import re, sys
p, w, a = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
s = re.sub(r'"operator_weight": [0-9.]+', f'"operator_weight": {w}', s)
s = re.sub(r'"acquire_every": [0-9]+',   f'"acquire_every": {a}', s)
open(p, "w").write(s)
PYEOF
}

# A PORT THAT IS FREE, NOT A PORT THAT SHOULD BE FREE.
#
# scsynth wedged in an uninterruptible CoreAudio call survives SIGKILL and keeps
# its UDP socket bound until the machine reboots. On 24 August a zombie left over
# from two concurrent loops squatted 57302, and because the port sequence just
# increments blindly, op0.50_r2 drew 57302 twice and failed twice with "failed to
# open UDP socket: address in use". Twenty minutes each time, for a port
# collision that lsof can see instantly.
pick_port() {
  P=$1
  while [ "$P" -le 57398 ]; do
    if ! lsof -nP -iUDP:"$P" >/dev/null 2>&1; then
      echo "$P"; return 0
    fi
    echo "    port $P is held (probably a wedged scsynth); trying $((P + 2))" >&2
    P=$((P + 2))
  done
  echo "ABORT: no free UDP port in 57300-57398. Reboot to clear wedged scsynth." >&2
  return 1
}

PORT=57300
R=1
while [ "$R" -le "$REPS" ]; do
  for COND in "op0.00 0.00 0" "op0.20 0.20 0" "op0.35 0.35 0" "op0.50 0.50 0" "acquire 0.35 12"; do
    set -- $COND
    NAME=$1; W=$2; ACQ=$3
    if [ -f "$OUT/windows_${NAME}_r${R}.log" ]; then
      echo "--- $NAME  r$R  already done, skipping"
      continue
    fi
    killall -9 sclang scsynth 2>/dev/null || true
    sleep 8
    # every condition starts from an EMPTY operator and the ORIGINAL vocabulary,
    # so no condition inherits another's history or another's acquired machines
    rm -f "$ROOT/mutable/memory.json"
    rm -f "$ROOT/mutable/machines"/br*.scd
    set_policy "$W" "$ACQ"
    PORT=$(pick_port "$PORT") || exit 1
    echo "--- $NAME  r$R  $(date +%H:%M:%S)  port $PORT"
    rm -f "$ROOT"/renders/live_*.log
    SCPORT=$PORT MACRO=grains_macro OUTDEV="$OUTDEV" GRAINS=grains_ev N=2400 \
      "$ROOT/tools/run_live.sh" > "$OUT/stdout_${NAME}_r${R}.log" 2>&1 &
    sleep "$SECS"
    killall -9 sclang scsynth 2>/dev/null || true
    sleep 5
    # ACCEPT A RUN ONLY IF IT ACTUALLY RAN.
    #
    # On 24 August two conditions produced EMPTY logs and were nonetheless
    # recorded as complete, because the resume check tests only whether the file
    # EXISTS. The machine was on 8% battery with Acrobat at 76% CPU and Spotlight
    # reindexing the freshly reattached external drive; op0.35_r2 spent its whole
    # twenty minutes loading buffers and reached 832 of 2400, op0.50_r2 loaded
    # none at all. Both wrote a zero-byte windows log, which would then have been
    # skipped for ever, leaving that condition with two replicates while the
    # scored table claimed three. A silently short experiment is worse than a
    # visibly failed one.
    #
    # Every genuine 20-minute run so far has produced 99 to 113 MASTER lines, one
    # per window. 60 sits far below the observed floor and far above anything a
    # starved run can reach.
    MINW=60
    L=$(ls -t "$ROOT"/renders/live_*.log 2>/dev/null | head -1)
    if [ -n "$L" ]; then
      # `grep -c` PRINTS 0 and EXITS 1 when there are no matches, so the obvious
      # `$(grep -c ... || echo 0)` yields the two-line string "0\n0" and `[ -ge ]`
      # then dies with "integer expression expected". It happened to reject
      # correctly, because a failed test is false, but it rejected by accident.
      NW=$(grep -c '^MASTER ' "$L" 2>/dev/null) || NW=0
      if [ "$NW" -ge "$MINW" ]; then
        cp "$L" "$OUT/windows_${NAME}_r${R}.log"
        echo "    accepted: $NW windows"
      else
        # NOT copied, so the condition stays incomplete and a later resume retries
        cp "$L" "$OUT/REJECTED_${NAME}_r${R}_$(date +%H%M%S).log" 2>/dev/null || true
        echo "    REJECTED: only $NW windows (< $MINW). Condition left incomplete."
      fi
    else
      echo "    REJECTED: the factory produced no log at all."
    fi
    # what, if anything, the factory wrote for itself
    ls "$ROOT/mutable/machines"/br*.scd > "$OUT/acquired_${NAME}_r${R}.txt" 2>/dev/null || true
    PORT=$((PORT + 2)); [ "$PORT" -gt 57390 ] && PORT=57300
  done
  R=$((R + 1))
done

killall -9 sclang scsynth 2>/dev/null || true
rm -f "$ROOT/mutable/machines"/br*.scd
cp "$OUT/policy_before.json" "$ROOT/mutable/policy.json"

echo
echo "================ SCORED, pre-registered criterion ================"
python3 - "$OUT" "$ROOT/.." <<'PYEOF'
import subprocess, sys, glob, os, re, statistics as st
out, tools = sys.argv[1], sys.argv[2]
conds = ["op0.00", "op0.20", "op0.35", "op0.50", "acquire"]
print(f"{'condition':10} {'runs':>5} {'rho mean':>10} {'rho sd':>8} "
      f"{'vocab':>7} {'audible':>9} {'converged':>10} {'acquired':>9}")
for c in conds:
    rhos, vocab, aud, conv, acq = [], [], [], 0, []
    for f in sorted(glob.glob(f"{out}/windows_{c}_r*.log")):
        r = subprocess.run(["python3", f"{tools}/tools/convergence2.py", f],
                           capture_output=True, text=True).stdout
        m = re.search(r"observed rho\s+([+-][0-9.]+)", r)
        if m: rhos.append(float(m.group(1)))
        m = re.search(r"machines used (\d+)", r)
        if m: vocab.append(int(m.group(1)))
        m = re.search(r"audible (\d+)/(\d+)", r)
        if m: aud.append(int(m.group(1)) / max(1, int(m.group(2))))
        if "CONVERGED" in r and "NOT CONVERGED" not in r: conv += 1
        n = len(open(f"{out}/acquired_{c}_r{f[-5]}.txt").readlines()) \
            if os.path.exists(f"{out}/acquired_{c}_r{f[-5]}.txt") else 0
        acq.append(n)
    if rhos:
        sd = st.stdev(rhos) if len(rhos) > 1 else 0.0
        print(f"{c:10} {len(rhos):5} {st.mean(rhos):+10.3f} {sd:8.3f} "
              f"{st.mean(vocab):7.1f} {st.mean(aud):8.1%} {conv:10} "
              f"{st.mean(acq) if acq else 0:9.1f}")
PYEOF
echo "done. $OUT"
