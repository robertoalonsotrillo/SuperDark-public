#!/bin/sh
# Score an A-B-A-C-A-D sequence that run_n_arms.sh produced.
#
#   sh tools/score_n_arms.sh harness/n_arms_YYMMDD_HHMMSS.json
#
# Pairs, all from one log, all disjoint by construction:
#   candidate pairs  A1-C1, A2-C2, A3-C3   intent=promotion, one knob each
#   null pairs       A1-A2, A2-A3          intent=null, zero changes
#
# Every pair goes through eval_rig run / compare / gate exactly as a two-arm
# comparison does, so its bundle is indistinguishable in form from comparisons
# 1-3 and can be pooled with them. Refuses anything not COMPLETE, and refuses a
# bundle older than its own start (the 18 Sept lesson: eval_rig failing produces
# no bundle, and the newest existing one is somebody else's run).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$(command -v /opt/homebrew/bin/python3 || command -v python3)"
cd "$ROOT" || exit 1

# Only one scorer at a time. Two concurrent scorers share the /tmp logs and,
# worse, each one's bundle-detection sees the other's output. Observed 18 Sept:
# a first invocation survived a client-side read timeout, a second was started
# on top of it, and the second reported "compare produced no bundle" for a
# comparison that had in fact been written -- by the first.
LOCK="$ROOT/harness/.score_n_arms.lock"
mkdir "$LOCK" 2>/dev/null || {
  echo "REFUSED: another score_n_arms.sh holds $LOCK"
  echo "  If no scorer is running (pgrep -fl score_n_arms), remove it by hand."
  exit 3; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

STATE="${1:-$(ls -t harness/n_arms_*.json 2>/dev/null | head -1)}"
[ -n "$STATE" ] && [ -f "$STATE" ] || { echo "no state file"; exit 2; }
echo "=== $(basename "$STATE") ==="

STATUS=$("$PY" -c "import json;print(json.load(open('$STATE'))['status'])")
echo "  status: $STATUS"
case "$STATUS" in COMPLETE) ;; *) echo "  NOT COMPLETE -- refusing."; exit 1 ;; esac
LOG=$("$PY" -c "import json;print(json.load(open('$STATE'))['log'])")
cp "workdir_music/renders/$LOG" /Volumes/FMA/superdark/renders/ 2>/dev/null

echo; echo "=== seal ==="
"$PY" tools/seal_rig.py verify || { echo "  SEAL BROKEN. Adopt first."; exit 1; }

# enumerate pairs: one line each  CH_LABEL CA_LABEL INTENT
PAIRS=$("$PY" - "$STATE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1])); arms = d["arms"]
A = [a for a in arms if a["knob"] is None]
for a in arms:
    if a["knob"] is not None:
        # champion is the A immediately before this candidate
        prev = [x for x in arms[:arms.index(a)] if x["knob"] is None][-1]
        print(prev["label"], a["label"], "promotion")
for x, y in zip(A, A[1:]):
    print(x["label"], y["label"], "null")
PYEOF
)

score_arm() {   # score_arm LABEL ARMROLE INTENT -> bundle path
  lab=$1; role=$2; intent=$3
  eval "$("$PY" - "$STATE" "$lab" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
a = [x for x in d["arms"] if x["label"] == sys.argv[2]][0]
print(f'F={a["from"]};T={a["to"]};S={a["since"]};U={a["until"]};CK="{a["checkpoint"]}"')
PYEOF
)"
  T0=$(mktemp /tmp/score_stamp.XXXXXX)
  ./tools/eval_rig.sh run --checkpoint "$CK" --policy superdark_release@1 \
    --arm "$role" --intent "$intent" --log "$LOG" \
    --win-from "$F" --win-to "$T" --since "$S" --until "$U" >"/tmp/s_$lab.$$.log" 2>&1 </dev/null
  B=$(find harness/runs -maxdepth 1 -name "run_*$role" -newer "$T0" | sort | tail -1)
  rm -f "$T0"
  [ -n "$B" ] || { echo "  eval_rig produced NO bundle for $lab:"; tail -4 "/tmp/s_$lab.$$.log" | sed 's/^/    /'; exit 1; }
  echo "$B"
}

