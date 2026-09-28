#!/bin/sh
# Renders the SAME configuration repeatedly. Any spread is nondeterminism in
# the renderer, and it is the noise floor under every A/B comparison made this
# week. thisThread.randSeed fixes sclang's RNG; it does not fix scsynth's, and
# HDVerb uses ExpRand/Rand while playgran uses LFNoise2.
set -e
R=/work
for i in 3 4 5; do
  sed -e "s|SEEDVAL|20260819|" -e "s|SKIPVAL|0|" -e "s|WORKDIR|\"$R\"|" \
      -e "s|OUTWAV|\"$R/renders/rep$i.wav\"|" \
      $R/tools/render_parallel.scd > $R/renders/_rep.scd
  timeout 900 sclang -l $R/tools/sclang_conf.yaml $R/renders/_rep.scd < /dev/null 2>&1 \
    | grep -E 'SCORE_ENTRIES|RENDER_OK|ERROR' | tr '\n' ' '
  echo " <- rep$i"
done
echo REPLICATES_DONE
