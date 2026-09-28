// brbrrysc2609031456x1brhpgl2609040130x22609262056x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brrysc2609031456x1 -> brhpgl2609040130x2 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.44 between them:
//   brrysc2609031456x1 median event 0.0891 s
//   brhpgl2609040130x2 median event 0.1405 s
//   this   0.1091 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.519), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-an;rate<-lu;cutoff<-grammar;pan<-so;amp<-wa;out<-an;env<-so;layers=2;dsp=dly+blur
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.1091,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var an_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  an_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  an_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  an_bright = args.at(\avgrolloff).linlin(0, 12000, 200, 10000, clip: \minmax),
  an_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  an_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  an_cutoff = rrand(100 * an_velocity, 400 * an_velocity),
  an_rate = (rrand(1, 2) * 2),
  an_reps = rrand(16, 80).asInteger,
  an_atk = (0.5 * (~sampleSize / an_rate));
    var lu_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  lu_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  lu_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  lu_cent = args.at(\avgcent).linlin(0, 10000, 200, 13000, clip: \minmax),
  lu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  lu_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  lu_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  lu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  lu_atk = 0.1;
    var so_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  so_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  so_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  so_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  so_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  so_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  so_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  so_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  so_reps = rrand(so_dense, so_dense * 7),
  so_granreps = rrand(0, 1),
  so_choose = rrand(0, 2),
  so_freq = args.at(\mainpitch).asString.pitchcps,
  so_atk = rrand(0.01, 0.4);
    var wa_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  wa_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  wa_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  wa_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  wa_reps = rrand(6, 35).asInteger,
  wa_atk = 0.1;

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(0.001, 0.1, inf), 0.1091], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Prand([Pseg(Pseq([1141.8676, 1712.8013, 342.5603], inf), Pseq([5.5024, 8.609], inf), \lin), Pseq([1342.9194, 1791.0162, Pn(Pgeom(1165.5674, 0.857, 3), inf)], inf)], inf), inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pseq(     [1.0]++     (0.5!(lu_noise.asInteger))++     (-1.0!(lu_dense.asInteger * 2))++     (-0.5!((lu_dense/2).asInteger)),     2), 0.5194], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * so_width, so_width), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0.06, 0.08, 0.01], [rrand(0.01, 20), rrand(0.01, 20)], \sin).discretize(69).asArray,      inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \dly, 0.499,
        \dlyt, 0.007,
        \dlyfb, 0.4108,
        \blur, 0.7486,
        \blurhz, 600.0,
        \atk, (so_atk).clip(0.003, 4.0),
        \rel, (~sampleSize - so_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~reverbLongBus[rrand(0, 4) % ~numPairs]),     (~reverbShortBus[rrand(0, 4) % ~numPairs]!4)    ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.1436).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.49, \pan, (Pkey(\pan) + 0.76).clip(-1.0, 1.0))])
}
