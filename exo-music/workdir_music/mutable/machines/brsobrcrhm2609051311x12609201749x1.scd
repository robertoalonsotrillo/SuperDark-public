// brsobrcrhm2609051311x12609201749x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition so -> brcrhm2609051311x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.49 between them:
//   so median event 0.092 s
//   brcrhm2609051311x1 median event 0.0724 s
//   this   0.0819 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.048), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.0819,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pgeom(0.0819, 0.995, 4), inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pseg(Pseq([1131.4002, 1697.1003, 339.4201], inf), Pseq([8.3599, 3.5334], inf), \lin), 1571.9284], [0.88, 0.12].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.048, 1.1983, 1.4102, 1.5629], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pwhite(0.12, 0.28), inf).max(0.0005).min(0.5),
        \atk, 0.0123,
        \rel, 0.0573,
        \out, 0
    )
}
