#!/bin/sh
# Bring up the factory with the SELF-INGESTION LOOP CLOSED. One command.
#
# WHAT WAS BROKEN UNTIL 31 AUG
# live_factory.scd never referenced self_ingest_weight and never loaded a file
# from grains_pool_*. The ingester filled a pool nothing played from, so the
# loop was open no matter what the weight said. This script is the missing
# connection: it ASSEMBLES the corpus the factory plays by mixing the archive
# with the pool at self_ingest_weight, then boots the factory on that.
#
# WHY ASSEMBLY AND NOT A LIVE BLEND
# The factory loads buffers ONCE at boot, so it cannot vary the mix mid-run in
# any case. Mixing on disk therefore loses nothing and keeps the change out of
# a 1900-line block that has hit sclang's parser limit before. One consequence
# to be aware of: newly admitted grains do not sound until the corpus is
# REASSEMBLED and the factory RESTARTED. That restart is the generation
# boundary, and it is what the twenty-generation test steps through.
#
# RUN THIS ON A FRESHLY BOOTED MACHINE.
# scsynth can wedge in an uninterruptible CoreAudio state (STAT UE/UNE) that
# survives SIGKILL and keeps its UDP port and its audio device for ever. Four
# accumulated on 31 Aug across seven restarts, after which a fifth booted its
# audio driver but sclang could never complete registration -- the boot loop
# printing "/notify : already registered". Nothing short of a reboot clears it.
#
#   sh tools/start_loop.sh            # uses self_ingest_weight from policy.json
#   WEIGHT=0.10 sh tools/start_loop.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
# ---- NEVER RUN INSIDE AN APP'S PROCESS GROUP (24 Sept 2026) -----------------
# Two runs died with their whole stack the moment the Claude desktop app
# restarted (23 Sept 23:35, 24 Sept 17:24): everything launched from a shell
# the app owns sits in the app's process group and goes down with it. If this
# script finds itself in a group led by an application, it re-launches itself
# through tools/detach.sh (its own session, parent launchd) and exits.
if [ -z "${SD_DETACHED:-}" ]; then
  _leader="$(ps -o comm= -p "$(ps -o pgid= -p $$ | tr -d ' ')" 2>/dev/null)"
  case "$_leader" in
    *Claude*|*.app/*|*Electron*)
      echo "  process group is led by '$_leader'; re-launching detached"
      SD_DETACHED=1 exec sh "$ROOT/tools/detach.sh" env SD_DETACHED=1 sh "$0" "$@" ;;
  esac
fi
# THE DRIVE IS A PARAMETER. A replica runs from its own SSD and must never read
# or write this machine's pool, archive or assembled corpus. Defaults unchanged,
# so the ordinary invocation on this machine is exactly as before.
SD_ROOT="${SD_ROOT:-/Volumes/FMA/superdark}"
POOL="${POOL:-$SD_ROOT/self_corpus}"
ARCHIVE_DIR="${ARCHIVE_DIR:-$SD_ROOT/archive}"
SCPORT="${SCPORT:-57110}"
OUTDEV="${OUTDEV:-VB-Cable}"
INDEV="${INDEV:-MacBook Pro Microphone}"

# CHECK THE OUTPUT DEVICE'S CHANNEL COUNT BEFORE HANDING IT TO scsynth.
#
# 18 Sept 2026, 08:52. VB-Cable enumerated with ONE output channel, scsynth
# asked for two, and the server quit during boot -- the same fault this file
# has described since 6 Sept, and still only described. The device had been
# fine all night; the mono state appeared between a clean stop at 08:48 and
# the restart four minutes later, and did not clear on its own. Driver state,
# not code, and it recurs.
#
# The factory writes its stream to the FIFO, not to the output device, so the
# device is only a sink that has to open. Any silent 2-channel loopback will do.
# If the requested device reports fewer than SC_OUTCH channels, fall back to
# BlackHole 2ch and SAY SO, rather than let an unattended comparison die at
# boot for a reason a human would fix in ten seconds.
#
# Fallback only. A device that reports correctly is used as asked, and a device
# the caller named explicitly via OUTDEV that is unhealthy is still swapped --
# with the swap on the console -- because a dead boot serves nobody.
want_ch="${SC_OUTCH:-2}"
dev_ch=$(system_profiler SPAudioDataType 2>/dev/null \
         | awk -v d="$OUTDEV:" '$0 ~ d {f=1} f && /Output Channels/ {print $NF; exit}')
if [ -n "$dev_ch" ] && [ "$dev_ch" -lt "$want_ch" ] 2>/dev/null; then
  echo "  OUTPUT DEVICE '$OUTDEV' reports $dev_ch output channel(s); the factory needs $want_ch."
  bh_ch=$(system_profiler SPAudioDataType 2>/dev/null \
          | awk '/BlackHole 2ch:/ {f=1} f && /Output Channels/ {print $NF; exit}')
  if [ -n "$bh_ch" ] && [ "$bh_ch" -ge "$want_ch" ] 2>/dev/null; then
    echo "  FALLING BACK to 'BlackHole 2ch' ($bh_ch channels). The stream is unaffected;"
    echo "  it reads the FIFO. To return to $OUTDEV, reset it in Audio MIDI Setup or"
    echo "  restart coreaudiod, then start again without the fallback."
    OUTDEV="BlackHole 2ch"
  else
    echo "  and no healthy fallback found. The boot will fail at the server; stopping"
    echo "  here instead so nothing is left holding the port."
    exit 1
  fi
fi

# ---- PYTHON, EXPLICITLY, BECAUSE BARE python3 SUMMONS A DIALOG ---------------
# Under `sh` and `nohup` the PATH is not the interactive one, so bare `python3`
# resolves to /usr/bin/python3 -- Apple's stub, which pops "The python3 command
# requires the command line developer tools" every time it is called, however
# many times the tools are installed. Roberto saw that box repeatedly on 9 Sept.
# xcode-select points at Xcode here, not the standalone CLT, and the stub asks
# anyway. Naming the interpreter removes the question.
PY="$(command -v /opt/homebrew/bin/python3 || command -v /usr/local/bin/python3 \
      || command -v python3)"

# ---- THE PLAY CORPORA MUST NOT LIVE ON AN iCLOUD-SYNCED PATH ----------------
#
# THIS IS WHY THE FACTORY WOULD NOT BOOT ON 9 SEPT. `brctl status` named
#   Under /Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music/grains_play_ev
# as pending sync. The Desktop is in iCloud Drive, so the assembled corpus --
# 2,400 files, rebuilt HERE at every start -- was being uploaded while scsynth
# tried to read it. iCloud may hold a synced file "dataless", a placeholder that
# materialises on first read, and a read of one BLOCKS until the download
# finishes. sclang then sits on a server.sync that never returns, at 0% CPU,
# which is indistinguishable from a hang and was misdiagnosed all day as wedged
# CoreAudio, as VB-Cable, and as boot-order.
#
# Four boots stalled at four different depths on the night of 9 Sept, which is
# the signature of a race and not of a bug: whichever file iCloud had not yet
# materialised is where that boot stopped.
#
# Same family as the fix that solved the clicking, and the same blind spot. The
# SOURCE corpora were moved off iCloud on 1 Sept; the ASSEMBLED ones are
# regenerated into workdir_music every run and landed straight back in the
# synced folder. Moving one and not the other left the fault fully intact.
#
# So they are built on the SSD and reached through symlinks, exactly as
# workdir_music/renders already is.
#
# "ALREADY IS" WAS TRUE ON ONE MACHINE ONLY.
# 17 Sept 2026: the replica published a state file with `"run": {}` and zero
# charter metrics. workdir_music/renders is a symlink to the SSD that was
# created BY HAND on 22 August and is NOT tracked in git, and nothing here ever
# made it. So on this machine the sentence above is true, and on a fresh clone
# the link simply does not exist -- the factory writes its window log into a
# plain directory nobody reads, and factory_status finds nothing to report.
#
# The comment asserted the invariant; no code held it. Made real here, derived
# from SD_ROOT like every other path, so it is correct on both machines and on
# any future one.
RENDERS="${RENDERS:-$SD_ROOT/renders}"
mkdir -p "$RENDERS"
if [ ! -L "$W/renders" ]; then
  # Only ever replace a non-symlink if it is EMPTY. A real directory with
  # window logs in it is somebody's run history, and silently deleting it to
  # tidy up a path would destroy exactly the data this project measures.
  if [ -d "$W/renders" ] && [ -n "$(ls -A "$W/renders" 2>/dev/null)" ]; then
    echo "  WARNING $W/renders is a real directory holding files, not a symlink."
    echo "          Leaving it alone. Move its contents to $RENDERS and remove"
    echo "          it if you want the SSD-backed layout."
  else
    rm -rf "$W/renders"
    ln -s "$RENDERS" "$W/renders"
    echo "  linked workdir_music/renders -> $RENDERS"
  fi
fi

PLAY_ROOT="${PLAY_ROOT:-$SD_ROOT/play}"
mkdir -p "$PLAY_ROOT"
for L in ev mid macro; do
  if [ ! -L "$W/grains_play_$L" ]; then
    rm -rf "$W/grains_play_$L"
    ln -s "$PLAY_ROOT/grains_play_$L" "$W/grains_play_$L"
    echo "  moved grains_play_$L off the synced Desktop onto the SSD"
  fi
  mkdir -p "$PLAY_ROOT/grains_play_$L"
done

echo "=== 0. refuse to start on a dirty audio subsystem ==="
# A wedged scsynth (state U*, uninterruptible, survives SIGKILL, needs a reboot)
# blocks a new factory only if it still holds THE PORT THIS RUN WANTS.
#
# WHY THIS WAS NARROWED, 1 Sept. The old test refused on the existence of ANY
# wedged scsynth. PID 16583 had been wedged for 19 hours holding UDP 57110 and
# nothing else, while the factory ran perfectly well on 57700 beside it all day
# -- so the guard blocked a configuration that had demonstrably just worked, and
# the only remedy it offered was a reboot of Roberto's machine.
#
# The narrowing is deliberately to PORT and not to audio device. Device
# ownership is not visible: CoreAudio is reached over mach IPC, so `lsof` shows
# zero audio handles for a process that may still hold one, and a check written
# against that would report a freedom it cannot see. Port ownership IS visible,
# it is what actually produces the "/notify : already registered" boot loop, and
# the boot loop is caught again at the end of this script regardless.
WEDGED=$(ps -o pid,stat,command -ax | grep '[s]csynth' | awk '$2 ~ /^U/ {print $1}' | tr '\n' ' ')
BLOCKING=""
for P in $WEDGED; do
  if lsof -p "$P" -a -iUDP:"$SCPORT" >/dev/null 2>&1; then
    BLOCKING="$BLOCKING $P"
  fi
done
if [ -n "$BLOCKING" ]; then
  echo "  WEDGED scsynth holding UDP $SCPORT:$BLOCKING"
  echo "  These survive SIGKILL and hold their port and audio device."
  echo "  REBOOT before running the factory; starting now will boot-loop."
  exit 1
fi
if [ -n "$WEDGED" ]; then
  echo "  wedged scsynth present ($WEDGED) but not on port $SCPORT; proceeding."
  echo "  A reboot is still owed -- these never exit and accumulate."
else
  echo "  no wedged scsynth; audio subsystem is clean"
fi

# THE STATE DIRECTORY, RESOLVED ONCE.
#
# MUTABLE names the factory's own learned layer and may be relative (the usual
# "mutable") or absolute (a replica on another volume). Four places below read
# policy.json and every one of them had "$W/mutable" written out longhand, so
# passing MUTABLE moved the FACTORY's state and left the SHELL still reading the
# primary's -- a half-applied parameter, which is worse than one that does
# nothing because it looks like it worked.
case "${MUTABLE:-mutable}" in
  /*) MUTDIR="${MUTABLE}" ;;
  *)  MUTDIR="$W/${MUTABLE:-mutable}" ;;
esac
if [ ! -f "$MUTDIR/policy.json" ]; then
  echo "FATAL: no policy.json under $MUTDIR" >&2
  echo "MUTABLE=${MUTABLE:-mutable} resolved to a directory with no state." >&2
  exit 1
fi
[ "$MUTDIR" = "$W/mutable" ] || echo "  state: $MUTDIR (not the default)"

WEIGHT="${WEIGHT:-$("$PY" -c "import json;print(json.load(open('$MUTDIR/policy.json'))['self_ingest_weight'])")}"
echo
echo "=== 1. assemble the play corpus at weight $WEIGHT ==="
for L in ev mid macro; do
  "$PY" "$ROOT/tools/assemble_play_corpus.py" \
    --archive "$W/grains_lic_$L" --pool "$POOL/grains_pool_$L" \
    --weight "$WEIGHT" --out "$W/grains_play_$L"
done

echo
echo "=== 2. verify descriptors match the assembled audio ==="
# The mix takes each slot's descriptor row from whichever corpus supplied that
# slot's audio. If that ever goes wrong the factory navigates to grains by the
# wrong coordinates and nothing errors, which is the 2,389-of-2,400 failure.
# ALIGN_OVERRIDE="<who, when, why>" lets a PERSON boot past a failed check,
# recorded here and in the factory's start log (26 Sept 2026, Roberto: macro
# pc4 tie noise, 4 of 45 probes moved against a tolerance of 3, diagnosed
# LOCAL by why_misaligned.py). Unset, a failure stops the boot as before.
if ! "$PY" "$ROOT/tools/verify_alignment.py" --root "$W" \
  --corpora grains_play_ev,grains_play_mid,grains_play_macro; then
  if [ -n "${ALIGN_OVERRIDE:-}" ]; then
    echo "  ALIGNMENT CHECK FAILED AND OVERRIDDEN: $ALIGN_OVERRIDE"
  else
    exit 1
  fi
fi

echo
echo "=== 3. stream, BEFORE the factory ==="
# ORDER IS LOAD-BEARING AND THIS SCRIPT HAD IT BACKWARDS UNTIL 6 SEPT.
#
# With capture_in_sc=1 scsynth writes raw audio into a named pipe, and opening a
# FIFO for write BLOCKS until a reader attaches. Starting the factory first
# therefore hands it a pipe nobody is reading. run_fifo.sh has said so in its own
# header since 1 Sept -- "the splitter starts FIRST" -- and this script started
# it at step 5, two steps too late.
#
# AND IT WAS STARTING THE WRONG STREAM. `run_stream.sh start` is the topology the
# FIFO work REPLACED: it reads the audio back off VB-Cable with ffmpeg and writes
# rotated captures into capture/. Running it here reintroduced the loopback that
# was found to be the source of the clicking on 31 Aug, and fed a directory the
# ingest daemon was repointed away from on 5 Sept. Exactly the staleness
# documented at step 5 below for --capture-dir, in the same file, unnoticed.
#
# run_stream.sh is still the right thing for the TUNNEL, which is common to both
# topologies and is all that is used from it now.
#
# NO_STREAM=1 SKIPS THIS WHOLE STEP, and a second instance needs it.
# There is ONE public Icecast mount. Two factories publishing to it fight, and
# the listener gets whichever won the last reconnect -- an outage that looks
# like neither machine is broken, because neither is. A listening replica plays
# locally and publishes nothing.
if [ "${NO_STREAM:-0}" = "1" ]; then
  echo "  NO_STREAM=1: no tunnel, no splitter, no publishing."
  echo "  This instance plays locally and does not touch the public mount."
else
cd "$W/stream"
RH=$(grep "^RELAY_HOST=" .stream_secrets | cut -d= -f2- | tr -d "\"'")
ICECAST_REMOTE=1 RELAY_HOST="$RH" sh run_stream.sh tunnel || true
# MOUNT/SEGDIR/FIFO forwarded so a replica publishes to its own mount and writes
# its own segments. Defaults are the primary's, so this machine is unchanged.
MOUNT="${MOUNT:-/superdark.mp3}" \
  SEGDIR="${SEGDIR:-$SD_ROOT/segments}" \
  FIFO="${FIFO:-/tmp/superdark_live.fifo}" \
  sh run_fifo.sh start || true
fi

echo
echo "=== 4. factory ==="
cd "$W"
# MUTABLE IS PASSED THROUGH, AND WAS NOT.
#
# run_live.sh has taken MUTABLE since the shadow instance was built ("Each
# factory owns its mutable layer", run_live.sh:174-177) and this script never
# forwarded it, so `MUTABLE=... sh tools/start_loop.sh` was accepted and
# silently ignored -- the instance ran on the repo's own mutable/ regardless.
# Found 16 Sept while building the replica kit, which would have shipped a
# second factory quietly learning into the first one's state.
#
# Sixth instance of the same shape in this project: a parameter that exists,
# carries an intended value, and is never reached. Default is unchanged.
nohup env SCPORT="$SCPORT" OUTDEV="$OUTDEV" INDEV="$INDEV" \
  MUTABLE="${MUTABLE:-mutable}" \
  GRAINS=grains_play_ev MID=grains_play_mid MACRO=grains_play_macro N=2400 \
  sh tools/run_live.sh > /tmp/factory.log 2>&1 &
echo "  starting, log /tmp/factory.log"
# 180 s AND NOT 100. A boot that retries registration takes longer than a boot
# that does not: 186 retries on 7 Sept pushed the corpus past the 100 s mark, so
# the guard failed a boot that went on to load all 2,400 buffers. It then exited
# the script, which skipped the ingest daemon and the publisher, and left the
# factory running -- so the next attempt found the port held and failed too. One
# impatient check produced a cascade of three.
sleep 180

# THE STRING IS NOT THE FAULT; NOT GETTING PAST IT IS. sclang prints "/notify :
# already registered" while it RETRIES, and a boot that retries a few times and
# then succeeds prints it too. On 6 Sept this guard aborted a run that had gone
# on to load all 2,400 buffers and read its corpus, and because it aborted at
# step 3 the stream and the ingest daemon never started at all -- so a healthy
# boot was reported as a wedged machine and then half-crippled by the report.
#
# Progress is the test. BUFFERS is printed once the factory has the corpus in the
# server, which no amount of failed registration can reach.
if ! grep -q "^BUFFERS " /tmp/factory.log; then
  if grep -q "exited with exit code" /tmp/factory.log; then
    echo "  SERVER EXITED DURING BOOT. Usually the audio device."
    grep -A3 "Output Device" /tmp/factory.log | sed 's/^/    /'
    echo "  6 Sept: VB-Cable enumerated with ONE channel and scsynth quit on it."
    echo "  Retry with OUTDEV='MacBook Pro Speakers'."
  else
    echo "  NO BUFFERS AFTER 180 s: the boot did not reach the corpus."
    grep -c "already registered" /tmp/factory.log \
      | sed 's/^/    registration retries: /'
    echo "  A wedged CoreAudio state survives SIGKILL and needs a REBOOT."
  fi
  # LEAVE NOTHING HOLDING THE PORT. A failed boot that is merely reported goes on
  # running at 0% CPU, keeps UDP 57110 and the audio device, and the NEXT attempt
  # then fails on the port it is holding. That is how one bad boot became three
  # on 7 Sept. Whatever this script started, this script stops.
  pkill -f "_live.scd" 2>/dev/null || true
  sleep 2
  pkill -x scsynth 2>/dev/null || true
  echo "  stopped the failed factory; the port is free for a retry."
  exit 1
fi
grep -E "GRAINS |BUFFERS |DESCRIPTORS " /tmp/factory.log | sed 's/^/  /' || true

echo
echo "=== 5. ingest daemon ==="
# SEGMENTS, NOT capture/. The FIFO topology of 1 Sept moved the factory's audio
# from rotated captures in capture/ to 10-minute segments written by
# fifo_splitter.py, and this line was never repointed. The daemon went on running
# and starving: last admission 2 Sept 19:30, and on 5 Sept it was still alive,
# watching an empty directory, two and a half days later. The eval panel read
# "self-ingest rate 0, admitted last hour 0" and was telling the exact truth.
#
# AND NO --delete-captures. The old captures were disposable so deleting them was
# housekeeping. segments/ IS the 10 GB ring with score-based deletion; deleting
# from it here would fight the ring manager and destroy the archive the pool is
# built from. Reprocessing is prevented by ingested.json instead.
# ONE DAEMON, NOT ONE PER BOOT. 15 Sept 2026: four self_ingest.py processes were
# found running at once, one for every start_loop.sh invocation of the afternoon.
# Nothing here ever stopped the previous one. Four daemons watch the same segment
# directory and write the same pools, racing on ingested.json and on admission,
# which is a corrupt provenance record waiting to happen. The comment above about
# a daemon "alive, watching an empty directory, two and a half days later" is the
# same family of fault: nobody was counting the daemons.
if pgrep -f "self_ingest.py" >/dev/null 2>&1; then
  echo "  stopping $(pgrep -f 'self_ingest.py' | wc -l | tr -d ' ') existing ingest daemon(s)"
  pkill -f "self_ingest.py" 2>/dev/null || true
  sleep 2
fi

# AN ISOLATION RUN MUST NOT FEED THE LEARNING CHANNELS. `layers_active` narrows
# which layers sound; self-ingestion then admits that atypical output into pools
# used by layers that were silent. On 15 Sept a macro-only run put three grains
# into grains_pool_ev and one into grains_pool_mid before Roberto caught it. The
# experiment was contaminating the instrument it was measuring.
LAYERS_ACTIVE_NOW="$("$PY" -c "import json;print(json.load(open('$MUTDIR/policy.json')).get('layers_active','macro mid micro'))" 2>/dev/null || echo "macro mid micro")"
if [ "$(echo "$LAYERS_ACTIVE_NOW" | wc -w | tr -d ' ')" -lt 3 ]; then
  echo "  ISOLATION RUN (layers_active = '$LAYERS_ACTIVE_NOW')."
  echo "  Ingest NOT started: the factory's own atypical output must not enter"
  echo "  the pools of layers that are silent. Start it by hand after restoring"
  echo "  layers_active, or pass INGEST_ANYWAY=1 and say why in the record."
  if [ "${INGEST_ANYWAY:-0}" != "1" ]; then
    echo "  skipped"
  else
    echo "  INGEST_ANYWAY=1 given; starting anyway, and this line is the record"
    nohup "$PY" "$ROOT/tools/self_ingest.py" \
      --capture-dir ${SEGDIR:-$SD_ROOT/segments} --out-root "$POOL" \
      --basis-dir "$ARCHIVE_DIR" --policy-json "$MUTDIR/policy.json" \
      > /tmp/ingest.log 2>&1 &
  fi
else
  nohup "$PY" "$ROOT/tools/self_ingest.py" \
    --capture-dir ${SEGDIR:-$SD_ROOT/segments} --out-root "$POOL" \
    --basis-dir "$ARCHIVE_DIR" --policy-json "$MUTDIR/policy.json" \
    > /tmp/ingest.log 2>&1 &
  echo "  starting, log /tmp/ingest.log"
fi

echo
echo "=== 6. publish the state the public panel reads ==="
# NOT IN THIS SCRIPT UNTIL 6 SEPT, AND NOBODY NOTICED FOR FIVE DAYS.
#
# publish_state.sh has run since 1 Sept because it was started BY HAND that day
# and never stopped. The reboot of 6 Sept ended it, and nothing brought it back:
# the panel went on serving its last snapshot, which described the 15:50 run that
# never got past boot -- windows 0, every metric null -- while a healthy factory
# ran beside it. Roberto: "did the system not logging date into the website?"
#
# The failure is the same shape as the ingest daemon watching an empty directory
# for two and a half days, and as PatternGrammar sitting unwired: a component
# that is UP is not a component that is DOING ANYTHING, and a stale panel looks
# exactly like a working one to everybody except the person reading the numbers.
#
# So it is started here, with the factory, and its liveness is asserted below
# rather than assumed.
cd "$W/stream"
sh publish_state.sh start || true

echo
echo "=== 7. stream status ==="
sleep 20
sh run_fifo.sh status
sh publish_state.sh status
# ASSERT THE PANEL IS FRESH, not merely that the publisher has a pid. A loop that
# is running and failing every snapshot leaves the endpoint stale and the process
# table reassuring.
"$PY" - <<'PYEOF' || true
import json, time, urllib.request
try:
    d = json.load(urllib.request.urlopen(
        "https://stream.robertoalonsotrillo.com/state.json", timeout=15))
    age = time.time() - d["generated"]
    print(f"  panel age {age:.0f}s, run {d['run']['log']}, "
          f"{d['run']['windows']} windows")
    if age > 120:
        print("  STALE: the publisher is up but the endpoint is not moving.")
except Exception as e:
    print(f"  panel unreachable: {type(e).__name__}: {e}")
PYEOF

echo
echo "=== up. the loop is closed at weight $WEIGHT ==="
echo "  A grain ingested now is generation 1 + $WEIGHT * mean(pool generation)."
echo "  Admitted grains sound only after REASSEMBLY AND RESTART; that is the"
echo "  generation boundary. Check progress with:"
echo "    python3 tools/generation_drift.py --ring $POOL"
