// brbrcrhm2609051311x1brhpgl2609040130x22609281238x6 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brcrhm2609051311x1 -> brhpgl2609040130x2 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 1.38 between them:
//   brcrhm2609051311x1 median event 0.0724 s
//   brhpgl2609040130x2 median event 0.1405 s
//   this   0.1806 s -> mid layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.672), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-st;cutoff<-grammar;pan<-pu;amp<-grammar;out<-grammar;env<-hm;layers=2;dsp=dry
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.1806,
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
    var pu_grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
  pu_bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
  pu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
  
  pu_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
  pu_atk = 0.005;
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
        \instrument, \playback,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Prand([Pstutter(Pwhite(1, 4), 0.1323), Pseg(Pseq([0.1907, 0.2575, 0.0744], inf), Pseq([6.7662, 1.9693], inf), \exp), Pseq([0.1325, 0.1305], inf)], inf), 5), inf).max(0.01).min(6.0),
        \cutoff, Pn(Pwhite(600.0, 1800.0), inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([st_rate, 1.6717], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1 * pu_width, pu_width), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pn(Pseg(Pseq([0.2, 0.28, 0.072], inf), Pseq([3.1309, 3.0518], inf), \exp), inf).max(0.0005).min(0.5),
        \atk, (0.05).clip(0.003, 4.0),
        \rel, (hm_dur * 0.9).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 6), ((~dryBus ? [0])[0] ! 4), ((~reverbMidBus ? [0])[0] ! 4)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.4916).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.72, \pan, (Pkey(\pan) + 0.73).clip(-1.0, 1.0))])
}
