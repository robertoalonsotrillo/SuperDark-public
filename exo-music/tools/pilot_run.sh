#!/bin/sh
# A bounded PILOT of the closed loop. Not the twenty-generation test.
#
# WHY A PILOT AND NOT THE REAL THING
# corpus_generation() sets a new grain's generation to 1 + w * mean(pool), whose
# fixed point is 1/(1-w). So generation 20 is unreachable below w = 0.95 and, in
# finite time, needs w = 1.0. At the measured turnover the full test is about
# three and a half days of UNINTERRUPTED running -- which a laptop cannot give
# (the sleep event of 28 Aug invalidated 85% of an 8-hour run) and a VPS can.
# This run is therefore scoped to answer three narrower questions:
#
#   1. does the closed loop run for hours without stalling, wedging or drifting
#      into silence?
#   2. what is the ACTUAL turnover rate? Everything above rests on a 4%-per-
#      capture estimate taken from one reading, and the schedule for the real
#      run depends on it.
#   3. does consecutive-generation similarity move at all, and in which
#      direction?
#
# It does NOT test the pre-registered target and must not be reported as if it
# did. Its output is a rate and a stability record.
#
# WEIGHT 1.0. Chosen so generation can advance at all; at 0.25 the corpus
# asymptotes at generation 1.33 and six hours would show nothing. The archive
# becomes a seed that is never played, which is the strongest reading of a
# closed loop and also the one most likely to degrade audibly. The charter is
# scored every snapshot precisely so that degradation is caught by a criterion
# rather than by taste.
#
#   HOURS=6 sh tools/pilot_run.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
POOL=/Volumes/FMA/superdark/self_corpus
ARCHIVE=/Volumes/FMA/superdark/archive
OUT="$W/pilot_$(date +%Y%m%d_%H%M)"
HOURS="${HOURS:-6}"
EVERY="${EVERY:-1800}"          # snapshot twice an hour
WEIGHT="${WEIGHT:-1.0}"

mkdir -p "$OUT"
echo "=== pilot: ${HOURS}h at weight $WEIGHT, snapshots every $((EVERY/60)) min ==="
echo "    -> $OUT"

snapshot () {
  T=$1
  python3 - "$POOL" "$T" "$OUT" <<'PYEOF'
import json, glob, os, sys, time
pool, t, out = sys.argv[1], sys.argv[2], sys.argv[3]
row = {"t_min": float(t), "wall": time.time(), "layers": {}}
for d in sorted(glob.glob(os.path.join(pool, "grains_pool_*"))):
    if "lineage" in d:
        continue
    m = json.load(open(os.path.join(d, "manifest.json")))
    g = [e.get("gen", 0.0) for e in m["manifest"]]
    row["layers"][os.path.basename(d)] = {
        "grains": len(g), "admitted": m.get("admitted", 0),
        "self_material": sum(1 for x in g if x > 0),
        "mean_gen": sum(g) / max(len(g), 1),
        "max_gen": max(g) if g else 0.0,
    }
with open(os.path.join(out, "snapshots.jsonl"), "a") as f:
    f.write(json.dumps(row) + "\n")
ev = row["layers"].get("grains_pool_ev", {})
print(f"    t+{float(t):5.0f}min  ev: admitted {ev.get('admitted',0)} "
      f"self {ev.get('self_material',0)}/{ev.get('grains',0)} "
      f"mean gen {ev.get('mean_gen',0):.3f}")
PYEOF
  # the charter is the only criterion that can fail, so record it every time
  L=$(ls -t "$W"/renders/live_*.log 2>/dev/null | head -1)
  if [ -n "$L" ]; then
    python3 "$ROOT/tools/score_charter.py" --log "$L" \
      --charter "$W/mutable/charter.json" > "$OUT/charter_t${T}.txt" 2>&1 || true
    grep -E "FAIL|SCRAPPING|DEPARTURE" "$OUT/charter_t${T}.txt" 2>/dev/null \
      | sed 's/^/      charter: /' || echo "      charter: all metrics pass"
  fi
  # STALL AND SLEEP GUARD. A stalled factory and a sleeping laptop both look
  # like "no new windows"; both invalidated earlier runs and neither raised an
  # error at the time.
  if [ -n "$L" ]; then wc -l < "$L" | sed 's/^/      window log lines: /'; fi
}

echo
echo "  weight -> $WEIGHT"
python3 - "$W/mutable/policy.json" "$WEIGHT" <<'PYEOF'
import json, sys
p, w = sys.argv[1], sys.argv[2]
d = json.load(open(p)); d["self_ingest_weight"] = w
json.dump(d, open(p, "w"), indent=1)
PYEOF

echo "  reassembling the play corpus at weight $WEIGHT"
for L in ev mid macro; do
  python3 "$ROOT/tools/assemble_play_corpus.py" \
    --archive "$W/grains_lic_$L" --pool "$POOL/grains_pool_$L" \
    --weight "$WEIGHT" --out "$W/grains_play_$L" | sed 's/^/    /'
done
# CHECK THE EXIT STATUS, DO NOT PIPE IT AWAY.
# The first version ended this line with `| tail -2 | sed ...`, which makes the
# pipeline's status that of sed. verify_alignment reported MISALIGNMENT, exited
# 1, `set -e` saw 0 from the pipe, and the factory started anyway on a corpus
# the guard had just rejected. Same shape as the `.try` that hid the broken
# capture rotation: a check that reports and cannot stop anything.
if python3 "$ROOT/tools/verify_alignment.py" --root "$W" \
     --corpora grains_play_ev,grains_play_mid,grains_play_macro > "$OUT/alignment.txt" 2>&1; then
  tail -2 "$OUT/alignment.txt" | sed 's/^/    /'
