// brteht2609281238x5 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition te -> ht had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 1.45 between them:
//   te median event 0.11 s
//   ht median event 0.057 s
//   this   0.0425 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.795), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-cr;pan<-grammar;amp<-grammar;out<-grammar;env<-grammar(swell);layers=2;dsp=blur
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0425,
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
        \instrument, \playbackHPFX,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pwhite(0.0276, 0.0573), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([cr_cent, cr_cent * 2, cr_cent / 2], [rrand(2, 10), rrand(2, 40)], \sin).discretize(128).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([1.7955, 2.0529, 2.4159, 2.6776], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseq([Pseg(Pseq([0.1855, 0.2598, 0.0668], inf), Pseq([3.2356, 9.8257], inf), \exp), Pstutter(Pwhite(1, 4), 0.1443), Pwhite(0.093, 0.217)], inf), inf).max(0.0005).min(0.5),
        \blur, 0.3742,
        \blurhz, 600.0,
        \atk, 0.0386,
        \rel, 0.0204,
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 2), ((~reverbLongBus ? [0])[0] ! 6), ((~reverbShortBus ? [0])[0] ! 1), ((~reverbMidBus ? [0])[0] ! 4)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.4916).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.71, \pan, (Pkey(\pan) + 0.75).clip(-1.0, 1.0))])
}
