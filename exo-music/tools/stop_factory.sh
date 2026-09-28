#!/bin/sh
# Stop the factory completely, and verify it. (#108)
#
# WHY THIS EXISTS. On 16 Sept the factory was stopped with
#
#     pkill -f "MacOS/sclang" ; pkill -f caffeinate
#
# which left **scsynth running and holding UDP 57110**, because its path is
# .../Resources/../Resources/scsynth and contains neither string. The next start
# failed with "port already in use" while the health check reported no scsynth --
# because the check matched the same wrong pattern. A factory that looks stopped
# and is not is the same class of fault as a change that is configured and not
# running, which this project has now hit five times.
#
# start_loop.sh already had this right on its failure path (`pkill -x scsynth`).
# This makes it a first-class operation instead of three lines someone retypes.
#
# It STOPS. It does not delete, reset, or touch mutable/. Recovery is one
# command, which is the same refusal run_integrity.py makes.
#
#   sh tools/stop_factory.sh              # stop, verify, report
#   SCPORT=57111 sh tools/stop_factory.sh # a second instance on another port
set -u

SCPORT="${SCPORT:-57110}"
HERE=$(cd "$(dirname "$0")" && pwd)

echo "=== stopping the factory on port $SCPORT ==="

# ORDER MATTERS. caffeinate wraps sclang, so killing sclang first leaves
# caffeinate parented to nothing and holding a wake assertion. Kill the wrapper,
# then the language, then the server: outside in.
for pat in "caffeinate.*sclang" "_live.scd" "MacOS/sclang"; do
    pids=$(pgrep -f "$pat" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "  TERM $pat: $pids"
        pkill -f "$pat" 2>/dev/null || true
    fi
done
sleep 2

# scsynth by EXACT NAME, which is the line the 16 Sept stop was missing.
if pgrep -x scsynth >/dev/null 2>&1; then
    echo "  TERM scsynth: $(pgrep -x scsynth | tr '\n' ' ')"
    pkill -x scsynth 2>/dev/null || true
    sleep 3
fi
if pgrep -x scsynth >/dev/null 2>&1; then
    echo "  still up after TERM; sending KILL"
    pkill -9 -x scsynth 2>/dev/null || true
    sleep 2
fi

# The ingest daemon is deliberately NOT stopped by default: it consumes segments
# the factory already wrote and stopping it mid-file loses that file's admission.
# --all includes it, for a full teardown.
if [ "${1:-}" = "--all" ]; then
    if pgrep -f self_ingest.py >/dev/null 2>&1; then
        echo "  TERM self_ingest.py: $(pgrep -f self_ingest.py | tr '\n' ' ')"
        pkill -f self_ingest.py 2>/dev/null || true
        sleep 1
    fi
fi

echo
echo "=== verify ==="
fail=0

for name in "MacOS/sclang" "_live.scd" "caffeinate.*sclang"; do
    n=$(pgrep -f "$name" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -eq 0 ]; then echo "  ok    $name down"
    else echo "  FAIL  $name still up ($n)"; fail=1; fi
done

n=$(pgrep -x scsynth 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" -eq 0 ]; then echo "  ok    scsynth down"
else
    echo "  FAIL  scsynth still up ($n) -- may be WEDGED"
    echo "        A wedged scsynth (state U*, uninterruptible) survives SIGKILL"
    echo "        and needs a reboot. start_loop.sh detects this at boot."
    fail=1
fi

# THE PORT IS THE REAL TEST. A process can be gone and the socket still held, and
# the port is what the next start actually collides with.
holders=$(lsof -nP -i "UDP:$SCPORT" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
if [ "$holders" -eq 0 ]; then echo "  ok    UDP $SCPORT free"
else
    echo "  FAIL  UDP $SCPORT still held:"
    lsof -nP -i "UDP:$SCPORT" 2>/dev/null | tail -n +2 | sed 's/^/          /'
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "STOPPED CLEANLY. mutable/, the corpora and every log are untouched."
    exit 0
fi
echo "STOP INCOMPLETE -- do not start again until this is clear."
exit 1
