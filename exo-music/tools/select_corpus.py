#!/usr/bin/env python3
"""Select an FMA track list by genre, balanced across sub-genres.

Selection is by `track.genres_all`, the multi-label field, NOT `track.genre_top`.
That matters: only 49,598 of 106,574 tracks carry a genre_top at all, and
Classical by genre_top is 1,230 tracks against 4,106 by genres_all.

  python3 select_corpus.py --meta /Volumes/FMA/fma/meta/fma_metadata \
      --subset large --roots Classical --include-curated-experimental \
      --per-subgenre 300 --out corpus_ids.txt
"""
import argparse, ast, sys
import pandas as pd

# Experimental sub-genres kept. Novelty, Holiday, Christmas, Kid-Friendly and
# Sound Effects are dropped: they are experimental by catalogue position and
# not by material.
CURATED_EXPERIMENTAL = {
    'Avant-Garde', 'Noise', 'Electroacoustic', 'Improv', 'Field Recordings',
    'Musique Concrete', 'Drone', 'Sound Collage', 'Sound Art', 'Minimalism',
    'Audio Collage', 'Sound Poetry',
}
SUBSETS = {'small': ['small'],
           'medium': ['small', 'medium'],
           'large': ['small', 'medium', 'large']}


def load(meta):
    t = pd.read_csv(f'{meta}/tracks.csv', index_col=0, header=[0, 1])
    g = pd.read_csv(f'{meta}/genres.csv', index_col=0)
    return t, g['title'].to_dict(), g['parent'].to_dict()


def descendants(root_id, parent):
    """All genre ids whose ancestor chain reaches root_id."""
    out = set()
    for gid in parent:
        seen, cur = set(), gid
        while parent.get(cur, 0) != 0 and cur not in seen:
            seen.add(cur)
            cur = parent[cur]
        if cur == root_id:
            out.add(gid)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--meta', required=True)
    p.add_argument('--subset', default='large', choices=SUBSETS)
    p.add_argument('--roots', nargs='*', default=[],
                   help='top-level genre names taken whole, e.g. Classical')
    p.add_argument('--include-curated-experimental', action='store_true')
    p.add_argument('--per-subgenre', type=int, default=0,
                   help='cap per sub-genre; 0 takes everything')
    p.add_argument('--seed', type=int, default=0)
    p.add_argument('--out', required=True)
    a = p.parse_args()

    t, name, parent = load(a.meta)
    by_name = {v: k for k, v in name.items()}

    wanted = {}                                    # genre id -> label
    for r in a.roots:
        if r not in by_name:
            sys.exit(f'unknown genre {r!r}')
        for gid in descendants(by_name[r], parent) | {by_name[r]}:
            wanted[gid] = name[gid]
    if a.include_curated_experimental:
        for nm in CURATED_EXPERIMENTAL:
            if nm in by_name:
                wanted[by_name[nm]] = nm
    if not wanted:
        sys.exit('no genres selected')

    ga = t[('track', 'genres_all')].fillna('[]').map(ast.literal_eval)
    in_subset = t[('set', 'subset')].isin(SUBSETS[a.subset])

    # Balance by sub-genre so a large sub-genre (Avant-Garde, 8693) does not
    # swamp a small one (Symphony, 25). Assign each track to its RAREST
    # matching label, so the cap counts each track once.
    freq = {gid: int((ga.map(lambda L, g=gid: g in L) & in_subset).sum())
            for gid in wanted}
    buckets = {}
    for tid, labels in ga[in_subset].items():
        hit = [g for g in labels if g in wanted]
        if hit:
            buckets.setdefault(min(hit, key=lambda g: freq[g]), []).append(tid)

    rng = pd.Series(range(1)).sample  # placeholder to keep pandas import honest
    import random
    random.Random(a.seed).seed(a.seed)
    r = random.Random(a.seed)
    chosen, report = [], []
    for gid, ids in sorted(buckets.items(), key=lambda kv: -len(kv[1])):
        take = ids if a.per_subgenre <= 0 else r.sample(
            ids, min(a.per_subgenre, len(ids)))
        chosen += take
        report.append((wanted[gid], len(ids), len(take)))

    chosen = sorted(set(chosen))
    with open(a.out, 'w') as f:
        f.write('\n'.join(f'{i:06d}' for i in chosen) + '\n')

    w = max(len(n) for n, _, _ in report)
    for nm, avail, took in report:
        print(f'  {nm:<{w}}  available {avail:6d}   taken {took:5d}')
    print(f'\n{len(chosen)} tracks -> {a.out}   '
          f'({len(chosen) * 30 / 3600:.1f} h of 30 s clips)')


if __name__ == '__main__':
    main()
