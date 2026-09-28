#!/bin/sh
# Tests whether gp/bu are silenced by Archon or by this renderer's playgran
# SynthDef. The suspect is `levelScale: amp` on the FILTER envelope, which
# multiplies a frequency by an amplitude: at amp 0.03 the BPF sits 30x below
# its intended centre and removes nearly everything.
set -e
R=/work
for M in gp bu; do
  # control: renderer as written
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/pg_${M}_ctl.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      $R/tools/render_machine.scd > $R/renders/_g1.scd
  timeout 600 sclang -l $R/tools/sclang_conf.yaml $R/renders/_g1.scd < /dev/null >/dev/null 2>&1 || true
  # patched: drop levelScale from the filter envelope only
  sed -e "s|SEEDVAL|${SEED:-20260819}|" -e "s|SKIPVAL|${SKIP:-0}|" -e "s|WORKDIR|\"$R\"|" -e "s|OUTWAV|\"$R/renders/pg_${M}_fix.wav\"|" \
      -e "s|MACHINE|\\\\$M|" -e "s|dur = 30.0|dur = 45.0|" \
      -e "s|Env(\[cutoff/2, cutoff, cutoff/2\],\[atk,rel\],\\\\sin,1), levelScale:amp)|Env([cutoff/2, cutoff, cutoff/2],[atk,rel],\\\\sin,1))|" \
      $R/tools/render_machine.scd > $R/renders/_g2.scd
  grep -c "levelScale:amp" $R/renders/_g2.scd || true
  timeout 600 sclang -l $R/tools/sclang_conf.yaml $R/renders/_g2.scd < /dev/null >/dev/null 2>&1 || true
  echo "$M done"
done
echo PLAYGRAN_TEST_DONE
