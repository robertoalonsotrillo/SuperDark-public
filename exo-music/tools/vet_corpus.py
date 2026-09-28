#!/usr/bin/env python3
"""Vet FMA audio before it reaches the grain pipeline.

FMA's own errata (mdeff/fma issue #41) lists four problems with the rc1
release: bzip2 zips that macOS unzip cannot read, excerpts shorter than 30 s
with erroneous length metadata, bad ID3 tags, and 937 exact duplicates.

Published lists exist for the short files and the duplicates. This does not
use them. Measuring is cheaper than trusting a list, catches whatever the
list missed, and independently checks the errata, which is worth having on
the record for a proposal that leans on this corpus.

Four rejections, each measured:

  missing    the file is not on disk
  short      duration below --min-sec, read from the stream and not from
             the metadata, since the errata says the metadata is wrong
  silent     mean RMS below --floor-db, which catches corrupt decodes as
             well as genuinely empty files
  duplicate  identical md5, keeping the lowest track id

  python3 vet_corpus.py --ids corpus_ids.txt --audio /Volumes/FMA/fma/audio/fma_medium \\
      --out corpus_vetted.txt --report vet_report.csv
"""
import argparse, csv, hashlib, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor


def path_for(tid, root):
    return os.path.join(root, f'{tid // 1000:03d}', f'{tid:06d}.mp3')


def duration(path):
    """Duration from the decoded stream, not the container metadata."""
    try:
        r = subprocess.run(
            ['ffprobe', '-v', 'error', '-select_streams', 'a:0',
             '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
            capture_output=True, text=True, timeout=30)
        return float(r.stdout.strip())
    except Exception:
        return -1.0


def rms_db(path):
    """Mean volume in dBFS via ffmpeg's volumedetect."""
    try:
        r = subprocess.run(
            ['ffmpeg', '-v', 'info', '-i', path, '-af', 'volumedetect',
             '-f', 'null', '-'],
            capture_output=True, text=True, timeout=60)
        for line in r.stderr.splitlines():
            if 'mean_volume:' in line:
                return float(line.split('mean_volume:')[1].split('dB')[0])
    except Exception:
        pass
    return -999.0


def md5(path, chunk=1 << 20):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def check(tid, root, min_sec, floor_db):
    p = path_for(tid, root)
    if not os.path.exists(p):
        return dict(id=tid, path=p, verdict='missing', sec=0, db=0, md5='')
    d = duration(p)
    if d < min_sec:
        return dict(id=tid, path=p, verdict='short', sec=round(d, 2), db=0, md5='')
    v = rms_db(p)
    if v < floor_db:
        return dict(id=tid, path=p, verdict='silent', sec=round(d, 2),
                    db=round(v, 1), md5='')
    return dict(id=tid, path=p, verdict='ok', sec=round(d, 2),
                db=round(v, 1), md5=md5(p))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ids', required=True)
    ap.add_argument('--audio', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--report', required=True)
    ap.add_argument('--min-sec', type=float, default=25.0)
    ap.add_argument('--floor-db', type=float, default=-50.0)
    ap.add_argument('--workers', type=int, default=8)
    ap.add_argument('--limit', type=int, default=0)
    a = ap.parse_args()

    ids = [int(l) for l in open(a.ids) if l.strip()]
    if a.limit:
        ids = ids[:a.limit]
    print(f'vetting {len(ids)} tracks from {a.audio}', flush=True)

    with ThreadPoolExecutor(a.workers) as ex:
        rows = list(ex.map(
            lambda t: check(t, a.audio, a.min_sec, a.floor_db), ids))

    seen, out = {}, []
    for r in sorted(rows, key=lambda r: r['id']):
        if r['verdict'] != 'ok':
            continue
        if r['md5'] in seen:
            r['verdict'] = f"duplicate of {seen[r['md5']]}"
        else:
            seen[r['md5']] = r['id']
            out.append(r['id'])

    with open(a.report, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['id', 'path', 'verdict', 'sec', 'db', 'md5'])
        w.writeheader()
        w.writerows(rows)
    with open(a.out, 'w') as f:
        f.write('\n'.join(f'{i:06d}' for i in out) + '\n')

    tally = {}
    for r in rows:
        k = r['verdict'].split(' of ')[0]
        tally[k] = tally.get(k, 0) + 1
    print()
    for k in sorted(tally, key=lambda k: -tally[k]):
        print(f'  {k:12s} {tally[k]:6d}  {100*tally[k]/len(rows):5.1f}%')
    print(f'\n{len(out)} kept -> {a.out}   ({len(out)*30/3600:.1f} h at 30 s)')


if __name__ == '__main__':
    main()
