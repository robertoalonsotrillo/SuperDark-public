#!/bin/sh
# Resume after the Mac died, 27 Sept 2026. Commit, boot, watch, trial.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$(pwd)
exec > /tmp/resume_260927.out 2>&1
echo "== commit"
cd .. && git add exo-music/tools/trial_sources.scd exo-music/tools/trial_propose.py exo-music/tools/decide_source_proposal.py \
  exo-music/tools/source_evidence.py exo-music/tools/resume_260927.sh exo-music/workdir_music/lib/SynthGrammar.sc \
  exo-music/workdir_music/tools/live_factory.scd && \
  git commit -q -m "B8 rung 3 (second half): catalogue of four candidate sources (pluck, formant, fm, freeze), offline trial, source_add proposals; evidence reads the source name from the def; seventh knob and adopted sources at this boot" && \
  git push -q origin main; git log --oneline -1; cd "$R"
echo "== boot"
pkill -f 'run_integrity.py --watch'; sh tools/stop_factory.sh 2>&1 | tail -1; sleep 3
: > /tmp/factory.log
ALIGN_OVERRIDE="Roberto 26 Sept 20:55 (reused 27 Sept after the Mac died, if identical: macro 4 of 45), see .lab/measurements/2026-09-26_alignment_override.md" \
  INDEV="BlackHole 2ch" sh tools/start_loop.sh 2>&1 | tail -1
n=0; while [ $n -lt 60 ]; do sleep 10; n=$((n+1)); L=$(ls -t workdir_music/renders/live_*.log 2>/dev/null | head -1); \
  [ -n "$L" ] && [ "$(grep -c '^COUPLE' "$L")" -ge 3 ] && [ "$L" -nt tools/resume_260927.sh ] && break; done
echo "log $L windows $(grep -c '^COUPLE' "$L")"
DETACH_LOG=/tmp/run_integrity.out sh tools/detach.sh python3 tools/run_integrity.py --watch >/dev/null
echo "== trial"
sclang=/Applications/SuperCollider.app/Contents/MacOS/sclang
timeout 1500 $sclang -l workdir_music/tools/live_conf.yaml tools/trial_sources.scd > /tmp/trial_sources.out 2>&1
grep -E '^\s+(pluck|formant|fm|freeze)|TRIAL' /tmp/trial_sources.out
echo "== propose"
python3 tools/trial_propose.py
echo "RESUME DONE"
