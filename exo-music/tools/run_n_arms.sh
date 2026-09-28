#!/bin/sh
# Drive an A-B-A-C-A-D comparison sequence without supervision.
#
# WHY THIS EXISTS
# run_two_arms.sh runs one champion arm and one candidate arm. Three comparisons
# in, the null (18 Sept) showed the drift between two IDENTICAL arms is the same
# size as the movement the real comparisons produced. Every comparison from here
# needs a drift estimate taken in the same run, and one knob per five-hour boot
# is too slow to reach five paired comparisons.
#
# So: N candidates in ONE unbroken run, every candidate bracketed by a champion
# arm. A1 B A2 C A3 D. Each boundary changes exactly one policy key -- the
# candidate's knob going in, or the same knob coming back out -- so
# one_change_at_a_time holds at every step. The A-vs-A pairs are nulls measured
# inside the same run, on the same corpus and trace, which is the noise floor
# the release policy needs and could not get any other way.
#
# WHAT IT WILL NOT DO -- inherited from run_two_arms.sh, every one of them
# earned on a night it was missing:
#   - restart the factory mid-sequence (a second change; the gate would refuse)
#   - flip a knob into a dead factory (aborts, leaves completed arms labelled)
#   - run on through a clock jump (the machine slept; the arm is not one series)
#   - start on battery (caffeinate -s does not hold on battery)
#   - take the previous run's log because the new one is not there yet
#   - stop the factory at the end (a decision for a person)
#
#   sh tools/run_n_arms.sh --windows 853 \
#       --cand self_ingest_weight=0.5 --cand voices_max=5 --cand collapse_after=300
#   ... --dry-run
#   --settle N  windows discarded after each reload (default 12)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
# ---- NEVER RUN INSIDE AN APP'S PROCESS GROUP (24 Sept 2026) -----------------
# Two runs died with their whole stack the moment the Claude desktop app
# restarted (23 Sept 23:35, 24 Sept 17:24): everything launched from a shell
# the app owns sits in the app's process group and goes down with it. If this
# script finds itself in a group led by an application, it re-launches itself
# through tools/detach.sh (its own session, parent launchd) and exits.
if [ -z "${SD_DETACHED:-}" ]; then
  _leader="$(ps -o comm= -p "$(ps -o pgid= -p $$ | tr -d ' ')" 2>/dev/null)"
  case "$_leader" in
    *Claude*|*.app/*|*Electron*)
      echo "  process group is led by '$_leader'; re-launching detached"
      SD_DETACHED=1 exec sh "$ROOT/tools/detach.sh" env SD_DETACHED=1 sh "$0" "$@" ;;
  esac
fi
MUT="$W/mutable"
PY="$(command -v /opt/homebrew/bin/python3 || command -v python3)"

WINDOWS=853; DRY=0; CANDS=""; ALLOW_BATTERY=0; SETTLE=12
STALL_S=900; POLL_S=60

while [ $# -gt 0 ]; do
  case "$1" in
    --cand)    CANDS="$CANDS $2"; shift 2 ;;
    --windows) WINDOWS=$2; shift 2 ;;
    --settle)  SETTLE=$2; shift 2 ;;   # windows discarded after each reload
    --dry-run) DRY=1; shift ;;
    --allow-battery) ALLOW_BATTERY=1; shift ;;   # Roberto, 18 Sept: a person's call, recorded in the state file
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -n "$CANDS" ] || { echo "usage: --cand KEY=VALUE [--cand ...] [--windows N] [--dry-run]" >&2; exit 2; }

STATE="$ROOT/harness/n_arms_$(date +%y%m%d_%H%M%S).json"
say() { echo "[$(date '+%H:%M:%S')] $*"; }
newest_log() { ls -t "$W/renders"/live_*.log 2>/dev/null | head -1; }

count() {
  if [ -f "$1" ]; then
    n=$(grep -c '^VOICES' "$1" 2>/dev/null | head -1)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac; echo "$n"
  else echo 0; fi
}
JOURNAL=/tmp/superdark_integrity.jsonl
MONITOR="run_integrity.py --watch"
jumps() {
  if [ -f "$JOURNAL" ]; then
    n=$(grep -c CLOCK_JUMP "$JOURNAL" 2>/dev/null | head -1)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac; echo "$n"
  else echo 0; fi
}
# "no jumps" and "cannot tell" are not the same answer, and jumps() cannot tell
# them apart -- a missing journal reads as zero forever. On 18 Sept the machine
# rebooted at 09:12, /tmp was cleared, nothing restarts the monitor, and the
# clock-jump abort listed at the top of this file was inert: it would have
# reported a clean 14 h run through any number of sleeps. So the monitor's own
# liveness is checked, at preflight and at every poll.
monitor_dead() {   # 0 = dead or unreadable, 1 = alive
  pgrep -f "$MONITOR" >/dev/null 2>&1 || return 0
  [ -f "$JOURNAL" ] || return 0
  return 1
}
setkey() {   # setkey KEY VALUE  -- hot reload: the factory re-reads policy each window
  "$PY" - "$MUT/policy.json" "$1" "$2" <<'PYEOF'
import json, sys
p, k, v = sys.argv[1:4]
d = json.load(open(p)); d[k] = v
json.dump(d, open(p, "w"), indent=2)
PYEOF
}
getkey() { "$PY" -c "import json,sys;print(json.load(open('$MUT/policy.json'))['$1'])"; }

# ---------------------------------------------------------------- preflight ---
say "=== preflight ==="
fail=0
[ -f "$MUT/policy.json" ] || { say "  FAIL no policy.json"; fail=1; }
for kv in $CANDS; do
  k=${kv%%=*}; v=${kv#*=}
  [ -n "$k" ] && [ -n "$v" ] && [ "$k" != "$kv" ] || { say "  FAIL bad --cand '$kv' (want KEY=VALUE)"; fail=1; continue; }
  "$PY" -c "import json;d=json.load(open('$MUT/policy.json'));d['$k']" 2>/dev/null \
    || { say "  FAIL policy has no key '$k'"; fail=1; }
done
if ps -o pid,stat,command -ax | grep '[s]csynth' | awk '$2 ~ /^U/' | grep -q .; then
  say "  FAIL a wedged scsynth is present; a reboot is owed"; fail=1; fi
[ -d /Volumes/FMA/superdark ] || { say "  FAIL the SSD is not mounted"; fail=1; }
if monitor_dead; then
  say "  FAIL the integrity monitor is not running, so sleeps, clock jumps and"
  say "       FIFO stalls would go unrecorded and the CLOCK JUMP abort above"
  say "       would be inert. Start it first, in its own window:"
  say "         nohup python3 tools/run_integrity.py --watch > /tmp/run_integrity_watch.log 2>&1 &"
  fail=1
else
  say "  monitor: up, journal $(wc -l < "$JOURNAL" | tr -d ' ') lines"
fi
PWR=$(pmset -g batt 2>/dev/null | head -1)
case "$PWR" in *"'AC Power'"*) : ;;
  *) if [ "$ALLOW_BATTERY" -eq 1 ]; then
       say "  WARN on battery, overridden by --allow-battery. caffeinate -s does not hold;"
       say "       a sleep will show as a CLOCK JUMP and end the sequence VOID."
     else say "  FAIL on battery. caffeinate -s does not prevent sleep on battery. (--allow-battery overrides)"; fail=1; fi ;; esac
BATT=$(pmset -g batt 2>/dev/null | grep -oE '[0-9]+%' | head -1)
SRC=$(echo "$PWR" | grep -oE "'[A-Za-z ]+'" | tr -d "'")
[ -n "$BATT" ] && say "  power: ${SRC:-unknown}, battery $BATT"
"$PY" "$ROOT/tools/seal_rig.py" verify >/dev/null 2>&1 || say "  warn seal is broken; scoring later will refuse until adopted"

# THE AUDIO RING MUST HOLD THE WHOLE RUN. 18-19 Sept: six arms, 15.5 h, ring
# 8 GB = 6.3 h of raw f32 stereo. The ring wrapped while the run was going and
# five of six arms had no audio by scoring time. sonic_variety, the one
# promoting measure wired into arms, returned NO AUDIO on every pair and both
# in-run nulls were lost. Everything else about the run was clean, which is
# what made it invisible. Count the bytes before starting, not after.
NC_PRE=$(echo $CANDS | wc -w | tr -d ' ')
RUN_S=$(( WINDOWS * NC_PRE * 2 * 11 ))              # 11 s/window: measured 10.6-10.7, with margin
NEED_GB=$(awk "BEGIN{printf \"%.1f\", $RUN_S * 352800 / 1073741824}")   # 44100 Hz * 2 ch * 4 B
RING_GB=$(ps -axo command | grep '[f]ifo_splitter.py' | grep -oE -- '--ring-gb[ =][0-9.]+' | grep -oE '[0-9.]+$' | head -1)
if [ -z "$RING_GB" ]; then
  say "  FAIL no fifo_splitter running, so no audio would be captured for any arm"; fail=1
elif awk "BEGIN{exit !($NEED_GB > $RING_GB * 0.9)}"; then
  say "  FAIL the run needs ~${NEED_GB} GB of audio and the splitter's ring is ${RING_GB} GB."
  say "       The ring would wrap before the sequence ends and early arms would be"
  WANT_GB=$(awk -v n="$NEED_GB" 'BEGIN{printf "%d", n * 1.25 + 1}' </dev/null)
  say "       deleted before they are scored. Restart the splitter with"
  say "       --ring-gb $WANT_GB or shorten the arms."
  fail=1
else
  say "  audio: run needs ~${NEED_GB} GB, ring holds ${RING_GB} GB"
fi
SEG_FREE_GB=$(df -g /Volumes/FMA 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "$SEG_FREE_GB" ] && [ -n "$RING_GB" ] && awk "BEGIN{exit !($RING_GB > $SEG_FREE_GB)}"; then
  say "  FAIL ring ${RING_GB} GB exceeds free space ${SEG_FREE_GB} GB on the SSD"; fail=1
fi
[ "$fail" -eq 0 ] || { say "PREFLIGHT FAILED -- nothing started."; exit 1; }
say "  ok"

# The BASELINE is the policy as it stands now. Every champion arm is this.
# Record the baseline value of every knob so the reload back is exact.
BASE=""
for kv in $CANDS; do k=${kv%%=*}; BASE="$BASE $k=$(getkey "$k")"; done
say "  baseline:$BASE"
say "  candidates:$CANDS"
NC=$(echo $CANDS | wc -w | tr -d ' ')
# 26 Sept 2026: NARMS was NC*2, so the sequence ran A1 C1 ... Cn and stopped;
# the last candidate had no closing champion arm and the bracket the prereg
# asks for (A C A) never existed for a single candidate. It is 2*NC+1 now.
NARMS=$((NC * 2 + 1))
say "  sequence: $NARMS arms ($NC candidates, each bracketed, closing on A$((NC + 1))), $WINDOWS windows each, $SETTLE settle windows after each reload"
say "  estimated $(echo "$WINDOWS $NARMS" | awk -v s="$SETTLE" -v nc="$NC" '{printf "%.1f", ($1*$2 + s*2*nc)*10.6/3600}') h"

# refuse a candidate equal to its baseline: that is a null, and nulls are run
# with run_two_arms --champ X --cand X so they are DECLARED, not accidental
for kv in $CANDS; do
  k=${kv%%=*}; v=${kv#*=}
  [ "$v" != "$(getkey "$k")" ] || { say "FAIL --cand $kv equals the baseline; use run_two_arms.sh for a declared null"; exit 1; }
done

[ "$DRY" -eq 1 ] && { say "DRY RUN: would run the sequence above."; exit 0; }

# -------------------------------------------------------------------- start ---
STAMP=$(mktemp /tmp/n_arms_stamp.XXXXXX)
if pgrep -f "_live.scd" >/dev/null 2>&1; then
  say "factory already running; using it"; LOG=$(newest_log)
else
  say "=== starting the factory ==="
  ( cd "$ROOT" && nohup sh tools/start_loop.sh > /tmp/n_arms_start.log 2>&1 & )
  n=0; while [ $n -lt 40 ]; do sleep 15; n=$((n+1)); pgrep -f "_live.scd" >/dev/null 2>&1 && break; done
  pgrep -f "_live.scd" >/dev/null 2>&1 || { say "FACTORY DID NOT START"; tail -20 /tmp/n_arms_start.log; rm -f "$STAMP"; exit 1; }
  say "  up"
  n=0; LOG=""
  while [ $n -lt 60 ]; do
    LOG=$(find -L "$W/renders" -name 'live_*.log' -newer "$STAMP" 2>/dev/null | sort | tail -1)
    [ -n "$LOG" ] && break; sleep 5; n=$((n+1))
  done
  [ -n "$LOG" ] || { say "FACTORY UP BUT NO NEW WINDOW LOG in 5 min. Refusing the previous run's log."; rm -f "$STAMP"; exit 1; }
  # "up" meant: sclang exists and an empty log file exists. On 18 Sept 10:28
  # both were true, the interpreter had already corrupted its own heap, the
  # server never booted, start_loop.sh killed it at 10:31, and this script sat
  # on "A1 0/853" until the 15-minute stall guard. A factory is up when it has
  # written a window, and not before.
  say "  waiting for the first window"
  n=0
  while [ $n -lt 72 ]; do
    [ "$(count "$LOG")" -ge 1 ] && break
    pgrep -f "_live.scd" >/dev/null 2>&1 || {
      say "FACTORY DIED BEFORE ITS FIRST WINDOW. Nothing started."
      say "  /tmp/n_arms_start.log says:"; tail -8 /tmp/n_arms_start.log | sed 's/^/    /'
      say "  /tmp/factory.log, first error:"; grep -n -m1 -i "error" /tmp/factory.log | sed 's/^/    /'
      rm -f "$STAMP"; exit 1; }
    sleep 5; n=$((n+1))
  done
  [ "$(count "$LOG")" -ge 1 ] || { say "FACTORY ALIVE BUT NO WINDOW IN 6 MIN. Nothing started."; rm -f "$STAMP"; exit 1; }
  say "  first window written"
fi
rm -f "$STAMP"
say "  log: $(basename "$LOG")"

wait_for() {   # wait_for N LABEL -> 0 done, 1 stalled, 2 clock jump, 3 unwatched, 4 died
  target=$1; label=$2
  last=$(count "$LOG"); lastmove=$(date +%s); j0=$(jumps); lastsay=0
  while :; do
    now=$(count "$LOG")
    [ "$now" -ge "$target" ] && return 0
    # a dead factory is known within one poll, not after a 15-minute stall
    pgrep -f "_live.scd" >/dev/null 2>&1 || { say "  FACTORY DIED during $label at $now windows."; return 4; }
    monitor_dead && { say "  INTEGRITY MONITOR DIED during $label. From here nothing"; \
                      say "  would record a sleep or a clock jump, and jumps() would"; \
                      say "  keep answering zero. Aborting rather than running blind."; return 3; }
    [ "$(jumps)" -gt "$j0" ] && { say "  CLOCK JUMP during $label: not one continuous series. Aborting."; return 2; }
    if [ "$now" -gt "$last" ]; then last=$now; lastmove=$(date +%s); fi
    [ $(( $(date +%s) - lastmove )) -gt "$STALL_S" ] && { say "  STALLED: $label at $now windows for ${STALL_S}s"; return 1; }
    if [ $(( $(date +%s) - lastsay )) -ge 600 ]; then lastsay=$(date +%s); say "  $label $now/$target"; fi
    sleep "$POLL_S"
  done
}

# state file: an ordered list of arms
N_ARMS_ALLOW_BATTERY=$ALLOW_BATTERY N_ARMS_SETTLE=$SETTLE "$PY" - "$STATE" "$(basename "$LOG")" "$WINDOWS" "$BASE" "$CANDS" <<'PYEOF'
import json, sys
st, log, w, base, cands = sys.argv[1:6]
d = {"design": "A-B-A-C-A-D: every candidate bracketed by a champion arm",
     "log": log, "windows_per_arm": int(w),
     "settle_windows": int(__import__("os").environ.get("N_ARMS_SETTLE", "0")),
     "baseline": dict(kv.split("=", 1) for kv in base.split()),
     "candidates": [dict(zip(("knob", "value"), kv.split("=", 1))) for kv in cands.split()],
     "arms": [], "status": "starting",
     "power_at_start": __import__("subprocess").run(["pmset", "-g", "batt"], capture_output=True, text=True).stdout.splitlines()[0].strip(),
     "battery_override": __import__("os").environ.get("N_ARMS_ALLOW_BATTERY") == "1"}
json.dump(d, open(st, "w"), indent=1)
PYEOF
say "  state: $(basename "$STATE")"

# arm LABEL KNOB VALUE  -- runs one arm from the current window count, checkpoints,
# appends to the state file. KNOB/VALUE empty means a champion arm.
arm() {
  label=$1; knob=$2; val=$3
  from=$(( $(count "$LOG") + 1 )); to=$(( from + WINDOWS - 1 )); since=$(date +%s)
  say "=== ARM $label: ${knob:+$knob=$val }windows $from-$to ==="
  "$PY" - "$STATE" "$label" "$knob" "$val" "$from" "$to" "$since" <<'PYEOF'
import json, sys
st, label, knob, val, f, t, s = sys.argv[1:8]
d = json.load(open(st))
d["arms"].append({"label": label, "knob": knob or None, "value": val or None,
                  "from": int(f), "to": int(t), "since": int(s), "until": None, "checkpoint": None})
d["status"] = f"arm {label} running"
json.dump(d, open(st, "w"), indent=1)
PYEOF
  wait_for "$to" "$label"; rc=$?
  until=$(date +%s)
  if [ "$rc" -ne 0 ]; then
    case "$rc" in
      2) why="VOID at arm $label: clock jump" ;;
      3) why="VOID at arm $label: the integrity monitor died; the run was unwatched" ;;
      4) why="ABORTED at arm $label: the factory died" ;;
      *) why="PARTIAL at arm $label: stalled" ;;
    esac
    "$PY" - "$STATE" "$why" "$until" <<'PYEOF'
import json, sys
st, why, u = sys.argv[1:4]
d = json.load(open(st)); d["arms"][-1]["until"] = int(u); d["status"] = why
json.dump(d, open(st, "w"), indent=1)
PYEOF
    say "$why. Completed arms before it stand; nothing after it was run."
    exit 1
  fi
  ck=$("$PY" "$ROOT/tools/checkpoint.py" create \
        --note "arm $label${knob:+, $knob=$val}, windows $from-$to, run_n_arms.sh, unsupervised" 2>/dev/null \
        | awk '/path/{print $2}')
  "$PY" - "$STATE" "$until" "$(basename "${ck:-}")" <<'PYEOF'
import json, sys
st, u, ck = sys.argv[1:4]
d = json.load(open(st)); d["arms"][-1]["until"] = int(u); d["arms"][-1]["checkpoint"] = ck
json.dump(d, open(st, "w"), indent=1)
PYEOF
  say "  arm $label complete, checkpoint $(basename "${ck:-none}")"
}

# settle LABEL -- after a hot reload, discard SETTLE windows before the next arm.
# 26 Sept 2026: the reload to +0.5 reached the log one window late (819) and
# the reload back eleven windows late (1619-1629 still read K=+0.5), so the
# first windows of an arm belonged to the previous condition. Settle windows
# sit in no arm; the state file records how many.
settle() {
  [ "$SETTLE" -gt 0 ] || return 0
  s_to=$(( $(count "$LOG") + SETTLE ))
  say "  settling $SETTLE windows (to $s_to), counted in no arm"
  wait_for "$s_to" "settle before $1"; rc=$?
  [ "$rc" -eq 0 ] && return 0
  "$PY" -c "import json;d=json.load(open('$STATE'));d['status']='ABORTED during settle before $1 (rc $rc)';json.dump(d,open('$STATE','w'),indent=1)"
  say "ABORTED during settle before $1. Completed arms stand."; exit 1
}

alive_or_die() {
  pgrep -f "_live.scd" >/dev/null 2>&1 || {
    say "FACTORY DIED at $1. Not reloading. Completed arms stand."
    "$PY" -c "import json;d=json.load(open('$STATE'));d['status']='ABORTED: factory died at $1';json.dump(d,open('$STATE','w'),indent=1)"
    exit 1; }
}

# ------------------------------------------------------------------ sequence ---
i=0
for kv in $CANDS; do
  i=$((i+1)); k=${kv%%=*}; v=${kv#*=}; b=$(getkey "$k")
  # champion arm first: baseline is already in force (the previous candidate,
  # if any, was reverted at the end of its own arm)
  arm "A$i" "" ""
  alive_or_die "before reload to $k=$v"
  setkey "$k" "$v"; say "=== hot reload: $k $b -> $v, no restart ==="
  settle "C$i"
  arm "C$i" "$k" "$v"
  alive_or_die "after arm C$i"
  setkey "$k" "$b"; say "=== hot reload back: $k $v -> $b, no restart ==="
  settle "A$((i + 1))"
done
# the closing champion arm: the last candidate is bracketed like every other
arm "A$((NC + 1))" "" ""
alive_or_die "after arm A$((NC + 1))"

"$PY" -c "import json;d=json.load(open('$STATE'));d['status']='COMPLETE';json.dump(d,open('$STATE','w'),indent=1)"
say "=== ALL $NARMS ARMS COMPLETE ==="
say "  state file: $STATE"
say "  The factory is STILL RUNNING, on the baseline, and was never restarted."
say "  Score with: sh tools/score_n_arms.sh $STATE"
