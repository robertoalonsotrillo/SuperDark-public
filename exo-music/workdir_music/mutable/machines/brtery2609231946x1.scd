// brtery2609231946x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition te -> ry had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.47 between them:
//   te median event 0.11 s
//   ry median event 0.082 s
//   this   0.0957 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.184), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-sc;rate<-te;cutoff<-wa;pan<-grammar;amp<-lu;out<-grammar;env<-ma;layers=2;dsp=res
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0957,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var lu_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  lu_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  lu_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  lu_cent = args.at(\avgcent).linlin(0, 10000, 200, 13000, clip: \minmax),
  lu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  lu_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  lu_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  lu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  lu_atk = 0.1;
    var ma_dur = args.at(\density).linlin(0.0, 5.0, 0.2, 1.0, clip: \minmax),
  ma_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.1, 0.3, clip: \minmax),
  ma_bright = args.at(\avgrolloff).linlin(1000, 12000, 1, 4, clip: \minmax),
  ma_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  ma_width = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax),
  ma_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  ma_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  ma_cutoff = rrand(200 * ma_velocity, 800 * ma_velocity),
  ma_reps = rrand(10, ma_bright * 50),
  ma_atk = 0.1;
    var sc_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  sc_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  sc_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  sc_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  sc_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  sc_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  sc_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  sc_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  sc_atk = 0.1;
    var te_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  te_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  te_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  te_bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
  te_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  te_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  te_cutoff = rrand(200 * te_velocity, 800 * te_velocity),
  te_reps = rrand(10, 35).asInteger,
  te_atk = rrand(0.01, te_variance + 0.1);
    var wa_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  wa_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  wa_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  wa_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  wa_reps = rrand(6, 35).asInteger,
  wa_atk = 0.1;

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pseq([     Pwhite(0.05, 0.2 * sc_dur, (sc_dur + 2).asInteger),     Pwhite(0.01, 0.02 * sc_dur, (sc_dur + 2).asInteger),     Pwhite(0.4, 1.2, (sc_dur + 2).asInteger)    ], 2), 0.0957], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([wa_bright * 1000, wa_bright * 2000, wa_bright * 500], [rrand(0.1, 10), rrand(4, 19)], \sin).discretize(69).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pwrand(     [0.5, 1, 2.0, -1],     [2, 6, 1, 6].normalizeSum,     te_reps * 2), 2.1837], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(0.02, 0.1), 0.2], 1), inf)).max(0.0005).min(0.5),
        \res, 0.3381,
        \resfz, Pn(Pn(Pwhite(1440.0, 2160.0), 3), inf).max(60).min(6000),
        \resrt, 1.3921,
        \atk, (ma_atk).clip(0.003, 4.0),
        \rel, (~sampleSize - ma_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbMidBus ? [0])[0] ! 5), ((~reverbLongBus ? [0])[0] ! 4), ((~reverbLongBus ? [0])[0] ! 2)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.4916).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.52, \pan, (Pkey(\pan) + 0.71).clip(-1.0, 1.0))])
}
