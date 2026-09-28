// brbrmapu2609051311x6brhpgl2609040130x22609211901x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brmapu2609051311x6 -> brhpgl2609040130x2 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.57 between them:
//   brmapu2609051311x6 median event 0.0966 s
//   brhpgl2609040130x2 median event 0.1405 s
//   this   0.1197 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.578), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.9574,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playgran,
        \freq, 8.36,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pseq([Pseg(Pseq([0.911, 1.2299, 0.3553], inf), Pseq([2.129, 12.0607], inf), \sin), 1.2532], inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pn(1200.0, 4), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.5779, 0.6607, 0.7776, 0.8618], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 2), Pseg(Pseq([0.2, 0.28, 0.072], inf), Pseq([1.5785, 9.0719], inf), \sin)), inf).max(0.0005).min(0.5),
        \atk, 0.479,
        \rel, 1.436,
        \out, 0
    )
}
