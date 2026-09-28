#!/bin/sh
set -e
R=/work
for M in sc cr an ht; do
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/m_$M.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_c$M.scd
  echo "--- m_$M"
  timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_c$M.scd < /dev/null 2>&1 \
    | grep -E 'PATTERNS|SCORE_ENTRIES|RENDER_OK|STAGE ASSERTION|ERROR' || true
done
echo CTL_DONE
