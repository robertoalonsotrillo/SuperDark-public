#!/bin/sh
# The pipe topology: one clean source, two consumers, nothing stored.
#
#   scsynth --raw f32le--> FIFO --> fifo_splitter.py --> ffmpeg --> Icecast
#                                          `----------> wav segments --> ingest
#
# WHY. Roberto, 1 Sept: "but we are planning to run this forever." Every
# file-based design needed a restart to bound disk, and kernel.json's
# k2_continuous forbids a factory with a start and an end. A pipe holds nothing.
#
# WHAT THIS REPLACES. stream_from_sc.sh followed one unbounded AIFF with
# `tail -f` at 1.27 GB/hour, which was clean but grew for ever; and the ingest
# daemon ate segments from the SAME directory, which is how it came to delete
# the file scsynth was actively writing.
#
# ORDER IS LOAD-BEARING. Opening a FIFO for write blocks until a reader attaches,
# so the splitter starts FIRST. The splitter also cannot be restarted while the
# factory runs: it holds the read end, and dropping it sends SIGPIPE to scsynth.
# Stop the factory first, always.
#
# WHY --encoder-buffer IS 25 s AND NOT 4. The first run of this topology measured
# 1.51 clicks/s against 0.08 on the path it replaced, and the splitter's own
# counter explained it: 95 drops in 290 s. Each drop splices the stream, so a
# shallow queue MANUFACTURES the clicks this project spent two days removing.
# ffmpeg's writes to Icecast are bursty, and 4 s of slack overflows on ordinary
# network jitter. A deeper queue costs the listener nothing that is not already
# spent -- Icecast holds a 16 s burst of its own, so every listener is seconds
# behind whatever happens here. The queue stays BOUNDED and still drops rather
# than blocking, because blocking would reach back into the audio thread.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# THE FIFO LIVES ON THE INTERNAL DISK, and this is not a violation of "keep the
# project on the external SSD" (Roberto, 28 Aug: "I don't want to use my
# computer's limited internal memory"). exFAT has no special files at all --
# mkfifo returns "Operation not supported" there, the same limitation that
# already cost this project its permission bits. A FIFO stores NOTHING: it is a
# kernel buffer of a few tens of kilobytes with a name, and it occupies no disk
# whatever passes through it. Everything that is actually stored -- the audio
# segments -- still goes to the SSD, below.
# EVERY ONE OF THESE IS A PARAMETER, so a second factory can publish alongside
# the first instead of fighting it for one mount.
#
# Icecast serves as many mounts as sources authenticate for; the relay needs no
# extra instance and no extra licence. A replica publishing to /replica.mp3 with
# the same source password is simply a second source on the server that is
# already running.
#
# SEGDIR and FIFO are per-instance too. Two factories writing one segments ring
# would interleave two different factories\' audio into one directory, and the
# ingest daemon would admit the mixture as though it were one history.
FIFO="${FIFO:-/tmp/superdark_live.fifo}"
SEGDIR="${SEGDIR:-/Volumes/FMA/superdark/segments}"
TUNNEL_PORT="${TUNNEL_PORT:-8100}"
MOUNT="${MOUNT:-/superdark.mp3}"
LOG="${LOG:-/tmp/fifo_splitter.log}"

# WHAT THE MOUNT CALLS ITSELF.
#
# 17 Sept 2026, reported from the replica: /replica.mp3 showed
# `server_name: "Unspecified name"` and no description in status-json.xsl,
# because the encoder command set -content_type and nothing else. Icecast has
# no other source for a mount's label, so every client, directory listing and
# status page saw the default.
#
# TWO LAYERS NAME A MOUNT, AND THE SERVER WINS.
#   1. icecast.xml's <mount><stream-name> on the relay -- authoritative, and it
#      OVERRIDES whatever the source sends.
#   2. these -ice_* headers from the source -- used only when no mount block
#      defines a name.
#
# /superdark.mp3 has a mount block, which is why it reads "SuperDark" even
# though the ffmpeg feeding it sets no -ice_name at all. /replica.mp3 has no
# block, which is why it read "Unspecified name". So ICE_NAME below is what
# actually names the replica, and is IGNORED for /superdark.mp3 -- the value
# there is kept only so the script does not lie about what it is sending.
#
# Doing it here rather than on the relay means the replica adopts it on its next
# gated pull, with no relay access and no local edit for the next update to
# fight. A matching <mount> block for /replica.mp3 is staged in icecast.xml for
# whenever the relay config is next applied; it would then take precedence.
case "$MOUNT" in
  /replica.mp3)  DEF_NAME="SuperDark - Factory 1 (continuous)" ;;
  /superdark.mp3) DEF_NAME="SuperDark - Factory 2 (development)" ;;
  *)             DEF_NAME="SuperDark${MOUNT}" ;;
esac
ICE_NAME="${ICE_NAME:-$DEF_NAME}"
ICE_DESCRIPTION="${ICE_DESCRIPTION:-A continuously running generative music factory. SuperCollider, self-ingesting corpus, no loop and no playlist.}"
ICE_GENRE="${ICE_GENRE:-Generative}"
ICE_URL="${ICE_URL:-https://robertoalonsotrillo.com/superdark}"
[ -f "$HERE/.stream_secrets" ] && . "$HERE/.stream_secrets"
RELAY_SOURCE="${RELAY_SOURCE:-$SOURCE}"

