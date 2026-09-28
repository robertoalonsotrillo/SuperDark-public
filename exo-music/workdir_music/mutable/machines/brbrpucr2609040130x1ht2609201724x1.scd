// brbrpucr2609040130x1ht2609201724x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brpucr2609040130x1 -> ht had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.45 between them:
//   brpucr2609040130x1 median event 0.0472 s
//   ht median event 0.057 s
//   this   0.0513 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.047), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.0513,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pseg(Pseq([0.0513, 0.0693, 0.02], inf), Pseq([3.2481, 11.4409], inf), \lin), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pn(Pseg(Pseq([1200.0, 1800.0, 360.0], inf), Pseq([4.6162, 7.7924], inf), \exp), 6), inf).max(80).min(9000),
        \rate, Pn(Pseq([2.0471, 2.3406, 2.7545, 3.0529], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Prand([Pwhite(0.0812, 0.1896), Pseq([Pwrand([0.2312, Pwhite(0.1736, 0.4051), Pwhite(0.0969, 0.2262)], [0.192, 0.26, 0.547].normalizeSum, inf), Pseq([Pwhite(0.1119, 0.2611), 0.2374, Pwhite(0.2189, 0.5)], inf), 0.1717], inf), Pseg(Pseq([0.1856, 0.2599, 0.0668], inf), Pseq([2.4244, 7.3945], inf), \exp)], inf), inf).max(0.0005).min(0.5),
        \atk, 0.0077,
        \rel, 0.0359,
        \out, 0
    )
}
