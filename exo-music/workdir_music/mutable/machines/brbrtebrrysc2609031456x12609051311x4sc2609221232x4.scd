// brbrtebrrysc2609031456x12609051311x4sc2609221232x4 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brtebrrysc2609031456x12609051311x4 -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.45 between them:
//   brtebrrysc2609031456x12609051311x4 median event 0.0985 s
//   sc median event 0.094 s
//   this   0.0965 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.427), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-grammar;pan<-gl;amp<-grammar;out<-te;env<-grammar(swell);layers=1
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0965,
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
    var te_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  te_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  te_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  te_bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
  te_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  te_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  te_cutoff = rrand(200 * te_velocity, 800 * te_velocity),
  te_reps = rrand(10, 35).asInteger,
  te_atk = rrand(0.01, te_variance + 0.1);

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pseq([Pseg(Pseq([0.0958, 0.1293, 0.0374], inf), Pseq([2.5714, 1.1972], inf), \exp), Pn(Pgeom(0.1255, 1.02, 3), inf)], inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pseg(Pseq([1200.0, 1800.0, 360.0], inf), Pseq([1.7423, 6.9374], inf), \exp), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.427, 1.6315, 1.92, 2.128], inf), inf).max(0.25).min(4.0),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * (gl_freq / 2), gl_freq / 2), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pn(Pstutter(Pwhite(1, 3), Pstutter(Pwhite(1, 3), Pwrand([Pwhite(0.1665, 0.3886), 0.1626], [0.507, 0.493].normalizeSum, inf))), inf).max(0.0005).min(0.5),
        \atk, 0.084,
        \rel, 0.0321,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~dryBus[0 % ~numPairs]!3),     (~reverbShortBus[rrand(0, 4) % ~numPairs]!(te_noise.asInteger))    ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
