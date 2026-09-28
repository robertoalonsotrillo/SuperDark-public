// fma4 -- DERIVED FROM MEASUREMENT, not composed.
//
// Regime 4 of 5 in temporal_regimes.json, clustered from 32
// FMA tracks. Every number below is measured; see tools/analyse_temporal.py.
//
//   inter-onset interval   median 0.232 s, IQR 0.163, 10th pct 0.128
//   attack (flux rise)     0.070 s
//   decay (flux fall)      0.023 s
//   centroid drift         0.500   (variation over 4 s windows)
//   onset density          3.86 per second
//
// Sparse and mobile: the sharpest attack and the largest spectral drift of the five. Percussive, and it travels.
//
// Cutoffs sit in 200-3000 Hz because that is where this corpus has energy:
// grains_600 has a median 99% rolloff of 2335 Hz. Archon's inherited machines
// sweep to 25740 Hz and were silent here until they were remapped.
{ |buf, args|
    var ioi     = 0.2322,
        fastest = 0.1277,
        spread  = 0.1625,
        // the factory's measured density scales the regime's own pacing rather
        // than replacing it, so the machine keeps its character while breathing
        scale   = args.at(\density).linlin(0.0, 1.2, 1.6, 0.6, clip: \minmax),
        atk     = 0.0697,
        rel     = 0.0232,
        body    = args.at(\avgrms).linlin(0.0, 1.0, 0.08, 0.30, clip: \minmax),
        centre  = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax),
        travel  = 0.5004,
        sweep;

    // measured drift becomes the filter's journey: a static regime holds, a
    // mobile one moves, and by how much is not a number I chose
    sweep = Env([centre, centre * (1 + travel), centre * (1 - (travel * 0.4))],
                [ioi * 8, ioi * 13], \sin).discretize(24).asArray;

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),

        // the regime's own interval distribution: its median, its fastest
        // tenth, and its spread, in the proportions the corpus showed
        \dur, Pseq([
            Pn(Pwhite(fastest, ioi) * scale, 4),
            Pn(Pwhite(ioi, ioi + spread) * scale, 2)
        ], inf),

        \atk, atk,
        \rel, rel,
        \cutoff, Pseq(sweep, inf),
        \rate, Pseq([1.0, 1.250, 1.0, 0.800], inf),
        \pan, Pwhite(-0.8, 0.8),
        \amp, Pwhite(body * 0.6, body),
        \out, 0
    )
}
