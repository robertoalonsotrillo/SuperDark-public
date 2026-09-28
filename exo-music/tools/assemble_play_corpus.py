#!/usr/bin/env python3
"""Assemble the corpus the factory actually plays, mixing archive and pool.

THE GAP THIS CLOSES
self_ingest.py has been scoring, admitting and ring-managing grains into
grains_pool_* since it was written. live_factory.scd never referenced
self_ingest_weight and never loaded a single file from those directories: it
loads from grains_lic_* at boot and nowhere else. So the ingester was filling a
pool nothing could play from, the loop was physically open, and no setting of
the weight could have closed it. Raising the weight would have measured
nothing, three times over.

WHY ASSEMBLE ON DISK RATHER THAN PATCH THE FACTORY
The factory loads its buffers ONCE at boot, so it cannot vary the mix during a
run whatever the code says. Nothing is therefore lost by choosing the mix at
assembly time, and a great deal is gained: no surgery inside a 1900-line
single-parenthesised block that has already hit sclang's parser limit, and the
result can be checked by verify_alignment.py before a note is played.

WHAT THE WEIGHT MEANS
corpus_generation() in self_ingest.py defines it exactly:

    generation of a new grain = 1 + weight * mean(generation of the pool)

so the weight is the PROPORTION OF SOUNDING AUDIO drawn from the pool. That is
a genuine per-slot mix and not a switch, and it is implemented here as one:
each grain slot independently takes the pool with probability `weight`. The
realised proportion is reported, because with 2400 slots it will not land
exactly on the requested value and the generation arithmetic should use what
actually happened.

DESCRIPTORS TRAVEL WITH THEIR AUDIO
Slot i takes its descriptor row from whichever corpus supplied slot i's audio.
This is only sound because both sides live in the same frozen basis: admitted
grains are described through basis_<layer>.json for exactly this reason, and
pc0..pc4 are min-max scaled coordinates in that basis rather than within-corpus
ranks. If that ever stops being true this file is wrong, so verify_alignment.py
is run over the output as a matter of course.

CONTINUITY IS DROPPED FOR ADMITTED GRAINS, DELIBERATELY
manifest.json gives each archive grain a (track, seq) so the factory can play
the next half-second of the same music. A grain cut from the factory's own
output has no source track and no successor. Carrying the displaced grain's
provenance forward would tell the factory that a piece of its own output is the
continuation of an FMA track, which is false and would quietly corrupt the one
mechanism that fixed the radio effect.

  python3 assemble_play_corpus.py --archive workdir_music/grains_lic_ev \\
      --pool /Volumes/FMA/superdark/self_corpus/grains_pool_ev \\
      --weight 0.25 --out workdir_music/grains_play_ev
"""
import argparse
import json
import os
import random
import shutil
import sys


