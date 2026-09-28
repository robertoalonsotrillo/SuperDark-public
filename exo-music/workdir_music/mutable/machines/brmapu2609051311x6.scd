// brmapu2609051311x6 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition ma -> pu had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.57 between them:
//   ma median event 0.013 s
//   pu median event 0.443 s
//   this   0.0966 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.087), drawn from the shared table [ 1.0, 1.114, 1.246, 1.427 ].
//
{ |buf, args|
    var ioi   = 0.0966,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(0.0966, inf).max(0.01).min(6.0),
        \cutoff, Pn(Pn(Pgeom(1200.0, 0.944, 4), inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.0868, 1.21, 1.3534, 1.551], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pwrand([Pwrand([Pn(Pgeom(0.1891, 0.928, 7), inf), Pn(Pwhite(0.1362, 0.3177), 2), Pwhite(0.1864, 0.435)], [0.524, 0.08, 0.396].normalizeSum, inf), Pstutter(Pwhite(1, 2), Pwrand([Pwhite(0.0973, 0.227), 0.1567], [0.411, 0.589].normalizeSum, inf))], [0.309, 0.691].normalizeSum, inf), inf).max(0.0005).min(0.5),
        \atk, 0.0145,
        \rel, 0.0676,
        \out, 0
    )
}
