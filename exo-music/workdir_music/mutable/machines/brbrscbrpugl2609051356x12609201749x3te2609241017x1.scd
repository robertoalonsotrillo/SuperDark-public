// brbrscbrpugl2609051356x12609201749x3te2609241017x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brscbrpugl2609051356x12609201749x3 -> te had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.56 between them:
//   brscbrpugl2609051356x12609201749x3 median event 0.102 s
//   te median event 0.11 s
//   this   0.1064 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.095), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-lu;pan<-grammar;amp<-dr;out<-grammar;env<-dr;layers=1;dsp=res+dly
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.1064,
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
    var lu_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  lu_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  lu_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  lu_cent = args.at(\avgcent).linlin(0, 10000, 200, 13000, clip: \minmax),
  lu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  lu_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  lu_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  lu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  lu_atk = 0.1;

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pseq([Pn(Pn(Pgeom(0.113, 1.084, 3), inf), 3), Pseq([0.0615, Prand([Pwhite(0.0391, 0.0812), 0.0553], inf), (Pwhite(0.0369, 0.0766) * 0.998), Pwrand([Pwhite(0.035, 0.0727), Pwhite(0.0389, 0.0807), 0.056], [0.159, 0.586, 0.255].normalizeSum, inf)], inf)], inf), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([lu_cent, 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([1.0952, 1.2522, 1.4736, 1.6333], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(dr_body * 0.6, dr_body), 0.2], 1), inf)).max(0.0005).min(0.5),
        \res, 0.3784,
        \resfz, Pn(Pseq([1997.0025, Prand([Pwhite(1055.0491, 1582.5736), Pn(Pwhite(752.6549, 1128.9824), 3)], inf), Pn(Pwrand([Pwhite(1438.1746, 2157.2619), Pwhite(1103.9985, 1655.9977), Pwhite(1915.9467, 2873.92)], [0.377, 0.102, 0.521].normalizeSum, inf), 6)], inf), inf).max(60).min(6000),
        \resrt, 1.0376,
        \dly, 0.224,
        \dlyt, 0.0235,
        \dlyfb, 0.6593,
        \atk, (dr_atk).clip(0.003, 4.0),
        \rel, (dr_dur).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbShortBus ? [0])[0] ! 1), ((~reverbLongBus ? [0])[0] ! 1), ((~dryBus ? [0])[0] ! 6), ((~reverbLongBus ? [0])[0] ! 1)], inf))
    );
    main
}
