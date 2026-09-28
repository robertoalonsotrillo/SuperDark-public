#!/bin/sh
# Drive a complete two-arm comparison without supervision.
#
# WHY THIS EXISTS, PLAINLY
# On the night of 15 September an overnight comparison was driven by hand: start
# the champion, come back in two hours, flip the knob, run the candidate. The
# hand never came back. Arm B never started, arm A became a nine-hour run, and
# the comparison was lost. Tonight the same gap opened again -- four hours passed
# between "I am going to sleep" and the next action.
#
# The fault is not carelessness, it is DEPENDING ON A SUPERVISOR BEING ALIVE at
# hour three. This script removes that dependency. Once launched it needs nobody:
# it starts the factory, waits out the champion arm by WINDOW COUNT, checkpoints,
# hot-reloads the knob, waits out the candidate arm, checkpoints again, and
# writes the arm boundaries to a file that scoring can read afterwards.
#
# WHAT IT WILL NOT DO
#   - restart the factory mid-sequence. A restart reassembles the corpus and
#     resets the running means, which is a second change; one_change_at_a_time
#     would refuse the result and it would be right.
#   - flip the knob into a factory that has died. If the factory is not advancing
#     it ABORTS and leaves the champion arm intact and honestly labelled, rather
#     than producing a candidate arm of silence.
#   - stop the factory at the end. Stopping is a decision for a person.
#   - touch anything if the preconditions fail.
#
# WINDOWS, NOT WALL CLOCK. An arm is a number of windows because that is what the
# measures consume. A wall-clock cap exists only as a dead-man's switch: if the
# window count has not moved for STALL_S the run is dead and waiting longer
# cannot help.
#
#   sh tools/run_two_arms.sh --key attention_weight --champ 0.15 --cand 0.3
#   sh tools/run_two_arms.sh --key attention_weight --champ 0.15 --cand 0.3 \
#        --windows 853 --dry-run
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
MUT="$W/mutable"
PY="$(command -v /opt/homebrew/bin/python3 || command -v python3)"

KEY=""; CHAMP=""; CAND=""; WINDOWS=853; DRY=0
STALL_S=900           # no new window for 15 min -> the factory is dead
POLL_S=60

while [ $# -gt 0 ]; do
  case "$1" in
    --key)     KEY=$2; shift 2 ;;
    --champ)   CHAMP=$2; shift 2 ;;
    --cand)    CAND=$2; shift 2 ;;
    --windows) WINDOWS=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -n "$KEY" ] && [ -n "$CHAMP" ] && [ -n "$CAND" ] || {
  echo "usage: --key K --champ V --cand V [--windows N] [--dry-run]" >&2; exit 2; }

STATE="$ROOT/harness/two_arms_$(date +%y%m%d_%H%M%S).json"
say() { echo "[$(date '+%H:%M:%S')] $*"; }

newest_log() { ls -t "$W/renders"/live_*.log 2>/dev/null | head -1; }

# grep -c PRINTS A NUMBER EVEN WHEN IT MATCHES NOTHING, and then exits 1. So
# `grep -c ... || echo 0` printed "0" twice on an empty log, count() returned a
# two-line string, and the arithmetic downstream died with
#   syntax error in expression (error token is "0")
# on the very first poll. Caught on the first launch; the factory was already up,
# so the cost was one relaunch of the runner rather than a lost arm.
count() {
    if [ -f "$1" ]; then
        n=$(grep -c '^VOICES' "$1" 2>/dev/null | head -1)
        case "$n" in ''|*[!0-9]*) n=0 ;; esac
        echo "$n"
    else
        echo 0
    fi
}

