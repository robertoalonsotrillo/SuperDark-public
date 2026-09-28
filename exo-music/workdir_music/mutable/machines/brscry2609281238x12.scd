// brscry2609281238x12 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> ry had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.12 between them:
//   sc median event 0.094 s
//   ry median event 0.082 s
//   this   0.0925 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.491), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-pu;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-grammar;out<-grammar;env<-lu;layers=1;dsp=res
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0925,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var lu_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  lu_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  lu_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  lu_cent = args.at(\avgcent).linlin(0, 10000, 200, 13000, clip: \minmax),
  lu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  lu_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  lu_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  lu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  lu_atk = 0.1;
    var pu_grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
  pu_bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
  pu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
  
  pu_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
  pu_atk = 0.005;

    main = Pbind(
        \instrument, \playbackFX,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pfsm([     #[0, 1],     Pseq([pu_grid, pu_grid, pu_grid, pu_grid], 1),                #[1, 2],     Pseq([pu_grid * 2, pu_grid, pu_grid], 1),                  #[0, 3],     Pseq([pu_grid / 2, pu_grid / 2, pu_grid, pu_grid * 2], 1),    #[1, 3],     Pseq([pu_grid * 4], 1),                              #[0, 1, 2]    ], inf), 0.0925], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([1338.2499, Prand([Pn(Pgeom(612.5244, 0.903, 3), inf), Pn(Pgeom(984.197, 1.169, 6), inf), Pwrand([Pwhite(533.742, 1601.226), Pwhite(339.0413, 1017.124)], [0.462, 0.538].normalizeSum, inf)], inf)], [0.302, 0.698].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([0.4907, 0.561, 0.6602, 0.7317], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(0.2, inf).max(0.0005).min(0.5),
        \res, 0.1708,
        \resfz, Pn((Pwhite(1440.0, 2160.0) * 0.887), inf).max(60).min(6000),
        \resrt, 0.3821,
        \atk, (lu_atk).clip(0.003, 4.0),
        \rel, (~sampleSize - lu_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~reverbShortBus ? [0])[0] ! 3), ((~dryBus ? [0])[0] ! 6), ((~reverbLongBus ? [0])[0] ! 3)], inf))
    );
    main
}
