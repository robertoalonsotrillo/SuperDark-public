#!/bin/sh
set -e
R=/work
# 90 s full render with the envelopes moving
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/envfix90.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_e.scd
echo "--- envfix90"
timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_e.scd < /dev/null 2>&1 \
  | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|ERROR' || true
# per-machine census again
for M in sc lu so ma cr te ry an hp st ht gl cp wa gp bu dr pu hm me; do
  sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
      -e "s|OUTWAV|\"$R/renders/e_$M.wav\"|" -e "s|MACHINE|\\\\$M|" \
      -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_em.scd
  timeout 600 sclang -l $R/tools/sclang_conf.yaml $R/renders/_em.scd < /dev/null 2>&1 \
    | grep -cE 'RENDER_OK' >/dev/null || true
  echo "$M done"
done
echo RUN44_DONE
