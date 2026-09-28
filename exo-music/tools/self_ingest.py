#!/usr/bin/env python3
"""Self-ingestion by ADMISSION CONTROL: new material must beat what it replaces.

WHAT THIS IS FOR
----------------
Everything the factory plays is derived from FMA. Its supply chain terminates in
material the architect chose, which is exactly P113's *c*. Self-ingestion pushes
away from c -- the factory acquiring material nobody supplied, faster than it can
be reconstituted (P75, r > 0).

THE MECHANISM IS COMPETITIVE, NOT ACCUMULATIVE
----------------------------------------------
Roberto, 28 Aug: "new sound will not necessarily replace the original FMA unless
there is an improvement... the ingestion is selective and based on the
qualitative difference between ingested and discarded material."

So this is not "record everything, granulate, keep, evict when the disk fills".
A candidate grain is scored against the CURRENT WEAKEST INCUMBENT of its layer
and is admitted only if it beats that incumbent by at least --margin. If it does,
it takes the incumbent's slot IN PLACE, keeping the same integer index and
filename. If it does not, it is discarded and the corpus is unchanged.

Three things follow, and they are why this design is better than the ring buffer
it replaces:

  FIXED SIZE     the pool never grows, so storage is constant and the ring-size
                 question disappears. 2400 ev + 1800 mid + 1200 macro, forever.
  STABLE INDICES the factory indexes grains by integer and reads a parallel
                 descriptors.json; in-place replacement keeps g07.wav meaning
                 slot 7 and never renumbers the corpus underneath a running
                 factory.
  A MEASURABLE   every admission and every rejection is journalled with its score
  DIFFERENCE     margin, so "qualitative difference between ingested and
                 discarded material" is a recorded quantity and not an
                 assumption about one.

THE RISK, STATED ONCE
---------------------
Admission and eviction now run on the SAME score, so the corpus is filtered twice
by one criterion. That is the audibility-score failure with more teeth: runs
53-58 measured a self-generated criterion becoming a convergence engine -- what
sounded got weighted up, got selected more, kept sounding -- and the vocabulary
fell from nine machines to four. P502 names the general form: when the thing
judged and the judgement share a vocabulary, they drift together and neither
notices.

Two brakes, both explicit rather than clever:
  the `distinct` term in score_grain rewards distance from the corpus centroid,
  so it actively opposes the `audible` term and keeps outliers alive;
  --margin > 0 means a candidate must be BETTER, not merely different, which
  stops churn from replacing the corpus with noise of equal score.

Neither brake is trusted. The journal is what settles it.

THE SEED IS DELETABLE
---------------------
An earlier version protected the generation-0 FMA material as a hard cast, on the
argument that deletion is the irreversible harm P458 says a hard world must make
impossible. That does not survive scrutiny: the seed is regenerable, and more
importantly, flooring FMA material into the corpus permanently guarantees the
factory's supply chain always contains material the architect chose -- P113's *c*
made unescapable BY CONSTRUCTION. It also breaks the measurement, since immortal
generation-0 grains drag the mean generation toward zero forever.

Roberto's resolution, 28 Aug: "keep the original FMA seeds as duplicate but allow
the system to delete the copy that it is working with." So the ARCHIVE
(grains_lic_*) is immutable and never opened by the factory; the POOL is a
working copy with no special status, and generation-0 grains compete and die on
the same terms as everything else. Recovery is a file copy. That is the honest
reading of a hard world: not one where nothing can be destroyed, but one where
nothing is UNRECOVERABLE.

VETTING IS PHYSICAL, SCORING IS SEPARATE
----------------------------------------
A candidate is REJECTED OUTRIGHT only for being silent, clipped, DC-offset,
non-finite, constant or IMPULSIVE -- facts about the signal. Whether it is any
good is the score's business, and the score only ever decides a comparison
against an incumbent, never an absolute standard. Keeping those two gates apart
is what stops the physical filter from quietly becoming an aesthetic one.

"Impulsive" was added on 31 Aug, after the loop was closed and immediately began
feeding the factory its own clicks. The other five tests were chosen as facts
about the signal, and a click is exactly as much a fact about the signal as a DC
offset; it was left out because nobody had written a detector for it yet, not
because it belonged on the aesthetic side of the line. Measured within hours of
closing the loop: 28% of admitted grains were over the damage threshold against
0% of the seed, p90 867 against 7.6. A click sounds, is captured, is cut into a
grain, is admitted, sounds again, and comes back louder.

    python3 tools/self_ingest.py --init --out-root RING --archive-dirs A,B,C
    python3 tools/self_ingest.py --capture-dir CAP --out-root RING --once
"""
import argparse
import glob
import json
import os
import random
import shutil
import subprocess
import sys
import time
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import descriptor_basis as DB                  # noqa: E402
import build_grains_onset as BGO               # noqa: E402
from audit_grain_transients import grain_score as _grain_score  # noqa: E402

