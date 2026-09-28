#!/usr/bin/env python3
"""Day 1, C-I: the world channel.

Opens a live input, embeds it in the corpus geometry, and sends the result to
the factory over OSC. This is the exogenous process W_t that ¶36 requires: a
signal the factory does not generate and the investigator does not specify.

WHY THE ANALYSIS IS HERE AND NOT IN SUPERCOLLIDER
-------------------------------------------------
31_Class3_Roadmap.md §2.1 says the world must be embedded "by exactly the map
the corpus was", reusing the stored `_pca_mean`, `_pca_scale`, `_pca_components`.
It assumed SuperCollider would compute the incoming MFCCs. It cannot compute
THIS map. The corpus MFCCs come from the hand-written filterbank in
`analyse_mfcc.py` -- 2595*log10(1+f/700), triangular bands floor-quantised onto
FFT bins, log with a 1e-10 floor, DCT-II, coefficient 0 dropped, then mean and
std per coefficient for 24 dimensions. SuperCollider's `MFCC.kr` uses a
different band count, a different filterbank and different scaling. Projecting
its output through `_pca_components` would produce a number per frame and none
of them would mean anything, with no error raised.

That is the failure this project keeps hitting: a transform applied to the wrong
input, silent, output that looks like data. So the analysis runs HERE, importing
`mfcc_stats` from `analyse_mfcc` directly. The map is identical because it is
the same function, not a reimplementation of it. "Factory and world live in one
metric space" becomes true by construction rather than by careful porting.

A SECOND BENEFIT, worth stating because it removes a known hazard. SuperCollider
never opens an input device. When it did, macOS renegotiated the headphone link
to a hands-free profile and the entire transport dropped to 24 kHz through a
speech codec; seven consecutive diagnoses were spent on the resulting artefact
before anyone read the sample rate printed at the top of every log. Capture
happens in ffmpeg, in a separate process, on an explicitly named device.

LATENCY is a window, not an event. §2.2 of the roadmap requires per-window
precomputation and forbids per-event work in the OSC callback -- doing O(k*n)
distance work there froze the factory once. Windows are ten to twenty seconds.
A one-second analysis hop is far inside that budget.

NO NEW DEPENDENCIES. numpy and ffmpeg only. OSC is hand-encoded below; the
protocol is a padded string, a type tag, and big-endian floats.

USAGE
    python3 tools/world_listen.py --device 6 --port 57120
    python3 tools/world_listen.py --list
    python3 tools/world_listen.py --device 6 --dry-run    # print, do not send
    python3 tools/world_listen.py --url https://.../replica.mp3   # the other factory
"""
import argparse
import json
import os
import struct
import socket
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from analyse_mfcc import mel_filterbank, mfcc_stats, N_MEL, N_MFCC, FFT  # noqa: E402

CORPUS_SR = 22050          # asserted against the corpus below, never assumed
HOP_SECONDS = 1.0          # one w_t per second; the factory consumes per window


# ---------------------------------------------------------------- OSC, by hand
def _pad(b):
    return b + b"\0" * (4 - len(b) % 4)


def osc_message(address, floats):
    """A minimal OSC 1.0 message: address, ',fff...', big-endian float32s."""
    out = _pad(address.encode() + b"\0")
    out += _pad(("," + "f" * len(floats)).encode() + b"\0")
    for f in floats:
        out += struct.pack(">f", float(f))
    return out


# ------------------------------------------------------------------- transform
def load_transform(descriptors_path):
    """The stored standardiser and PCA basis, exactly as analyse_mfcc wrote them.

    Refuses to run if they are absent, rather than falling back to something
    plausible. A world projected through the wrong basis is worse than no world:
    it is a coupling that cannot be detected as false.
    """
    with open(descriptors_path) as fh:
        d = json.load(fh)
    for k in ("_pca_mean", "_pca_scale", "_pca_components"):
        if k not in d:
            raise SystemExit(
                f"ABORT: {descriptors_path} has no {k}.\n"
                "  The corpus was not built by analyse_mfcc.py, so there is no\n"
                "  map to embed the world by. Rebuild the corpus first."
            )
    mu = np.asarray(d["_pca_mean"], dtype=float)
    sc = np.asarray(d["_pca_scale"], dtype=float)
    C = np.asarray(d["_pca_components"], dtype=float)
    if mu.shape != (2 * (N_MFCC - 1),):
        raise SystemExit(
            f"ABORT: _pca_mean has shape {mu.shape}, expected "
            f"{(2 * (N_MFCC - 1),)} for N_MFCC={N_MFCC}.\n"
            "  The corpus was analysed with different constants than this file "
            "carries."
        )
    sc = np.where(sc == 0, 1.0, sc)          # a constant dimension must not divide by 0
    return mu, sc, C


