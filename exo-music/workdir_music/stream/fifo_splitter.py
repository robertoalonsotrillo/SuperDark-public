#!/usr/bin/env python3
"""Drain SuperCollider's raw FIFO to two consumers, and never stall the factory.

WHY A FIFO AT ALL. Roberto, 1 Sept: "but we are planning to run this forever."
Every other topology needed a periodic restart to bound disk, and a restart
contradicts kernel.json's k2_continuous -- "a factory with a start and an end is
a work; a factory that only runs forward is a factory" -- as well as the public
page's "you may never witness the system beginning or ending". A pipe stores
nothing, so nothing accumulates and nothing needs rotating.

Verified 1 Sept before this file was written: scsynth CAN write into a named pipe
if the format is RAW. AIFF cannot, because it rewrites its chunk size at close by
seeking backwards, and a pipe has nowhere to seek to. Raw has no header at all.
An 8 s NRT render through a FIFO returned peak 0.200 exactly, both test tones on
frequency, largest sample-to-sample step 0.006.

THE HAZARD THIS FILE EXISTS TO PREVENT
A FIFO applies backpressure UPSTREAM. With a plain `tee`, a stalled Icecast stops
ffmpeg reading, the pipe fills, and scsynth's disk thread blocks -- a network
fault reaching into the audio thread and damaging the work itself. So:

    the read loop never waits on a consumer. Consumers that fall behind LOSE DATA.

A gap in the stream is a listener's inconvenience. A stall in the factory is
damage to the thing being made. That asymmetry is the whole policy, and it is why
the queues are bounded and dropping rather than unbounded and polite.

WHY SEGMENTS ARE WAV AND NOT RAW. The ingester already decodes wav via soundfile.
Each segment is closed before it is published, so a header can be written
correctly -- the reason the FIFO itself cannot take one does not apply here.

WHY .part AND THEN RENAME. On 1 Sept the ingest daemon deleted the file
SuperCollider was actively recording, because its 20 s mtime guard fails: an
AIFF's mtime does not advance while libsndfile writes into it. scsynth was left
writing into an unlinked inode. A segment that only appears under its final name
once it is closed cannot be read or deleted early, whatever the consumer believes
about mtime.

    python3 fifo_splitter.py --fifo /path/cap.fifo --segdir /path/segments \
        --encoder-cmd "ffmpeg ... -f mp3 icecast://..."
"""
import argparse
import base64
import collections
import json
import math
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import urllib.request

SR = 44100
CH = 2
ITEM = 4 * CH                      # float32 stereo frame
READ = 1 << 16                     # 64 KiB, about 186 ms


class Sink(threading.Thread):
    """A consumer fed by a BOUNDED queue. Full queue means drop, never wait.

    `maxitems` is deliberately small. A deep buffer does not prevent the stall,
    it delays it and then delivers a large slug of stale audio when the consumer
    recovers -- so the listener hears the factory's past believing it is its
    present, which is the one promise the page makes ("whatever state it is in at
    the moment you arrive").
    """

    def __init__(self, name, maxitems):
        super().__init__(daemon=True, name=name)
        self.q = queue.Queue(maxsize=maxitems)
        self.dropped = 0
        self.written = 0
        self.stop = threading.Event()

    def offer(self, block):
        """Called from the READ LOOP. Must return promptly, always."""
        try:
            self.q.put_nowait(block)
        except queue.Full:
            # Discard the OLDEST, keep the newest: on recovery the consumer
            # resumes at the present instead of replaying a backlog.
            try:
                self.q.get_nowait()
                self.dropped += 1
                self.q.put_nowait(block)
            except (queue.Empty, queue.Full):
                self.dropped += 1

    def take(self, timeout=0.5):
        try:
            return self.q.get(timeout=timeout)
        except queue.Empty:
            return None


