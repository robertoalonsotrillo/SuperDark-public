// brbrcrhm2609051311x1sc2609221232x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brcrhm2609051311x1 -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.64 between them:
//   brcrhm2609051311x1 median event 0.0724 s
//   sc median event 0.094 s
//   this   0.0856 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.047), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-cr;pan<-grammar;amp<-grammar;out<-cr;env<-grammar(percussive);layers=1
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
{ |buf, args|
    var ioi   = 0.0856,
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

    main = Pbind(
        \instrument, \playbackHP,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Prand([Pn(Pgeom(0.0946, 1.049, 3), inf), Pseg(Pseq([0.0707, 0.0955, 0.0276], inf), Pseq([7.7542, 5.4539], inf), \exp)], inf), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([cr_cent, cr_cent * 2, cr_cent / 2], [rrand(2, 10), rrand(2, 40)], \sin).discretize(128).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([2.0471, 2.3406, 2.7545, 3.0529], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pn(Pstutter(Pwhite(1, 2), Prand([0.181, Pwrand([0.2035, 0.1129, 0.1263], [0.54, 0.33, 0.131].normalizeSum, inf), Pwhite(0.1348, 0.3146)], inf)), inf).max(0.0005).min(0.5),
        \atk, 0.0098,
        \rel, 0.0547,
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~reverbShortBus[rrand(0, 4) % ~numPairs]!((cr_bright + 1).asInteger)),     (~reverbMidBus[rrand(0, 4) % ~numPairs]!((cr_bright + 1).asInteger)),     (~dryBus[rrand(0, 4) % ~numPairs]!(3))     ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
