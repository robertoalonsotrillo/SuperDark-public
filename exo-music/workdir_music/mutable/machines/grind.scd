// grind — an example runtime machine, and a template.
//
// Deliberately built on constructors run 35 measured as ABSENT from the whole
// vocabulary: Pswitch chooses between sub-patterns, Ptuple advances several
// streams in lockstep, and Pclutch holds a value while a boolean stream says
// so. None of the sixteen originals uses any of them.
//
// It is also here to prove the loading path: this file is read with .load
// while the server is running. Adding, editing or deleting it does not stop
// the music.
{ |buf, args|
    var dense  = args.at(\density).linlin(0.0, 5.0, 0.12, 0.02, clip: \minmax),
        bright = args.at(\avgcent).linlin(0, 10000, 300, 4000, clip: \minmax),
        body   = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.30, clip: \minmax),
        width  = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
        hold;

    // true for a run, then false for a run: Pclutch freezes the filter while
    // false, so the colour arrives in blocks instead of per event.
    hold = Pseq([ Pn(true, 3), Pn(false, 5) ], inf);

    Pbind(
        \instrument, \playback,

        // Pswitch alternates two rhythmic identities rather than blending them
        \dur, Pswitch([
            Pseq([dense, dense, dense * 3], 4),
            Pseq([dense * 6, dense / 2, dense / 2, dense / 2], 2)
        ], Pseq([0, 1, 0, 0, 1], inf)),

        \atk, 0.004,
        \rel, 0.30,

        // Ptuple keeps rate and pan in lockstep, so a rising line always
        // sweeps the same way rather than the two drifting apart
        [\rate, \pan], Ptuple([
            Pseq([1.0, 1.5, 2.0, 1.5, 0.75, 0.5], inf),
            Pseq([-1, -0.5, 0, 0.5, 1, 0].collect({ |v| v * width }), inf)
        ], inf),

        \buf, Pshuf(buf, inf),
        \cutoff, Pclutch(Pwhite(bright * 0.6, bright * 1.8), hold),
        \amp, Pseq([body, body * 0.5, body * 0.75, body * 0.4], inf),
        \out, 0
    )
}
