// brwasc2609281238x3 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition wa -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 1.0 between them:
//   wa median event 0.054 s
//   sc median event 0.094 s
//   this   0.0939 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.212), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-st;rate<-so;cutoff<-cp;pan<-gl;amp<-gl;out<-grammar;env<-ht;layers=3;dsp=res
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0939,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var cp_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  cp_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  cp_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  cp_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  cp_reps = rrand(6, 35).asInteger,
  cp_atk = 0.1;
    var gl_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  gl_resonant = args.at(\percpitch).linlin(0.0, 1.0, 2, 7, clip: \minmax),
  gl_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  gl_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  gl_reps = rrand(gl_resonant * 2, gl_resonant * 10).asInteger,
  gl_atk = 0.1;
    var ht_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  ht_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  ht_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  ht_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  ht_reps = rrand(6, 35).asInteger,
  ht_atk = 0.1;
    var so_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  so_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  so_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  so_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  so_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  so_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  so_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  so_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  so_reps = rrand(so_dense, so_dense * 7),
  so_granreps = rrand(0, 1),
  so_choose = rrand(0, 2),
  so_freq = args.at(\mainpitch).asString.pitchcps,
  so_atk = rrand(0.01, 0.4);
    var st_rates = [0.125, 0.25, 0.5],
  st_bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
  st_rate = st_rates[st_bright.asInteger],
  st_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 1, 10, clip: \minmax),
  st_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  st_choose = rrand(0, 4),
  st_atk = 0.1;

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(0.01, 3.0), 0.0939], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([cp_bright * 1000, cp_bright * 2000, cp_bright * 500], [rrand(0.1, 10), rrand(4, 19)], \sin).discretize(69).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pseq(     [1.0]++     (0.5!(so_noise.asInteger))++     (-1.0!(so_dense.asInteger * 2))++     (1.0!((so_dense/2).asInteger)),     inf), 2.2121], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * (gl_freq / 2), gl_freq / 2), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(0.01, 0.08), 0.2], 1), inf)).max(0.0005).min(0.5),
        \res, 0.4224,
        \resfz, Pn(Pn(Pwrand([Pwhite(317.0094, 475.5141), Pseg(Pseq([800.4099, 960.4919, 384.1968], inf), Pseq([2.8092, 5.0421], inf), \exp)], [0.408, 0.592].normalizeSum, inf), 2), inf).max(60).min(6000),
        \resrt, 0.6334,
        \atk, (ht_atk).clip(0.003, 4.0),
        \rel, ((~sampleSize * 2) - ht_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 5), ((~reverbShortBus ? [0])[0] ! 2)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.0002).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.57, \pan, (Pkey(\pan) + 0.3).clip(-1.0, 1.0)),
        Pbindf(main, \rate, (Pkey(\rate) * 1.4916).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.6, \pan, (Pkey(\pan) + -0.78).clip(-1.0, 1.0))])
}