# ---------------------------------------------------------------- preflight ---
# A NULL RUN IS DECLARED HERE, BEFORE ANYTHING IS MEASURED.
# Identical arms are the point of a null -- it measures how far the measures
# drift when nothing changes, which is the smallest-reportable-difference the
# release policy requires before margins can be set. inv_one_change_at_a_time
# refuses n == 0 unless BOTH arms carry intent=null, and the declaration has to
# exist before the comparison is assembled so it cannot be claimed after seeing
# the result. Deriving it from champ == cand means it cannot be set by accident
# either: the only way to get a null is to ask for the same value twice.
if [ "$CHAMP" = "$CAND" ]; then
  INTENT=null
  say "=== NULL COMPARISON: both arms $KEY=$CHAMP, nothing changes ==="
  say "    This measures the noise floor. NOTHING IS PROMOTABLE FROM IT."
else
  INTENT=promotion
fi

say "=== preflight ==="
fail=0
[ -f "$MUT/policy.json" ] || { say "  FAIL no policy.json"; fail=1; }
"$PY" -c "import json;d=json.load(open('$MUT/policy.json'));d['$KEY']" 2>/dev/null \
  || { say "  FAIL policy has no key '$KEY'"; fail=1; }
if ps -o pid,stat,command -ax | grep '[s]csynth' | awk '$2 ~ /^U/' | grep -q .; then
  say "  FAIL a wedged scsynth is present; a reboot is owed"; fail=1
fi
[ -d /Volumes/FMA/superdark ] || { say "  FAIL the SSD is not mounted"; fail=1; }

# ON BATTERY, A LONG RUN WILL NOT SURVIVE.
#
# 17 Sept 2026: a two-arm comparison was started on battery. At 11% macOS
# entered Low Power Sleep, suspending the machine for 36.3 minutes in the middle
# of the candidate arm and making it unscoreable. The factory is wrapped in
# `caffeinate -ims`, which looks like protection and is not: -s prevents system
# sleep ONLY on AC power. Nothing in the preflight looked at the power source.
#
# A comparison is hours long by construction, so this is checked before anything
# starts, when it costs nothing, instead of discovered afterwards.
PWR=$(pmset -g batt 2>/dev/null | head -1)
case "$PWR" in
  *"'AC Power'"*) : ;;
  *) say "  FAIL running on battery. caffeinate -s does not prevent sleep on"
     say "       battery, and a sleep mid-arm makes that arm unscoreable."
     say "       Connect power, then start again."
     fail=1 ;;
esac
# Charging from very low is still a risk if power is pulled, so say the level out
# loud instead of only passing silently.
BATTPCT=$(pmset -g batt 2>/dev/null | grep -oE '[0-9]+%' | head -1)
[ -n "$BATTPCT" ] && say "  power: AC, battery $BATTPCT"
"$PY" "$ROOT/tools/seal_rig.py" verify >/dev/null 2>&1 \
  || say "  warn seal is broken; scoring later will refuse until adopted"
[ "$fail" -eq 0 ] || { say "PREFLIGHT FAILED -- nothing started."; exit 1; }
say "  ok"

CUR=$("$PY" -c "import json;print(json.load(open('$MUT/policy.json'))['$KEY'])")
say "  $KEY is currently $CUR; champion wants $CHAMP"
if [ "$CUR" != "$CHAMP" ]; then
  if [ "$DRY" -eq 1 ]; then say "  DRY: would set $KEY=$CHAMP before starting"
  else
    "$PY" - <<PYEOF
import json
p="$MUT/policy.json"; d=json.load(open(p)); d["$KEY"]="$CHAMP"
json.dump(d, open(p,"w"), indent=2)
PYEOF
    say "  set $KEY=$CHAMP"
  fi
fi

if [ "$DRY" -eq 1 ]; then
  say "DRY RUN: would start the factory, run $WINDOWS windows at $CHAMP,"
  say "         checkpoint, hot-reload to $CAND, run $WINDOWS more, checkpoint."
  say "         estimated $(echo "$WINDOWS" | awk '{printf "%.1f", $1*2*10.6/3600}') h total"
  exit 0
fi

