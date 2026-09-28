#!/bin/sh
# usage: render_one.sh <machine> <outname> [dur]
R=/work; M=$1; OUT=$2; D=${3:-45.0}
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/$OUT.wav\"|" -e "s|MACHINE|\\\\$M|" \
    -e "s|dur = 30.0|dur = $D|" \
    $R/tools/render_machine.scd > $R/renders/_one.scd
timeout 500 sclang -l $R/tools/sclang_conf.yaml $R/renders/_one.scd < /dev/null 2>&1 \
  | grep -E 'SCORE_ENTRIES|RENDER_OK|ERROR' | tr '\n' ' '
echo " <- $OUT"