class Spectrogram(Sink):
    """Compute the spectrogram HERE, where the samples already are.

    WHY THIS EXISTS. The panel's spectrogram is drawn by a Web Audio analyser in
    the visitor's browser. That works in Chrome and Firefox and NOT in Safari,
    which refuses to pass cross-origin streaming media into an AudioContext --
    measured, not assumed: frames climb while the loudest bin stays 0. Most
    visitors will arrive on a phone, and on iOS every browser is Safari's engine
    underneath, so "works except Safari" means "works for almost nobody".

    The fix is to stop asking the browser to analyse audio at all. This splitter
    is already reading every sample on their way to the encoder, so the FFT costs
    one more pass over data held in hand, and the result is a small array any
    browser can draw. A phone with no Web Audio at all still sees the picture.

    Two honest differences from the client-side version. It is a few seconds
    behind what a listener hears, because it is computed before the encoder and
    the Icecast burst; and it is the same for everyone rather than being their
    own audio. Neither matters for a factory whose page already says you hear
    whatever state it is in when you arrive.
    """

    # 240 x 64 at a 0.2 s hop: 48 s of history, 15 KB of bytes which base64 to
    # 20 KB. Polled every 10 s that is about 7 MB an hour, against 86 MB an hour
    # for the 192 kbps stream it accompanies -- on a phone it is a rounding
    # error next to the audio the visitor came for.
    # 112 bins, not 64: the factory runs three grain layers at once and their
    # harmonic structure is the thing worth seeing. At 64 bins the layers smear
    # into one band. 240 columns at a 0.18 s hop is 43 s of history; the payload
    # is 27 KB of bytes, 36 KB base64, against 86 MB an hour for the audio.
    def __init__(self, path, maxitems, cols=240, bins=112, hop=0.18):
        super().__init__("spectrogram", maxitems)
        self.path = path
        self.cols, self.bins, self.hop = cols, bins, hop
        self.strip = []
        self.ref = 1e-6          # auto-range reference, see run()

    def run(self):
        import numpy as np
        need = int(self.hop * SR) * ITEM
        buf, have, last_write = [], 0, 0.0
        # Log-spaced edges: the corpus holds nothing above 11 kHz and linear bins
        # would spend most of the picture on an octave nobody hears as detail.
        # Geometric from 40 Hz: below that there is nothing musical in this
        # corpus and the bins would be a single fat band of rumble. The top is
        # 11 kHz, above which the 22050-derived corpus holds nothing at all.
        lo_bin = max(1, int(40 / (SR / 2048)))
        hi_bin = int(11000 / (SR / 2048))
        edges = np.unique(np.geomspace(lo_bin, hi_bin, self.bins + 1).astype(int))
        while not self.stop.is_set():
            b = self.take()
            if b is not None:
                buf.append(b); have += len(b)
            if have < need:
                continue
            data = b"".join(buf)[:need]
            buf, have = [], 0
            x = np.frombuffer(data, dtype="<f4").reshape(-1, CH).mean(1)
            n = min(2048, len(x))
            if n < 256:
                continue
            # NORMALISE BY THE WINDOW. An unnormalised rfft of n samples returns
            # magnitudes up to n/2 times the input amplitude, so a signal at 0.2
            # gives about 205 and 20*log10 of that is +46 dB -- far above the 0
            # dB ceiling below, which pinned every bin to 255 and painted the
            # whole picture in the accent colour. It looked correct only while
            # the factory was quiet. Dividing by n/2 puts a full-scale sine at
            # 0 dBFS, which is what the -80..0 mapping assumes.
            sp = np.abs(np.fft.rfft(x[:n] * np.hanning(n))) / (n / 2.0)
            # SELF-SCALING, because a fixed dB window cannot be right.
            # Per-BIN magnitudes sit far below the signal level: a broadband
            # sound spreads its energy over a thousand bins, so a -20 dBFS
            # passage has individual bins near -70 dB. A floor at -80 clipped
            # almost everything to zero; a floor set for quiet passages
            # saturated during loud ones. Both were tried and both were wrong.
            #
            # So the scale follows the music. `ref` tracks the loudest bin seen
            # recently, rising instantly and falling slowly, and each column is
            # drawn as dB BELOW that reference across a 60 dB span. The top of
            # the picture is always "as loud as it has lately been", which is
            # what an analyser's auto-range does and what makes structure
            # visible whether the factory is roaring or barely breathing.
            # THE REFERENCE HAS AN ABSOLUTE FLOOR, and it is load-bearing.
            # Without one, the reference decays through a silent passage until
            # it reaches the noise floor, at which point the noise is amplified
            # to full scale and the picture writhes while nothing is audible.
            # That is the standard failure of any auto-gain: it has no way to
            # know the difference between quiet and nothing, so it must be told.
            # 0.003 is about -50 dB relative to a full-scale sine, below which
            # this factory is not making a sound anyone can hear.
            peak = float(sp.max()) if sp.size else 0.0
            self.ref = max(peak, self.ref * 0.995, 0.003)
            col = []
            for i in range(len(edges) - 1):
                seg = sp[edges[i]:max(edges[i] + 1, edges[i + 1])]
                v = float(seg.max()) if len(seg) else 0.0
                db = 20 * math.log10((v + 1e-12) / self.ref)
                col.append(max(0, min(255, int((db + 60) / 60 * 255))))
            self.strip.append(col)
            self.strip = self.strip[-self.cols:]
            now = time.time()
            if now - last_write > 3.0:
                last_write = now
                try:
                    tmp = self.path + ".tmp"
                    # base64 of raw bytes, not hex: half the payload for the
                    # same data, and atob() is in every browser.
                    flat = bytes(v for c in self.strip for v in c)
                    json.dump({"t": now, "cols": len(self.strip),
                               "bins": len(self.strip[0]),
                               "hop": self.hop,
                               "b64": base64.b64encode(flat).decode("ascii")},
                              open(tmp, "w"))
                    os.replace(tmp, self.path)
                    self.written += 1
                except OSError:
                    pass