# THE SAMPLE RATE IS DETECTED, NEVER ASSUMED.
#
# This was the bare constant 22050 until 31 Aug 2026. That morning the corpora
# were resampled to 44100 so PlayBuf would stop interpolating and manufacturing
# imaging above the corpus Nyquist. This constant was not updated with them, so
# every admitted grain went on being written at 22050 INTO A 44100 POOL. Nothing
# errored, and two things went wrong quietly:
#
#   1. mfcc_stats read those grains at the wrong rate, so admitted grains
#      received coordinates unrelated to how they sound. Measured: rank
#      correlation 0.50 on ev, against 1.00000 for generation-0 slots.
#   2. Played back, BufRateScale would have resampled them 22050 -> 44100 and
#      put back exactly the interpolation imaging the resample had just
#      removed. Every grain the factory made from its own output would hiss.
#
# So it is now read off the pool at startup and asserted. A corpus rate change
# cannot silently desynchronise the ingester again.
SR = 44100


def detect_sr(pool_root, layers):
    """Read the sample rate the pool is actually stored at, and insist it is
    consistent. Disagreement between layers means a half-finished migration,
    which is worse than either rate and must stop the run."""
    import wave as _wave
    found = {}
    for layer in layers:
        d = os.path.join(pool_root, f"grains_pool_{layer}")
        for i in range(4):
            p = os.path.join(d, f"g{i:02d}.wav")
            if os.path.exists(p):
                with _wave.open(p) as w:
                    found[layer] = w.getframerate()
                break
    rates = set(found.values())
    if not rates:
        return None, found
    if len(rates) > 1:
        raise SystemExit(f"  POOL RATES DISAGREE {found}; refusing to ingest")
    return rates.pop(), found


# durations measured off the licence-clean corpora; these must match exactly or
# the factory loads a corpus with two different grain lengths in it
LAYERS = {"ev": 0.060, "mid": 0.400, "macro": 2.000}
FLOOR_DB = -45.0          # the floor build_grains.py uses, deliberately the same
# OVERRIDDEN FROM POLICY AT STARTUP, and it had to be, because -45 was set for a
# CORPUS BUILDER and then applied to the factory's own output.
#
# build_grains.py cuts grains from commercial recordings, which are mastered
# loud, so -45 dBFS there discards genuine silence and nothing else. The factory
# is not mastered loud: measured 8 Sept, the delivered stream runs about -41 dB
# mean. Its own material therefore sits about four decibels above the floor, and
# roughly HALF of every batch was being thrown out as "silent" before admission
# control ever scored it:
#
#     per 10-minute segment, ~360 candidates
#     ev 0-1 admitted | mid 0 | macro 0 | rejected ~180 silent, ~180 outscored
#
# Zero for macro every segment, all day. Mean generation frozen at ev 0.270,
# macro 0.518, mid 0.368 against a pre-registered target of twenty. So
# self_ingest_weight 0.75 was drawing three quarters of the play corpus from a
# pool that had stopped growing -- recycling grains admitted days earlier rather
# than incorporating anything the factory is making now.
#
# Roberto, 8 Sept: "the system admits a small percentage of grains ... accept
# silent grains."
#
# THIS IS A LOUDNESS GATE AND NOT A VALIDITY GATE, which is why lowering it is
# safe. Genuinely empty audio is caught by the `constant` test below -- max
# amplitude under 1e-6, or standard deviation under 1e-7 -- and that test is
# untouched. What the floor rejects is quiet-but-real material, which is exactly
# what a factory running at -41 dB produces and exactly what it needs to eat.
FLOOR_DB_DEFAULT = FLOOR_DB
CLIP_FRAC_MAX = 0.01
# Same threshold as build_grains_onset --max-transient. Admission must not hold
# the factory's own output to a laxer standard than the corpus it was seeded
# from; if it does, the pool drifts toward whatever admission does not measure.
MAX_TRANSIENT = 40.0
DC_MAX = 0.01


# ---------------------------------------------------------------- io

def decode(path, sr=None):
    """Stereo float32 at sr via ffmpeg.

    Captures are AIFF-C regardless of extension -- SuperCollider's
    recHeaderFormat defaults to aiff and server.record does not rename by
    extension -- so never infer the format from the filename here.
    """
    sr = SR if sr is None else sr        # resolved at CALL time; a default of
    # sr=SR would bind at import and freeze the pre-detection value
    try:
        r = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le",
             "-acodec", "pcm_f32le", "-ac", "2", "-ar", str(sr), "-"],
            capture_output=True, timeout=1800)
        x = np.frombuffer(r.stdout, dtype=np.float32)
        if len(x) >= 2:
            return x.reshape(-1, 2)
    except Exception:
        pass
    return decode_unclosed(path, sr)


