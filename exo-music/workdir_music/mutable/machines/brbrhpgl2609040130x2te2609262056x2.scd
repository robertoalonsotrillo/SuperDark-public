// brbrhpgl2609040130x2te2609262056x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brhpgl2609040130x2 -> te had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.55 between them:
//   brhpgl2609040130x2 median event 0.1405 s
//   te median event 0.11 s
//   this   0.1229 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.776), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-so;pan<-grammar;amp<-grammar;out<-grammar;env<-grammar(swell);layers=1;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.1229,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
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

    main = Pbind(
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Prand([Pn(0.1594, 2), (Pseg(Pseq([0.1266, 0.1709, 0.0494], inf), Pseq([6.7622, 1.4565], inf), \sin) * 1.392), (Pwrand([0.0749, Pwhite(0.0613, 0.1273)], [0.322, 0.678].normalizeSum, inf) * 0.991)], inf), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([so_cent, so_cent * 2, so_cent / 2], [1.0, 6.0], \sin).discretize(33).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([0.7763, 0.8876, 1.0445, 1.1577], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 2), Prand([Pwhite(0.1278, 0.2983), Pn(Pgeom(0.1294, 0.895, 6), inf), Pn(Pgeom(0.1917, 1.067, 5), inf)], inf)), inf).max(0.0005).min(0.5),
        \atk, 0.1164,
        \rel, 0.0426,
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 2), ((~reverbLongBus ? [0])[0] ! 3), ((~dryBus ? [0])[0] ! 3), ((~dryBus ? [0])[0] ! 6)], inf))
    );
    main
}
