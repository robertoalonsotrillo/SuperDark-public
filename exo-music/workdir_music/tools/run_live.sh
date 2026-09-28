#!/bin/sh
# Runs the factory on the HOST (CoreAudio), not in Docker.
#
# The live class path is a COPY of lib/ and behaviour/, patched in three ways
# that apply only to live running. lib/Handler_Local.sc and the offline
# renderer are never touched.
set -e
# BARE python3 SUMMONS A DIALOG UNDER sh AND nohup. The PATH here is not the
# interactive one, so python3 resolves to /usr/bin/python3 -- Apple's stub, which
# pops "The python3 command requires the command line developer tools" on every
# call however many times they are installed. Name the interpreter instead.
PY="$(command -v /opt/homebrew/bin/python3 || command -v /usr/local/bin/python3 || command -v python3)"


# Two live sclangs cannot share scsynth: maxLogins is 1, and the second one
# loops on "already registered" forever without ever reaching the factory. That
# cost half an hour once. Refuse to start rather than produce that loop again.
# Processes stuck exiting (STAT contains E or Z) do not count: one such sclang,
# wedged in an uninterruptible CoreAudio call after the headphones disconnected,
# survived SIGKILL for the rest of the session while holding no port at all.
# PORT-AWARE, not global. The original guard refused to start if ANY sclang was
# running, which is right for the reason it was written -- two clients cannot
# share ONE scsynth, maxLogins is 1, and the second boot-loops on "already
# registered" for ever. But two factories on DIFFERENT SCPORTs have different
# servers and do not collide at all, and the global guard made P318's economy of
# factories impossible by construction. Refuse only on a genuine port clash.
CHECK_PORT="${SCPORT:-57110}"
if lsof -nP -iUDP:"$CHECK_PORT" >/dev/null 2>&1; then
  echo "port $CHECK_PORT is already in use; another factory or a wedged scsynth"
  echo "holds it. Pick a different SCPORT, or clear it."
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAINS="${GRAINS:-grains}"
N="${N:-130}"
SC="${SC:-/Applications/SuperCollider.app/Contents/MacOS/sclang}"
# THE CLASS DIRECTORY IS PER-FACTORY, and this is a safety fix, not tidiness.
# The next line is `rm -rf "$LIVE"`. With the path hardcoded, starting a SECOND
# factory deleted the class directory the FIRST one was built from -- which has
# already happened here once and produced "Could not open directory". A shadow
# instance exists precisely to run beside the live one, so it must not share
# this path with it. LIVECLASSES defaults to the live location, so the ordinary
# invocation is unchanged.
LIVE="${LIVECLASSES:-$ROOT/tools/live_classes}"