def derive_scaling(grain_dir, mu, sc, C, fb, sr, n_probe=40):
    """Recover the per-component 0..1 scaling the corpus was written in.

    `analyse_mfcc.py` stores the standardiser and the PCA basis but NOT the final
    linear rescale, which is applied as

        Yn = (Y - lo) / (hi - lo)

    per component. The factory's `target`, every section centre and every
    `desc["norm"]` value live in that 0..1 space, so a world emitted in raw PCA
    coordinates would be in a DIFFERENT space from the thing it is supposed to
    share a metric with -- and it would still be five plausible numbers, so
    nothing would complain. That is the exact failure that put 2,389 grains on
    the wrong descriptors.

    lo and hi are recoverable exactly. Yn is affine in Y, so two grains with
    known Y and Yn determine both. Using many grains and least squares instead
    of two makes the residual a CHECK rather than an assumption: if the stored
    values were not produced by this transform, the fit will not be tight and we
    refuse to run.
    """
    import glob
    import wave

    d = json.load(open(os.path.join(grain_dir, "descriptors.json")))
    norm = d["norm"]
    files = sorted((f for f in os.listdir(grain_dir) if f.endswith(".wav")),
                   key=lambda f: int(f[1:-4]))
    step = max(1, len(files) // n_probe)
    idx = list(range(0, len(files), step))[:n_probe]

    Y = []
    for i in idx:
        with wave.open(os.path.join(grain_dir, files[i])) as w:
            ch, swid = w.getnchannels(), w.getsampwidth()
            raw = w.readframes(w.getnframes())
        dt = "<i4" if swid == 4 else "<i2"
        div = 2 ** 31 if swid == 4 else 2 ** 15
        x = np.frombuffer(raw, dtype=dt).astype(float) / div
        x = x.reshape(-1, ch).mean(axis=1)
        Y.append(C @ ((mfcc_stats(x, sr, fb) - mu) / sc))
    Y = np.array(Y)

    lo = np.zeros(Y.shape[1])
    hi = np.zeros(Y.shape[1])
    for j in range(Y.shape[1]):
        yn = np.array([norm[f"pc{j}"][i] for i in idx])
        # Yn = a*Y + b  with  a = 1/(hi-lo),  b = -lo/(hi-lo)
        A = np.vstack([Y[:, j], np.ones_like(Y[:, j])]).T
        (a, b), *_ = np.linalg.lstsq(A, yn, rcond=None)
        resid = float(np.max(np.abs(A @ [a, b] - yn)))
        if resid > 1e-3 or abs(a) < 1e-12:
            raise SystemExit(
                f"ABORT: component pc{j} does not fit an affine map "
                f"(max residual {resid:.2e}).\n"
                "  descriptors.json was not produced by this transform, so the "
                "world cannot be placed in the corpus geometry. Rebuild it with "
                "analyse_mfcc.py before opening a world channel."
            )
        hi[j] = (1.0 - b) / a
        lo[j] = -b / a
    return lo, hi


def assert_corpus_rate(grain_dir):
    """The filterbank is a function of the sample rate. If the live capture and
    the corpus disagree, every projected coordinate is wrong and nothing says so.
    """
    import glob
    import wave
    wavs = sorted(glob.glob(os.path.join(grain_dir, "*.wav")))[:1]
    if not wavs:
        return CORPUS_SR
    with wave.open(wavs[0]) as w:
        sr = w.getframerate()
    # THE CORPUS RATE WINS. analyse_mfcc.py reads sr from each grain and builds
    # mel_filterbank(sr, FFT, N_MEL) from it, so the stored PCA was fit on
    # MFCCs at the corpus's own rate. Doing the same here keeps the map
    # identical by construction. Until 20 Sept this aborted when the corpus
    # differed from the 22050 constant above -- and every corpus has been
    # 44100 since 26 Aug, so the listener had been unrunnable for 25 days
    # without anyone noticing, because nothing ran it.
    if sr != CORPUS_SR:
        print(f"  corpus is {sr} Hz (this file's default was {CORPUS_SR}); "
              "following the corpus, as analyse_mfcc.py does")
    return sr


# --------------------------------------------------------------------- capture
def ffmpeg_stream(device, sr):
    """Raw mono float32 from an explicitly named avfoundation device."""
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error",
        "-f", "avfoundation", "-i", f":{device}",
        "-ac", "1", "-ar", str(sr),
        "-f", "f32le", "-",
    ]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def ffmpeg_url(url, sr):
    """Raw mono float32 from an HTTP(S) stream: the other factory.

    20 Sept, Class 3 target 3: one factory consumes the other. The other
    factory is on another computer and the only thing that crosses between
    them is the relay's mp3. Decoded here by the same ffmpeg, resampled to the
    corpus rate, then handed to the same mfcc_stats as a room would be. The
    relay adds its own latency (seconds); §2.2's budget is a window (10-20 s),
    so it fits. -reconnect flags so a relay hiccup does not end the run, and
    no -re: read as fast as the server sends, which for a live Icecast mount
    is real time by construction.
    """
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error",
        "-reconnect", "1", "-reconnect_streamed", "1",
        "-reconnect_delay_max", "10",
        "-i", url,
        "-ac", "1", "-ar", str(sr),
        "-f", "f32le", "-",
    ]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def list_devices():
    p = subprocess.run(["ffmpeg", "-f", "avfoundation", "-list_devices", "true",
                        "-i", ""], capture_output=True, text=True)
    tail = p.stderr.split("AVFoundation audio devices:")
    print("audio input devices:")
    if len(tail) > 1:
        for line in tail[1].splitlines():
            if "] [" in line:
                print("   ", line.split("] ", 1)[1])


