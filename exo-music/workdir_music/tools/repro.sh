#!/bin/sh
set -e
R=/work
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/repro.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_r.scd
timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_r.scd < /dev/null 2>&1 \
  | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|ERROR' || true
# and one with a different opening
sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|180|" -e "s|WORKDIR|\"$R\"|" \
    -e "s|OUTWAV|\"$R/renders/skip180.wav\"|" \
    $R/tools/render_parallel.scd > $R/renders/_s.scd
timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_s.scd < /dev/null 2>&1 \
  | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|ERROR' || true
echo REPRO_DONE
