// brtebrcrhm2609051311x12609262056x3 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition te -> brcrhm2609051311x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.39 between them:
//   te median event 0.11 s
//   brcrhm2609051311x1 median event 0.0724 s
//   this   0.0935 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.135), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-grammar;pan<-ma;amp<-dr;out<-grammar;env<-me;layers=1;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0935,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var dr_dur = args.at(\windowsize).linlin(0, 5, 3.0, 9.0, clip: \minmax),
  dr_dark = args.at(\avgcent).linlin(0, 10000, 90, 700, clip: \minmax),
  dr_width = args.at(\avgrms).linlin(0.0, 1.0, 0.4, 1.0, clip: \minmax),
  
  
  
  dr_body = args.at(\avgrms).linlin(0.0, 1.0, 0.12, 0.39, clip: \minmax),
  dr_atk = 1.2,
  dr_voice;
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
    var me_dur = args.at(\windowsize).linlin(0, 5, 0.18, 0.6, clip: \minmax),
  me_bright = args.at(\avgcent).linlin(0, 10000, 600, 5000, clip: \minmax),
  me_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
  
  me_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.75, clip: \minmax),
  me_motif = [0, 2, 4, 2, 7, 5, 4, 0],   
  me_atk = 0.01;

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn((Pwhite(0.0608, 0.1263) * 0.846), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwhite(600.0, 1800.0), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.135, 1.2977, 1.5271, 1.6926], inf), inf).max(0.25).min(4.0),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(     rrand(-1, 1),     (rrand(-1, 1) + 0.3)      .linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),     inf), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(dr_body * 0.6, dr_body), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, (me_atk).clip(0.003, 4.0),
        \rel, (me_dur * 2).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 6), ((~reverbLongBus ? [0])[0] ! 5)], inf))
    );
    main
}
