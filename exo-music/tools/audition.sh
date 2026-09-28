#!/bin/sh
# Render written machines offline so they can be heard before selection picks
# them. 22 Sept 2026, B9.
#
#   sh tools/audition.sh <machine name or .scd path> [more...]
#   sh tools/audition.sh --since "2026-09-22 12:00"     # every machine written since
#
# Output: $OUTDIR/<name>.wav (30 s, 44.1 kHz, the live SynthDefs, the three
# returns at fx_depth 1.0, master gain 4.0, the first 24 grains of
# grains_lic_ev). The live factory is not touched: this is non-real-time.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
OUTDIR="${OUTDIR:-/Volumes/FMA/superdark/renders/audition}"
SCLANG="${SCLANG:-/Applications/SuperCollider.app/Contents/MacOS/sclang}"
GRAINS="${GRAINS:-$W/grains_lic_ev}"
# the class path: the live factory's own (rebuilt from lib/ at every boot), so
# the render sees the classes the factory runs; /tmp/sctest.yaml is the test
# harness's and does not survive a reboot
SCCONF="${SCCONF:-$W/tools/live_conf.yaml}"
mkdir -p "$OUTDIR" /tmp/audition

# 1. the live SynthDefs, lifted from live_factory.scd (tokens substituted the
#    way run_live.sh does), assigned to ~sd_<name> so the score can send them
sed -e 's|MACRODIR|"/x"|' -e 's|MIDDIR|"/x"|' -e 's|MUTABLEDIR|"mutable"|' -e 's|SCPORT|57120|g' \
    -e 's|OUTDEVICE|server.options.device = nil;|' -e 's|WORKDIR|"/x"|' -e 's|GRAINDIR|"/x"|' -e 's|NGRAINS|100|' \
    "$W/tools/live_factory.scd" > /tmp/audition/lf.scd
python3 - <<'EOF'
s=open('/tmp/audition/lf.scd').read()
out=[]
for name in ('playback','playbackFX','playbackHP','playbackHPFX','playgran','fxReturn','master'):
    i=s.find('SynthDef(\\'+name+','); j=s.index('{',i); depth=0
    for k in range(j,len(s)):
        if s[k]=='{': depth+=1
        elif s[k]=='}':
            depth-=1
            if depth==0: break
    end=s.index('.add;',k)+5
    b=s[i:end]
    b='~sd_'+name+' = '+b[:-len('.add;')]+';'
    out.append(b)
open('/tmp/audition/defs.scd','w').write('\n\n'.join(out)+'\n')
EOF

# 2. which machines
if [ "${1:-}" = "--since" ]; then
    LIST=$(find "$W/mutable/machines" -name '*.scd' -newermt "$2" | sort)
else
    LIST=""
    for m in "$@"; do
        case "$m" in
            */*) LIST="$LIST $m" ;;
            *)   LIST="$LIST $W/mutable/machines/${m%.scd}.scd" ;;
        esac
    done
fi
[ -z "$LIST" ] && { echo "nothing to render"; exit 1; }

# 3. render each
for M in $LIST; do
    NAME=$(basename "$M" .scd)
    OUT="$OUTDIR/$NAME.wav"
    sed -e "s|MACHINEPATH|\"$M\"|" -e "s|OUTWAV|\"$OUT\"|" \
        -e "s|DEFSPATH|\"/tmp/audition/defs.scd\"|" -e "s|GRAINDIR|\"$GRAINS\"|" \
        "$ROOT/tools/audition_machine.scd" > "/tmp/audition/$NAME.scd"
    printf "%s ... " "$NAME"
    timeout 240 "$SCLANG" -l "$SCCONF" "/tmp/audition/$NAME.scd" < /dev/null > "/tmp/audition/$NAME.out" 2>&1
    if grep -q RENDER_OK "/tmp/audition/$NAME.out" && [ -s "$OUT" ]; then
        echo "ok  $(du -h "$OUT" | cut -f1)  $OUT"
    else
        echo "FAILED (see /tmp/audition/$NAME.out)"; grep -E "ERROR|AUDITION" "/tmp/audition/$NAME.out" | head -3
    fi
done
