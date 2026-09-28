#!/usr/bin/env python3
"""Build a grain corpus from vetted FMA tracks.

Matches the existing corpus exactly: 0.500 s, 22050 Hz, stereo, 32-bit PCM,
which is what the 130 grains in workdir_music/grains measure.

Naming matters and is easy to get wrong. render.scd builds paths with

    "/grains/g" ++ i.asString.padLeft(2, "0")

so grain 7 is `g07.wav` and grain 130 is `g130.wav`. Python's `str(i).zfill(2)`
reproduces that for every i. Zero-padding to a fixed width beyond two digits
would silently produce a corpus the renderer cannot find, and the renderer
fails by rendering silence rather than by erroring.

Slices are fixed-length at random offsets rather than onset-aligned. That is
deliberate. Onset detection imposes my segmentation on the supply, and the
b\\c argument in docs/06 needs the corpus statistics to be something I did not
choose. A slice is rejected only if it is below the silence floor.

  python3 build_grains.py --ids corpus_vetted.txt --audio AUDIO \\
      --picks picks.csv --n 600 --out workdir_music/grains_600
"""
import argparse, csv, os, random, subprocess, sys, wave
import numpy as np

SR = 22050
GRAIN_S = 0.5
FLOOR_DB = -45.0


def decode(path, sr=SR):
    """Stereo float32 at sr via ffmpeg."""
    try:
        r = subprocess.run(
            ['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le',
             '-acodec', 'pcm_f32le', '-ac', '2', '-ar', str(sr), '-'],
            capture_output=True, timeout=60)
        x = np.frombuffer(r.stdout, dtype=np.float32)
        return x.reshape(-1, 2) if len(x) >= 2 else None
    except Exception:
        return None


def write_grain(path, x):
    """32-bit PCM stereo, matching the existing corpus.

    ATTENUATE, DO NOT CLIP -- see build_grains_onset.py for the full note. A
    bare clip here is what put hard clipping into the corpora: FMA is MP3, MP3
    decodes exceed +/-1.0 on intersample peaks, and everything over the line was
    flattened rather than scaled.
    """
    peak = float(np.abs(x).max())
    if peak > 0.999:
        x = x * (0.999 / peak)
    y = np.clip(x, -1.0, 1.0)
    y = (y * (2 ** 31 - 1)).astype('<i4')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(4)
        w.setframerate(SR)
        w.writeframes(y.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ids', required=True, help='vetted track ids, one per line')
    ap.add_argument('--audio', required=True)
    ap.add_argument('--picks', help='id,genre csv; if given, sampling is genre-balanced')
    ap.add_argument('--n', type=int, required=True, help='grains to produce')
    ap.add_argument('--per-track', type=int, default=3)
    ap.add_argument('--out', required=True)
    ap.add_argument('--seed', type=int, default=20260821)
    a = ap.parse_args()

    ids = [int(l) for l in open(a.ids) if l.strip()]
    rng = random.Random(a.seed)

    if a.picks:
        genre = {}
        with open(a.picks) as f:
            for row in csv.DictReader(f):
                genre[int(row['id'])] = row['genre']
        buckets = {}
        for t in ids:
            buckets.setdefault(genre.get(t, '?'), []).append(t)
        for v in buckets.values():
            rng.shuffle(v)
        # round-robin across genres so the corpus is balanced by construction
        order, gs = [], sorted(buckets)
        while any(buckets[g] for g in gs):
            for g in gs:
                if buckets[g]:
                    order.append(buckets[g].pop())
    else:
        order = ids[:]
        rng.shuffle(order)

    os.makedirs(a.out, exist_ok=True)
    n = int(SR * GRAIN_S)
    floor = 10 ** (FLOOR_DB / 20)
    made, used, skipped = 0, 0, 0

    for tid in order:
        if made >= a.n:
            break
        p = os.path.join(a.audio, f'{tid // 1000:03d}', f'{tid:06d}.mp3')
        if not os.path.exists(p):
            continue
        x = decode(p)
        if x is None or len(x) < n * 2:
            continue
        used += 1
        starts = rng.sample(range(0, len(x) - n), min(a.per_track * 4, 40))
        taken = 0
        for s in starts:
            if made >= a.n or taken >= a.per_track:
                break
            g = x[s:s + n]
            if np.sqrt((g ** 2).mean()) < floor:
                skipped += 1
                continue
            write_grain(os.path.join(a.out, f'g{str(made).zfill(2)}.wav'), g)
            made += 1
            taken += 1

    print(f'{made} grains from {used} tracks -> {a.out}')
    print(f'  {skipped} slices rejected below {FLOOR_DB} dBFS')
    print(f'  {made * GRAIN_S:.1f} s of material, {SR} Hz stereo 32-bit')
    if made < a.n:
        print(f'  WARNING: asked for {a.n}, ran out of tracks', file=sys.stderr)


if __name__ == '__main__':
    main()
