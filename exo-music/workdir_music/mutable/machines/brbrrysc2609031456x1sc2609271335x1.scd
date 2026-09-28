// brbrrysc2609031456x1sc2609271335x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brrysc2609031456x1 -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.49 between them:
//   brrysc2609031456x1 median event 0.0891 s
//   sc median event 0.094 s
//   this   0.0914 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.0), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-ry;rate<-grammar;cutoff<-lu;pan<-grammar;amp<-grammar;out<-ry;env<-cp;layers=1;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0914,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var cp_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  cp_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  cp_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  cp_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  cp_reps = rrand(6, 35).asInteger,
  cp_atk = 0.1;
    var lu_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  lu_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  lu_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  lu_cent = args.at(\avgcent).linlin(0, 10000, 200, 13000, clip: \minmax),
  lu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  lu_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  lu_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  lu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  lu_atk = 0.1;
    var ry_temp = args.at(\density).linlin(0.0, 10.0, 0.1, 3.0, clip: \minmax),
  ry_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.01, 0.1, clip: \minmax),
  ry_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  ry_bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
  ry_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  ry_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  ry_cutoff = rrand(200 * ry_velocity, 800 * ry_velocity),
  ry_reps = rrand(10, 35).asInteger,
  ry_atk = rrand(0.01, ry_variance);

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pseq([     ry_temp,     (rrand(0.01, 0.03) ! ry_velocity.asInteger * 2).sum    ], inf), 0.0914], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([lu_cent, 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([1.0002, 1.1436, 1.3458, 1.4916], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseg(Pseq([0.2, 0.28, 0.072], inf), Pseq([6.459, 1.9744], inf), \sin), inf).max(0.0005).min(0.5),
        \atk, (cp_atk).clip(0.003, 4.0),
        \rel, ((~sampleSize * 2) - cp_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~dryBus[0 % ~numPairs]!3),     (~reverbShortBus[rrand(0, 4) % ~numPairs]!(ry_noise.asInteger))    ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