class Encoder(Sink):
    def __init__(self, cmd, maxitems):
        super().__init__("encoder", maxitems)
        self.cmd = cmd
        self.proc = None
        self.restarts = 0
        # THE MOUNT, so the thread can ask Icecast whether the source it
        # thinks it is feeding still exists. 21 Sept: the laptop napped for
        # two minutes at 17:36, Icecast dropped /superdark.mp3 on "socket
        # timeout", and ffmpeg here kept writing for 80 minutes into a
        # connection nobody was reading. Its stdin never broke, so the
        # respawn below never ran. The stream was dead and every counter said
        # it was fine. Parsed from the command, not configured twice.
        m = re.search(r"icecast://(?:[^@\s]*@)?([^/\s]+)(/\S+)", cmd)
        self.status_url = f"http://{m.group(1)}/status-json.xsl" if m else None
        self.mount = m.group(2) if m else None
        self.spawned_at = 0.0
        self.last_probe = 0.0
        self.mount_missing = 0

    def _spawn(self):
        self.proc = subprocess.Popen(self.cmd, shell=True, stdin=subprocess.PIPE)
        self.spawned_at = time.monotonic()
        self.last_probe = self.spawned_at
        self.mount_missing = 0

    def _mount_alive(self):
        """None if the question cannot be asked; else whether Icecast lists it."""
        if not self.status_url:
            return None
        try:
            with urllib.request.urlopen(self.status_url, timeout=5) as r:
                d = json.load(r)
        except Exception:
            return None
        src = d.get("icestats", {}).get("source", [])
        src = src if isinstance(src, list) else [src]
        return any((s.get("listenurl") or "").endswith(self.mount) for s in src)

    def _probe(self):
        """Every 60 s after the first 90 s of a spawn: if Icecast has not
        listed the mount on two consecutive probes, kill ffmpeg. The next
        write raises BrokenPipeError and the respawn path below takes over,
        which is the one path that has been exercised 440 times."""
        now = time.monotonic()
        if now - self.spawned_at < 90 or now - self.last_probe < 60:
            return
        self.last_probe = now
        alive = self._mount_alive()
        if alive is None:
            return
        self.mount_missing = 0 if alive else self.mount_missing + 1
        if self.mount_missing >= 2:
            print(f"  encoder: {self.mount} absent from Icecast on 2 probes; "
                  "killing ffmpeg so it respawns", flush=True)
            try:
                self.proc.kill()
            except Exception:
                pass

    def run(self):
        # SPAWN LAZILY, ON THE FIRST BLOCK OF AUDIO. Spawning at start-up means
        # ffmpeg opens the Icecast connection and then sends nothing until the
        # factory attaches; Icecast's source-timeout is 30 s, so any longer gap
        # kills the source and the first real audio arrives on a dead socket.
        # That happened on the very first cutover, 1 Sept: the encoder was up
        # about five minutes before the factory, died, and was only recovered by
        # the respawn below. Waiting for data removes the race instead of
        # surviving it.
        #
        # OPERATIONAL NOTE: this thread can be restarted freely, but the
        # SPLITTER cannot be restarted while the factory is running. It holds
        # the read end of the pipe; dropping it sends SIGPIPE to scsynth. Stop
        # the factory first.
        first = self.take(timeout=None)
        if first is None:
            return
        self._spawn()
        pending = first
        while not self.stop.is_set():
            b = pending if pending is not None else self.take()
            pending = None
            if b is None:
                continue
            self._probe()
            try:
                self.proc.stdin.write(b)
                self.written += len(b)
            except (BrokenPipeError, OSError, ValueError):
                # The encoder died. Respawn it. The factory is unaffected: it has
                # been writing into the pipe throughout, and this thread has been
                # dropping on its behalf.
                self.restarts += 1
                try:
                    # Close the dead pipe explicitly. Leaving it to the garbage
                    # collector prints "Exception ignored in BufferedWriter"
                    # with a traceback pointing at the RESPAWN line, which reads
                    # like the recovery crashing when it is only the corpse
                    # being swept up.
                    self.proc.stdin.close()
                except Exception:
                    pass
                try:
                    self.proc.kill()
                except Exception:
                    pass
                time.sleep(2.0)
                self._spawn()


