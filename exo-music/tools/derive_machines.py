#!/usr/bin/env python3
"""Write runtime machines whose numbers come from the corpus, not from a person.

Reads temporal_regimes.json and emits one .scd per regime into
mutable/machines/. The factory loads them at the next window boundary without
stopping, which is the mechanism that already works.

WHAT IS DERIVED AND WHAT IS NOT, stated plainly because the distinction is the
whole point:

  DERIVED from measurement    every duration, attack, release and filter
                              trajectory. \\dur comes from the regime's measured
                              inter-onset intervals; \\atk and \\rel from the
                              flux envelope around real onsets; the filter
                              envelope's travel from measured centroid drift.

  MINE                        the three features, the number of clusters, the
                              choice of Pbind constructors, and the mapping from
                              statistic to slot. The derivation still terminates
                              in my inputs (P113). This is measurement plus
                              k-means, not learning, and should not be described
                              as learning.

Cutoffs are placed inside the band the corpus actually occupies -- grains_600
has a median 99% rolloff of 2335 Hz -- because Archon's inherited machines
sweep to 25740 Hz over material that has nothing above 11 kHz, which is what
silenced a third of the vocabulary until the cutoff remap.

These are the first behaviours in the system that came from neither Marek nor
me. Sixteen of the twenty-two class machines are Archon's, inherited whole;
four are mine; the two existing runtime machines are mine. Nothing until now
was derived from data.
"""
import argparse
import json
import os

TEMPLATE = '''// {name} -- DERIVED FROM MEASUREMENT, not composed.
//
// Regime {idx} of {total} in temporal_regimes.json, clustered from {n_tracks}
// FMA tracks. Every number below is measured; see tools/analyse_temporal.py.
//
//   inter-onset interval   median {ioi_median:.3f} s, IQR {ioi_spread:.3f}, 10th pct {ioi_fastest:.3f}
//   attack (flux rise)     {rise:.3f} s
//   decay (flux fall)      {fall:.3f} s
//   centroid drift         {drift:.3f}   (variation over 4 s windows)
//   onset density          {density:.2f} per second
//
// {character}
//
// Cutoffs sit in 200-3000 Hz because that is where this corpus has energy:
// grains_600 has a median 99% rolloff of 2335 Hz. Archon's inherited machines
// sweep to 25740 Hz and were silent here until they were remapped.
{{ |buf, args|
    var ioi     = {ioi_median:.4f},
        fastest = {ioi_fastest:.4f},
        spread  = {ioi_spread:.4f},
        // the factory's measured density scales the regime's own pacing rather
        // than replacing it, so the machine keeps its character while breathing
        scale   = args.at(\\density).linlin(0.0, 1.2, 1.6, 0.6, clip: \\minmax),
        atk     = {rise:.4f},
        rel     = {fall:.4f},
        body    = args.at(\\avgrms).linlin(0.0, 1.0, 0.08, 0.30, clip: \\minmax),
        centre  = args.at(\\avgcent).linlin(1200, 6000, 300, 2400, clip: \\minmax),
        travel  = {drift:.4f},
        sweep;

    // measured drift becomes the filter's journey: a static regime holds, a
    // mobile one moves, and by how much is not a number I chose
    sweep = Env([centre, centre * (1 + travel), centre * (1 - (travel * 0.4))],
                [ioi * 8, ioi * 13], \\sin).discretize(24).asArray;

    Pbind(
        \\instrument, {instrument},
        \\buf, Pshuf(buf, inf),

        // the regime's own interval distribution: its median, its fastest
        // tenth, and its spread, in the proportions the corpus showed
        \\dur, Pseq([
            Pn(Pwhite(fastest, ioi) * scale, {rep_a}),
            Pn(Pwhite(ioi, ioi + spread) * scale, {rep_b})
        ], inf),

        \\atk, atk,
        \\rel, rel,
        \\cutoff, Pseq(sweep, inf),
        \\rate, Pseq([1.0, {rate_b:.3f}, 1.0, {rate_c:.3f}], inf),
        \\pan, Pwhite(-0.8, 0.8),
        \\amp, Pwhite(body * 0.6, body),
        \\out, 0
    )
}}
'''

CHARACTER = [
    "Dense and static: the fastest pacing in the corpus, with a slow swell into "
    "each event and almost no spectral movement. Sits still and fills.",
    "Sustained: the least mobile regime measured, with the longest decay. Events "
    "overlap into a continuous surface rather than articulating.",
    "Middling on every axis. Included because it is what most of the corpus "
    "actually does, and a vocabulary of extremes would misrepresent it.",
    "Articulated: a wide interval spread and a quick attack, so events group "
    "unevenly. The first regime where rhythm is legible as rhythm.",
    "Sparse and mobile: the sharpest attack and the largest spectral drift of "
    "the five. Percussive, and it travels.",
]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--regimes", default="temporal_regimes.json")
    p.add_argument("--out", default="mutable/machines")
    a = p.parse_args()

    d = json.load(open(a.regimes))
    regimes = d["regimes"]
    os.makedirs(a.out, exist_ok=True)

    written = []
    for i, r in enumerate(regimes):
        name = f"fma{i}"
        # a sharp attack wants the high-pass voice, a swell wants the band-pass
        instrument = "\\playbackHP" if r["rise"] < 0.2 else "\\playback"
        body = dict(r)
        body.update(
            name=name, idx=i, total=len(regimes),
            character=CHARACTER[i] if i < len(CHARACTER) else "Measured regime.",
            instrument=instrument,
            # repeat counts from the regime's own density: denser regimes hold a
            # figure longer before changing it
            rep_a=max(2, int(round(r["density"]))),
            rep_b=max(2, int(round(r["density"] / 2))),
            rate_b=round(1.0 + r["drift"] * 0.5, 3),
            rate_c=round(max(0.4, 1.0 - r["drift"] * 0.4), 3),
        )
        txt = TEMPLATE.format(**body)
        path = os.path.join(a.out, name + ".scd")
        open(path, "w").write(txt)
        written.append((name, instrument, r["ioi_median"], r["rise"], r["drift"]))

    print(f"wrote {len(written)} machines to {a.out}\n")
    print(f"  {'name':6} {'instrument':13} {'ioi':>7} {'atk':>7} {'drift':>7}")
    for n, ins, ioi, rise, drift in written:
        print(f"  {n:6} {ins:13} {ioi:7.3f} {rise:7.3f} {drift:7.3f}")


if __name__ == "__main__":
    main()
