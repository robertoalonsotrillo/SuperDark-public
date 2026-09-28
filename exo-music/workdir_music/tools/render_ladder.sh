#!/bin/sh
# The corpus ladder. Same events, same seed, same behaviour, same duration.
# The ONLY variable is how many grains the factory has to draw on.
#
# docs/06: corpus scale is the magnitude of auxiliary supply, and the open
# question is whether more of it expands readable space c or only b\c.
set -e
R=/work
for RUNG in 130:grains 60:grains_60 600:grains_600 6000:grains_6000; do
  N=${RUNG%%:*}; D=${RUNG##*:}
  sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|NGRAINS|$N|" \
      -e "s|GRAINDIR|\"$D\"|" -e "s|WORKDIR|\"$R\"|" \
      -e "s|OUTWAV|\"$R/renders/ladder_$N.wav\"|" \
      $R/tools/render_parallel.scd > $R/renders/_l.scd
  echo "--- rung $N ($D)"
  timeout 1200 sclang -l $R/tools/sclang_conf.yaml $R/renders/_l.scd < /dev/null 2>&1 \
    | grep -E 'TRANSITIONS|PATTERNS|SCORE_ENTRIES|RENDER_OK|STAGE ASSERTION|ERROR' || true
done
echo LADDER_DONE
