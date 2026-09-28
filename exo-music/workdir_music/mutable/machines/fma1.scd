// fma1 -- DERIVED FROM MEASUREMENT, not composed.
//
// Regime 1 of 5 in temporal_regimes.json, clustered from 12
// FMA tracks. Every number below is measured; see tools/analyse_temporal.py.
//
//   inter-onset interval   median 0.151 s, IQR 0.116, 10th pct 0.046
//   attack (flux rise)     0.534 s
//   decay (flux fall)      0.244 s
//   centroid drift         0.093   (variation over 4 s windows)
//   onset density          5.58 per second
//
// Sustained: the least mobile regime measured, with the longest decay. Events overlap into a continuous surface rather than articulating.
//
// Cutoffs sit in 200-3000 Hz because that is where this corpus has energy:
// grains_600 has a median 99% rolloff of 2335 Hz. Archon's inherited machines
// sweep to 25740 Hz and were silent here until they were remapped.
{ |buf, args|
    var ioi     = 0.1509,
        fastest = 0.0464,
        spread  = 0.1161,
        // the factory's measured density scales the regime's own pacing rather
        // than replacing it, so the machine keeps its character while breathing
        scale   = args.at(\density).linlin(0.0, 1.2, 1.6, 0.6, clip: \minmax),
        atk     = 0.5341,
        rel     = 0.2438,
        body    = args.at(\avgrms).linlin(0.0, 1.0, 0.08, 0.30, clip: \minmax),
        centre  = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax),
        travel  = 0.0931,
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
            Pn(Pwhite(fastest, ioi) * scale, 6),
            Pn(Pwhite(ioi, ioi + spread) * scale, 3)
        ], inf),

        \atk, atk,
        \rel, rel,
        \cutoff, Pseq(sweep, inf),
        \rate, Pseq([1.0, 1.047, 1.0, 0.963], inf),
        \pan, Pwhite(-0.8, 0.8),
        \amp, Pwhite(body * 0.6, body),
        \out, 0
    )
}
