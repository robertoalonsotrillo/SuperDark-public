#!/bin/sh
R=/work; N=$1; D=$2; OUT=$3; DUR=${4:-20.0}
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|NGRAINS|$N|" \
    -e "s|GRAINDIR|\"$D\"|" -e "s|WORKDIR|\"$R\"|" -e "s|dur = 90.0|dur = $DUR|" \
    -e "s|OUTWAV|\"$R/renders/$OUT.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_s$OUT.scd
S=$(date +%s)
timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_s$OUT.scd < /dev/null 2>&1 > /tmp/o.txt
echo "$OUT  $(( $(date +%s) - S ))s"
grep -ac "duplicate node ID" /tmp/o.txt | sed 's/^/  duplicate node ID: /'
grep -aE "SCORE_ENTRIES|RENDER_OK|too many nodes" /tmp/o.txt | sort | uniq -c | head -4