def load(p):
    return json.load(open(p)) if os.path.exists(p) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True)
    ap.add_argument("--pool", required=True)
    ap.add_argument("--weight", type=float, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=20260831)
    a = ap.parse_args()

    if not 0.0 <= a.weight <= 1.0:
        raise SystemExit("  --weight must be in [0,1]")

    ad = load(os.path.join(a.archive, "descriptors.json"))
    pd = load(os.path.join(a.pool, "descriptors.json"))
    if ad is None:
        raise SystemExit(f"  no descriptors.json in {a.archive}")
    if pd is None:
        raise SystemExit(f"  no descriptors.json in {a.pool}")

    n = len(ad["index"])
    if len(pd["index"]) != n:
        raise SystemExit(f"  size mismatch: archive {n}, pool {len(pd['index'])}. "
                         "The pool must be a same-shape working copy.")
    keys = [k for k in ad["norm"]]
    missing = [k for k in keys if k not in pd["norm"]]
    if missing:
        raise SystemExit(f"  pool descriptors lack {missing}; refusing to mix")

    pman = load(os.path.join(a.pool, "manifest.json")) or {}
    pgen = {}
    for e in pman.get("manifest", []):
        pgen[int(e["i"])] = float(e.get("gen", 0.0))

    rng = random.Random(a.seed)
    take_pool = [rng.random() < a.weight for _ in range(n)]

    os.makedirs(a.out, exist_ok=True)
    norm = {k: [None] * n for k in keys}
    # None when the archive predates the Hz column, so a corpus built before
    # this change still assembles instead of failing on a key nobody had.
    raw_hz = [0.0] * n if "raw_hz" in ad else None
    n_pool, n_self, gsum = 0, 0, 0.0

    for i in range(n):
        name = f"g{i:02d}.wav"
        src_dir = a.pool if take_pool[i] else a.archive
        s = os.path.join(src_dir, name)
        if not os.path.exists(s):
            s = os.path.join(a.archive, name)
            take_pool[i] = False
        # copyfile, not copy2: exFAT has no chflags and copy2 raises EINVAL
        shutil.copyfile(s, os.path.join(a.out, name))

        src_desc = pd if take_pool[i] else ad
        for k in keys:
            norm[k][i] = src_desc["norm"][k][i]
        # raw_hz IS PER-SLOT AND MUST BE MIXED, NOT INHERITED.
        # out_desc starts as dict(ad), which carries every archive key forward --
        # the right default for the frozen PCA basis, and wrong for anything
        # indexed by slot. Left alone, raw_hz[i] would describe the ARCHIVE grain
        # at slot i even when the pool supplied that slot: not missing, which
        # something might notice, but STALE, which nothing would.
        if raw_hz is not None:
            src_hz = src_desc.get("raw_hz", {}).get("pitch")
            raw_hz[i] = float(src_hz[i]) if src_hz and i < len(src_hz) else 0.0

        g = pgen.get(i, 0.0) if take_pool[i] else 0.0
        gsum += g
        if take_pool[i]:
            n_pool += 1
            if g > 0:
                n_self += 1

    # START FROM THE ARCHIVE FILE AND REPLACE ONLY WHAT IS MIXED.
    # The first version built a fresh dict with the fields that looked
    # relevant, and silently dropped _pca_mean / _pca_scale / _pca_components:
    # the transform world_listen.load_transform needs to embed live audio into
    # the corpus space. Nothing downstream noticed except verify_alignment.py,
    # which refused outright. Carrying the whole file forward means a key added
    # to descriptors.json later cannot go missing here by omission.
    out_desc = dict(ad)
    out_desc["index"] = list(range(n))
    out_desc["norm"] = norm
    if raw_hz is not None:
        out_desc["raw_hz"] = {"pitch": [round(x, 2) for x in raw_hz]}
    else:
        # explicit, so a downstream reader can tell "this corpus has no Hz" from
        # "this corpus has Hz that happens to be zero everywhere"
        out_desc.pop("raw_hz", None)
    out_desc["_comment"] = ("ASSEMBLED play corpus: archive and self-ingest pool "
                            "mixed per slot. Descriptors travel with their audio; "
                            "both sides share the frozen basis, so the PCA "
                            "transform carried over from the archive applies to "
                            "every slot regardless of which side supplied it.")
    json.dump(out_desc, open(os.path.join(a.out, "descriptors.json"), "w"))

    # continuity: archive provenance, minus every slot now holding self-material
    aman = load(os.path.join(a.archive, "manifest.json"))
    if aman and aman.get("manifest"):
        kept = []
        for e in aman["manifest"]:
            i = int(e["i"])
            if i < n and take_pool[i] and pgen.get(i, 0.0) > 0:
                continue          # self-material has no source track to continue
            kept.append(e)
        aman["manifest"] = kept
        aman["_comment"] = ("Provenance for ARCHIVE slots only. Slots holding "
                            "self-ingested material are absent, so they get no "
                            "continuity, which is correct: a grain cut from the "
                            "factory's own output has no next half-second of "
                            "source music.")
        json.dump(aman, open(os.path.join(a.out, "manifest.json"), "w"))

    mean_gen = gsum / n
    json.dump({
        "archive": os.path.abspath(a.archive),
        "pool": os.path.abspath(a.pool),
        "requested_weight": a.weight,
        "realised_pool_fraction": n_pool / n,
        "slots": n, "from_pool": n_pool, "of_which_self_generated": n_self,
        "mean_generation": mean_gen,
        "next_ingest_generation": 1 + a.weight * mean_gen,
        "seed": a.seed,
    }, open(os.path.join(a.out, "provenance.json"), "w"), indent=1)

    print(f"  {os.path.basename(a.out)}: {n} slots, {n_pool} from pool "
          f"({100*n_pool/n:.1f}%, asked {100*a.weight:.0f}%), "
          f"{n_self} self-generated")
    print(f"    mean generation {mean_gen:.3f}  ->  a grain ingested next is "
          f"generation {1 + a.weight * mean_gen:.3f}")
    if n_self == 0 and a.weight > 0:
        print("    NOTE: pool holds no self-material yet, so this is still "
              "generation-0 audio. The mix is live; the loop closes as "
              "admissions accumulate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
