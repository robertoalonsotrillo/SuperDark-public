#!/bin/sh
# The SuperDark stream, in either of two modes.
#
# LOCAL  (default)      icecast runs here; you listen at localhost:8000.
#                       For development. Nothing leaves the machine.
#
# REMOTE (ICECAST_REMOTE=1)
#                       icecast runs on the relay server, bound to ITS loopback.
#                       This machine opens an ssh tunnel and the encoder sends
#                       through it. Listeners reach the server over https.
#
#   laptop:  factory -> BlackHole -> ffmpeg --.
#                                             |  ssh tunnel, OUTBOUND ONLY
#   server:                    127.0.0.1:8000 <'  icecast  [never on a public
#                                             |             interface]
#            listeners <- :443 caddy (TLS) ---'
#
# Why a tunnel rather than exposing icecast on the server: the admin interface
# then has no public surface at all, by construction rather than by password
# strength, and this machine needs no static IP and no inbound port. It is also
# the only arrangement where the source password never crosses the network in
# the clear.
#
# THE TUNNEL USES A DIFFERENT LOCAL PORT (8100) than a local icecast (8000), so
# the two modes never collide and you can run a local server while the remote
# one is up.
#
#   sh stream/run_stream.sh start|stop|status
#   ICECAST_REMOTE=1 RELAY_HOST=stream.example.com sh stream/run_stream.sh tunnel
#   ICECAST_REMOTE=1 RELAY_HOST=stream.example.com sh stream/run_stream.sh start
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
CONF="$HERE/icecast.conf.live"
LOGDIR="$HERE/logs"
SECRETS="$HERE/.stream_secrets"
MOUNT="${MOUNT:-/superdark.mp3}"
INDEV="${INDEV:-BlackHole 2ch}"
# 192k, not 128k, and low-passed before encoding.
#
# MEASURED 30 Aug, comparing 10 s off BlackHole against 10 s off the stream:
#   pre-encoder   2-8 kHz band = 0.5% of energy
#   post-encoder  2-8 kHz band = 1.0%
# The encoder was ADDING high-frequency energy that is not in the source. On
# material where 99.9% of the energy sits below 3.4 kHz that added band is
# plainly audible as noise, and it is the same class of artefact as the
# Bluetooth headset codec that produced the "patina" earlier in this project.
#
# Two changes, for two reasons:
#   LOWPASS at 11 kHz  the corpus is 22050 Hz, so the factory's output cannot
#                      contain anything above 11 kHz. Everything the encoder
#                      writes up there is invention. Cutting it first stops the
#                      psychoacoustic model from spending bits, and artefacts,
#                      on a band that is empty by construction.
#   192k               transient-dense granular texture is close to worst case
#                      for MP3; the extra headroom buys back what the model
#                      cannot predict.
BITRATE="${BITRATE:-192k}"
LOWPASS="${LOWPASS:-11000}"

REMOTE="${ICECAST_REMOTE:-0}"
RELAY_HOST="${RELAY_HOST:-}"
RELAY_USER="${RELAY_USER:-root}"
TUNNEL_PORT="${TUNNEL_PORT:-8100}"

[ -f "$SECRETS" ] || { echo "missing $SECRETS"; exit 1; }
. "$SECRETS"
mkdir -p "$LOGDIR"

if [ "$REMOTE" = "1" ]; then
  ENC_PORT="$TUNNEL_PORT"
  # The relay's source password, which is NOT the local one. Set RELAY_SOURCE in
  # .stream_secrets after provisioning the server.
  ENC_PW="${RELAY_SOURCE:-$SOURCE}"
else
  ENC_PORT=8000
  ENC_PW="$SOURCE"
fi

CAPDIR="${CAPDIR:-/Volumes/FMA/superdark/capture}"
CAPSECS="${CAPSECS:-600}"

