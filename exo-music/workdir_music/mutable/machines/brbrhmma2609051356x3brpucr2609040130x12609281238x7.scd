// brbrhmma2609051356x3brpucr2609040130x12609281238x7 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brhmma2609051356x3 -> brpucr2609040130x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 2.6 between them:
//   brhmma2609051356x3 median event 0.0715 s
//   brpucr2609040130x1 median event 0.0472 s
//   this   0.0243 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.317), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-grammar;out<-cr;env<-grammar(percussive);layers=3;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0243,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var cr_dur = args.at(\density).linlin(0.0, 5.0, 0.2, 1.0, clip: \minmax),
  cr_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.1, 0.3, clip: \minmax),
  cr_bright = args.at(\avgrolloff).linlin(1000, 12000, 1, 4, clip: \minmax),
  
  
  
  
  
  
  cr_cent = args.at(\avgcent).linlin(0, 10000, 150, 6000, clip: \minmax),
  cr_width = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax),
  cr_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  cr_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  cr_cutoff = rrand(200 * cr_velocity, 800 * cr_velocity),
  cr_reps = rrand(10, cr_bright * 50),
  cr_buffno = rrand(0, 10),
  cr_atk = 0.1;

    main = Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pstutter(Pwhite(1, 3), Pn(Pgeom(0.0243, 0.9, 5), inf)), 2), inf).max(0.01).min(6.0),
        \cutoff, Pn(1200.0, inf).max(80).min(9000),
        \rate, Pn(Pseq([0.3166, 0.362, 0.426, 0.4722], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseg(Pseq([0.2, 0.28, 0.072], inf), Pseq([1.4454, 7.683], inf), \exp), inf).max(0.0005).min(0.5),
        \atk, 0.003,
        \rel, 0.0158,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~reverbShortBus[rrand(0, 4) % ~numPairs]!((cr_bright + 1).asInteger)),     (~reverbMidBus[rrand(0, 4) % ~numPairs]!((cr_bright + 1).asInteger)),     (~dryBus[rrand(0, 4) % ~numPairs]!(3))     ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.0002).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.65, \pan, (Pkey(\pan) + 0.67).clip(-1.0, 1.0)),
        Pbindf(main, \rate, (Pkey(\rate) * 1.1436).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.62, \pan, (Pkey(\pan) + -0.75).clip(-1.0, 1.0))])
}
