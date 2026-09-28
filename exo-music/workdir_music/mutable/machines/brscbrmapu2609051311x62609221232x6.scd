// brscbrmapu2609051311x62609221232x6 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> brmapu2609051311x6 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.42 between them:
//   sc median event 0.094 s
//   brmapu2609051311x6 median event 0.0966 s
//   this   0.0951 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.059), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-gp;rate<-bu;cutoff<-grammar;pan<-grammar;amp<-grammar;out<-gp;env<-grammar(percussive);layers=2
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.7606,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var bu_dense = args.at(\density).linlin(0.0, 10.0, 20, 1, clip: \minmax),
  bu_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  bu_reps = rrand(1, 5),
  bu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 1.6, clip: \minmax),
  bu_rates = [1.0, bu_velocity],
  bu_bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
  bu_freq = rrand(1, bu_dense),
  bu_altfreq = rrand(1, bu_dense),
  bu_atk = 0.1;
    var gp_freq = args.at(\mainpitch).asString.pitchcps,
  gp_choose = rrand(0, 4),
  gp_dense = args.at(\density).linlin(0.0, 5.0, 5, 1, clip: \minmax),
  gp_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  gp_reps = rrand(1, 5),
  gp_rates = [0.125, 0.25, 0.5, 1.0],
  gp_bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
  gp_rate = gp_rates[gp_bright.asInteger],
  gp_atk = 0.1;

    main = Pbind(
        \instrument, \playgran,
        \freq, 10.52,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(1, gp_dense, inf), 0.7606], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pn(Prand([Pwhite(722.5798, 2167.7395), 1454.1882, (Pwhite(773.5797, 2320.7391) * 0.729)], inf), 4), inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pseq([     (bu_rates[0]!bu_reps),     (bu_rates[1]!bu_reps),    ], rrand(3, 20)), 1.0594], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 4), Pn(Pn(Pgeom(0.2, 0.866, 4), inf), 6)), inf).max(0.0005).min(0.5),
        \atk, 0.38,
        \rel, 1.141,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~reverbShortBus[rrand(0, 4) % ~numPairs]),     (~reverbMidBus[rrand(0, 4) % ~numPairs]),     (~reverbLongBus[rrand(0, 4) % ~numPairs]),    ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.4916).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.59, \pan, (Pkey(\pan) + 0.49).clip(-1.0, 1.0))])
}
