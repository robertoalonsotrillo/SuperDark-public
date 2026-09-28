// brglpu2609051356x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition gl -> pu had been observed
// 5 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.59 between them:
//   gl median event 0.05 s
//   pu median event 0.443 s
//   this   0.1809 s -> mid layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.635), drawn from the shared table [ 1.0, 1.114, 1.246, 1.427 ].
//
{ |buf, args|
    var ioi   = 0.1809,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pstutter(Pwhite(1, 3), 0.1809), 2), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pn(Pgeom(1200.0, 0.873, 7), inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.635, 0.707, 0.7908, 0.9062], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseq([Pwrand([Pn(Pgeom(0.1609, 0.935, 7), inf), 0.1572, (0.154 * 1.019)], [0.539, 0.183, 0.278].normalizeSum, inf), 0.2143, Pstutter(Pwhite(1, 3), Pstutter(Pwhite(1, 2), Pwhite(0.1307, 0.305)))], inf), inf).max(0.0005).min(0.5),
        \atk, 0.0271,
        \rel, 0.1267,
        \out, 0
    )
}
