// brbrsobrcrhm2609051311x12609201749x1brhpgl2609040130x22609281238x15 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brsobrcrhm2609051311x12609201749x1 -> brhpgl2609040130x2 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 1.72 between them:
//   brsobrcrhm2609051311x12609201749x1 median event 0.0819 s
//   brhpgl2609040130x2 median event 0.1405 s
//   this   0.2069 s -> mid layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.25), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-bu;rate<-grammar;cutoff<-gp;pan<-grammar;amp<-grammar;out<-grammar;env<-grammar(swell);layers=1;dsp=dly
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 1.6556,
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
        \instrument, \playgranFX,
        \freq, 4.83,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(1, bu_dense, inf), 1.6556], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([gp_cent, gp_cent * 5, gp_cent / 2], [(gp_reps / 2).asInteger, (gp_reps / 2).asInteger], \sin).discretize(17).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([0.2501, 0.2859, 0.3364, 0.3729], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pseq([Pn(Pgeom(0.2424, 1.109, 6), inf), Pwrand([Pseg(Pseq([0.1924, 0.2693, 0.0693], inf), Pseq([1.7432, 5.2916], inf), \exp), Pwrand([Pwhite(0.1471, 0.3432), Pwhite(0.1361, 0.3175)], [0.627, 0.373].normalizeSum, inf), Pstutter(Pwhite(1, 3), Pwhite(0.169, 0.3944))], [0.237, 0.435, 0.328].normalizeSum, inf), Pstutter(Pwhite(1, 4), Pseq([0.1961, 0.1959, 0.1153, Pwhite(0.0763, 0.178)], inf))], inf), inf).max(0.0005).min(0.5),
        \dly, 0.3882,
        \dlyt, 0.2441,
        \dlyfb, 0.3784,
        \atk, 0.828,
        \rel, 2.483,
        \out, Pflatten(1, Pseq([((~reverbMidBus ? [0])[0] ! 5), ((~reverbLongBus ? [0])[0] ! 4)], inf))
    );
    main
}
