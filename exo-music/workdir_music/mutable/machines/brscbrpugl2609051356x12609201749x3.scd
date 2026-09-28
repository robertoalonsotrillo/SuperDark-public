// brscbrpugl2609051356x12609201749x3 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> brpugl2609051356x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.45 between them:
//   sc median event 0.094 s
//   brpugl2609051356x1 median event 0.1126 s
//   this   0.102 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.798), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.102,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pseg(Pseq([0.102, 0.1377, 0.0398], inf), Pseq([2.1961, 1.9125], inf), \sin), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pseg(Pseq([1573.371, 2360.0566, 472.0113], inf), Pseq([6.77, 1.8788], inf), \exp), Pseq([(Pwhite(388.9382, 1166.8146) * 0.726), Pn(Pgeom(852.8795, 0.895, 3), inf)], inf)], [0.269, 0.731].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.7987, 0.9132, 1.0746, 1.191], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(0.2, inf).max(0.0005).min(0.5),
        \atk, 0.0153,
        \rel, 0.0714,
        \out, 0
    )
}
