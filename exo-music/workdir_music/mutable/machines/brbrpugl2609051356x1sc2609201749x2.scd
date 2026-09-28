// brbrpugl2609051356x1sc2609201749x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brpugl2609051356x1 -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.35 between them:
//   brpugl2609051356x1 median event 0.1126 s
//   sc median event 0.094 s
//   this   0.1056 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.594), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.8452,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playgran,
        \freq, 9.47,
        \buf, Pshuf(buf, inf),
        \dur, Pn((0.8452 * 1.32), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pstutter(Pwhite(1, 3), Pn(Pgeom(1200.0, 0.985, 5), inf)), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.594, 1.8225, 2.1448, 2.3771], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn((Pwhite(0.12, 0.28) * 1.214), inf).max(0.0005).min(0.5),
        \atk, 0.423,
        \rel, 1.268,
        \out, 0
    )
}
