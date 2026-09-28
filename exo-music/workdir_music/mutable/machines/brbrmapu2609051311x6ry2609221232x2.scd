// brbrmapu2609051311x6ry2609221232x2 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brmapu2609051311x6 -> ry had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.4 between them:
//   brmapu2609051311x6 median event 0.0966 s
//   ry median event 0.082 s
//   this   0.0904 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.844), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-gp;rate<-grammar;cutoff<-gp;pan<-grammar;amp<-grammar;out<-grammar;env<-gp;layers=2
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.7234,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
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
        \freq, 11.06,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(1, gp_dense, inf), 0.7234], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([gp_cent, gp_cent * 5, gp_cent / 2], [(gp_reps / 2).asInteger, (gp_reps / 2).asInteger], \sin).discretize(17).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([2.8447, 3.2526, 3.8277, 4.0], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 4), Prand([Pwrand([0.1864, Pwhite(0.135, 0.315)], [0.619, 0.381].normalizeSum, inf), Pseg(Pseq([0.2568, 0.3596, 0.0925], inf), Pseq([8.2049, 9.4726], inf), \sin), Prand([0.1024, 0.16, 0.2171], inf)], inf)), inf).max(0.0005).min(0.5),
        \atk, 0.362,
        \rel, 1.085,
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 3), ((~reverbShortBus ? [0])[0] ! 3), ((~reverbShortBus ? [0])[0] ! 5), ((~reverbShortBus ? [0])[0] ! 1)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.3458).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.5, \pan, (Pkey(\pan) + 0.39).clip(-1.0, 1.0))])
}
