#!/bin/sh
# eval_rig.sh -- the boundary between the factory and the thing that judges it.
#
# WHY A BOUNDARY AT ALL
# Exo's continual-release proposal puts its evaluation behind eval.sh and says
# it "is not part of Exo", because an agent judged only by scores will eventually
# treat the scorer as one more thing it can modify. SuperDark cannot rewrite its
# own code, so that failure is not available to it. The failure available here is
# mine: changing a measure and reporting the new number against the old
# pre-registration. Everything behind this script is checked for that first.
#
# NOTHING HERE TOUCHES THE FACTORY. It reads logs, checkpoints and corpora. It
# never starts, stops or reconfigures anything. Recovery is a decision for a
# person, which is the same refusal run_integrity.py makes.
#
#   eval_rig.sh validate                      # rig is sane; runs nothing
#   eval_rig.sh schema                        # the JSON shapes, stable interface
#   eval_rig.sh run     --checkpoint <id> --policy superdark_release@1
#   eval_rig.sh compare --candidate <run> --champion <run>
#   eval_rig.sh gate    --comparison <path> --policy superdark_release@1
#
# EXIT CODES (from #201; a caller branches on these)
#   0  the evaluation completed, even if the factory scored badly
#   1  the rig itself broke
#   2  the invocation was wrong
#   3  gate completed and the verdict is not "promote"
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
EM=$(dirname "$HERE")
HARNESS="$EM/harness"
RUNS="$HARNESS/runs"
PY=${PY:-/opt/homebrew/bin/python3}
[ -x "$PY" ] || PY=$(command -v python3)

die()  { echo "$1" >&2; exit "${2:-2}"; }
have() { [ -f "$EM/$1" ]; }

cmd=${1:-}; [ -n "$cmd" ] || die "usage: eval_rig.sh {validate|schema|run|compare|gate}"
shift

# ---------------------------------------------------------------- validate ---
# Runs nothing and spends no compute. A broken rig should fail here, before
# anyone spends two hours of factory time finding out.
do_validate() {
    fail=0
    echo "=== seal ==="
    "$PY" "$EM/tools/seal_rig.py" verify || fail=1

    echo
    echo "=== registry ==="
    "$PY" "$EM/tools/measure_registry.py" status >/dev/null 2>&1 \
        || { echo "FAIL  measures.json does not parse"; fail=1; }
    n=$("$PY" - <<EOF
import json
r=json.load(open("$HARNESS/measures.json"))
print(len(r["measures"]))
EOF
)
    echo "ok    $n live measures, $("$PY" - <<EOF
import json
r=json.load(open("$HARNESS/measures.json"))
print(len(r.get("retired",{})))
EOF
) retired"

    echo
    echo "=== policy ==="
    "$PY" - <<EOF || fail=1
import json, sys
p = json.load(open("$HARNESS/release_policy.v1.json"))
need = ["hard_invariants","reasons_to_switch","margins","exceptions",
        "tripwires","sign_off","rollback","one_change_at_a_time"]
missing = [k for k in need if k not in p]
if missing:
    print("FAIL  policy missing:", ", ".join(missing)); sys.exit(1)
print(f"ok    {p['id']}@{p['version']}, "
      f"{len(p['hard_invariants']['checks'])} hard invariants, "
      f"{len(p['tripwires']['list'])} tripwires")
if p["margins"]["status"] == "UNSET":
    print("note  margins UNSET: the gate runs in shadow and promotes nothing")
EOF

    echo
    echo "=== checkpoints ==="
    "$PY" "$EM/tools/checkpoint.py" list 2>/dev/null | tail -5

    echo
    echo "=== tools present ==="
    for t in tools/checkpoint.py tools/seal_rig.py tools/measure_registry.py \
             tools/archive_guard.py tools/run_integrity.py tools/kernel_guard.py \
             tools/score_charter.py tools/sonic_variety.py tools/recurrence_sweep.py; do
        if have "$t"; then echo "ok    $t"; else echo "FAIL  $t missing"; fail=1; fi
    done

    echo
    [ "$fail" -eq 0 ] && echo "VALIDATE OK" || echo "VALIDATE FAILED"
    return "$fail"
}

