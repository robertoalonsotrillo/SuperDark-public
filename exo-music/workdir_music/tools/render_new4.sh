#!/bin/sh
set -e
R=/work
for M in dr pu hm me; do
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/m_$M.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_n.scd
  echo "$M $(timeout 600 sclang -l $R/tools/sclang_conf.yaml $R/renders/_n.scd < /dev/null 2>&1 | grep -E 'SCORE_ENTRIES|RENDER_OK|ERROR' | tr '\n' ' ')"
done
echo GAIN_DONE
