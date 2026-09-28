// brryte2609281238x14 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition ry -> te had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.33 between them:
//   ry median event 0.082 s
//   te median event 0.11 s
//   this   0.0903 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.25), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-hm;pan<-grammar;amp<-st;out<-st;env<-grammar(percussive);layers=1;dsp=blur
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0903,
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
        \dur, Pn(Pwhite(0.0587, 0.1219), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq([ Pseries(hm_bright, hm_bright / 16, 8),      Pseries(hm_bright * 1.5, hm_bright / -16, 8) ], inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([0.2501, 0.2859, 0.3364, 0.3729], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(0.01, 0.1), 0.2], 1), inf)).max(0.0005).min(0.5),
        \blur, 0.7492,
        \blurhz, 2400.0,
        \atk, 0.0066,
        \rel, 0.0732,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~dryBus[rrand(0, 4) % ~numPairs]!2),     (~reverbShortBus[4 % ~numPairs]!1),     (~reverbMidBus[3 % ~numPairs]!(st_freq.asInteger)),    ], rrand(2, 5)), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
