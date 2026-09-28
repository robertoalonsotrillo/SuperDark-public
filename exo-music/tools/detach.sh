#!/bin/sh
# Run a command in its OWN SESSION, so it outlives whatever launched it.
#
# 24 Sept 2026. The factory, the splitter, the tunnel and the integrity
# watcher all died at 17:24:02, the second the Claude desktop app restarted:
# every one of them had been started from a shell the app owned, and the app
# took its process tree with it. scsynth handles the termination as a clean
# quit, which is the "exited with exit code 0, no crash report" signature of
# 23 Sept 23:35 (#116) as well. nohup is not enough: it ignores SIGHUP and
# nothing else.
#
#   sh tools/detach.sh sh tools/start_loop.sh
#   sh tools/detach.sh python3 tools/run_integrity.py --watch
#
# stdout/stderr go to $DETACH_LOG (default /tmp/detach_<basename>.out).
# Everything the command starts inherits the new session, so one wrapper
# around start_loop.sh covers the splitter and the tunnel it brings up.
set -u
[ $# -ge 1 ] || { echo "usage: sh tools/detach.sh <command...>"; exit 2; }
PY="$(command -v /opt/homebrew/bin/python3 || command -v python3)"
LOG="${DETACH_LOG:-/tmp/detach_$(basename "$1" .sh)_$(date +%H%M%S).out}"
DETACH_LOG_PATH="$LOG" "$PY" - "$@" <<'EOF'
import os, sys, subprocess
log = open(os.environ["DETACH_LOG_PATH"], "ab")
p = subprocess.Popen(sys.argv[1:], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                     start_new_session=True, cwd=os.getcwd())
print("detached pid %d session %d -> %s" % (p.pid, os.getsid(p.pid), os.environ["DETACH_LOG_PATH"]))
EOF
