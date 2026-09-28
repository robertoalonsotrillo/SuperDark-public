// brtebrtebrrysc2609031456x12609051311x42609221232x5 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition te -> brtebrrysc2609031456x12609051311x4 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.61 between them:
//   te median event 0.11 s
//   brtebrrysc2609031456x12609051311x4 median event 0.0985 s
//   this   0.1029 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.098), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-pu;rate<-grammar;cutoff<-grammar;pan<-an;amp<-an;out<-grammar;env<-grammar(sustained);layers=2
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.1029,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var an_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  an_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  an_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  an_bright = args.at(\avgrolloff).linlin(0, 12000, 200, 10000, clip: \minmax),
  an_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  an_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  an_cutoff = rrand(100 * an_velocity, 400 * an_velocity),
  an_rate = (rrand(1, 2) * 2),
  an_reps = rrand(16, 80).asInteger,
  an_atk = (0.5 * (~sampleSize / an_rate));
    var pu_grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
  pu_bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
  pu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
  
  pu_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
  pu_atk = 0.005;

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pfsm([     #[0, 1],     Pseq([pu_grid, pu_grid, pu_grid, pu_grid], 1),                #[1, 2],     Pseq([pu_grid * 2, pu_grid, pu_grid], 1),                  #[0, 3],     Pseq([pu_grid / 2, pu_grid / 2, pu_grid, pu_grid * 2], 1),    #[1, 3],     Pseq([pu_grid * 4], 1),                              #[0, 1, 2]    ], inf), 0.1029], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pn(Pn(1200.0, 6), 2), inf).max(80).min(9000),
        \rate, Pn(Pseq([2.0985, 2.3993, 2.8236, 3.1294], inf), inf).max(0.25).min(4.0),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(     rrand(-1, 1),     (rrand(-1, 1) + 0.2)      .linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),     an_reps), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0, 0.1, 0], [rrand(4, 10), rrand(6, 14)], \sin).discretize(77).asArray,      inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, 0.0497,
        \rel, 0.1707,
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 2), ((~reverbShortBus ? [0])[0] ! 3)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.0002).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.74, \pan, (Pkey(\pan) + 0.68).clip(-1.0, 1.0))])
}