# -------------------------------------------------------------------- start ---
# A PROCESS EXISTING IS NOT THE SAME AS ITS LOG EXISTING.
#
# 18 Sept 2026, 00:56. The runner started the factory, saw `pgrep -f _live.scd`
# succeed, and immediately took newest_log() -- which returned YESTERDAY'S log,
# because sclang had been alive for under a second and had not yet created
# today's. The runner then watched a file that would never grow again while the
# factory wrote happily to another one, and would have sat there until the 900 s
# stall timer fired and reported a stall that had not happened.
#
# pgrep is true the moment the interpreter starts; the window log appears after
# the corpora are assembled and the buffers loaded, which is seconds later. The
# gap is small and the consequence is total: every window count, every arm
# boundary and both checkpoints would have been taken against the wrong file.
#
# So the factory is not considered started until a log NEWER THAN THIS RUNNER
# exists. The stamp is created before start_loop.sh is invoked, so a log that
# predates it cannot be selected however recent it looks.
STAMP=$(mktemp /tmp/two_arms_stamp.XXXXXX)

if pgrep -f "_live.scd" >/dev/null 2>&1; then
  # ALREADY RUNNING: its log necessarily predates the stamp, so the newer-than
  # test cannot be applied and newest_log is the only available answer. Taking
  # an existing factory is a deliberate feature -- it is how a comparison is
  # attached to a run already in progress -- so this is not weakened, only
  # scoped to the case where the ambiguity cannot arise.
  say "factory already running; using it"
  LOG=$(newest_log)
else
  say "=== starting the factory ==="
  ( cd "$ROOT" && nohup sh tools/start_loop.sh > /tmp/two_arms_start.log 2>&1 & )
  n=0
  while [ $n -lt 40 ]; do
    sleep 15; n=$((n+1))
    pgrep -f "_live.scd" >/dev/null 2>&1 && break
  done
  pgrep -f "_live.scd" >/dev/null 2>&1 || {
    say "FACTORY DID NOT START. Last lines:"; tail -20 /tmp/two_arms_start.log
    rm -f "$STAMP"; exit 1; }
  say "  up"

  # Now wait for ITS log, not for any log.
  n=0; LOG=""
  while [ $n -lt 60 ]; do
    # -L BECAUSE $W/renders IS A SYMLINK to the SSD. Without it find treats
    # the path as a file, never descends, and returns nothing for ever -- which
    # is how the first version of this fix hung in its own wait loop for two
    # minutes while the log it wanted sat there. The unit test missed it by
    # using a real directory; the condition that matters is the one on disk.
    LOG=$(find -L "$W/renders" -name 'live_*.log' -newer "$STAMP" 2>/dev/null \
          | sort | tail -1)
    [ -n "$LOG" ] && break
    sleep 5; n=$((n+1))
  done
  [ -n "$LOG" ] || {
    say "THE FACTORY IS UP BUT WROTE NO NEW WINDOW LOG in 5 min."
    say "Refusing to fall back to the previous run's log: every window count and"
    say "both arm boundaries would be taken against the wrong file."
    rm -f "$STAMP"; exit 1; }
fi
rm -f "$STAMP"

[ -n "$LOG" ] || { say "no run log"; exit 1; }
say "  log: $(basename "$LOG")"

# How many CLOCK_JUMP events the integrity journal holds. A machine that sleeps
# mid-arm splits that arm into two non-contiguous stretches; the windows either
# side are not one series and must not be compared as though they were.
jumps() {
  if [ -f /tmp/superdark_integrity.jsonl ]; then
    n=$(grep -c CLOCK_JUMP /tmp/superdark_integrity.jsonl 2>/dev/null | head -1)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    echo "$n"
  else
    echo 0
  fi
}

