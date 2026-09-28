#!/bin/sh
R=/work; N=$1; D=$2
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|NGRAINS|$N|" \
    -e "s|GRAINDIR|\"$D\"|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/ladder_$N.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_r$N.scd
timeout 1800 sclang -l $R/tools/sclang_conf.yaml $R/renders/_r$N.scd < /dev/null 2>&1 \
  | grep -E 'PATTERNS|SCORE_ENTRIES|RENDER_OK|ERROR|FAILURE' || true
