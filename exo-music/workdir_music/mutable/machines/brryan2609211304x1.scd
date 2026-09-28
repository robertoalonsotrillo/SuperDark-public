// brryan2609211304x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition ry -> an had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.59 between them:
//   ry median event 0.082 s
//   an median event 0.037 s
//   this   0.0513 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.531), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.0513,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn((Pn(Pn(Pwhite(0.0333, 0.0692), 5), 6) * 1.076), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pn(1200.0, 6), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.5318, 1.7514, 2.061, 2.2843], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pn(Prand([Prand([0.1168, 0.1658, 0.1012], inf), Pn(Pgeom(0.2501, 1.139, 4), inf)], inf), 6), inf).max(0.0005).min(0.5),
        \atk, 0.0077,
        \rel, 0.0359,
        \out, 0
    )
}
