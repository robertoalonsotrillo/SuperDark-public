// brbrhmma2609051356x3te2609221232x8 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brhmma2609051356x3 -> te had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.62 between them:
//   brhmma2609051356x3 median event 0.0715 s
//   te median event 0.11 s
//   this   0.0934 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (3.047), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-hm;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-grammar;out<-grammar;env<-grammar(percussive);layers=1
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0934,
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

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([hm_dur, 0.0934], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pstutter(Pwhite(1, 2), Pn(1200.0, 3)), inf).max(80).min(9000),
        \rate, Pn(Pseq([3.048, 3.485, 4.0, 4.0], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(0.2, inf).max(0.0005).min(0.5),
        \atk, 0.0129,
        \rel, 0.0532,
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 1), ((~dryBus ? [0])[0] ! 6)], inf))
    );
    main
}
