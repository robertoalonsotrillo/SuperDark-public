// brhtwa2609201738x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition ht -> wa had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.65 between them:
//   ht median event 0.057 s
//   wa median event 0.054 s
//   this   0.055 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.996), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
//
{ |buf, args|
    var ioi   = 0.055,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pwrand([Pstutter(Pwhite(1, 2), Prand([Pwhite(0.0629, 0.1307), Pwhite(0.0433, 0.0898), Pwhite(0.0315, 0.0655)], inf)), Pn(Pgeom(0.0479, 1.168, 5), inf)], [0.482, 0.518].normalizeSum, inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pstutter(Pwhite(1, 3), Pseg(Pseq([1182.3542, 1773.5314, 354.7063], inf), Pseq([6.9148, 6.3591], inf), \exp)), Pseq([Pn(Pwhite(587.2669, 1761.8007), 4), Pseq([1254.599, Pwhite(562.8419, 1688.5258), 917.0719, 893.179], inf), 1592.0544, Pstutter(Pwhite(1, 3), 1939.6383)], inf), Pn((Pwhite(805.673, 2417.019) * 0.644), 6)], [0.449, 0.322, 0.229].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.996, 2.2822, 2.6857, 2.9766], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Prand([Prand([(Pwhite(0.2264, 0.5) * 1.271), Pn(0.3462, 3)], inf), Pn(Pgeom(0.1936, 0.866, 7), inf), Pwrand([Pwrand([0.0786, Pwhite(0.0804, 0.1876)], [0.679, 0.321].normalizeSum, inf), Pwhite(0.0711, 0.166)], [0.665, 0.335].normalizeSum, inf)], inf), inf).max(0.0005).min(0.5),
        \atk, 0.0083,
        \rel, 0.0385,
        \out, 0
    )
}
