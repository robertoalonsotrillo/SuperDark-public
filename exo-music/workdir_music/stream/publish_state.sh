#!/bin/sh
# Push the factory's evaluation snapshot to the relay, on a timer.
#
# WHY IT IS PUSHED AND NOT PULLED. The relay cannot reach this machine: the ssh
# tunnel is OUTBOUND ONLY, which is the whole reason the stream survives behind
# a domestic router. So the snapshot travels the same direction the audio does.
#
# WHY IT WRITES TO A TEMP NAME AND MOVES. Caddy serves the file directly. A
# half-copied JSON served to a visitor is a parse error in their browser, and
# `mv` within a filesystem is atomic, so a reader sees either the previous
# snapshot or the next one.
#
# WHY THE PERIOD IS 10 s AND NOT 1 s. Measured on the live log: the window is
# 11.7 s, the engaged machine changes in 94% of windows (median run: 1 window)
# and the voice count in 14% (median run: 5 windows, about a minute). So 10 s
# keeps the machine readout within roughly one window of the truth, and anything
# faster would republish an identical snapshot. The quantities do not exist at
# finer resolution than the log records them.
#
# Genuinely per-frame motion comes from the Web Audio analyser in player.html,
# which reads the decoded stream in the listener's own browser and costs this
# machine nothing.
#
#   sh stream/publish_state.sh once     # one snapshot, for testing
#   sh stream/publish_state.sh start    # background loop
#   sh stream/publish_state.sh stop
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RELAY=root@stream.robertoalonsotrillo.com
# ONE FILE PER FACTORY. Two factories publishing to one state.json would
# overwrite each other every ten seconds and the page would show whichever wrote
# last -- a panel that flickers between two different systems while claiming to
# describe one. The default is unchanged, so the primary needs no restart:
#   primary  STATE_NAME=state.json          (default)
#   replica  STATE_NAME=state-replica.json
STATE_NAME="${STATE_NAME:-state.json}"
REMOTE="/var/www/superdark/$STATE_NAME"
LOCAL="/tmp/superdark_$STATE_NAME"
PERIOD=10
LOG=/tmp/publish_state.log

snapshot() {
  python3 "$ROOT/tools/factory_status.py" --out "$LOCAL" >/dev/null 2>&1 || return 1
  # -T because some sshd builds reject scp's default; and a fixed temp name so a
  # failed run cannot litter the relay with partial files.
  scp -q -o BatchMode=yes -o ConnectTimeout=10 "$LOCAL" "$RELAY:$REMOTE.tmp" \
    && ssh -q -o BatchMode=yes -o ConnectTimeout=10 "$RELAY" "mv $REMOTE.tmp $REMOTE"
}

case "${1:-status}" in
once)
  if snapshot; then
    echo "  published"
    curl -s --max-time 10 https://stream.robertoalonsotrillo.com/$STATE_NAME \
      | python3 -c "import json,sys; d=json.load(sys.stdin); \
print('  served back:', d['run'].get('windows'), 'windows, charter ed.', d['charter']['edition'])"
  else
    echo "  FAILED"; exit 1
  fi
  ;;
start)
  if pgrep -f "publish_state.sh loop" >/dev/null; then echo "  already running"; exit 0; fi
  nohup sh "$0" loop > "$LOG" 2>&1 &
  sleep 3
  pgrep -f "publish_state.sh loop" >/dev/null \
    && echo "  publishing every ${PERIOD}s -> https://stream.robertoalonsotrillo.com/$STATE_NAME" \
    || { echo "  FAILED"; tail -5 "$LOG"; exit 1; }
  ;;
loop)
  while true; do
    snapshot || echo "$(date -u +%H:%M:%S) snapshot failed"
    sleep "$PERIOD"
  done
  ;;
stop)
  pkill -f "publish_state.sh loop" 2>/dev/null || true
  echo "  stopped"
  ;;
status)
  pgrep -f "publish_state.sh loop" >/dev/null && echo "  publisher: running" || echo "  publisher: down"
  curl -s -o /dev/null -w "  endpoint: HTTP %{http_code}\n" --max-time 10 \
    https://stream.robertoalonsotrillo.com/$STATE_NAME
  ;;
esac