encoder_running() { pgrep -f "icecast://source:.*:$ENC_PORT$MOUNT" >/dev/null 2>&1; }
tunnel_running()  { pgrep -f "ssh.*-L $TUNNEL_PORT:127.0.0.1:8000" >/dev/null 2>&1; }
capture_running() { pgrep -f "segment_time $CAPSECS" >/dev/null 2>&1; }

start_capture() {
  # Capture for self-ingestion, as SEGMENTS. This used to live in
  # live_factory.scd via server.record + stopRecording/record on a timer, which
  # produced a good first chunk and a 0-byte second chunk every time, silently,
  # because the calls were wrapped in .try. ffmpeg's segment muxer closes each
  # file properly by construction.
  #
  # A second reader of BlackHole alongside the encoder is fine; macOS allows it,
  # and it is how the A/B captures were taken.
  #
  # f32le keeps full headroom; self_ingest decodes with ffmpeg anyway, so the
  # container only has to be honest, not small.
  if [ ! -d "$CAPDIR" ]; then
    echo "  capture dir $CAPDIR is not reachable (external drive unmounted?);"
    echo "  skipping capture. The stream is unaffected."
    return 0
  fi
  if capture_running; then echo "  capture already running"; return 0; fi
  nohup ffmpeg -nostdin -loglevel warning \
    -f avfoundation -i ":$INDEV" \
    -ac 2 -ar 44100 -c:a pcm_f32le \
    -f segment -segment_time "$CAPSECS" -reset_timestamps 1 \
    -strftime 1 "$CAPDIR/cap_%Y%m%d_%H%M%S.wav" \
    > "$LOGDIR/capture.log" 2>&1 &
  sleep 3
  capture_running \
    && echo "  capture up, ${CAPSECS}s segments -> $CAPDIR" \
    || { echo "  capture FAILED:"; tail -4 "$LOGDIR/capture.log"; }
}

case "${1:-status}" in

tunnel)
  [ -n "$RELAY_HOST" ] || { echo "set RELAY_HOST=stream.example.com"; exit 1; }
  if tunnel_running; then echo "  tunnel already open"; exit 0; fi
  # autossh restarts the tunnel when the network drops, which a laptop's does.
  # Falls back to plain ssh with keepalives if autossh is not installed.
  if command -v autossh >/dev/null 2>&1; then
    autossh -M 0 -f -N \
      -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
      -o "ExitOnForwardFailure yes" \
      -L "$TUNNEL_PORT:127.0.0.1:8000" "$RELAY_USER@$RELAY_HOST"
  else
    echo "  autossh not installed (brew install autossh); using plain ssh"
    ssh -f -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
        -o "ExitOnForwardFailure yes" \
        -L "$TUNNEL_PORT:127.0.0.1:8000" "$RELAY_USER@$RELAY_HOST"
  fi
  sleep 2
  tunnel_running && echo "  tunnel open: localhost:$TUNNEL_PORT -> $RELAY_HOST:8000" \
                 || { echo "  tunnel FAILED"; exit 1; }
  ;;

