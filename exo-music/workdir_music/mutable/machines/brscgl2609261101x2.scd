// brscgl2609261101x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> gl had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.57 between them:
//   sc median event 0.094 s
//   gl median event 0.05 s
//   this   0.0657 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (4.0), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-hp;out<-grammar;env<-grammar(percussive);layers=2;dsp=dly
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0657,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var hp_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  hp_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  hp_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  hp_bright = args.at(\avgrolloff).linlin(0, 12000, 200, 10000, clip: \minmax),
  hp_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  hp_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  hp_rate = (hp_velocity.asInteger * 2),
  hp_reps = rrand(hp_temp * 30, hp_temp * 80).asInteger,
  hp_atk = (0.5 * (~sampleSize / hp_rate));

    main = Pbind(
        \instrument, \playbackHPFX,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pwrand([Pseq([Pwrand([Pwhite(0.0283, 0.0588), 0.046, Pwhite(0.0471, 0.0978)], [0.314, 0.368, 0.318].normalizeSum, inf), (0.0556 * 1.036)], inf), Prand([Pseq([Pwhite(0.0229, 0.0476), Pwhite(0.0422, 0.0877), Pwhite(0.0409, 0.0849), 0.041], inf), Pstutter(Pwhite(1, 2), Pwhite(0.039, 0.081)), (Pwhite(0.0503, 0.1046) * 0.678)], inf), Pn(Pgeom(0.0789, 1.145, 5), inf)], [0.142, 0.436, 0.423].normalizeSum, inf), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pseq([Pseg(Pseq([1751.3499, 2627.0249, 525.405], inf), Pseq([3.6486, 8.1768], inf), \lin), Pwrand([Pwhite(1044.8803, 3134.641), Pwhite(963.0833, 2889.25)], [0.137, 0.863].normalizeSum, inf)], inf), Prand([(1204.1387 * 1.024), 1520.9271], inf), Pwrand([Pwrand([725.6625, Pwhite(464.0007, 1392.0022), 1236.8038], [0.349, 0.355, 0.296].normalizeSum, inf), 1211.8942], [0.528, 0.472].normalizeSum, inf)], [0.492, 0.325, 0.183].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([4.0, 4.0, 4.0, 4.0], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0, 0.1, 0], [rrand(4, 10), rrand(6, 14)], \sin).discretize(8).asArray,                inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \dly, 0.3781,
        \dlyt, 0.0224,
        \dlyfb, 0.3495,
        \atk, 0.0065,
        \rel, 0.0472,
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 2), ((~dryBus ? [0])[0] ! 3), ((~reverbLongBus ? [0])[0] ! 3), ((~reverbShortBus ? [0])[0] ! 5)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.1436).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.51, \pan, (Pkey(\pan) + 0.74).clip(-1.0, 1.0))])
}
