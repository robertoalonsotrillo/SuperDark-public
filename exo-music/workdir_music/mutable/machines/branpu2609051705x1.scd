// branpu2609051705x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition an -> pu had been observed
// 2 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.38 between them:
//   an median event 0.037 s
//   pu median event 0.443 s
//   this   0.0952 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.569), drawn from the shared table [ 1.0, 1.114, 1.246, 1.427 ].
//
{ |buf, args|
    var ioi   = 0.762,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playgran,
        \freq, 10.5,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pgeom(0.762, 0.877, 4), inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pseq([1208.4771, Pseq([Pseg(Pseq([1209.5785, 1814.3678, 362.8736], inf), Pseq([7.3103, 2.0553], inf), \lin), Pseq([Pwhite(327.185, 981.5549), 1048.9518, 850.3201], inf), Pn(1086.4702, 2)], inf), Pwrand([Pwrand([1567.6922, Pwhite(728.537, 2185.611)], [0.411, 0.589].normalizeSum, inf), (Pwhite(976.2719, 2928.8157) * 1.301), Pwhite(979.0733, 2937.2198)], [0.179, 0.707, 0.113].normalizeSum, inf), Pn(Pgeom(1030.8028, 0.892, 6), inf)], inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.5687, 0.6332, 0.7083, 0.8117], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseq([0.2119, Pseq([Pwhite(0.0755, 0.1763), Pstutter(Pwhite(1, 4), Pwhite(0.1151, 0.2685))], inf), Pn(Prand([0.1735, 0.2343], inf), 4)], inf), inf).max(0.0005).min(0.5),
        \atk, 0.381,
        \rel, 1.143,
        \out, 0
    )
}
