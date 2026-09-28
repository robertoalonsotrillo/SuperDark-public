// brgpst16 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition gp -> st had been observed
// 16 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.44 between them:
//   gp median event 2.488 s
//   st median event 0.891 s
//   this   1.7926 s -> macro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
{ |buf, args|
    var ioi   = 1.7926,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pseq([
            Pn(Pwhite(ioi * 0.7, ioi) * scale, 3),
            Pn(Pwhite(ioi, ioi * 1.6) * scale, 3)
        ], inf),
        \atk, 0.2689,
        \rel, 1.2548,
        \cutoff, Pseg(Pseq([centre, centre * 1.7, centre * 0.8], inf),
                       Pseq([ioi * 9, ioi * 14], inf), \sin),
        \rate, Pseq([1.0, 0.97, 1.0], inf),
        \pan, Pwhite(-0.7, 0.7),
        \amp, Pwhite(body * 0.6, body),
        \out, 0
    )
}
