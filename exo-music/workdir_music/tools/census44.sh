#!/bin/sh
R=/work
for M in sc lu so ma cr te ry an hp st ht gl cp wa gp bu dr pu hm me; do
  sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
      -e "s|OUTWAV|\"$R/renders/e_$M.wav\"|" -e "s|MACHINE|\\\\$M|" \
      -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_c44.scd
  S=$(date +%s)
  OUT=$(timeout 120 sclang -l $R/tools/sclang_conf.yaml $R/renders/_c44.scd < /dev/null 2>&1 | grep -E 'SCORE_ENTRIES|RENDER_OK|ERROR' | tr '\n' ' ')
  echo "$M  $(( $(date +%s) - S ))s  $OUT"
done
echo CENSUS44_DONE
