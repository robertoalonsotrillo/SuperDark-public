// brhmma2609051356x3 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition hm -> ma had been observed
// 5 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.62 between them:
//   hm median event 1.143 s
//   ma median event 0.013 s
//   this   0.0715 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.42), drawn from the shared table [ 1.0, 1.114, 1.246, 1.427 ].
//
{ |buf, args|
    var ioi   = 0.0715,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pstutter(Pwhite(1, 4), Prand([Pwhite(0.0301, 0.0625), Pwhite(0.0345, 0.0717)], inf)), 4), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pwhite(803.8874, 2411.6623), 1131.6151], [0.72, 0.28].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.4204, 0.468, 0.5235, 0.5999], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 4), Pn(Pgeom(0.2, 0.933, 3), inf)), inf).max(0.0005).min(0.5),
        \atk, 0.0107,
        \rel, 0.05,
        \out, 0
    )
}
