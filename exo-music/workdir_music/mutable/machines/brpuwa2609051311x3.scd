// brpuwa2609051311x3 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition pu -> wa had been observed
// 1 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.44 between them:
//   pu median event 0.443 s
//   wa median event 0.054 s
//   this   0.1771 s -> mid layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.669), drawn from the shared table [ 1.0, 1.114, 1.246, 1.427 ].
//
{ |buf, args|
    var ioi   = 1.4171,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playgran,
        \freq, 5.65,
        \buf, Pshuf(buf, inf),
        \dur, Pn((Prand([Pn(1.7796, 6), Pwrand([Pwhite(0.4745, 0.9854), 1.1036], [0.74, 0.26].normalizeSum, inf), Pwrand([2.3223, 2.212, 1.1134], [0.408, 0.22, 0.372].normalizeSum, inf)], inf) * 0.969), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pstutter(Pwhite(1, 4), (Pn(1200.0, 5) * 0.777)), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.6688, 0.7446, 0.8328, 0.9544], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseq([Prand([Pwrand([0.1326, Pwhite(0.0534, 0.1246)], [0.491, 0.509].normalizeSum, inf), 0.0984], inf), 0.1358, Pwrand([0.2943, 0.3206, 0.1778], [0.518, 0.36, 0.122].normalizeSum, inf)], inf), inf).max(0.0005).min(0.5),
        \atk, 0.709,
        \rel, 2.126,
        \out, 0
    )
}
