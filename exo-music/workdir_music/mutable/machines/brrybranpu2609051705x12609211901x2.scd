// brrybranpu2609051705x12609211901x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition ry -> branpu2609051705x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.5 between them:
//   ry median event 0.082 s
//   branpu2609051705x1 median event 0.0952 s
//   this   0.0884 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.0), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.0884,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pwrand([(Pwhite(0.0607, 0.1261) * 1.084), (0.1217 * 0.825), Pwrand([Pstutter(Pwhite(1, 2), Pwhite(0.0459, 0.0953)), Pstutter(Pwhite(1, 4), 0.0418), Pstutter(Pwhite(1, 4), Pwhite(0.0354, 0.0735))], [0.46, 0.388, 0.152].normalizeSum, inf)], [0.394, 0.465, 0.141].normalizeSum, inf), inf).max(0.01).min(6.0),
        \cutoff, Pn((Pstutter(Pwhite(1, 4), 1200.0) * 1.106), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.0002, 1.1436, 1.3458, 1.4916], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 3), Pstutter(Pwhite(1, 4), Pstutter(Pwhite(1, 2), Pwhite(0.12, 0.28)))), inf).max(0.0005).min(0.5),
        \atk, 0.0133,
        \rel, 0.0619,
        \out, 0
    )
}
