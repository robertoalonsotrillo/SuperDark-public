#!/bin/sh
# Wait for the machine to go quiet, then start the long run.
#
# A freshly booted Mac spends ten to twenty minutes on Spotlight, iCloud, Metal
# asset upgrades and autoupdate helpers. On 25 Aug the load average one minute
# after a reboot was 611. Buffer loading is I/O bound and under that kind of
# queue it does not fail, it just runs slower than the window -- which is how a
# starved run reached 832 of 2400 buffers in twenty minutes on 24 Aug and still
# looked healthy.
#
# So poll rather than guess a settling time, and hand over to longrun.sh (whose
# own guards then re-check drive, mains, load and port independently).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THRESH="${THRESH:-12}"
MAXWAIT="${MAXWAIT:-2400}"          # 40 minutes
WAITED=0

echo "waiting for load <= $THRESH  (checking every 30 s, giving up after $((MAXWAIT / 60)) min)"
while [ "$WAITED" -lt "$MAXWAIT" ]; do
  L=$(uptime | sed 's/.*averages*: *//' | awk '{print int($1)}')
  if [ "$L" -le "$THRESH" ]; then
    echo "$(date +%H:%M:%S)  load $L -- starting"
    exec caffeinate -dimsu "$ROOT/tools/longrun.sh"
  fi
  echo "$(date +%H:%M:%S)  load $L  still settling"
  sleep 30
  WAITED=$((WAITED + 30))
done

echo "GAVE UP: load never fell to $THRESH in $((MAXWAIT / 60)) min."
echo "Something is genuinely busy. Check: ps ax -o pcpu,comm -r | head"
exit 1
