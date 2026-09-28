#!/bin/sh
# One factory listens to the other. Class 3 target 3, 20 Sept 2026.
#
# Two listeners, both world_listen.py, both in the corpus geometry:
#   world  the OTHER factory's relay mount -> OSC /world to this factory, logged
#   self   THIS factory's own relay mount  -> logged only, never sent
# The factory consumes /world only when policy world_pull > 0 (set separately,
# through set_policy.py, so the change is on the record). With world_pull 0
# this is the control arm: the world arrives, is logged on every WORLD line,
# and steers nothing.
#
#   sh tools/factory_consumes_factory.sh start [WORLD_URL] [SELF_URL]
#   sh tools/factory_consumes_factory.sh status
#   sh tools/factory_consumes_factory.sh stop
#   sh tools/factory_consumes_factory.sh test          # world_coupling.py on the logs
#
# Defaults: world = Factory 1's mount, self = Factory 2's mount. Reverse them
# on the replica.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAINS="$ROOT/workdir_music/grains_lic_ev"
RUN="$ROOT/workdir_music/renders/world"
mkdir -p "$RUN"
WORLD_URL="${2:-https://stream.robertoalonsotrillo.com/replica.mp3}"
SELF_URL="${3:-https://stream.robertoalonsotrillo.com/superdark.mp3}"
WLOG="$RUN/world.csv"; SLOG="$RUN/self.csv"
WPID="$RUN/world.pid"; SPID="$RUN/self.pid"

alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }

case "${1:-status}" in
  start)
    if alive "$WPID" || alive "$SPID"; then echo "already running; stop first"; exit 1; fi
    echo "world  <- $WORLD_URL"
    echo "self   <- $SELF_URL"
    echo "logs   $RUN"
    nohup python3 "$ROOT/tools/world_listen.py" --url "$WORLD_URL" --grains "$GRAINS" \
        --log "$WLOG" > "$RUN/world.out" 2>&1 </dev/null &
    echo $! > "$WPID"
    nohup python3 "$ROOT/tools/world_listen.py" --url "$SELF_URL" --grains "$GRAINS" \
        --log "$SLOG" --log-only > "$RUN/self.out" 2>&1 </dev/null &
    echo $! > "$SPID"
    sleep 8
    "$0" status
    ;;
  stop)
    for p in "$WPID" "$SPID"; do
      if alive "$p"; then kill "$(cat "$p")" 2>/dev/null; echo "stopped $(cat "$p")"; fi
      rm -f "$p"
    done
    ;;
  status)
    for n in world self; do
      p="$RUN/$n.pid"; l="$RUN/$n.csv"
      if alive "$p"; then
        rows=$(wc -l < "$l" 2>/dev/null | tr -d ' ')
        age=$(( $(date +%s) - $(tail -1 "$l" 2>/dev/null | cut -d. -f1 || echo 0) ))
        echo "  $n  up pid $(cat "$p")  rows $rows  last row ${age}s ago"
      else
        echo "  $n  DOWN  $(tail -1 "$RUN/$n.out" 2>/dev/null | cut -c1-100)"
      fi
    done
    wp=$(python3 -c "import json;print(json.load(open('$ROOT/workdir_music/mutable/policy.json'))['world_pull'])" 2>/dev/null)
    echo "  world_pull = $wp"
    ;;
  test)
    python3 "$ROOT/tools/world_coupling.py" --world "$WLOG" --self "$SLOG"
    ;;
  *) echo "usage: $0 start|stop|status|test"; exit 2 ;;
esac
