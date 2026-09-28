#!/bin/sh
R=/work; N=$1; D=$2; OUT=${3:-dup_$N}
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|NGRAINS|$N|" \
    -e "s|GRAINDIR|\"$D\"|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/$OUT.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_f$N.scd
timeout 2400 sclang -l $R/tools/sclang_conf.yaml $R/renders/_f$N.scd < /dev/null 2>&1 \
  | grep -aE 'SCORE_ENTRIES|RENDER_OK|duplicate node ID|too many nodes|FAILURE' \
  | sort | uniq -c | sort -rn | head -6