# ------------------------------------------------------------------ schema ---
do_schema() {
    cat <<'EOF'
Every run writes a directory of plain files. The bundle is the source of truth:
no service needs to be running to inspect or replay a completed run.

  harness/runs/<run-id>/
    manifest.json     checkpoint, measures, policy id@version, window range
    results.json      the numbers each measure produced, and the seal hash
                      of the scorer that produced each one
    invariants.json   each hard invariant, pass/fail, and what was tested
    decisions.jsonl   gate inputs, verdict, human sign-off
    provenance.json   git head, corpus manifests, run logs, tool hashes

manifest.json
  { "run_id": str, "created": float, "checkpoint": str,
    "policy": "superdark_release@1", "arm": "champion"|"candidate",
    "log": str, "windows": [int, int], "warm_up_discarded": int,
    "measures": [str] }

results.json
  { "<measure>": { "value": any, "scorer": str, "scorer_sha256": str,
                   "frames_scored": int, "promote": bool, "veto": bool } }

invariants.json
  { "<key>": { "pass": bool, "test": str, "observed": str } }

decisions.jsonl   one object per line
  { "t": float, "event": "gate"|"sign_off"|"rollback",
    "verdict": "promote"|"retain"|"blocked"|"margins_unset",
    "why": str, "who": str }

Additive changes only. A field is never repurposed, because a bundle written
in September has to still mean what it said when it is read in November.
EOF
}

# --------------------------------------------------------------------- run ---
do_run() {
    ckpt=""; policy=""; log=""; arm="champion"; since=""; until_=""; winfrom=""; winto=""; intent=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --checkpoint) ckpt=$2; shift 2 ;;
            --policy)     policy=$2; shift 2 ;;
            --log)        log=$2; shift 2 ;;
            --arm)        arm=$2; shift 2 ;;
            --since)      since=$2; shift 2 ;;
            --until)      until_=$2; shift 2 ;;
            --win-from)   winfrom=$2; shift 2 ;;
            --win-to)     winto=$2; shift 2 ;;
            # 18 Sept 2026: added to eval_run.py for the null comparison and NOT
            # here. This wrapper rejected the flag, produced no bundle, and
            # score_two_arms then scored yesterday's arms as if they were today's.
            --intent)     intent=$2; shift 2 ;;
            *) die "unknown flag: $1" ;;
        esac
    done
    [ -n "$ckpt" ]   || die "--checkpoint is required"
    [ -n "$policy" ] || die "--policy is required"

    echo "verifying the seal before anything is measured" >&2
    "$PY" "$EM/tools/seal_rig.py" verify >&2 \
        || die "seal broken: no number produced now is attributable" 1
    "$PY" "$EM/tools/checkpoint.py" verify "$ckpt" >&2 \
        || die "checkpoint $ckpt does not verify" 1

    run_id="run_$(date +%y%m%d_%H%M%S)_${arm}"
    dest="$RUNS/$run_id"
    mkdir -p "$dest"
    PY="$PY" "$PY" "$EM/tools/eval_run.py" \
        --checkpoint "$ckpt" --policy "$policy" --arm "$arm" \
        --dest "$dest" ${log:+--log "$log"} ${since:+--since "$since"} ${until_:+--until "$until_"} \
        ${winfrom:+--win-from "$winfrom"} ${winto:+--win-to "$winto"} ${intent:+--intent "$intent"} \
        || die "rig broke during run" 1
    echo "$dest"
}

# ----------------------------------------------------------------- compare ---
do_compare() {
    cand=""; champ=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --candidate) cand=$2; shift 2 ;;
            --champion)  champ=$2; shift 2 ;;
            *) die "unknown flag: $1" ;;
        esac
    done
    # Roles are named flags on purpose. Silently swapping argument order would
    # flip the sign of every delta and the output would still look plausible.
    [ -n "$cand" ]  || die "--candidate is required"
    [ -n "$champ" ] || die "--champion is required"
    "$PY" "$EM/tools/eval_compare.py" --candidate "$cand" --champion "$champ" \
        || die "rig broke during compare" 1
}

# -------------------------------------------------------------------- gate ---
do_gate() {
    comp=""; policy=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --comparison) comp=$2; shift 2 ;;
            --policy)     policy=$2; shift 2 ;;
            *) die "unknown flag: $1" ;;
        esac
    done
    [ -n "$comp" ]   || die "--comparison is required"
    [ -n "$policy" ] || die "--policy is required"
    "$PY" "$EM/tools/eval_gate.py" --comparison "$comp" --policy "$policy"
    rc=$?
    # 0 promote, 3 anything else, 1 rig broke. Deterministic: same comparison
    # and same policy version give the same verdict, every time.
    exit $rc
}

case "$cmd" in
    validate) do_validate; exit $? ;;
    schema)   do_schema;   exit 0  ;;
    run)      do_run "$@";  exit $? ;;
    compare)  do_compare "$@"; exit $? ;;
    gate)     do_gate "$@" ;;
    *) die "unknown command: $cmd" ;;
esac
