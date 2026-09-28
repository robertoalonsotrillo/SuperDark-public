#!/bin/sh
# Two steps, one call: judges writes the cell matrix, the operator reads it.
#
# version_operator needs a .npy of judge-score profiles that only judges.py can
# produce, so it cannot be a single command in measures.json. The cells go in
# the ARM'S OWN bundle directory rather than /tmp, because two arms running
# minutes apart would otherwise overwrite each other's cells and the second
# would silently score the first's chain.
#
#   run_version_operator.sh <window-log> <dest-dir>
set -u
LOG=${1:?window log}
DEST=${2:?destination directory}
HERE=$(cd "$(dirname "$0")" && pwd)
EM=$(dirname "$HERE")
PY=${PY:-/opt/homebrew/bin/python3}
[ -x "$PY" ] || PY=$(command -v python3)

CELLS="$DEST/judge_cells.npy"
"$PY" "$EM/tools/judges.py" --log "$LOG" --cells "$CELLS" \
      --cell-source judges >/dev/null 2>&1 || {
    echo "  judges could not build cells for this arm (too short?)" >&2
    exit 1
}
[ -f "$CELLS" ] || { echo "  no cell matrix written" >&2; exit 1; }
exec "$PY" "$EM/tools/version_operator.py" --cells "$CELLS"
