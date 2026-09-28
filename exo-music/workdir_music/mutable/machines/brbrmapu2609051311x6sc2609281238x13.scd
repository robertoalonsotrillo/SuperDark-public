// brbrmapu2609051311x6sc2609281238x13 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brmapu2609051311x6 -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at -0.09 between them:
//   brmapu2609051311x6 median event 0.0966 s
//   sc median event 0.094 s
//   this   0.0968 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.422), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-pu;cutoff<-grammar;pan<-grammar;amp<-te;out<-grammar;env<-te;layers=2;dsp=res+dly
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0968,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var pu_grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
  pu_bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
  pu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
  
  pu_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
  pu_atk = 0.005;
    var te_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  te_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  te_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  te_bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
  te_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  te_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  te_cutoff = rrand(200 * te_velocity, 800 * te_velocity),
  te_reps = rrand(10, 35).asInteger,
  te_atk = rrand(0.01, te_variance + 0.1);

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pseq([(0.0793 * 1.379), Pstutter(Pwhite(1, 3), Pwhite(0.0483, 0.1003)), Pwrand([Pwhite(0.107, 0.2222), Pwhite(0.0739, 0.1535), Pwhite(0.0658, 0.1367)], [0.064, 0.442, 0.495].normalizeSum, inf)], inf), 4), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pseq([1523.1977, 768.2046], inf), inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pwrand([1.0, 2.0, 0.5], [0.7, 0.2, 0.1], inf), 1.4221], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0, 0.1, 0], [(te_reps / 2).asInteger, (te_reps / 2).asInteger], \sin).discretize(44).asArray,      inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \res, 0.237,
        \resfz, Pn(Pstutter(Pwhite(1, 3), Pstutter(Pwhite(1, 3), Pn(600.0, 6))), inf).max(60).min(6000),
        \resrt, 0.8389,
        \dly, 0.2966,
        \dlyt, 0.009,
        \dlyfb, 0.5653,
        \atk, (te_atk).clip(0.003, 4.0),
        \rel, (~sampleSize - te_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbShortBus ? [0])[0] ! 2), ((~reverbShortBus ? [0])[0] ! 6), ((~reverbShortBus ? [0])[0] ! 6), ((~reverbShortBus ? [0])[0] ! 5)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.0002).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.58, \pan, (Pkey(\pan) + 0.44).clip(-1.0, 1.0))])
}
