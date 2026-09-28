#!/bin/sh
set -e
R=/work
for M in gp bu; do
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/pg_${M}_fix.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine_pgfix.scd > $R/renders/_g.scd
  timeout 600 sclang -l $R/tools/sclang_conf.yaml $R/renders/_g.scd < /dev/null 2>&1 | grep -E 'SCORE_ENTRIES|RENDER_OK|ERROR' | tr '\n' ' '
  echo " <- $M"
done
echo PG2_DONE