else
  echo "  ALIGNMENT FAILED -- not starting the factory. See $OUT/alignment.txt"
  cat "$OUT/alignment.txt" | sed 's/^/    /'
  exit 1
fi
# The pool is a different case: its admitted grains are described through the
# frozen basis, so 0.999 is the wrong bar. diagnose_pool_alignment splits the
# correlation by generation, which is the check that distinguishes a permutation
# from ordinary projection error.
python3 "$ROOT/tools/diagnose_pool_alignment.py" 2>&1 | sed -n '3,8p' | sed 's/^/    /'

echo
echo "  restarting the factory on the reassembled corpus"
pkill -9 -f caffeinate 2>/dev/null || true
pkill -9 -f "MacOS/sclang" 2>/dev/null || true
sleep 3
pkill -9 scsynth 2>/dev/null || true
sleep 4
cd "$W"
# BlackHole, not VB-Cable: after the 31 Aug reboot VB-Cable produced 74 failed
# registrations where BlackHole produced none.
# USE $SCPORT. This line hardcoded 57110 while the variable above defaulted to
# it, so overriding SCPORT on the command line changed nothing and the factory
# refused to start against the wedged scsynth that has held 57110 since the
# reboot. The failure was quiet: run_live.sh printed its refusal into
# factory.log and the pilot went on snapshotting a pool nothing was feeding.
nohup env SCPORT="$SCPORT" SC_HWBUF="${SC_HWBUF:-512}" SC_OUTCH="${SC_OUTCH:-2}" \
  OUTDEV="$OUTDEV" INDEV="$INDEV" \
  GRAINS=grains_play_ev MID=grains_play_mid MACRO=grains_play_macro N=2400 \
  sh tools/run_live.sh > "$OUT/factory.log" 2>&1 &
sleep 200
# ASSERT THE FACTORY ACTUALLY STARTED. run_live.sh refuses on a port clash and
# says so in factory.log; without this check the pilot happily snapshots a pool
# that nothing is feeding for six hours and reports generation 0 throughout.
if grep -q "already in use" "$OUT/factory.log" 2>/dev/null; then
  echo "  FACTORY REFUSED TO START (port $SCPORT in use). Pilot aborted."
  grep "already in use" -A2 "$OUT/factory.log" | sed 's/^/    /'
  exit 1
fi
if ! pgrep -f "MacOS/sclang" >/dev/null; then
  echo "  FACTORY NOT RUNNING after 200s. Pilot aborted; see $OUT/factory.log"
  tail -5 "$OUT/factory.log" | sed 's/^/    /'
  exit 1
fi
# Read the WINDOW LOG, not stdout. sclang's postln is block-buffered when
# redirected while scsynth writes unbuffered stderr, so an absence of progress
# lines on stdout says nothing at all -- a misreading that cost half an hour.
L=$(ls -t renders/live_*.log | head -1)
echo "    window log $(wc -c < "$L") bytes after 200s"

echo
echo "=== ingest daemon and stream ==="
# The first version of this script restarted the factory and then snapshotted a
# pool that NOTHING WAS FEEDING: no ingest daemon, so captures piled up, no
# grain was ever admitted, and six hours of snapshots would all have read
# generation 0. The pilot's whole question is the turnover rate, so the thing
# producing turnover has to be started by the same script that measures it.
if ! pgrep -f self_ingest >/dev/null; then
  nohup python3 "$ROOT/tools/self_ingest.py" \
    --capture-dir /Volumes/FMA/superdark/capture --out-root "$POOL" \
    --basis-dir "$ARCHIVE" --policy-json "$W/mutable/policy.json" \
    --delete-captures > "$OUT/ingest.log" 2>&1 &
  sleep 6
fi
grep -E "sample rate" "$OUT/ingest.log" 2>/dev/null | head -1 | sed 's/^/    /'
echo "    ingest daemon: $(pgrep -f self_ingest | wc -l | tr -d ' ') proc"

cd "$W/stream"
RH=$(grep "^RELAY_HOST=" .stream_secrets | cut -d= -f2- | tr -d "\"'")
if ! pgrep -f "ffmpeg.*BlackHole" >/dev/null; then
  ICECAST_REMOTE=1 RELAY_HOST="$RH" sh run_stream.sh tunnel >/dev/null 2>&1 || true
  ICECAST_REMOTE=1 RELAY_HOST="$RH" INDEV="BlackHole 2ch" \
    sh run_stream.sh start >/dev/null 2>&1 || true
  sleep 15
fi
ICECAST_REMOTE=1 RELAY_HOST="$RH" sh run_stream.sh status 2>&1 | sed 's/^/    /'
cd "$W"

echo
N=$(( HOURS * 3600 / EVERY ))
i=1
while [ "$i" -le "$N" ]; do
  sleep "$EVERY"
  snapshot $(( i * EVERY / 60 ))
  i=$(( i + 1 ))
done

echo
echo "=== pilot complete ==="
python3 "$ROOT/tools/generation_drift.py" --ring "$POOL" > "$OUT/drift_final.txt" 2>&1 || true
tail -12 "$OUT/drift_final.txt" | sed 's/^/  /'
echo
echo "  snapshots: $OUT/snapshots.jsonl"
echo "  REMEMBER: this is a pilot. It does not test the twenty-generation"
echo "  target, which needs weight ~1.0 and about 3.5 days uninterrupted."
