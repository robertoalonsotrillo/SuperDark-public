#!/bin/sh
R=/work
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/v46.wav\"|" $R/tools/render_parallel.scd > $R/renders/_v46.scd
timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_v46.scd < /dev/null 2>&1 \
  | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|ERROR'
for M in cr; do sh $R/tools/render_one.sh $M f_$M; done
echo RUN46_DONE
