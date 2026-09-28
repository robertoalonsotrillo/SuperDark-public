// brtebrmapu2609051311x62609211901x4 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition te -> brmapu2609051311x6 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.6 between them:
//   te median event 0.11 s
//   brmapu2609051311x6 median event 0.0966 s
//   this   0.1017 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.795), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.1017,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pwrand([0.0852, Pwhite(0.0898, 0.1864)], [0.669, 0.331].normalizeSum, inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(1200.0, inf).max(80).min(9000),
        \rate, Pn(Pseq([1.7955, 2.0529, 2.4159, 2.6776], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 2), (Prand([0.145, 0.2501, 0.1674], inf) * 1.248)), inf).max(0.0005).min(0.5),
        \atk, 0.0153,
        \rel, 0.0712,
        \out, 0
    )
}
