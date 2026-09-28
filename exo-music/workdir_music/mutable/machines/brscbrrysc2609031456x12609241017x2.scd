// brscbrrysc2609031456x12609241017x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> brrysc2609031456x1 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.4 between them:
//   sc median event 0.094 s
//   brrysc2609031456x1 median event 0.0891 s
//   this   0.092 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.19), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-gl;rate<-pu;cutoff<-gl;pan<-ht;amp<-grammar;out<-grammar;env<-grammar(sustained);layers=1;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.092,
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
    var ht_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  ht_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  ht_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  ht_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  ht_reps = rrand(6, 35).asInteger,
  ht_atk = 0.1;
    var pu_grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
  pu_bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
  pu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
  
  pu_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
  pu_atk = 0.005;

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(0.01, 0.1), 0.092], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([gl_bright * 1000, gl_bright * 2000, gl_bright * 500], [rrand(0.1, 3), rrand(4, 19)], \sin).discretize(71).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pwrand([1.0, 2.0, 0.5], [0.7, 0.2, 0.1], inf), 1.1902], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * (ht_freq / 2), ht_freq / 2), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pn(Pseg(Pseq([0.2, 0.28, 0.072], inf), Pseq([2.4785, 12.6125], inf), \sin), inf).max(0.0005).min(0.5),
        \atk, 0.0251,
        \rel, 0.2153,
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 5), ((~reverbShortBus ? [0])[0] ! 6), ((~dryBus ? [0])[0] ! 1)], inf))
    );
    main
}