# f32le, NOT f32be. The old path read AIFF, which is big-endian; libsndfile
# writes raw in host order, little on arm64.
# 128k AND NOT 192k, 4 Sept. The -af above lowpasses at 11 kHz, so there is no
# content above 11 kHz for the extra 64 kbps to carry: a third of the bitrate was
# being spent encoding a band the signal does not occupy. The mount on the relay
# had advertised <bitrate>128</bitrate> the whole time, so this also makes the
# config honest instead of merely consistent with itself.
#
# WHAT IT BUYS, and the reason is geography. Roberto listens from Hong Kong and
# the relay is at Hetzner: 347 ms RTT, 28 ms jitter, 0% loss. The stream was
# never starved -- measured 192.5 kbps sustained over five minutes against a
# nominal 192, with the source feeding at exact real time (splitter clock skew
# constant across five status lines). What failed was CUSHION. Icecast logged ten
# "client has fallen too far behind" removals in five days, roughly one per long
# listening session, and on that path a client needs real slack to ride out a
# stall it cannot recover from inside one RTT.
#
# At 128 kbps the relay's queue is 524 s of slack instead of 131, and the burst
# hands a new connection 48 s instead of 16. Those two numbers, not the bitrate,
# are what stop the rebuffering; the bitrate is what makes them affordable.
#
# THE OTHER HALF OF THIS FIX LIVES ON THE RELAY AND NOT IN THIS REPO, which is
# why it is written down here. /etc/icecast2/icecast.xml on
# stream.robertoalonsotrillo.com was changed at the same time:
#
#     queue-size   2097152 -> 8388608     (87 s -> 524 s at 128 kbps)
#     burst-size    393216 ->  786432     (16 s ->  48 s at 128 kbps)
#
# Backup at /etc/icecast2/icecast.xml.bak_260904. Changing the bitrate here
# WITHOUT those two is most of the cost and little of the benefit: the encoder
# was never the thing that ran out. Anyone restoring this system from the repo
# alone will rebuild a relay that rebuffers.
ENC="ffmpeg -hide_banner -loglevel warning \
  -f f32le -ar 44100 -ac 2 -i - \
  -af lowpass=f=11000 -c:a libmp3lame -b:a 128k -reservoir 0 \
  -content_type audio/mpeg -f mp3 \
  -ice_name \"${ICE_NAME}\" -ice_description \"${ICE_DESCRIPTION}\" \
  -ice_genre \"${ICE_GENRE}\" -ice_url \"${ICE_URL}\" \
  icecast://source:${RELAY_SOURCE}@127.0.0.1:${TUNNEL_PORT}${MOUNT}"

case "${1:-status}" in
start)
  mkdir -p "$SEGDIR" "$(dirname "$FIFO")"
  # A stale FIFO left by a crash is still a FIFO, and a stale REGULAR file at
  # this path would silently turn the pipe back into an unbounded recording.
  [ -p "$FIFO" ] || { rm -f "$FIFO"; mkfifo "$FIFO"; }
  if pgrep -f "fifo_splitter.py" >/dev/null; then
    echo "  splitter already running"; exit 0
  fi
  nohup python3 "$HERE/fifo_splitter.py" \
    --fifo "$FIFO" --segdir "$SEGDIR" --encoder-cmd "$ENC" \
    --segment-seconds 600 --encoder-buffer 25 --segment-buffer 30 \
    --ring-gb "${RING_GB:-24}" --status-every 300 > "$LOG" 2>&1 &
  sleep 2
  # Check the SPLITTER by its own script name. Matching the encoder command
  # would also match the splitter's own argv, which is how the stall test froze
  # the process it was testing.
  if pgrep -f "fifo_splitter.py --fifo" >/dev/null; then
    echo "  splitter up, waiting for the factory to attach"
    echo "  fifo     $FIFO"
    echo "  segments $SEGDIR"
    echo "  log      $LOG"
  else
    echo "  FAILED"; tail -20 "$LOG"; exit 1
  fi
  ;;
stop)
  pkill -f "fifo_splitter.py --fifo" 2>/dev/null || true
  pkill -f "f32le -ar 44100" 2>/dev/null || true
  echo "  stopped"
  ;;
status)
  pgrep -f "fifo_splitter.py --fifo" >/dev/null \
    && echo "  splitter: running" || echo "  splitter: down"
  pgrep -f "f32le -ar 44100" >/dev/null \
    && echo "  encoder : running" || echo "  encoder : down"
  [ -p "$FIFO" ] && echo "  fifo    : present" || echo "  fifo    : MISSING"
  echo "  segments: $(ls "$SEGDIR"/*.wav 2>/dev/null | wc -l | tr -d ' ') wav, \
$(du -sh "$SEGDIR" 2>/dev/null | cut -f1)"
  tail -3 "$LOG" 2>/dev/null | sed 's/^/  /'
  ;;
esac
