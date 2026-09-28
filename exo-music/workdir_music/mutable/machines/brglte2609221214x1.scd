// brglte2609221214x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition gl -> te had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.43 between them:
//   gl median event 0.05 s
//   te median event 0.11 s
//   this   0.0702 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.634), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-hp;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-hp;out<-hp;env<-grammar(sustained);layers=1
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0702,
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
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pseq(      Env([hp_velocity / 10, hp_velocity, hp_velocity / 10], [rrand(hp_noise, hp_noise * 3), rrand(hp_noise * 2, hp_noise * 4)], \sin).discretize(8).asArray,                inf), 0.0702], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pstutter(Pwhite(1, 4), Pwhite(600.0, 1800.0)), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.6346, 1.869, 2.1994, 2.4377], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0, 0.1, 0], [rrand(4, 10), rrand(6, 14)], \sin).discretize(8).asArray,                inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, 0.0237,
        \rel, 0.1819,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~reverbLongBus[rrand(0, 4) % ~numPairs]),     (~reverbShortBus[rrand(0, 4) % ~numPairs]!4)    ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
