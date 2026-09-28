// brbrpugl2609051356x1so2609201749x4 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brpugl2609051356x1 -> so had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.43 between them:
//   brpugl2609051356x1 median event 0.1126 s
//   so median event 0.092 s
//   this   0.1033 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.049), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.1033,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Prand([Pstutter(Pwhite(1, 2), Pseq([Pwhite(0.0578, 0.12), 0.0513], inf)), Pwhite(0.0483, 0.1003), 0.0849], inf), inf).max(0.01).min(6.0),
        \cutoff, Pn((Pwrand([(1569.4453 * 1.21), 863.0663, Pstutter(Pwhite(1, 4), 738.5425)], [0.311, 0.333, 0.356].normalizeSum, inf) * 1.027), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.0492, 1.1996, 1.4118, 1.5647], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Prand([Pseg(Pseq([0.1912, 0.2677, 0.0688], inf), Pseq([1.8522, 5.1856], inf), \exp), Pstutter(Pwhite(1, 4), Pseg(Pseq([0.2278, 0.3189, 0.082], inf), Pseq([4.7111, 2.958], inf), \sin)), Pwrand([Pseg(Pseq([0.1381, 0.1934, 0.0497], inf), Pseq([8.2681, 7.8276], inf), \exp), Pwhite(0.137, 0.3197), Prand([Pwhite(0.0761, 0.1775), Pwhite(0.0984, 0.2296), 0.1498], inf)], [0.325, 0.342, 0.333].normalizeSum, inf)], inf), inf).max(0.0005).min(0.5),
        \atk, 0.0155,
        \rel, 0.0723,
        \out, 0
    )
}