# wait_for N -- block until the log reaches N windows, or the run dies
wait_for() {
  target=$1; label=$2
  last=$(count "$LOG"); lastmove=$(date +%s)
  j0=$(jumps)
  while :; do
    now=$(count "$LOG")
    [ "$now" -ge "$target" ] && return 0

    # ABORT ON A SLEEP, DO NOT RUN ON THROUGH IT.
    #
    # 17 Sept 2026: the laptop reached 11% battery and macOS entered Low Power
    # Sleep at 14:16, waking at 14:53 when AC was reattached -- 36.3 minutes
    # suspended, squarely inside the candidate arm. The runner noticed nothing
    # and kept counting windows toward 853, so it would have spent two more
    # hours producing an arm that the gate must refuse. On 28 Aug the same class
    # of sleep cost an 8 h run 85% of its data and WAS read as data.
    #
    # caffeinate -s does not help: it prevents system sleep only on AC power.
    #
    # The integrity watcher already detects this. It was the only thing that
    # did. Reading its journal here turns a detection nobody was watching into a
    # stop.
    if [ "$(jumps)" -gt "$j0" ]; then
      say "  CLOCK JUMP during the $label arm: the machine slept or the clock"
      say "  stepped. Windows either side are not one continuous series, so this"
      say "  arm cannot be scored. Aborting instead of running on."
      return 2
    fi

    if [ "$now" -gt "$last" ]; then last=$now; lastmove=$(date +%s); fi
    if [ $(( $(date +%s) - lastmove )) -gt "$STALL_S" ]; then
      say "  STALLED: $label stuck at $now windows for ${STALL_S}s"
      return 1
    fi
    # Progress. `now % 100` alone almost never lands, because the count jumps
    # past exact multiples between polls -- on 17 Sept the runner printed one
    # progress line in two and a half hours and looked stalled while healthy.
    # Report on elapsed time instead, which cannot be skipped over.
    if [ $(( $(date +%s) - ${lastsay:-0} )) -ge 600 ]; then
      lastsay=$(date +%s); say "  $label $now/$target"
    fi
    sleep "$POLL_S"
  done
}

START=$(count "$LOG")
C_FROM=$((START + 1))
C_TO=$((START + WINDOWS))
C_EPOCH=$(date +%s)
say "=== CHAMPION arm: $KEY=$CHAMP, windows $C_FROM-$C_TO ==="

"$PY" - <<PYEOF
import json
json.dump({"key":"$KEY","champion_value":"$CHAMP","candidate_value":"$CAND",
           "intent":"$INTENT",
           "log":"$(basename "$LOG")","windows_per_arm":$WINDOWS,
           "champion":{"from":$C_FROM,"to":$C_TO,"since":$C_EPOCH,"until":None},
           "candidate":None,"status":"champion running"},
          open("$STATE","w"), indent=1)
PYEOF
say "  state: $(basename "$STATE")"

wait_for "$C_TO" "champion"; RC=$?
if [ "$RC" -ne 0 ]; then
  # NAME THE FAULT, DO NOT CALL EVERYTHING A STALL. A stalled factory and a
  # machine that slept are different failures with different remedies, and a
  # state file that says "stalled" when the cause was a sleep sends the next
  # reader to look at the factory instead of at the power settings.
  if [ "$RC" -eq 2 ]; then
    WHY="ABORTED: clock jump during the champion arm; the machine slept or the clock stepped, so the arm is not one continuous series"
  else
    WHY="ABORTED: factory stalled during the champion arm"
  fi
  "$PY" - <<PYEOF
import json; d=json.load(open("$STATE")); d["status"]="""$WHY"""
json.dump(d, open("$STATE","w"), indent=1)
PYEOF
  say "ABORTED during the champion arm. The knob was NOT flipped."
  exit 1
fi
C_UNTIL=$(date +%s)
say "  champion arm complete at $(count "$LOG") windows"

# ------------------------------------------------------ checkpoint + reload ---
CK=$("$PY" "$ROOT/tools/checkpoint.py" create \
  --note "CHAMPION arm, $KEY=$CHAMP, windows $C_FROM-$C_TO. Sealed BEFORE the hot reload to $CAND. Driven by run_two_arms.sh, unsupervised." \
  2>/dev/null | awk '/path/{print $2}')
