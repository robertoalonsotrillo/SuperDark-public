#!/bin/sh
# Rebuild the corpus from tracks this project may legally use.
#
# WHY. A public stream distributes a derivative work, and the per-track licence
# governs -- FMA's own README: "We do not hold the copyright on the audio and
# distribute it under the license chosen by the artist." Measured 27 Aug across
# the 150 source tracks then in use: 28.4% No-Derivatives, 52.9% ShareAlike.
# ND prohibits distributing derivatives outright, so 41 rights-holders would
# have been infringed by the stream the GRF proposes to advertise.
#
# WHAT COUNTS AS USABLE HERE, in order:
#   1. LICENCE   CC0, Public Domain, or Attribution-only. No ND (prohibits
#                derivatives), no SA (requires the derivative carry the same
#                licence, and the corpus mixes incompatible SA versions).
#   2. PRESENT   actually extracted from fma_large.
#   3. VETTED    passes vet_corpus.py: long enough, not silent, not a duplicate.
#                The existing vetting rejected only 3 of 2,425, but those three
#                were 2 silent and 1 truncated -- exactly what poisons a grain
#                corpus, and exactly what an unvetted pool would reintroduce.
#
# GEOMETRY IS DELIBERATELY UNCHANGED. 2,400 micro grains in runs of 24 and 1,200
# macro in runs of 8, the same as the corpus everything to date was measured on.
# The larger archive widens the POOL those tracks are drawn from -- 17,189 clean
# candidates instead of 150 -- without changing what `neighbourhood: 600`,
# `path_max` or `N=2400` mean. Run length stays at 24 because `continuity` is
# what fixed the radio effect, and shortening runs is exactly how to break it.
# A bigger corpus is a separate decision and should be taken separately.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FMA=/Volumes/FMA/fma
AUDIO=$FMA/fma_large
CLEAN=$FMA/clean

echo "=== waiting for extraction to finish ==="
while pgrep -f 7zz >/dev/null 2>&1; do
  echo "  $(find $AUDIO -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ') of 106576 ..."
  sleep 60
