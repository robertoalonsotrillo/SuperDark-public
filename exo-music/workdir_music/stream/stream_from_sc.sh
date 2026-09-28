#!/bin/sh
# Stream the factory WITHOUT any audio device in the path.
#
# WHY THIS REPLACES THE LOOPBACK CAPTURE
# Every device-capture variant tried on 31 Aug measured far worse than
# SuperCollider's own recording of the SAME audio:
#
#     ffmpeg <- BlackHole, buffer 512        clicks/s  4.32   worst  163
#     ffmpeg <- BlackHole, buffer 2048       clicks/s  2.39   worst  477
#     ffmpeg <- aggregate, clock = BlackHole clicks/s 10.45   worst  584
#     ffmpeg <- aggregate, clock = built-in  clicks/s  6.44   worst  662
#     SuperCollider internal recording       clicks/s  0.40   worst   45
#
# Roberto confirmed by ear that the built-in speakers are clean, so the factory
# was never at fault. BlackHole and VB-Cable are loopback drivers with no
# hardware clock: a ring buffer between two independent clients, scsynth writing
# and ffmpeg reading, each on its own timer. When they drift the ring slips and a
# block is lost. An aggregate device with drift correction did not fix it and
# made it worse, twice.
#
# So take the device out. scsynth writes its output to disk with server.record,
# which is the one path measured clean, and the encoder reads that file AS IT
# GROWS.
#
# THE TRICK, AND WHY IT IS NOT A LATENCY PENALTY
# SuperCollider writes an AIFF's SSND chunk SIZE only on close, so the file is
# undecodable by a normal reader until the factory stops. But the SAMPLES are on
# disk immediately and are perfectly intact -- self_ingest.decode_unclosed
# already relies on this to recover interrupted captures. Audio begins right
# after the SSND chunk header (id 4 + size 4 + offset 4 + blockSize 4 = 16
# bytes). So: seek past that header, follow the file with `tail -f`, and hand
# ffmpeg raw f32be. The stream is live, with no chunking and no rotation.
#
#   sh stream/stream_from_sc.sh start|stop|status
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
CAPDIR=/Volumes/FMA/superdark/capture
PIDF=/tmp/superdark_sc_stream.pid
TUNNEL_PORT=8100
MOUNT=/superdark.mp3
[ -f "$HERE/.stream_secrets" ] && . "$HERE/.stream_secrets"
RELAY_SOURCE="${RELAY_SOURCE:-$SOURCE}"

case "${1:-status}" in
start)
  # newest recording the factory is currently writing
  F=$(ls -t "$CAPDIR"/*.aiff 2>/dev/null | head -1)
  [ -n "$F" ] || { echo "  no SC recording in $CAPDIR."; \
                   echo "  Set capture_in_sc=1 in mutable/policy.json and restart the factory."; exit 1; }
  # give it a moment so the header exists
  sleep 2
  OFF=$(python3 - "$F" <<'PYEOF'
import sys
with open(sys.argv[1], "rb") as f:
    head = f.read(65536)
i = head.find(b"SSND")
# id(4) + size(4) + offset(4) + blockSize(4). ffprobe reads COMM correctly even
# when the size field is zero, so the format is read and not assumed elsewhere;
# here only the data start is needed.
print(-1 if i < 0 else i + 16)
PYEOF
)
  [ "$OFF" -ge 0 ] 2>/dev/null || { echo "  no SSND chunk in $F yet; is the factory recording?"; exit 1; }
  echo "  source : $F"
  echo "  audio begins at byte $OFF (past the SSND header)"

  # tail -c +N is 1-BASED, so the offset needs +1. Off by one here silently
  # shifts every sample by a byte and turns the stream into noise, which is
  # exactly the kind of failure that looks like a codec problem.
  nohup sh -c "tail -c +$((OFF + 1)) -f '$F' | \
    ffmpeg -hide_banner -loglevel warning \
      -f f32be -ar 44100 -ac 2 -i - \
      -af 'lowpass=f=11000' -c:a libmp3lame -b:a 192k -reservoir 0 \
      -content_type audio/mpeg -f mp3 \
      'icecast://source:${RELAY_SOURCE}@127.0.0.1:${TUNNEL_PORT}${MOUNT}'" \
    > /tmp/sc_stream.log 2>&1 &
  echo $! > "$PIDF"
  sleep 6
  if pgrep -f "tail -c +$((OFF + 1))" >/dev/null; then
    echo "  encoder up, reading the factory's own recording -- no audio device involved"
  else
    echo "  FAILED, see /tmp/sc_stream.log"; tail -5 /tmp/sc_stream.log
  fi
  ;;
stop)
  pkill -f "tail -c \+" 2>/dev/null || true
  pkill -f "f32be -ar 44100" 2>/dev/null || true
  rm -f "$PIDF"
  echo "  stopped"
  ;;
status)
  pgrep -f "f32be -ar 44100" >/dev/null && echo "  encoder: running" || echo "  encoder: down"
  ls -t "$CAPDIR"/*.aiff 2>/dev/null | head -1 | sed 's/^/  source: /'
  ;;
esac