# ---- iCLOUD CONFLICT COPIES ARE DUPLICATE CLASS DEFINITIONS -----------------
#
# This directory sits on the iCloud-synced Desktop and this script REWRITES every
# class file in it at each boot. iCloud sees a file change it cannot reconcile
# and keeps a numbered copy beside the original, so a boot leaves
# "Handler_Local 2.sc" next to "Handler_Local.sc" -- byte-identical, and one more
# on every subsequent attempt.
#
# sclang compiles EVERY .sc in its class path. Twenty such copies had
# accumulated by 10 Sept, three each of BehaviorTrimmed, Handler_Local,
# MachineWriter, Methods_Local, PatternGrammar, Pkill_Local, ScBand,
# Simultaneity, Synths_Local and TransferOperator -- timestamped 23:55, 00:11 and
# 00:24, one per failed boot that night. Every class in the factory defined three
# times over.
#
# The proper fix is to move live_classes off the synced volume as the play
# corpora were, and that is worth doing. This is the guard that holds until then
# and afterwards: a copy is removed only when it is byte-identical to the file it
# shadows, so a real edit is never destroyed.
for dup in "$LIVE"/*\ [0-9]*.sc; do
  [ -f "$dup" ] || continue
  orig="$(echo "$dup" | sed 's/ [0-9]*\.sc$/.sc/')"
  if [ -f "$orig" ] && cmp -s "$dup" "$orig"; then
    rm -f "$dup"
    echo "  removed iCloud conflict copy $(basename "$dup")"
  else
    echo "  WARNING: $(basename "$dup") differs from its original and was KEPT."
    echo "  sclang will see a duplicate class definition. Resolve it by hand."
  fi
done

rm -rf "$LIVE"
mkdir -p "$LIVE"

# 1. ArchonCapture is EXCLUDED. It overrides Pkill.play to capture patterns
#    instead of playing them, which is right offline and makes the live
#    factory silent.
for f in "$ROOT"/lib/*.sc; do
  case "$(basename "$f")" in ArchonCapture.sc) continue ;; esac
  cp "$f" "$LIVE/"
done
cp "$ROOT"/behaviour/*.sc "$LIVE/"

# 2. The corpus-freeing cleanup is stripped. Every machine ends its Pkill with
#    { { buf.do { |b| b.free } }.defer(20) }, which is correct for Archon's
#    real flow where msg_handler loads fresh buffers per event. Here the corpus
#    is loaded ONCE, so the first machine to finish frees the whole thing and
#    everything after it is silent.
#    The delay is NOT always 20. Handler_Local.sc uses defer(20) fourteen
#    times but also defer(40), defer(60), defer(90) and defer(160). The first
#    version of this regex matched the literal 20, so six cleanups survived,
#    and the first machine to finish with one of those freed the whole corpus
#    partway through the run: audible for about three minutes, then silent for
#    ever. The delay is now \d+, and the count is ASSERTED afterwards so a
#    surviving cleanup fails the build instead of failing the music.
"$PY" - "$LIVE/Handler_Local.sc" <<'PYEOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
pat = re.compile(r"\{\s*\{\s*buf\.do\s*\{\s*\|b\|\s*b\.free;?\s*\}\s*\}\.defer\(\d+\);?\s*\}", re.S)
s2, n = pat.subn("{ }", s)
open(p, "w").write(s2)
left = s2.count("b.free")
print(f"  stripped {n} corpus-free cleanups, {left} remaining")
if left:
    sys.exit(f"  ABORT: {left} buffer-freeing cleanups survived; they would "
             f"silence the factory mid-run")
PYEOF

# 3. Pshuf -> Pseq. Every machine draws grains with Pshuf(buf, inf), which
#    SHUFFLES whatever array it is handed, so handing it an ordered path is
#    pointless. Pseq walks the array as given, so when the factory supplies a
#    nearest-neighbour PATH the machines follow it and consecutive grains are
#    adjacent in descriptor space. That is continuity at the 50 ms scale.
#    PSHUF=1 SKIPS this substitution, restoring the class behaviour. That is
#    the single-variable test for whether ORDERED traversal of a small grain
#    neighbourhood is what produces the artifact layer Roberto hears live and
#    does not hear in offline renders of the same machines.
if [ "${PSHUF:-0}" = "1" ]; then
  echo "  Pshuf KEPT (PSHUF=1): machines shuffle the neighbourhood, no path"
else
  sed -i.bak 's/Pshuf(buf, inf)/Pseq(buf, inf)/g' "$LIVE/Handler_Local.sc"
  rm -f "$LIVE"/*.bak
  echo "  Pshuf -> Pseq: $(grep -c 'Pseq(buf, inf)' "$LIVE/Handler_Local.sc") sites"
fi

# 4. Player methods RETURN their pattern. SuperCollider methods return `this`
#    unless a caret says otherwise, and Handler_Local.sc has exactly one caret
#    in the whole file, in `new`. So stateMachine has always returned the
#    Handler, the factory's isKindOf(EventStreamPlayer) guard has never been
#    true for a class machine, and class voices are neither tracked, deadlined
#    nor given an amplitude arc.
"$PY" "$ROOT/tools/patch_returns.py" "$LIVE/Handler_Local.sc"

# 5. Filter cutoffs mapped onto the band the corpus actually occupies. grains_600
#    has a median 99% rolloff of 2335 Hz; st high-passes at 5.7-15 kHz and gp/bu
#    sweep past Nyquist, so they filtered where no audio exists. Offline this
#    lifts st by 9.8 dB and gp by 19.4 dB while leaving the in-band control gl
#    within 0.4 dB, matching what a bright test corpus predicted independently.
"$PY" "$ROOT/tools/patch_cutoffs.py" "$LIVE/Handler_Local.sc" | tail -1

# The conf names the class directory, so it belongs to the factory that owns
# that directory. Shared, a shadow start would repoint the LIVE factory's conf
# at the shadow's classes -- harmless to the instance already running, since it
# read the file at boot, and waiting to be wrong the next time the live factory
# restarts. That is the worst kind of fault: invisible now, fatal later.
CONF_PATH="${LIVECONF:-$ROOT/tools/live_conf.yaml}"
cat > "$CONF_PATH" <<CONF
includePaths:
  - $LIVE
excludePaths:
  - $HOME/Library/Application Support/SuperCollider/Extensions
  - /Library/Application Support/SuperCollider/Extensions
excludeDefaultPaths: false
postInlineWarnings: false
CONF

OUTDEV_LINE=""
# in and out are named SEPARATELY: "MacBook Pro Speakers" has no input stream,
# so pinning both to it fails with kAudioDevicePropertyStreamFormat error.
if [ -n "${OUTDEV:-}" ]; then
  OUTDEV_LINE="server.options.outDevice = \"$OUTDEV\"; server.options.inDevice = \"${INDEV:-MacBook Pro Microphone}\";"
fi
SCPORT="${SCPORT:-57110}"
MACRO="${MACRO:-}"
# MID is the gesture layer, ~400 ms. Empty is allowed and means machines in the
# 0.2-1 s band fall back to micro, which is the behaviour before 27 Aug.
MID="${MID:-}"
# Each factory owns its mutable layer. A shadow instance runs with
# MUTABLE=mutable_shadow so the chaos monkey perturbing it cannot touch the live
# factory's policy, which both would otherwise re-read every window.
MUTABLE="${MUTABLE:-mutable}"
# and its own generated script, or a second factory overwrites the first's
OUTSCD="${OUTSCD:-$ROOT/renders/_live.scd}"
# THE SOURCE IS A PARAMETER, so a shadow can run instrumentation the live
# factory is not running. Without this, testing a change means putting it in the
# file the live factory reads at its next restart, and the only way to try
# something is to ship it. FACTORY_SRC defaults to the live file, so the
# ordinary invocation is unchanged.
sed -e "s|MACRODIR|\"$MACRO\"|" -e "s|MIDDIR|\"$MID\"|" -e "s|MUTABLEDIR|\"$MUTABLE\"|" -e "s|SCPORT|$SCPORT|g" -e "s|OUTDEVICE|$OUTDEV_LINE|" -e "s|WORKDIR|\"$ROOT\"|" -e "s|GRAINDIR|\"$GRAINS\"|" -e "s|NGRAINS|$N|" \
    "${FACTORY_SRC:-$ROOT/tools/live_factory.scd}" > "$OUTSCD"

echo "--- factory: $N grains from $GRAINS"

# ---- THE PIPE IS A SHARED RESOURCE AND WAS THE LAST ONE UNGUARDED ----------
#
# 4 Sept 2026. A shadow factory started at 15:21 on its own SCPORT, its own
# LIVECLASSES, its own MUTABLE and its own OUTSCD -- every shared resource this
# script had ever been taught about. It then wrote raw audio into the SAME named
# pipe as the live factory, because the pipe is not one of this script's
# parameters: it is `capture_fifo` inside policy.json, and mutable_shadow's copy
# names the live pipe verbatim.
#
# WHAT THAT SOUNDS LIKE. Two writers at 44100x2x4 bytes/s into a splitter sized
# for one. The encoder's bounded queue overflows (11,062 drops), each drop
# splices the stream, and the splitter loses its writer often enough to inject
# minutes of silence at a time -- 918 s of dead air in the hour Roberto was
# listening. The factory's own capture was measured over the same period and was
# healthy: -31.7 dBFS, true peak 0.578, median sounding run 0.75 s against 0.30 s
# in the hour of 3 Sept. Nothing in the factory, the charter or the kernel
# noticed, because every one of them measures the side of the pipe the fault was
# not on. That is the m3_no_clipping lesson for the third time.
#
# WHY THE PORT GUARD DID NOT CATCH IT. It is port-aware on purpose, so an economy
# of factories stays possible, and two factories on different ports genuinely do
# not collide -- on scsynth. The FIFO is the one resource whose name comes from
# POLICY instead of from argv, so it was invisible to the pattern that had
# already made the class dir, the mutable dir and the generated script
# per-factory. Each of those was added after its own incident. This is that
# addition for the pipe.
#
# WHY A WRITER CHECK AND NOT A DERIVED PATH. Deriving a per-factory FIFO would
# fix the shadow and miss the wedged scsynth from a previous run still holding
# the pipe, which is the other way to get two writers. Asking the kernel who
# currently holds the pipe open for writing catches both, and it catches them
# whatever chose the path.
#
# lsof CANNOT LOOK UP A FIFO BY PATH on macOS -- `lsof /tmp/superdark_live.fifo`
# returns nothing while the pipe demonstrably has a writer. It has to be found by
# scanning a process's open files and matching the name. Scoped to scsynth, which
# is always the writer, this costs 40 ms.
CAP_IN_SC=$("$PY" -c "import json,sys;print(json.load(open(sys.argv[1])).get('capture_in_sc','0'))" \
              "$ROOT/$MUTABLE/policy.json" 2>/dev/null || echo 0)
if [ "$CAP_IN_SC" = "1" ]; then
  CAP_FIFO=$("$PY" -c "import json,sys;print(json.load(open(sys.argv[1])).get('capture_fifo',''))" \
               "$ROOT/$MUTABLE/policy.json" 2>/dev/null)
  if [ -n "$CAP_FIFO" ]; then
    FIFO_BASE=$(basename "$CAP_FIFO")
    HOLDER=$(lsof +c0 -w -c scsynth 2>/dev/null \
             | awk -v f="$FIFO_BASE" '$NF ~ f && $4 ~ /[wu]$/ {print $2; exit}')
    if [ -n "$HOLDER" ]; then
      echo "REFUSING TO START: pid $HOLDER already writes $CAP_FIFO."
      echo "Two writers on one pipe interleave their blocks, overflow the"
      echo "encoder queue and deliver silence -- this is the 4 Sept fault."
      echo
      echo "  MUTABLE=$MUTABLE names this pipe in its policy.json."
      echo "  If this is a shadow, give it its own pipe or no pipe at all:"
      echo "    python3 tools/set_policy.py $MUTABLE capture_in_sc 0"
      echo "  If pid $HOLDER is a wedged factory from a previous run, stop it"
      echo "  BEFORE the splitter -- dropping the read end SIGPIPEs the writer."
      exit 1
    fi
  fi
fi

# caffeinate: -i no idle sleep, -m no disk sleep, -s no system sleep on AC.
#
# On 28 Aug the shadow factory's clock jumped 20,309 s between window 100 and
# window 105 because the laptop slept at ~01:55 and woke at 07:33:56. On wake
# sclang's scheduler was 5.6 hours behind, flooded scsynth catching up, and the
# server dropped commands for the remaining 7.75 hours -- 77,491 `command FIFO
# full` messages -- while the factory's own metrics reported it healthy. A
# second sleep at 09:42 took the log file's descriptor with it.
#
# BE CLEAR ABOUT WHAT THIS DOES NOT DO. sclang ALREADY asserts
# PreventUserIdleSystemSleep ("avoiding audio hiccups and reducing latency"),
# so idle sleep was never the problem, and caffeinate does not add much there.
# NOTHING in userspace prevents sleep from a closed lid. A laptop is not a
# machine that runs forever, and that is an argument about hardware, not code:
# a run that must survive the night either keeps the lid open or does not run
# here. The factory now logs CLOCKJUMP when it happens, so at minimum the
# contaminated windows are identifiable instead of silent.
exec caffeinate -ims "$SC" -l "$CONF_PATH" "$OUTSCD"
