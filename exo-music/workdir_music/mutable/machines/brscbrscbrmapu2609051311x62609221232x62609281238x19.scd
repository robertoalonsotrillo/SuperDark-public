// brscbrscbrmapu2609051311x62609221232x62609281238x19 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> brscbrmapu2609051311x62609221232x6 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.26 between them:
//   sc median event 0.094 s
//   brscbrmapu2609051311x62609221232x6 median event 0.0951 s
//   this   0.0943 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.107), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-te;rate<-ry;cutoff<-grammar;pan<-grammar;amp<-an;out<-grammar;env<-grammar(sustained);layers=1;src=playbuf;stages=none
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=playbuf;stages=none
SynthDef(\sg_brscbrscbrmapu2609051311x62609221232x62609281238x19, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE playbuf; STAGES none -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03), rel.max(0.01)], [1, -1]), doneAction: 2);
        life = atk.max(0.03) + rel;
        bdur = BufDur.ir(buf) / rate.abs.max(0.01);
        lp = life > (bdur * 1.5);
        rt = BufRateScale.ir(buf) * rate;
        sig = PlayBuf.ar(1, buf, rt, loop: lp, startPos: (rt < 0) * (BufFrames.ir(buf) - 1), doneAction: 0);
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.0943,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var an_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  an_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  an_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  an_bright = args.at(\avgrolloff).linlin(0, 12000, 200, 10000, clip: \minmax),
  an_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  an_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  an_cutoff = rrand(100 * an_velocity, 400 * an_velocity),
  an_rate = (rrand(1, 2) * 2),
  an_reps = rrand(16, 80).asInteger,
  an_atk = (0.5 * (~sampleSize / an_rate));
    var ry_temp = args.at(\density).linlin(0.0, 10.0, 0.1, 3.0, clip: \minmax),
  ry_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.01, 0.1, clip: \minmax),
  ry_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  ry_bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
  ry_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  ry_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  ry_cutoff = rrand(200 * ry_velocity, 800 * ry_velocity),
  ry_reps = rrand(10, 35).asInteger,
  ry_atk = rrand(0.01, ry_variance);
    var te_temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
  te_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
  te_cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
  te_bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
  te_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
  te_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  te_cutoff = rrand(200 * te_velocity, 800 * te_velocity),
  te_reps = rrand(10, 35).asInteger,
  te_atk = rrand(0.01, te_variance + 0.1);

    main = Pbind(
        \instrument, \sg_brscbrscbrmapu2609051311x62609221232x62609281238x19,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([rrand(te_temp / 2, te_temp), 0.0943], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(1200.0, inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pwrand(     [1.0, 1.3, -1.0, -0.9, -0.8, 2.0],     [6, 1, 6, 4, 2, 1].normalizeSum,     ry_reps * 2), 2.1075], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0, 0.1, 0], [rrand(4, 10), rrand(6, 14)], \sin).discretize(77).asArray,      inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, 0.0342,
        \rel, 0.1204,
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 5), ((~reverbShortBus ? [0])[0] ! 2), ((~reverbMidBus ? [0])[0] ! 1)], inf))
    );
    main
}
