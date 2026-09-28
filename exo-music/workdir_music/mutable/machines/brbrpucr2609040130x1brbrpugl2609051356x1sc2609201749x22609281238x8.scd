// brbrpucr2609040130x1brbrpugl2609051356x1sc2609201749x22609281238x8 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brpucr2609040130x1 -> brbrpugl2609051356x1sc2609201749x2 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at -0.91 between them:
//   brpucr2609040130x1 median event 0.0472 s
//   brbrpugl2609051356x1sc2609201749x2 median event 0.1056 s
//   this   0.0226 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
{ |buf, args|
    var ioi   = 0.0226,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;

    main = Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pseq([
            Pn(Pwhite(ioi * 0.7, ioi) * scale, 4),
            Pn(Pwhite(ioi, ioi * 1.6) * scale, 2)
        ], inf),
        \cutoff, Pseg(Pseq([centre, centre * 1.7, centre * 0.8], inf),
                       Pseq([ioi * 9, ioi * 14], inf), \sin),
        \rate, Pseq([1.0, 1.04, 1.0], inf),
        \pan, Pwhite(-0.7, 0.7),
        \amp, Pwhite(body * 0.6, body),
        \atk, 0.0034,
        \rel, 0.0158,
        \out, 0
    );
    main
}
