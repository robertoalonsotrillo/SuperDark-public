// fma2 -- DERIVED FROM MEASUREMENT, not composed.
//
// Regime 2 of 5 in temporal_regimes.json, clustered from 68
// FMA tracks. Every number below is measured; see tools/analyse_temporal.py.
//
//   inter-onset interval   median 0.186 s, IQR 0.139, 10th pct 0.093
//   attack (flux rise)     0.418 s
//   decay (flux fall)      0.046 s
//   centroid drift         0.250   (variation over 4 s windows)
//   onset density          4.75 per second
//
// Middling on every axis. Included because it is what most of the corpus actually does, and a vocabulary of extremes would misrepresent it.
//
// Cutoffs sit in 200-3000 Hz because that is where this corpus has energy:
// grains_600 has a median 99% rolloff of 2335 Hz. Archon's inherited machines
// sweep to 25740 Hz and were silent here until they were remapped.
{ |buf, args|
    var ioi     = 0.1858,
        fastest = 0.0929,
        spread  = 0.1393,
        // the factory's measured density scales the regime's own pacing rather
        // than replacing it, so the machine keeps its character while breathing
        scale   = args.at(\density).linlin(0.0, 1.2, 1.6, 0.6, clip: \minmax),
        atk     = 0.4180,
        rel     = 0.0464,
        body    = args.at(\avgrms).linlin(0.0, 1.0, 0.08, 0.30, clip: \minmax),
        centre  = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax),
        travel  = 0.2504,
        sweep;

    // measured drift becomes the filter's journey: a static regime holds, a
    // mobile one moves, and by how much is not a number I chose
    sweep = Env([centre, centre * (1 + travel), centre * (1 - (travel * 0.4))],
                [ioi * 8, ioi * 13], \sin).discretize(24).asArray;

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),

        // the regime's own interval distribution: its median, its fastest
        // tenth, and its spread, in the proportions the corpus showed
        \dur, Pseq([
            Pn(Pwhite(fastest, ioi) * scale, 5),
            Pn(Pwhite(ioi, ioi + spread) * scale, 2)
        ], inf),

        \atk, atk,
        \rel, rel,
        \cutoff, Pseq(sweep, inf),
        \rate, Pseq([1.0, 1.125, 1.0, 0.900], inf),
        \pan, Pwhite(-0.8, 0.8),
        \amp, Pwhite(body * 0.6, body),
        \out, 0
    )
}
