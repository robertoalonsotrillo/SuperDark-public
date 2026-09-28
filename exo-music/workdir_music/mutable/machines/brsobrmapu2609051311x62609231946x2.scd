// brsobrmapu2609051311x62609231946x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition so -> brmapu2609051311x6 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.58 between them:
//   so median event 0.092 s
//   brmapu2609051311x6 median event 0.0966 s
//   this   0.0946 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.996), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-so;rate<-grammar;cutoff<-me;pan<-grammar;amp<-grammar;out<-grammar;env<-gl;layers=2;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0946,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var gl_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  gl_resonant = args.at(\percpitch).linlin(0.0, 1.0, 2, 7, clip: \minmax),
  gl_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  gl_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  gl_reps = rrand(gl_resonant * 2, gl_resonant * 10).asInteger,
  gl_atk = 0.1;
    var me_dur = args.at(\windowsize).linlin(0, 5, 0.18, 0.6, clip: \minmax),
  me_bright = args.at(\avgcent).linlin(0, 10000, 600, 5000, clip: \minmax),
  me_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
  
  me_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.75, clip: \minmax),
  me_motif = [0, 2, 4, 2, 7, 5, 4, 0],   
  me_atk = 0.01;
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

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pseq([     Pwhite(0.05, 0.2 * so_dur, 5),     Pwhite(0.01, 0.02 * so_dur, 6),     Pwhite(0.4, 2.2, (so_dur + 2).asInteger)    ], so_reps), 0.0946], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pclutch(     Pseq([ Pseries(me_bright, me_bright / 12, 6),      Pseries(me_bright * 1.5, me_bright / -12, 6) ], inf),     Pseq([true, false, false, true], inf)), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([1.996, 2.2822, 2.6857, 2.9766], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 3), Pwhite(0.12, 0.28)), inf).max(0.0005).min(0.5),
        \atk, (gl_atk).clip(0.003, 4.0),
        \rel, ((~sampleSize * 2) - gl_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 6), ((~dryBus ? [0])[0] ! 5)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.1436).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.46, \pan, (Pkey(\pan) + 0.7).clip(-1.0, 1.0))])
}
