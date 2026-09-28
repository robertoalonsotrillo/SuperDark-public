// brbrhmma2609051356x3ry2609221232x3 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brhmma2609051356x3 -> ry had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.63 between them:
//   brhmma2609051356x3 median event 0.0715 s
//   ry median event 0.082 s
//   this   0.078 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.774), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-cr;rate<-hp;cutoff<-grammar;pan<-grammar;amp<-grammar;out<-grammar;env<-cr;layers=2
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.078,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var cr_dur = args.at(\density).linlin(0.0, 5.0, 0.2, 1.0, clip: \minmax),
  cr_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.1, 0.3, clip: \minmax),
  cr_bright = args.at(\avgrolloff).linlin(1000, 12000, 1, 4, clip: \minmax),
  
  
  
  
  
  
  cr_cent = args.at(\avgcent).linlin(0, 10000, 150, 6000, clip: \minmax),
  cr_width = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax),
  cr_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  cr_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  cr_cutoff = rrand(200 * cr_velocity, 800 * cr_velocity),
  cr_reps = rrand(10, cr_bright * 50),
  cr_buffno = rrand(0, 10),
  cr_atk = 0.1;
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
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwrand(     [(cr_dur / 16), (cr_dur / 64), (cr_dur / 128), (cr_dur /32), (cr_dur / 8)],     [16, 2, 1, 2, 1].normalizeSum,     inf), 0.078], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pn(1200.0, 4), inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pwrand(     [      Pwhite(hp_rate - 0.3, hp_rate),      Pwhite(       (-1 * (hp_rate - 0.3)),       (-1 * hp_rate))     ],     [2, 2].normalizeSum,     hp_reps), 0.7738], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pn(Pgeom(0.2, 1.062, 5), inf), inf).max(0.0005).min(0.5),
        \atk, (Pwhite(0.01, ~sampleSize / 2)).clip(0.003, 4.0),
        \rel, (Pwhite(0.01, ~sampleSize / 2)).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 5), ((~reverbLongBus ? [0])[0] ! 6), ((~reverbMidBus ? [0])[0] ! 4), ((~reverbMidBus ? [0])[0] ! 2)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.4916).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.55, \pan, (Pkey(\pan) + 0.57).clip(-1.0, 1.0))])
}
