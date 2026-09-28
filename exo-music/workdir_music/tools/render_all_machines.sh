#!/bin/sh
# Renders every machine in isolation at 45 s. This is the per-machine acoustic
# census run 35 attempted and could not complete (claim 166).
set -e
R=/work
for M in sc lu so ma cr te ry an hp st ht gl cp wa gp bu dr pu hm me; do
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/m_$M.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_a.scd
  R2=$(timeout 600 sclang -l $R/tools/sclang_conf.yaml $R/renders/_a.scd < /dev/null 2>&1 \
    | grep -E 'SCORE_ENTRIES|RENDER_OK|STAGE ASSERTION|ERROR' | tr '\n' ' ')
  echo "$M | $R2"
done
echo CENSUS_DONE
