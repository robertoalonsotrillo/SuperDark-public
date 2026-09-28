// brscbrpucr2609040130x12609211304x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> brpucr2609040130x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.39 between them:
//   sc median event 0.094 s
//   brpucr2609040130x1 median event 0.0472 s
//   this   0.0716 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.825), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.0716,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pwhite(0.0466, 0.0967), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwhite(600.0, 1800.0), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.8256, 0.9439, 1.1108, 1.2312], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(0.2, inf).max(0.0005).min(0.5),
        \atk, 0.0107,
        \rel, 0.0501,
        \out, 0
    )
}
