// brtesc2609231411x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition te -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.59 between them:
//   te median event 0.11 s
//   sc median event 0.094 s
//   this   0.1003 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.095), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-grammar;pan<-hm;amp<-sc;out<-sc;env<-grammar(sustained);layers=1;dsp=blur
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.1003,
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
    var sc_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  sc_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  sc_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  sc_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  sc_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  sc_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  sc_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  sc_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  sc_atk = 0.1;

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pn((0.1003 * 1.392), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pn(Pwrand([1195.2192, Pwrand([1907.178, 1350.6775], [0.522, 0.478].normalizeSum, inf)], [0.611, 0.389].normalizeSum, inf), 2), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.0952, 1.2522, 1.4736, 1.6333], inf), inf).max(0.25).min(4.0),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * hm_width, hm_width), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(0.02, 0.1), 0.2], 1), inf)).max(0.0005).min(0.5),
        \blur, 0.5413,
        \blurhz, 1200.0,
        \atk, 0.0454,
        \rel, 0.2419,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~dryBus[rrand(0, 4) % ~numPairs]!(sc_bright.asInteger)),     (~reverbShortBus[rrand(0, 4) % ~numPairs]!4),     (~reverbLongBus[rrand(0, 4) % ~numPairs]!(sc_resonant.asInteger)),     (~dryBus[1 % ~numPairs]!1),     (~reverbMidBus[0 % ~numPairs]!(sc_resonant.asInteger))], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