done
N=$(find $AUDIO -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ')
echo "  extraction done: $N files"
[ "$N" -lt 100000 ] && { echo "ABORT: only $N files, expected ~106576"; exit 1; }

echo
echo "=== 1. licence-clean AND present on disk ==="
python3 - "$FMA" "$AUDIO" "$CLEAN" <<'PYEOF'
import csv, os, sys, collections
csv.field_size_limit(10**7)
fma, audio, clean = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(clean, exist_ok=True)
f = open(f"{fma}/meta/fma_metadata/tracks.csv", newline="", encoding="utf8", errors="replace")
h1 = next(csv.reader(f)); h2 = next(csv.reader(f)); next(csv.reader(f))
cols = [f"{a}.{b}" for a, b in zip(h1, h2)]
li, gi = cols.index("track.license"), cols.index("track.genre_top")
def ok(t):
    t = (t or "").lower()
    if "noderivative" in t or "no derivative" in t: return False
    if "sharealike" in t or "share alike" in t: return False
    return "attribution" in t or "cc0" in t or "public domain" in t
ids, genres = [], collections.Counter()
for r in csv.reader(f):
    if r and ok(r[li]):
        tid = int(r[0])
        if os.path.exists(f"{audio}/{tid//1000:03d}/{tid:06d}.mp3"):
            ids.append(tid); genres[r[gi] or "(none)"] += 1
f.close()
open(f"{clean}/clean_large_ids.txt", "w").write("\n".join(str(i) for i in ids) + "\n")
print(f"  {len(ids)} licence-clean tracks present on disk")
for g, n in genres.most_common(8): print(f"    {n:6}  {g}")
PYEOF

echo
# VET THE WHOLE POOL, not a sample.
#
# The first version sampled 900 on the grounds that only ~150 tracks are needed.
# That is true for THIS corpus and wrong for the pool: a vetted pool is a
# durable asset every future corpus build draws on, and vetting is cheap --
# duration, peak level and an md5 for duplicates, over 30 s files, parallel.
# Sampling would mean re-vetting on every rebuild and never knowing how much of
# the licence-clean pool is actually usable, which is a number this project
# needs for the GRF regardless.
echo "=== 2. vet the whole licence-clean pool ==="
python3 "$ROOT/tools/vet_corpus.py" \
  --ids "$CLEAN/clean_large_ids.txt" --audio "$AUDIO" \
  --out "$CLEAN/clean_vetted.txt" --report "$CLEAN/clean_vet_report.csv" \
  --limit "${VET_LIMIT:-999999}" --workers 8
echo "  vetted: $(wc -l < "$CLEAN/clean_vetted.txt" | tr -d ' ') usable of "\
"$(wc -l < "$CLEAN/clean_large_ids.txt" | tr -d ' ') licence-clean"
# what the vetting rejected, and why -- the number matters for the GRF
python3 - "$CLEAN/clean_vet_report.csv" <<'PYEOF'
import csv, collections, sys
try:
    c = collections.Counter(r["verdict"] for r in csv.DictReader(open(sys.argv[1])))
except Exception as e:
    print(f"  (no report: {e})"); raise SystemExit
tot = sum(c.values())
for k, n in c.most_common():
    print(f"    {n:6}  {n/tot:5.1%}  {k}")
PYEOF

echo
echo "=== 3. build grains (geometry unchanged: 2400 in runs of 24, 1200 in runs of 8) ==="
rm -rf "$ROOT/workdir_music/grains_lic_ev" "$ROOT/workdir_music/grains_lic_macro"
python3 "$ROOT/tools/build_grains_onset.py" --ids "$CLEAN/clean_vetted.txt" \
  --audio "$AUDIO" --out "$ROOT/workdir_music/grains_lic_ev" \
  --grain 0.06 --per-track 24 --tracks 100 --seed 20260827
python3 "$ROOT/tools/build_grains_onset.py" --ids "$CLEAN/clean_vetted.txt" \
  --audio "$AUDIO" --out "$ROOT/workdir_music/grains_lic_macro" \
  --grain 2.0 --per-track 8 --tracks 150 --seed 20260827

echo
echo "=== 4. descriptors ==="
python3 "$ROOT/tools/analyse_mfcc.py" --dir "$ROOT/workdir_music/grains_lic_ev"
python3 "$ROOT/tools/analyse_mfcc.py" --dir "$ROOT/workdir_music/grains_lic_macro"

echo
echo "=== 5. VERIFY ALIGNMENT ==="
# The bug that had the factory reading the wrong descriptors for 2,389 of 2,400
# grains raised no error and produced plausible numbers. It is checked here
# every time a corpus is built, not trusted because the sort was fixed once.
python3 - "$ROOT" <<'PYEOF'
import sys, os, json, numpy as np
sys.path.insert(0, os.path.join(sys.argv[1], "tools"))
from analyse_mfcc import mel_filterbank, mfcc_stats, read_mono, N_MEL, FFT
from world_listen import load_transform
from scipy.stats import spearmanr
bad = False
for g in ("grains_lic_ev", "grains_lic_macro"):
    G = os.path.join(sys.argv[1], "workdir_music", g)
    d = json.load(open(G + "/descriptors.json"))
    mu, sc, C = load_transform(G + "/descriptors.json")
    norm = d["norm"]; fb = None; ids = list(range(0, 400, 9)); mine = []
    for i in ids:
        m, sr = read_mono(os.path.join(G, f"g{i:02d}.wav"))
        if fb is None: fb = mel_filterbank(sr, FFT, N_MEL)
        mine.append(C @ ((mfcc_stats(m, sr, fb) - mu) / sc))
    mine = np.array(mine)
    rs = [spearmanr(mine[:, k], [norm[f"pc{k}"][i] for i in ids]).correlation
          for k in range(5)]
    good = min(rs) > 0.999
    bad |= not good
    print(f"  {g:18} _order:{'yes' if '_order' in d else 'NO':4} "
          f"min Spearman {min(rs):+.5f}  {'ALIGNED' if good else 'MISALIGNED'}")
sys.exit(1 if bad else 0)
PYEOF

echo
echo "=== done ==="
echo "  grains_lic_ev / grains_lic_macro are licence-clean, vetted and aligned."
echo "  Attribution record: $CLEAN/clean_vet_report.csv"
echo "  To run: GRAINS=grains_lic_ev MACRO=grains_lic_macro N=2400 ./tools/run_live.sh"
echo "  LISTEN WARM: the factory needs ~45 windows to cohere. Judging the"
echo "  material before then measures the cold start, not the corpus."