# ------------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default=None,
                    help="avfoundation audio device index; see --list")
    ap.add_argument("--url", default=None,
                    help="HTTP(S) audio stream to consume instead of a device "
                         "(the other factory's relay mount)")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=57120,
                    help="sclang's OSC port")
    ap.add_argument("--address", default="/world")
    ap.add_argument("--grains", default=None,
                    help="corpus dir holding descriptors.json")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--dry-run", action="store_true",
                    help="print w_t instead of sending it")
    ap.add_argument("--log", default=None, help="append w_t to this file")
    ap.add_argument("--log-only", action="store_true",
                    help="neither send nor print: only --log. For the SECOND "
                         "listener on the factory's own output, which gives the "
                         "acceptance test its other series in the same space")
    a = ap.parse_args()
    if a.log_only and not a.log:
        raise SystemExit("ABORT: --log-only needs --log")

    if a.list:
        list_devices()
        return

    if a.device is None and a.url is None:
        raise SystemExit("ABORT: --device or --url is required. Run --list to see devices.\n"
                         "  Never let the host pick implicitly: that is how the\n"
                         "  transport ended up at 24 kHz through a speech codec.")

    grains = a.grains or os.path.join(
        os.path.dirname(HERE), "workdir_music", "grains_ev")
    sr = assert_corpus_rate(grains)
    mu, sc, C = load_transform(os.path.join(grains, "descriptors.json"))
    fb = mel_filterbank(sr, FFT, N_MEL)
    lo, hi = derive_scaling(grains, mu, sc, C, fb, sr)
    span = np.where((hi - lo) == 0, 1.0, hi - lo)
    print("  corpus 0..1 scaling recovered: "
          + "  ".join(f"pc{j}[{lo[j]:+.2f},{hi[j]:+.2f}]" for j in range(len(lo))))

    hop = int(sr * HOP_SECONDS)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    proc = ffmpeg_url(a.url, sr) if a.url else ffmpeg_stream(a.device, sr)

    print(f"world -> {a.host}:{a.port}{a.address}   "
          f"{'url ' + a.url if a.url else 'device ' + str(a.device)}   "
          f"{sr} Hz   hop {HOP_SECONDS}s   dims {C.shape[0]}")
    print("  ctrl-c to stop")

    logfh = open(a.log, "a") if a.log else None
    nbytes = hop * 4
    silent_frames = 0
    try:
        while True:
            raw = proc.stdout.read(nbytes)
            if not raw or len(raw) < nbytes:
                err = proc.stderr.read().decode(errors="replace")[:400]
                raise SystemExit(f"ABORT: capture ended.\n{err}")
            mono = np.frombuffer(raw, dtype="<f4").astype(float)

            rms = float(np.sqrt(np.mean(mono ** 2)))
            # A dead input is a real condition and must be visible, not averaged
            # away. If the room is silent the world contributes nothing and the
            # Day 1 acceptance test SHOULD fail; that is information.
            if rms < 1e-5:
                silent_frames += 1
                if silent_frames % 10 == 1:
                    print(f"  input silent ({silent_frames}x). "
                          "Is the device right?", flush=True)
            else:
                silent_frames = 0

            x = mfcc_stats(mono, sr, fb)
            # into the SAME 0..1 space the factory's target and section centres
            # live in. NOT clipped: a world outside the corpus range is a real
            # condition and the factory should be able to be pulled off the edge
            # of what it has. Clipping here would quietly make the world look
            # more like the corpus than it is.
            w = ((C @ ((x - mu) / sc)) - lo) / span

            payload = list(w) + [rms]
            if a.log_only:
                pass
            elif a.dry_run:
                print("  w = " + "  ".join(f"{v:+.3f}" for v in w)
                      + f"   rms {rms:.5f}", flush=True)
            else:
                sock.sendto(osc_message(a.address, payload), (a.host, a.port))
            if logfh:
                logfh.write(f"{time.time():.3f}," +
                            ",".join(f"{v:.6f}" for v in payload) + "\n")
                logfh.flush()
    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        proc.terminate()
        if logfh:
            logfh.close()


if __name__ == "__main__":
    main()