# The loop reads from a file, not a pipe. In a pipe it runs in a subshell, so
# `exit 1` on a failed pair killed only the loop and the script still exited 0 --
# a scoring failure that reported success.
PAIRFILE=$(mktemp /tmp/n_arms_pairs.XXXXXX)
printf '%s\n' "$PAIRS" > "$PAIRFILE"
trap 'rm -f "$PAIRFILE"; rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

while read -r CHL CAL INTENT; do
  [ -n "$CHL" ] || continue
  echo; echo "=== pair $CHL vs $CAL  ($INTENT) ==="
  CH=$(score_arm "$CHL" champion "$INTENT") || exit 1
  CA=$(score_arm "$CAL" candidate "$INTENT") || exit 1
  echo "  $(basename "$CH")  /  $(basename "$CA")"
  # </dev/null on every child in this loop: stdin IS the pair file, and ffmpeg
  # (run inside eval_run to concatenate an arm's audio) reads stdin for its
  # keypress interface. On 19 Sept it ate "A1 " from the next line and the
  # first null pair arrived as "A2 null". The three pairs before it were fine
  # only because they had no audio and ffmpeg never ran.
  ./tools/eval_rig.sh compare --candidate "$CA" --champion "$CH" >"/tmp/s_cmp.$$.log" 2>&1 </dev/null
  # Find the bundle BY IDENTITY -- its comparison.json must name both of the run
  # bundles just produced. Newest-wins has been wrong twice: on 18 Sept when
  # eval_rig failed and the newest existing bundle was the previous day's, and
  # again when a second scorer's bundle was newer than this pair's.
  CMP=$("$PY" - "$(basename "$CH")" "$(basename "$CA")" <<'PYEOF'
import glob, json, os, sys
ch, ca = sys.argv[1:3]
hits = []
for d in glob.glob("harness/runs/cmp_*"):
    p = os.path.join(d, "comparison.json")
    try:
        j = json.load(open(p))
    except Exception:
        continue
    if j.get("champion_run") == ch and j.get("candidate_run") == ca:
        hits.append((os.path.getmtime(p), d))
print(sorted(hits)[-1][1] if hits else "")
PYEOF
)
  [ -n "$CMP" ] || { echo "  compare produced no bundle naming $(basename "$CH") / $(basename "$CA"):"
                     tail -4 "/tmp/s_cmp.$$.log" | sed 's/^/    /'; exit 1; }
  ./tools/eval_rig.sh gate --comparison "$CMP" --policy superdark_release@1 </dev/null \
    | grep -E "one_change|run_not_cont|charter_not|VERDICT|veto:|unjudged:" | sed 's/^/  /'
  echo "  bundle: $(basename "$CMP")"
  "$PY" - "$CMP" "$CHL" "$CAL" "$INTENT" <<'PYEOF'
import json, sys, os
cmp, chl, cal, intent = sys.argv[1:5]
j = json.load(open(os.path.join(cmp, "comparison.json")))
j["_n_arms"] = {"champion_arm": chl, "candidate_arm": cal, "intent": intent}
json.dump(j, open(os.path.join(cmp, "comparison.json"), "w"), indent=1)
m = j["measures"]


def fmt(meas, key, spec):
    """A measure that produced no number has to say so. The f-string here assumed
    one, and raised TypeError AFTER the bundle was already written -- so a pair
    whose scoring had in fact succeeded ended in a traceback."""
    d = (meas or {}).get("delta") or {}
    v = d.get(key)
    if isinstance(v, (int, float)):
        return format(v, spec)
    cs = (meas or {}).get("candidate_status"); hs = (meas or {}).get("champion_status")
    bad = [f"{r} {s}" for r, s in (("champ", hs), ("cand", cs)) if s not in ("ok", None)]
    return "--(" + ("; ".join(bad) if bad else "no delta") + ")"


print("  sonic_variety " + fmt(m.get("sonic_variety"), "recurrence", "+.4f")
      + "   empirical dwell " + fmt(m.get("version_operator"), "empirical dwell", "+.2f"))
PYEOF
done < "$PAIRFILE"