say "  champion checkpoint: $(basename "${CK:-none}")"

# THE FACTORY MUST STILL BE ALIVE. Flipping a knob into a dead factory would
# produce a candidate arm of silence that looks like a measurement.
pgrep -f "_live.scd" >/dev/null 2>&1 || {
  say "FACTORY DIED before the reload. Not flipping. Champion arm stands alone."
  "$PY" - <<PYEOF
import json; d=json.load(open("$STATE")); d["status"]="ABORTED: factory died before the reload"
d["champion"]["until"]=$C_UNTIL
json.dump(d, open("$STATE","w"), indent=1)
PYEOF
  exit 1; }

cp "$MUT/policy.json" "$MUT/policy.json.bak_two_arms"
"$PY" - <<PYEOF
import json
p="$MUT/policy.json"; d=json.load(open(p)); d["$KEY"]="$CAND"
json.dump(d, open(p,"w"), indent=2)
PYEOF
D_EPOCH=$(date +%s)
D_START=$(count "$LOG")
D_FROM=$((D_START + 1))
D_TO=$((D_START + WINDOWS))
say "=== hot reload: $KEY $CHAMP -> $CAND, no restart ==="
say "=== CANDIDATE arm: windows $D_FROM-$D_TO ==="

"$PY" - <<PYEOF
import json
d=json.load(open("$STATE"))
d["champion"]["until"]=$C_UNTIL
d["champion"]["checkpoint"]="$(basename "${CK:-}")"
d["candidate"]={"from":$D_FROM,"to":$D_TO,"since":$D_EPOCH,"until":None}
d["status"]="candidate running"
json.dump(d, open("$STATE","w"), indent=1)
PYEOF

wait_for "$D_TO" "candidate"; RC=$?
if [ "$RC" -ne 0 ]; then
  # A CLOCK JUMP IS NOT "PARTIAL". A short arm is still readable as far as it
  # goes; an arm with a sleep in it is not readable at all, because the windows
  # either side are not one series. Calling both PARTIAL would invite someone to
  # score the second the way the first can be scored.
  if [ "$RC" -eq 2 ]; then
    WHY="VOID: clock jump during the candidate arm; the machine slept or the clock stepped, so the arm is not one continuous series and cannot be scored at any length"
    SHORT="candidate arm VOID: the machine slept mid-arm. Champion is intact."
  else
    WHY="PARTIAL: candidate arm stalled"
    SHORT="candidate arm stalled. Champion is intact; candidate is short and marked PARTIAL."
  fi
  "$PY" - <<PYEOF
import json; d=json.load(open("$STATE")); d["status"]="""$WHY"""
d["candidate"]["until"]=$(date +%s)
json.dump(d, open("$STATE","w"), indent=1)
PYEOF
  say "$SHORT"
  exit 1
fi
D_UNTIL=$(date +%s)

CK2=$("$PY" "$ROOT/tools/checkpoint.py" create \
  --note "CANDIDATE arm, $KEY=$CAND, windows $D_FROM-$D_TO, hot-reloaded with no restart. Driven by run_two_arms.sh, unsupervised." \
  2>/dev/null | awk '/path/{print $2}')

"$PY" - <<PYEOF
import json
d=json.load(open("$STATE"))
d["candidate"]["until"]=$D_UNTIL
d["candidate"]["checkpoint"]="$(basename "${CK2:-}")"
d["status"]="COMPLETE"
json.dump(d, open("$STATE","w"), indent=1)
PYEOF

say "=== BOTH ARMS COMPLETE ==="
say "  champion  $KEY=$CHAMP  windows $C_FROM-$C_TO"
say "  candidate $KEY=$CAND   windows $D_FROM-$D_TO"
say "  state file: $STATE"
say ""
say "  The factory is STILL RUNNING and was never restarted."
say "  Score with eval_rig.sh using the ranges and epochs in the state file."