def decode_unclosed(path, sr=None):
    """Recover a capture the factory never closed.

    SuperCollider writes an AIFF's SSND chunk size only on close, so a chunk
    interrupted by a crash, a SIGTERM, or a power cut reports duration=N/A and
    ffmpeg decodes nothing from it -- even though every sample is on disk and
    perfectly intact. Losing up to a full rotation interval of the factory's
    output to a header field would be an absurd way to lose data, and the
    factory WILL be interrupted: that is the normal case over a long run, not
    the exceptional one.

    The audio starts immediately after the SSND chunk header (id, size, offset,
    blockSize = 16 bytes). ffprobe still reports the stream parameters correctly
    from COMM even when the size field is zero, so the format is read rather
    than assumed, and the samples are piped in raw.
    """
    sr = SR if sr is None else sr        # see decode(): resolved at call time
    try:
        with open(path, "rb") as f:
            head = f.read(65536)
        i = head.find(b"SSND")
        if i < 0:
            return None
        start = i + 16

        pr = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "a:0",
             "-show_entries", "stream=sample_rate,channels,codec_name",
             "-of", "default=nw=1:nk=1", path],
            capture_output=True, text=True, timeout=120)
        vals = [v.strip() for v in pr.stdout.split() if v.strip()]
        codec = next((v for v in vals if not v.isdigit()), "pcm_f32be")
        nums = [int(v) for v in vals if v.isdigit()]
        if len(nums) < 2:
            return None
        rate, ch = max(nums), min(nums)

        with open(path, "rb") as f:
            f.seek(start)
            raw = f.read()
        if not raw:
            return None
        fmt = {"pcm_f32be": "f32be", "pcm_f32le": "f32le",
               "pcm_s16be": "s16be", "pcm_s24be": "s24be"}.get(codec, "f32be")
        # trim to a whole number of frames so ffmpeg is not handed a partial one
        width = 4 if "32" in fmt else (2 if "16" in fmt else 3)
        raw = raw[: (len(raw) // (width * ch)) * width * ch]

        r = subprocess.run(
            ["ffmpeg", "-v", "error", "-f", fmt, "-ar", str(rate), "-ac", str(ch),
             "-i", "pipe:0", "-f", "f32le", "-acodec", "pcm_f32le",
             "-ac", "2", "-ar", str(sr), "-"],
            input=raw, capture_output=True, timeout=1800)
        x = np.frombuffer(r.stdout, dtype=np.float32)
        if len(x) < 2:
            return None
        print(f"    recovered {len(x)//2/sr:.0f}s from an unclosed capture "
              f"({fmt} {rate}Hz {ch}ch)")
        return x.reshape(-1, 2)
    except Exception:
        return None


def write_grain(path, x, fade_ms=3.0):
    """32-bit PCM stereo at 22050, matching the archive's format AND its fade.

    The 3 ms fade is not cosmetic. Every grain in the archive carries one --
    build_grains_onset.py:122 applies it in write_grain -- because a grain cut at
    an arbitrary zero-crossing-agnostic offset starts and ends on a
    discontinuity, and the factory concatenates these at up to ~17 per second.
    Measured on the archive: first 66 samples peak at 0.12 against a body peak of
    0.89. Writing self-ingested grains unfaded would put a click at both ends of
    every one of them, and the ingested material would be audibly dirtier than
    the material it displaced for a reason that has nothing to do with its
    quality.
    """
    x = np.asarray(x, dtype=np.float64).copy()
    k = max(1, int(SR * fade_ms / 1000.0))
    if 2 * k < len(x):
        r = np.linspace(0.0, 1.0, k)[:, None]
        x[:k] *= r
        x[-k:] *= r[::-1]
    y = np.clip(np.nan_to_num(x), -1.0, 1.0)
    y = (y * (2 ** 31 - 1)).astype("<i4")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(4)
        w.setframerate(SR)
        w.writeframes(y.tobytes())


def read_grain(p):
    with wave.open(p) as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i4")
    return raw.reshape(-1, 2).astype(np.float32) / (2 ** 31 - 1)


# ---------------------------------------------------------------- gates

def vet(g):
    """Physical validity only. Returns (ok, reason)."""
    if not np.isfinite(g).all():
        return False, "nonfinite"
    if np.sqrt((g ** 2).mean()) < 10 ** (FLOOR_DB / 20):
        return False, "silent"
    if np.abs(g).max() < 1e-6 or g.std() < 1e-7:
        return False, "constant"
    if (np.abs(g) >= 0.999).mean() > CLIP_FRAC_MAX:
        return False, "clipped"
    if abs(g.mean()) > DC_MAX:
        return False, "dc_offset"
    # IMPULSIVE CONTENT IS A PHYSICAL FACT TOO, and leaving it out opened a
    # feedback loop for clicks.
    #
    # The five tests above are the ones this file's docstring calls "facts about
    # the signal": silent, constant, clipped, DC-offset, non-finite. A click is
    # equally a fact about the signal and was simply not among them, so clicks
    # were freely admissible. Measured 31 Aug, once the loop was closed and the
    # factory began playing its own material:
    #
    #     seed grains        median  4.2   p90   7.6   max   21.1    0% over 40
    #     SELF-INGESTED      median 10.4   p90 867.7   max 1949.1   28% over 40
    #
    # 28% of admitted grains were damaged against none of the seed. The loop
    # closes on itself: a click sounds, is captured, is cut into a grain, is
    # admitted, sounds again, and is re-ingested louder. Roberto heard the
    # result immediately and it survived the corpus gate, the resample and the
    # attack clamp because all three act on material the LOOP then bypasses.
    #
    # The threshold is the same 40 the corpus gate uses (build_grains_onset
    # --max-transient), deliberately: admission and corpus construction should
    # not hold new material to a laxer standard than the seed, or the pool
    # degrades toward whatever admission ignores.
    #
    # This is a REJECTION and not a score term. A score term would let a loud,
    # distinct, well-pitched click outbid a quiet clean grain, which is exactly
    # how the audibility score became a convergence engine in runs 53-58.
    r, _, _ = _grain_score(g.mean(1), SR)
    if r > MAX_TRANSIENT:
        return False, "impulsive"
    return True, ""


def describe(g):
    """Cheap spectral descriptors, computed identically for every layer so
    grains of different lengths stay comparable.

    pitch and clarity come from build_grains_onset.pitch_of, the same
    autocorrelation the corpus was built with, rather than a second
    implementation. Bounded to the first 0.2 s because np.correlate is O(n^2)
    and a 2 s macro grain would otherwise cost ~2 billion operations.
    """
    mono = g.mean(1)
    n = len(mono)
    S = np.abs(np.fft.rfft(mono * np.hanning(n))) + 1e-12
    f = np.fft.rfftfreq(n, 1 / SR)
    p = S / S.sum()
    centroid = float((f * p).sum())
    rms = float(np.sqrt((mono ** 2).mean()))
    cum = np.cumsum(p)
    pit, clar = BGO.pitch_of(mono[: int(0.2 * SR)], SR)
    return dict(
        pitch=float(pit), clarity=float(clar),
        centroid=centroid,
        spread=float(np.sqrt(((f - centroid) ** 2 * p).sum())),
        flatness=float(np.exp(np.log(S).mean()) / S.mean()),
        rms=rms,
        crest=float(np.abs(mono).max() / (rms + 1e-12)),
        rolloff=float(f[np.searchsorted(cum, 0.95)]) if len(f) else 0.0,
        rms_db=float(20 * np.log10(rms + 1e-12)))


def score_grain(d, cmean, cstd, w):
    """Retention score. HIGHER SURVIVES. See the header for why this is risky.

      audible     louder beats near-floor. THIS is the convergence term: it
                  rewards what already sounds, which is what fell nine machines
                  to four in runs 53-58.
      articulate  crest factor -- internal dynamics rather than flat sustain.
                  A cheap proxy for "there is an event in here".
      distinct    distance from the corpus centroid in descriptor space. This
                  term OPPOSES `audible` and keeps outliers alive. It is the
                  brake, and its weight is the most interesting number here.
    """
    audible = np.clip((d["rms_db"] + 60) / 40, 0, 1)
    articulate = np.clip(d["crest"] / 8.0, 0, 1)
    v = np.array([d["centroid"], d["spread"], d["flatness"], d["crest"]])
    z = (v - cmean) / (cstd + 1e-9)
    distinct = float(np.clip(np.sqrt((z ** 2).mean()) / 3.0, 0, 1))
    return float(w[0] * audible + w[1] * articulate + w[2] * distinct)


def harmonic_bonus(d, deficit, wh, band=0.02):
    """A HOMEOSTATIC pitch term. Returns a signed adjustment, not a gate.

    WHY THIS TERM EXISTS. Measured 28 Aug on one real capture: the factory's own
    output is 72.6% pitched with mean clarity 0.531, against an archive that is
    99.4% pitched at clarity 0.684 -- and that gap is present in ALL VETTED
    CANDIDATES, before scoring touches them. Granular synthesis over a grain path
    concatenates fragments of unrelated sources, so it breaks periodicity by
    construction and every generation is inherently less pitched than the last.
    Left alone, the pool sheds ~1% of its pitched grains per capture and the
    corpus converges toward noise. Pitch is carried separately in the descriptor
    space precisely because MFCCs cannot recover it; it is, in analyse_mfcc.py's
    words, "the axis harmony lives on".

    WHY IT IS NOT SIMPLY "PITCH IS BETTER". Roberto, 28 Aug: a pitch term "that
    still allows unpitched material to survive". A directional reward would fix
    the de-pitching by causing the opposite failure -- the corpus would fill with
    tone and lose the noise and transient material the factory equally needs, and
    it would be one more criterion rewarding a fixed direction, which is the
    convergence engine this project has already built once by accident.

    So the term tracks a DEFICIT against the seed's own pitched fraction:

        deficit > 0   the pool has lost harmonic content; pitched candidates are
                      rewarded and unpitched ones penalised
        deficit < 0   the pool has become too tonal; the sign flips and UNPITCHED
                      material is rewarded
        deficit = 0   no effect at all

    Rewarding whatever is scarce is structurally the opposite of an argmax rule,
    which is the behaviour P484 identifies as the thing that converges.

    THE DEFICIT NEEDS A SCALE. The first version multiplied the raw fraction by
    the weight: after losing 18 of 1800 pitched grains the deficit is 0.01, times
    a weight of 0.3 gives a 0.003 adjustment against admission margins around
    0.17. Sixty times too small to change any decision -- and measured as exactly
    that, since the A/B run produced identical drift with the term on and off. A
    one per cent loss of harmonic content is a large thing expressed as a small
    number, so the deficit is divided by a TOLERANCE BAND: drift of a full band
    saturates the term, and with the default band of 0.02 a one-point loss gives
    half strength.

    The magnitude stays deliberately bounded: at most wh, so with the default
    weight the adjustment cannot exceed 0.3 against a score range of 0..1 and
    observed margins around 0.15. A loud, articulate, distinct unpitched grain
    can still beat a mediocre pitched one. This is a thumb on the scale, not a
    filter.
    """
    if not wh or deficit == 0.0:
        return 0.0
    d_norm = float(np.clip(deficit / max(1e-9, band), -1.0, 1.0))
    c = float(np.clip(d.get("clarity", 0.0) / 0.6, 0.0, 1.0))
    return float(wh * d_norm * (2.0 * c - 1.0))


def pitched_fraction(entries, thresh=0.30):
    """Share of entries whose clarity clears pitch_of's own periodicity gate."""
    if not entries:
        return 0.0
    n = sum(1 for e in entries
            if e.get("desc", {}).get("clarity", 0.0) >= thresh)
    return n / len(entries)


# ---------------------------------------------------------------- pool

def pool_dir(root, layer):
    return os.path.join(root, f"grains_pool_{layer}")


def pool_dirs(root):
    return sorted(glob.glob(os.path.join(root, "grains_pool_*")))


def init_pool(archive_dirs, root, weights):
    """Copy the immutable archive into the ring as the working pool.

    Everything after this treats the pool uniformly: generation-0 FMA grains
    carry the same manifest schema, compete on the same scale and are displaced
    by the same rule as generation-N self-grains. There is no seed branch in the
    admission path to get wrong.
    """
    for src in archive_dirs:
        layer = os.path.basename(src.rstrip("/")).split("_")[-1]
        dst = pool_dir(root, layer)
        mp = os.path.join(dst, "manifest.json")
        if os.path.exists(mp):
            print(f"  pool {os.path.basename(dst)} exists, leaving it")
            continue
        files = sorted(glob.glob(os.path.join(src, "*.wav")),
                       key=lambda p: int("".join(c for c in os.path.basename(p)
                                                 if c.isdigit()) or 0))
        if not files:
            print(f"  ARCHIVE {src} has no grains, skipped")
            continue
        os.makedirs(dst, exist_ok=True)
        print(f"  {os.path.basename(src)} -> {os.path.basename(dst)}: "
              f"copying and scoring {len(files)} grains ...")
        descs, names = [], []
        for p in files:
            fn = os.path.basename(p)
            # copyfile, not copy2: exFAT has no chflags and copystat raises
            # EINVAL on it.
            shutil.copyfile(p, os.path.join(dst, fn))
            try:
                descs.append(describe(read_grain(p)))
            except Exception:
                descs.append(None)
            names.append(fn)
        A = np.array([[x["centroid"], x["spread"], x["flatness"], x["crest"]]
                      for x in descs if x])
        cm, cs = (A.mean(0), A.std(0)) if len(A) else (np.zeros(4), np.ones(4))
        man = {"_comment": "WORKING POOL. Fixed size; grains are replaced IN "
                           "PLACE by admission control, never appended. gen 0 is "
                           "the FMA working copy and is displaceable like "
                           "anything else. The immutable original is in "
                           "'archive'.",
               "archive": os.path.abspath(src), "layer": layer,
               "grain_seconds": LAYERS.get(layer, 0.0),
               "grains": 0, "admitted": 0, "rejected": 0, "manifest": []}
        for i, (fn, x) in enumerate(zip(names, descs)):
            if x is None:
                continue
            man["manifest"].append(dict(
                i=i, file=fn, gen=0.0, born=0.0,
                source="archive:" + os.path.basename(src),
                desc=x, score=round(score_grain(x, cm, cs, weights), 4)))
        man["grains"] = len(man["manifest"])
        # The seed's pitched fraction is the set point the harmonic term defends.
        # Recorded at init, from generation-0 material, so it cannot drift with
        # the pool it exists to anchor.
        man["pitched_target"] = round(pitched_fraction(man["manifest"]), 4)
        json.dump(man, open(mp, "w"), indent=1)
        print(f"    pitched fraction at generation 0: "
              f"{man['pitched_target']:.1%}  (the set point)")

        # descriptors.json travels with the audio. The factory reads it by grain
        # index for target, neighbourhood, nearest and grainPath, so a pool
        # without it is a corpus the factory cannot navigate. NOT manifest.json:
        # that name is taken by the pool's own admission record above, and the
        # archive's build provenance would overwrite it.
        dsrc = os.path.join(src, "descriptors.json")
        if os.path.exists(dsrc):
            shutil.copyfile(dsrc, os.path.join(dst, "descriptors.json"))
            print(f"    descriptors.json copied ({man['grains']} entries)")
        else:
            print("    WARNING: no descriptors.json in the archive; the factory "
                  "cannot navigate this pool")
        print(f"    {man['grains']} grains at generation 0, all displaceable")


def corpus_generation(root, weight):
    """The generation a newly ingested grain belongs to.

    A capture records the pool sounding, so a grain cut from it sits one
    generation beyond whatever sounded -- the pool, mixed in proportion to
    self_ingest_weight:

        1 + weight * mean(generation of the pool)

    With weight 0 the loop is OPEN: only generation-0 material sounds and every
    ingested grain is generation 1, forever. Reaching generation 20 requires
    raising the weight. The weight is the independent variable of this
    experiment, not a setting to leave alone.

    The mean is over the whole pool, so as generation-0 grains are displaced the
    mean climbs. The generation counter rising IS the corpus becoming its own
    material, which is the thing being measured.
    """
    if weight <= 0:
        return 1.0
    gens = []
    for d in pool_dirs(root):
        mp = os.path.join(d, "manifest.json")
        if not os.path.exists(mp):
            continue
        try:
            gens += [e["gen"] for e in json.load(open(mp)).get("manifest", [])
                     if "gen" in e]
        except (OSError, ValueError):
            pass
    return 1.0 + weight * float(np.mean(gens)) if gens else 1.0


# ---------------------------------------------------------------- admission

def ingest_capture(path, root, gen, tries_per_layer, rng, weights, margin, jf,
                   bases=None, wh=0.3, band=0.02):
    x = decode(path)
    if x is None or len(x) < int(SR * max(LAYERS.values())) * 2:
        return None
    bases = bases or {}
    out = {}
    for layer, dur in LAYERS.items():
        d = pool_dir(root, layer)
        mp = os.path.join(d, "manifest.json")
        if not os.path.exists(mp):
            continue
        m = json.load(open(mp))
        ent = m["manifest"]
        if not ent:
            continue

        # The factory navigates by descriptors.json, indexed by grain number. A
        # replaced grain whose descriptors still describe its predecessor is the
        # 2,389-of-2,400 failure again: nearest-neighbour lookups return
        # something unrelated and nothing errors, because wrong descriptors are
        # still plausible numbers. So descriptors are updated in the same breath
        # as the audio, through the FROZEN basis -- never re-derived from the
        # changing pool, which would rotate the axes under the factory.
        basis = bases.get(layer)
        dpath = os.path.join(d, "descriptors.json")
        desc_json = json.load(open(dpath)) if os.path.exists(dpath) else None
        clipped_total = 0

        A = np.array([[e["desc"]["centroid"], e["desc"]["spread"],
                       e["desc"]["flatness"], e["desc"]["crest"]]
                      for e in ent if "desc" in e])
        cm, cs = (A.mean(0), A.std(0)) if len(A) else (np.zeros(4), np.ones(4))

        # The seed's own pitched fraction is the set point. Stored at init so it
        # cannot drift with the pool it is supposed to anchor.
        target = m.get("pitched_target")
        if target is None:
            target = pitched_fraction(ent)
            m["pitched_target"] = round(target, 4)
        deficit = target - pitched_fraction(ent)

        n = int(SR * dur)
        admitted, rejected, margins = 0, {}, []
        deficit0 = deficit
        # random offsets, NOT onset-aligned: build_grains.py made that choice so
        # the corpus statistics are not ones the architect imposed. Changing it
        # here would quietly break that argument.
        span = max(1, len(x) - n)
        for s in rng.sample(range(span), min(tries_per_layer, span)):
            g = x[s:s + n]
            ok, why = vet(g)
            if not ok:
                rejected[why] = rejected.get(why, 0) + 1
                continue
            cand = describe(g)
            cand_score = score_grain(cand, cm, cs, weights)

            # Candidate and incumbent are compared on the SAME footing: the
            # stored score is the base, and the harmonic term is applied to both
            # at the current deficit. Storing the base rather than the effective
            # score is what lets the term change without invalidating every
            # score already in the pool.
            cand_eff = cand_score + harmonic_bonus(cand, deficit, wh, band)
            weakest = min(ent, key=lambda e: e.get("score", 0.0)
                          + harmonic_bonus(e.get("desc", {}), deficit, wh, band))
            weak_eff = (weakest.get("score", 0.0)
                        + harmonic_bonus(weakest.get("desc", {}), deficit, wh, band))
            gain = cand_eff - weak_eff
            if gain <= margin:
                rejected["outscored"] = rejected.get("outscored", 0) + 1
                jf.write(json.dumps(dict(
                    t=time.time(), layer=layer, verdict="rejected",
                    cand_score=round(cand_score, 4),
                    incumbent_score=round(weakest.get("score", 0.0), 4),
                    margin=round(gain, 4), required=margin,
                    source=os.path.basename(path), cand_desc=cand)) + "\n")
                continue

            # ADMITTED: take the incumbent's slot in place, keeping the integer
            # index and filename the factory relies on.
            gpath = os.path.join(d, weakest["file"])
            write_grain(gpath, g)
            if basis is not None and desc_json is not None:
                try:
                    # project the WRITTEN file, so the coordinates describe the
                    # faded audio the factory will actually play
                    coords, clip = DB.project(basis, gpath)
                    clipped_total += clip
                    slot = weakest["i"]
                    for k, v in coords.items():
                        col = desc_json.get("norm", {}).get(k)
                        if col is not None and slot < len(col):
                            col[slot] = v
                except Exception as exc:
                    print(f"    descriptor projection failed for "
                          f"{weakest['file']}: {exc}")
            jf.write(json.dumps(dict(
                t=time.time(), layer=layer, verdict="admitted",
                slot=weakest["i"], file=weakest["file"],
                cand_score=round(cand_score, 4),
                incumbent_score=round(weakest.get("score", 0.0), 4),
                margin=round(gain, 4),
                displaced_gen=weakest.get("gen"),
                displaced_source=weakest.get("source"),
                displaced_desc=weakest.get("desc"),
                new_gen=round(gen, 4), source=os.path.basename(path),
                cand_desc=cand)) + "\n")
            weakest.update(dict(gen=round(gen, 4), born=time.time(),
                                source=os.path.basename(path), desc=cand,
                                score=round(cand_score, 4)))
            admitted += 1
            margins.append(gain)
            # the deficit moves as the pool changes, so the term self-corrects
            # within a single capture rather than only between them
            deficit = target - pitched_fraction(ent)

        m["admitted"] = m.get("admitted", 0) + admitted
        m["rejected"] = m.get("rejected", 0) + sum(rejected.values())
        json.dump(m, open(mp, "w"), indent=1)
        if desc_json is not None and admitted:
            desc_json["_selfingest"] = (
                "Entries for replaced grains were projected into the FROZEN "
                "generation-0 basis by descriptor_basis.py, NOT re-derived from "
                "this pool. Re-deriving would rotate the axes as the corpus "
                "changes and make the space non-stationary.")
            json.dump(desc_json, open(dpath, "w"))
        out[layer] = (admitted, rejected, margins, clipped_total)
    return out


def pool_state(root):
    rows = []
    for d in pool_dirs(root):
        mp = os.path.join(d, "manifest.json")
        if not os.path.exists(mp):
            continue
        m = json.load(open(mp))
        g = [e.get("gen", 0) for e in m["manifest"]]
        rows.append((os.path.basename(d).split("_")[-1], len(g),
                     sum(1 for v in g if v == 0),
                     float(np.mean(g)) if g else 0.0,
                     pitched_fraction(m["manifest"]),
                     m.get("pitched_target", 0.0)))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--capture-dir", help="required unless --init")
    ap.add_argument("--out-root", required=True, help="the ring / pool root")
    ap.add_argument("--tries", type=int, default=120,
                    help="candidate slices attempted per layer per capture")
    ap.add_argument("--margin", type=float, default=0.02,
                    help="a candidate must beat the weakest incumbent by this "
                         "much. 0 admits anything marginally better and churns; "
                         "large values freeze the corpus.")
    ap.add_argument("--weight", type=float, default=None)
    ap.add_argument("--score-weights", default="0.5,0.3,0.2",
                    help="audible,articulate,distinct")
    ap.add_argument("--pitch-weight", type=float, default=0.3,
                    help="strength of the HOMEOSTATIC harmonic term. Signed: it "
                         "rewards pitched material only while the pool sits "
                         "below the seed's pitched fraction, and rewards "
                         "UNPITCHED material if the pool overshoots. 0 disables "
                         "it. The adjustment is bounded by this times the "
                         "deficit, so unpitched grains can still win on level, "
                         "articulation and distinctness.")
    ap.add_argument("--pitch-band", type=float, default=0.02,
                    help="drift in pitched fraction that saturates the harmonic "
                         "term. Without a band the raw deficit (~0.01) is two "
                         "orders below the admission margins and the term does "
                         "nothing at all -- measured.")
    ap.add_argument("--policy-json")
    ap.add_argument("--archive-dirs", default="")
    ap.add_argument("--basis-dir",
                    help="directory of frozen basis_<layer>.json files. Without "
                         "it, admitted grains get no descriptors and the factory "
                         "would navigate by its predecessor's coordinates.")
    ap.add_argument("--init", action="store_true")
    ap.add_argument("--delete-captures", action="store_true")
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--seed", type=int, default=20260828)
    a = ap.parse_args()

    rng = random.Random(a.seed)
    sw = tuple(float(v) for v in a.score_weights.split(","))

    # THE FLOOR IS NOW A POLICY VALUE. It was a module constant, which is how a
    # number chosen for the corpus builder came to govern the factory's intake
    # without anyone deciding that it should. Reported at startup so a run's
    # admission behaviour is visible in its own log rather than inferred.
    global FLOOR_DB
    if a.policy_json and os.path.exists(a.policy_json):
        try:
            FLOOR_DB = float(json.load(open(a.policy_json)).get(
                "ingest_floor_db", FLOOR_DB_DEFAULT))
        except (ValueError, OSError, json.JSONDecodeError):
            pass
    print(f"  ingest floor {FLOOR_DB:.1f} dBFS"
          + ("" if FLOOR_DB == FLOOR_DB_DEFAULT
             else f"  (default {FLOOR_DB_DEFAULT:.1f}, overridden from policy)"),
          flush=True)
    os.makedirs(a.out_root, exist_ok=True)

    if a.init:
        init_pool([d for d in a.archive_dirs.split(",") if d.strip()],
                  a.out_root, sw)
        return
    if not a.capture_dir:
        raise SystemExit("--capture-dir is required unless --init")

    weight = a.weight
    if weight is None and a.policy_json and os.path.exists(a.policy_json):
        try:
            weight = float(json.load(open(a.policy_json)).get("self_ingest_weight", 0))
        except (ValueError, OSError):
            weight = 0.0
    weight = weight or 0.0

    done_path = os.path.join(a.out_root, "ingested.json")
    done = set(json.load(open(done_path))) if os.path.exists(done_path) else set()
    jpath = os.path.join(a.out_root, "admissions.jsonl")

    bases = {}
    if a.basis_dir:
        for layer in LAYERS:
            bp = os.path.join(a.basis_dir, f"basis_{layer}.json")
            if os.path.exists(bp):
                bases[layer] = DB.load_basis(bp)
        print(f"  frozen descriptor bases: {sorted(bases) or 'NONE'}")
    if not bases:
        print("  WARNING: no frozen basis loaded. Admitted grains will keep the")
        print("  DESCRIPTORS OF THE GRAIN THEY REPLACED, so the factory would")
        print("  navigate to them by the wrong coordinates -- the same failure")
        print("  class as the 2,389-of-2,400 descriptor permutation. Pass")
        print("  --basis-dir unless you are deliberately testing without it.")

    # DETECT THE POOL'S RATE BEFORE ANY GRAIN IS CUT. Writing 22050 grains into
    # a 44100 pool is silent, plausible and wrong in two directions at once
    # (coordinates and playback), so it is checked rather than assumed.
    global SR
    detected, per_layer = detect_sr(a.out_root, LAYERS)
    if detected is None:
        print(f"  no pool grains yet at {a.out_root}; keeping SR={SR}")
    else:
        if detected != SR:
            print(f"  POOL SAMPLE RATE {detected} Hz, module default {SR} Hz "
                  f"-- following the pool")
        SR = detected
        print(f"  sample rate {SR} Hz {per_layer}")

    print(f"  self-ingest by ADMISSION CONTROL at {a.out_root}")
    print(f"  margin={a.margin}  score_w={sw}  self_ingest_weight={weight}")
    print(f"  harmonic term weight={a.pitch_weight} (homeostatic: defends the "
          f"seed's pitched fraction in BOTH directions)")
    print("  a candidate replaces the weakest incumbent IN PLACE, or is discarded")
    if weight == 0:
        print("  NOTE: weight 0 -- the loop is OPEN, so every admitted grain is")
        print("  generation 1 and the twenty-generation test cannot run yet.")

    while True:
        caps = sorted(p for p in glob.glob(os.path.join(a.capture_dir, "*"))
                      if os.path.splitext(p)[1].lower() in
                      (".wav", ".aiff", ".aif", ".w64")
                      and os.path.basename(p) not in done)
        # never touch the chunk the factory is still writing
        caps = [p for p in caps if time.time() - os.path.getmtime(p) > 20]

        for p in caps:
            gen = corpus_generation(a.out_root, weight)
            with open(jpath, "a") as jf:
                made = ingest_capture(p, a.out_root, gen, a.tries, rng, sw,
                                      a.margin, jf, bases, a.pitch_weight,
                                      a.pitch_band)
            if made is None:
                print(f"  {os.path.basename(p)}: undecodable or too short")
            else:
                print(f"  {os.path.basename(p)}  gen {gen:.2f}")
                for k, (adm, rej_, mar, clip) in made.items():
                    mm = f" (mean margin {np.mean(mar):+.3f})" if mar else ""
                    cc = f"  {clip} descriptor axes clipped" if clip else ""
                    print(f"      {k} {adm} admitted{mm}{cc}")
                rej = {}
                for _, r, _, _ in made.values():
                    for k, n in r.items():
                        rej[k] = rej.get(k, 0) + n
                if rej:
                    print(f"      rejected: {rej}")
            done.add(os.path.basename(p))
            json.dump(sorted(done), open(done_path, "w"))
            if a.delete_captures and made is not None:
                try:
                    os.remove(p)
                except OSError:
                    pass

        if caps:
            print(f"  {'layer':>8} {'grains':>7} {'gen0':>7} {'mean gen':>9} "
                  f"{'pitched':>9} {'target':>8} {'drift':>8}")
            for layer, n, z, mg, pf, tg in pool_state(a.out_root):
                print(f"  {layer:>8} {n:>7} {z:>7} {mg:>9.3f} "
                      f"{pf:>8.1%} {tg:>7.1%} {pf-tg:>+8.1%}")

        if a.once:
            return
        time.sleep(30)


if __name__ == "__main__":
    main()