class Segmenter(Sink):
    def __init__(self, segdir, seconds, maxitems, ring_gb):
        super().__init__("segmenter", maxitems)
        self.dir = segdir
        self.seconds = seconds
        self.ring = ring_gb * (1 << 30)
        os.makedirs(segdir, exist_ok=True)
        self.n = 0

    def _prune(self):
        """A cap the ingester's own deletion cannot be relied on to enforce.

        If the ingester is stopped -- as it was all of 1 Sept, because of the very
        conflict this topology removes -- segments accumulate unnoticed. This is
        the backstop, not the plan.
        """
        files = sorted(
            (os.path.join(self.dir, f) for f in os.listdir(self.dir)
             if f.endswith(".wav")), key=lambda p: os.path.getmtime(p))
        total = sum(os.path.getsize(f) for f in files)
        while total > self.ring and len(files) > 1:
            victim = files.pop(0)
            total -= os.path.getsize(victim)
            try:
                os.unlink(victim)
            except OSError:
                pass

    def run(self):
        import numpy as np
        import wave
        need = int(self.seconds * SR) * ITEM
        buf, have = [], 0
        while not self.stop.is_set():
            b = self.take()
            if b is not None:
                buf.append(b)
                have += len(b)
            if have < need:
                continue
            data = b"".join(buf)
            keep = data[need:]
            data = data[:need]
            buf, have = ([keep], len(keep)) if keep else ([], 0)

            stamp = time.strftime("%y%m%d_%H%M%S")
            base = os.path.join(self.dir, f"cap_{stamp}_{self.n:04d}")
            self.n += 1
            x = np.frombuffer(data, dtype="<f4").reshape(-1, CH)
            # 32-bit signed PCM, matching self_ingest.write_grain/read_grain
            # exactly (`<i4`, sampwidth 4). soundfile is NOT installed here and
            # the whole project reads audio through stdlib `wave`; writing a
            # format the ingester cannot open would be a silent starvation.
            y = (np.clip(np.nan_to_num(x), -1.0, 1.0)
                 * (2 ** 31 - 1)).astype("<i4")
            try:
                # WRITE UNDER .part, PUBLISH BY RENAME. rename is atomic within a
                # filesystem, so a consumer either sees a complete segment or no
                # segment. It never sees one being written.
                with wave.open(base + ".part", "wb") as w:
                    w.setnchannels(CH)
                    w.setsampwidth(4)
                    w.setframerate(SR)
                    w.writeframes(y.tobytes())
                os.rename(base + ".part", base + ".wav")
                self.written += len(data)
                self._prune()
            except Exception as e:
                print(f"  segmenter: {type(e).__name__}: {e}", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fifo", required=True)
    ap.add_argument("--segdir", required=True)
    ap.add_argument("--encoder-cmd", required=True)
    ap.add_argument("--segment-seconds", type=float, default=600.0)
    ap.add_argument("--encoder-buffer", type=float, default=4.0,
                    help="seconds of slack for the encoder before it loses audio")
    ap.add_argument("--segment-buffer", type=float, default=30.0)
    ap.add_argument("--ring-gb", type=float, default=8.0)
    ap.add_argument("--status-every", type=float, default=60.0)
    ap.add_argument("--spectrogram", default="/tmp/superdark_spectrogram.json")
    a = ap.parse_args()

    per = READ / (SR * ITEM)
    enc = Encoder(a.encoder_cmd, max(2, int(a.encoder_buffer / per)))
    seg = Segmenter(a.segdir, a.segment_seconds,
                    max(2, int(a.segment_buffer / per)), a.ring_gb)
    # Small queue: if the spectrogram falls behind it should drop columns and
    # stay current, never accumulate a backlog and draw the past.
    spec = Spectrogram(a.spectrogram, max(2, int(4.0 / per)))
    enc.start()
    seg.start()
    spec.start()

    def bye(*_):
        enc.stop.set(); seg.stop.set()
        try:
            enc.proc.terminate()
        except Exception:
            pass
        sys.exit(0)
    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGINT, bye)

    print(f"  splitter: fifo={a.fifo}", flush=True)
    print(f"  encoder slack {a.encoder_buffer:.0f}s, segments {a.segment_seconds:.0f}s, "
          f"ring {a.ring_gb:g} GB", flush=True)

    # Opening a FIFO for read BLOCKS until a writer appears. That is the correct
    # behaviour here: the splitter may legitimately start before the factory.
    fd = os.open(a.fifo, os.O_RDONLY)
    print("  writer attached", flush=True)
    read_total = 0
    t0 = last = time.time()
    with os.fdopen(fd, "rb", buffering=0) as f:
        while True:
            b = f.read(READ)
            if not b:
                # WRITER CLOSED. THE PROCESSES SURVIVED AND THE STREAM DID NOT.
                #
                # This reopened the FIFO with a BLOCKING os.open and fed the
                # encoder nothing until the next writer appeared. The factory
                # takes about two minutes to boot and load 7,200 buffers, so
                # every restart left the encoder with no input for two minutes,
                # Icecast with nothing to send, and every listener's player
                # stalling. Measured 3 Sept after nine restarts in a day:
                # clock skew -1267.5 s, which is 21 minutes of missing audio and
                # matches 9 x 2 min almost exactly. Roberto: "the streaming keeps
                # interrupting."
                #
                # The topology's whole claim was that delivery survives a factory
                # restart. The PROCESSES survived -- ffmpeg ran two hours across
                # four restarts without respawning -- and the STREAM starved,
                # which is the half that a listener experiences.
                #
                # So the wait happens on a thread and the main loop keeps the
                # encoder fed with silence, paced against the wall clock so the
                # mp3 timeline advances at real time. A continuous quiet stream
                # is a factory between behaviours; a stalled stream is a dead
                # station. The factory is silent about 21% of windows anyway, so
                # this is not audibly a different kind of event.
                print("  writer gone, filling with silence until another",
                      flush=True)
                f.close()
                box, t_gap = [], time.time()
                th = threading.Thread(
                    target=lambda: box.append(os.open(a.fifo, os.O_RDONLY)),
                    daemon=True)
                th.start()
                fed = 0.0
                quiet = b"\x00" * READ
                per = READ / (SR * ITEM)          # seconds of audio per block
                while not box:
                    # only emit when the clock has actually advanced past what
                    # has been fed, or the encoder is handed a burst and the
                    # stream runs ahead of real time
                    if fed < (time.time() - t_gap):
                        enc.offer(quiet)
                        seg.offer(quiet)
                        fed += per
                    else:
                        time.sleep(per / 4)
                fd = box[0]
                f = os.fdopen(fd, "rb", buffering=0)
                print(f"  writer back after {time.time() - t_gap:.1f}s, "
                      f"{fed:.1f}s of silence sent", flush=True)
                continue
            read_total += len(b)
            enc.offer(b)
            seg.offer(b)
            spec.offer(b)
            now = time.time()
            if now - last >= a.status_every:
                last = now
                rt = read_total / (SR * ITEM)
                print(f"  {rt/3600:6.2f}h read | encoder {enc.written/(SR*ITEM)/3600:6.2f}h "
                      f"drop {enc.dropped} restart {enc.restarts} | "
                      f"segments {seg.n} drop {seg.dropped} | "
                      f"clock skew {rt - (now - t0):+.1f}s", flush=True)


if __name__ == "__main__":
    main()