start)
  if [ "$REMOTE" = "1" ]; then
    tunnel_running || { echo "  no tunnel. Run '$0 tunnel' first."; exit 1; }
    echo "  remote mode: encoding to the relay through localhost:$TUNNEL_PORT"
  else
    sed -e "s|__SOURCE__|$SOURCE|" -e "s|__ADMIN__|$ADMIN|" \
        -e "s|__RELAY__|$RELAY|"   -e "s|LOGDIR|$LOGDIR|" \
        "$HERE/icecast.xml" > "$CONF"
    chmod 600 "$CONF"
    if lsof -nP -iTCP:8000 -sTCP:LISTEN >/dev/null 2>&1; then
      echo "  icecast already listening on 8000"
    else
      icecast -b -c "$CONF" >/dev/null 2>&1
      sleep 2
      lsof -nP -iTCP:8000 -sTCP:LISTEN >/dev/null 2>&1 \
        && echo "  icecast up on :8000" \
        || { echo "  icecast FAILED; see $LOGDIR/error.log"; exit 1; }
    fi
  fi

  if encoder_running; then
    echo "  encoder already running"
  else
    # -ac/-ar go AFTER -i, as OUTPUT options. Before -i they are handed to the
    # avfoundation demuxer, which has no such options and fails with
    # "Option sample_rate not found" - an error that reads like a device problem
    # and is not one.
    # SUPERVISE IT. -reconnect applies to ffmpeg's INPUTS; the icecast:// URL is
    # an OUTPUT, so those three flags never protected this process at all.
    #
    # 1 Sept 03:22:31: Icecast's source-timeout (30 s) fired, the socket closed,
    # ffmpeg died on a broken pipe ten seconds later, and the mount served 404
    # for the next seven hours. The factory ran perfectly throughout. What hid
    # it was the health check: `pgrep -f 'ffmpeg.*BlackHole'` also matches the
    # CAPTURE process, so "encoder: 1" was reported while nothing was reaching
    # Icecast. Match on the icecast:// URL, as encoder_running() above does.
    #
    # A loop, not a cleverer flag. Every restart is stamped in the log so a
    # flapping encoder looks like a flapping encoder instead of like silence.
    nohup sh -c 'while true; do
        echo "--- encoder start $(date +%H:%M:%S) ---"
        ffmpeg -nostdin -loglevel warning \
          -f avfoundation -i ":'"$INDEV"'" \
          -ac 2 -ar 44100 -af "lowpass=f='"$LOWPASS"'" \
          -c:a libmp3lame -b:a "'"$BITRATE"'" -content_type audio/mpeg \
          -f mp3 "icecast://source:'"$ENC_PW"'@localhost:'"$ENC_PORT$MOUNT"'"
        echo "--- encoder exited $? at $(date +%H:%M:%S), restart in 5s ---"
        sleep 5
      done' > "$LOGDIR/encoder.log" 2>&1 &
    sleep 8
    encoder_running \
      && echo "  encoder up, reading '$INDEV' at $BITRATE" \
      || { echo "  encoder FAILED:"; tail -6 "$LOGDIR/encoder.log"; exit 1; }
  fi

  start_capture

  echo
  if [ "$REMOTE" = "1" ]; then
    echo "  listeners:  https://$RELAY_HOST$MOUNT"
  else
    echo "  listen:  http://localhost:8000$MOUNT"
  fi
  ;;

stop)
  pkill -f "segment_time $CAPSECS" 2>/dev/null && echo "  capture stopped" || echo "  no capture"
  pkill -f "icecast://source:.*$MOUNT" 2>/dev/null && echo "  encoder stopped" || echo "  no encoder"
  if [ "$REMOTE" = "1" ]; then
    pkill -f "ssh.*-L $TUNNEL_PORT:127.0.0.1:8000" 2>/dev/null && echo "  tunnel closed" || echo "  no tunnel"
  else
    pkill -f "icecast -b -c" 2>/dev/null && echo "  icecast stopped" || echo "  no icecast"
    rm -f "$CONF"
  fi
  ;;

status)
  if [ "$REMOTE" = "1" ]; then
    tunnel_running && echo "  tunnel:  open" || echo "  tunnel:  closed"
    STATURL="https://$RELAY_HOST/status-json.xsl"
  else
    lsof -nP -iTCP:8000 -sTCP:LISTEN >/dev/null 2>&1 \
      && echo "  icecast: listening on 8000" || echo "  icecast: down"
    STATURL="http://localhost:8000/status-json.xsl"
  fi
  encoder_running && echo "  encoder: running" || echo "  encoder: down"
  curl -s --max-time 8 "$STATURL" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)['icestats']
except Exception:
    print('  no stats'); raise SystemExit
s = d.get('source')
if not s:
    print('  mount: no source connected'); raise SystemExit
s = s if isinstance(s, dict) else s[0]
print(f\"  mount: {s.get('listenurl','?')}\")
print(f\"  listeners: {s.get('listeners','?')}  peak {s.get('listener_peak','?')}\")
print(f\"  since: {s.get('stream_start','?')}\")
" 2>/dev/null || true
  ;;
esac
