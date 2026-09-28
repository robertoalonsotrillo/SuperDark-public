// brbrhpgl2609040130x2brcrhm2609051311x12609261101x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brhpgl2609040130x2 -> brcrhm2609051311x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.51 between them:
//   brhpgl2609040130x2 median event 0.1405 s
//   brcrhm2609051311x1 median event 0.0724 s
//   this   0.0999 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.354), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-so;pan<-sc;amp<-hm;out<-grammar;env<-me;layers=2;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0999,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var hm_dur = args.at(\windowsize).linlin(0, 5, 1.1, 3.5, clip: \minmax),
  hm_bright = args.at(\avgrolloff).linlin(0, 12000, 500, 4000, clip: \minmax),
  hm_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
  
  hm_body = args.at(\avgrms).linlin(0.0, 1.0, 0.12, 0.36, clip: \minmax),
  hm_prog = [0, 9, 5, 7],   
  hm_voice;
    var me_dur = args.at(\windowsize).linlin(0, 5, 0.18, 0.6, clip: \minmax),
  me_bright = args.at(\avgcent).linlin(0, 10000, 600, 5000, clip: \minmax),
  me_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
  
  me_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.75, clip: \minmax),
  me_motif = [0, 2, 4, 2, 7, 5, 4, 0],   
  me_atk = 0.01;
    var sc_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  sc_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  sc_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  sc_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  sc_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  sc_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  sc_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  sc_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  sc_atk = 0.1;
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
        \dur, Pn((Pn(Pgeom(0.0999, 0.921, 7), inf) * 0.622), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([so_cent, so_cent * 2, so_cent / 2], [1.0, 6.0], \sin).discretize(33).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([1.3547, 1.5489, 1.8228, 2.0203], inf), inf).max(0.25).min(4.0),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * sc_width, sc_width), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pflatten(1, Pn(Pseq([hm_body, 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, (me_atk).clip(0.003, 4.0),
        \rel, (me_dur * 2).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbMidBus ? [0])[0] ! 1), ((~reverbShortBus ? [0])[0] ! 6), ((~reverbLongBus ? [0])[0] ! 1)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.1436).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.53, \pan, (Pkey(\pan) + 0.66).clip(-1.0, 1.0))])
}
