#!/bin/sh
# Score a comparison that run_two_arms.sh produced. One command, no arguments.
#
# WHY THIS EXISTS
# run_two_arms.sh removed the need for a supervisor DURING the comparison. This
# removes it AFTER. Scoring by hand on the night of 16 September took six
# invocations and hit three pitfalls that are invisible unless you already know
# them:
#
#   - `gate --comparison` wants a DIRECTORY containing comparison.json, not the
#     JSON file, though the usage text pairs `compare` and `gate` as if they
#     composed. They do not.
#   - `ls -dt` is unreliable for finding the newest comparison, because running
#     eval_invariants against an older one touches its mtime and floats it back
#     to the top. The bundle has to be named explicitly.
#   - both arms need --since AND --until, or a champion's audio runs to the
#     present and swallows the candidate's segments.
#
# All three are handled here. The arm ranges and epochs come from the state file
# the runner wrote, so they cannot be mistyped.
#
#   sh tools/score_two_arms.sh                     # newest state file
#   sh tools/score_two_arms.sh harness/two_arms_260917_015453.json
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$(command -v /opt/homebrew/bin/python3 || command -v python3)"
cd "$ROOT" || exit 1

STATE="${1:-$(ls -t harness/two_arms_*.json 2>/dev/null | head -1)}"
[ -n "$STATE" ] && [ -f "$STATE" ] || { echo "no state file"; exit 2; }
echo "=== $(basename "$STATE") ==="

# A HEREDOC INSIDE COMMAND SUBSTITUTION SWALLOWS THE CLOSING PAREN.
# The first version did `eval "$("$PY" - "$STATE" <<'PYEOF' ... PYEOF )"` and
# STATUS came out as ")". It refused to score anyway -- but only because ")" is
# not "COMPLETE", which is luck rather than correctness, and luck of that kind
# is what lets a broken guard look like a working one. Python writes a
# sourceable file instead; nothing is parsed twice.
VARS=$(mktemp /tmp/two_arms_vars.XXXXXX)
"$PY" - "$STATE" "$VARS" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
c, k = d.get("champion") or {}, d.get("candidate") or {}
with open(sys.argv[2], "w") as f:
    f.write(f'STATUS="{d.get("status","")}"\n')
    f.write(f'LOG="{d.get("log","")}"\n')
    f.write(f'CF={c.get("from",0)}\nCT={c.get("to",0)}\n')
    f.write(f'CS={c.get("since",0)}\nCU={c.get("until",0) or 0}\n')
    f.write(f'DF={k.get("from",0)}\nDT={k.get("to",0)}\n')
    f.write(f'DS={k.get("since",0)}\nDU={k.get("until",0) or 0}\n')
    f.write(f'CCK="{c.get("checkpoint","")}"\nDCK="{k.get("checkpoint","")}"\n')
    f.write(f'INTENT="{d.get("intent","promotion")}"\n')
PYEOF
# shellcheck disable=SC1090
. "$VARS"
rm -f "$VARS"

echo "  status: $STATUS"
case "$STATUS" in
  COMPLETE) ;;
  *) echo "  NOT COMPLETE -- refusing to score a partial comparison."
     echo "  A short arm scored as though it were whole is worse than no number."
     exit 1 ;;
esac
echo "  champion  $CF-$CT   candidate $DF-$DT"

# The rig reads logs from the SSD renders directory.
cp "workdir_music/renders/$LOG" /Volumes/FMA/superdark/renders/ 2>/dev/null

echo
echo "=== seal, before anything is measured ==="
"$PY" tools/seal_rig.py verify || {
  echo "  SEAL BROKEN. Adopt the change with a reason, then re-run."
  echo "  No number produced now would be attributable."; exit 1; }

echo
# A STAMP OLDER THAN ANY BUNDLE THIS INVOCATION MAY ACCEPT. The header above
# already warned that `ls -dt` is unreliable; it named the wrong reason. The
# fatal case is eval_rig FAILING: it writes nothing, ls -dt returns the newest
# bundle that does exist, and a stale run is scored under today's name. That
# happened on 18 Sept when the wrapper rejected a flag it had not been taught.
T0=$(mktemp /tmp/score_stamp.XXXXXX)
echo "=== champion arm ==="
./tools/eval_rig.sh run --checkpoint "$CCK" --policy superdark_release@1 \
  --arm champion --intent "$INTENT" --log "$LOG" \
  --win-from "$CF" --win-to "$CT" --since "$CS" --until "$CU" >/tmp/s_ch.log 2>&1
CH=$(find harness/runs -maxdepth 1 -name 'run_*champion' -newer "$T0" | sort | tail -1)
[ -n "$CH" ] || {
  echo "  eval_rig produced NO champion bundle. Its output:"
  tail -5 /tmp/s_ch.log | sed 's/^/    /'
  echo "  Refusing to fall back to an older bundle: on 18 Sept that scored"
  echo "  yesterday's arms as today's and the gate reported a knob change in a"
  echo "  null. A stale bundle is worse than no bundle."; exit 1; }
grep -E ": ok|NOT WIRED|NO AUDIO|failed" /tmp/s_ch.log | sed 's/^/  /'
echo "  -> $(basename "$CH")"

echo
echo "=== candidate arm ==="
./tools/eval_rig.sh run --checkpoint "$DCK" --policy superdark_release@1 \
  --arm candidate --intent "$INTENT" --log "$LOG" \
  --win-from "$DF" --win-to "$DT" --since "$DS" --until "$DU" >/tmp/s_ca.log 2>&1
CA=$(find harness/runs -maxdepth 1 -name 'run_*candidate' -newer "$T0" | sort | tail -1)
[ -n "$CA" ] || {
  echo "  eval_rig produced NO candidate bundle. Its output:"
  tail -5 /tmp/s_ca.log | sed 's/^/    /'
  echo "  Refusing to fall back to an older bundle."; exit 1; }
grep -E ": ok|NOT WIRED|NO AUDIO|failed" /tmp/s_ca.log | sed 's/^/  /'
echo "  -> $(basename "$CA")"

echo
echo "=== compare ==="
# CAPTURE THE BUNDLE NAME FROM THE FILESYSTEM BEFORE ANYTHING ELSE TOUCHES IT.
BEFORE=$(ls -d harness/runs/cmp_* 2>/dev/null | wc -l)
./tools/eval_rig.sh compare --candidate "$CA" --champion "$CH" >/tmp/s_cmp.log 2>&1
CMP=$(ls -d harness/runs/cmp_* 2>/dev/null | tail -1)
AFTER=$(ls -d harness/runs/cmp_* 2>/dev/null | wc -l)
[ "$AFTER" -gt "$BEFORE" ] || { echo "  compare produced no new bundle"; exit 1; }
echo "  bundle: $(basename "$CMP")"
"$PY" - "$CMP" <<'PYEOF'
import json, sys, os
j = json.load(open(os.path.join(sys.argv[1], "comparison.json")))
print(f"  paired: {j['paired']}  --  {j.get('_paired','')}")
PYEOF

echo
echo "=== gate ==="
# THE DIRECTORY, NOT THE JSON.
./tools/eval_rig.sh gate --comparison "$CMP" --policy superdark_release@1
RC=$?
echo
echo "  comparison bundle: $CMP"
echo "  exit $RC  (0 promote, 3 anything else, 1 the rig broke)"
