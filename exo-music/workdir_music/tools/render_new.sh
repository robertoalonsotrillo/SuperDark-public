#!/bin/sh
# Re-render the baseline with the run-39 fixes, then render each new machine
# forced across every window so the four categories can be heard in isolation.
set -e
R=/work
cat > $R/tools/sclang_conf.yaml <<CONF
includePaths:
  - $R/lib
  - $R/behaviour
excludePaths:
  - /root/.local/share/SuperCollider/Extensions
excludeDefaultPaths: false
postInlineWarnings: false
CONF

# 1. new baseline, parallel voicing, 90 s
sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/base90_v39.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_b.scd
echo "--- base90_v39"
timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_b.scd < /dev/null 2>&1 \
  | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|STAGE ASSERTION|ERROR' || true

# 2. each new machine forced, 45 s, sequential renderer
for M in dr pu hm me; do
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/m_$M.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_m.scd
  echo "--- m_$M"
  timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_m.scd < /dev/null 2>&1 \
    | grep -E 'PATTERNS|SCORE_ENTRIES|RENDER_OK|STAGE ASSERTION|ERROR' || true
done
echo ALL_RENDERS_DONE
