// brhtbrhmma2609051356x32609281238x9 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition ht -> brhmma2609051356x3 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 2.48 between them:
//   ht median event 0.057 s
//   brhmma2609051356x3 median event 0.0715 s
//   this   0.1 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.996), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-ma;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-te;out<-pu;env<-grammar(percussive);layers=2;src=klank;stages=none
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=klank;stages=none
SynthDef(\sg_brhtbrhmma2609051356x32609281238x9, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE klank; STAGES none -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03).min(0.05), rel.max(2.41)], [1, -1]), doneAction: 2);
        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 0, doneAction: 0)
            * EnvGen.ar(Env.perc(0.001, 0.015), 1);
        sig = DynKlank.ar(`[[600.0, 800.0, 1800.0] * rate.clip(0.25, 4.0), [1.0, 0.5, 0.333], [0.87, 2.41, 0.45]], exc) * 0.12;
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), (amp * 0.600).clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.1,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var ma_dur = args.at(\density).linlin(0.0, 5.0, 0.2, 1.0, clip: \minmax),
  ma_variance = args.at(\windowsize).linlin(0.0, 3.0, 0.1, 0.3, clip: \minmax),
  ma_bright = args.at(\avgrolloff).linlin(1000, 12000, 1, 4, clip: \minmax),
  ma_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  ma_width = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax),
  ma_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  ma_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  ma_cutoff = rrand(200 * ma_velocity, 800 * ma_velocity),
  ma_reps = rrand(10, ma_bright * 50),
  ma_atk = 0.1;
    var pu_grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
  pu_bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
  pu_width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
  
  pu_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
  pu_atk = 0.005;
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
        \instrument, \sg_brhtbrhmma2609051356x32609281238x9,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwrand(     [(ma_dur / 16), (ma_dur / 8), (ma_dur / 16), (ma_dur /32), (ma_dur / 2)],     [16, 1, 1, 2, 1].normalizeSum,     inf), 0.1], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pstutter(Pwhite(1, 3), Pn(833.9497, 6)), Pn(Pseq([1154.704, Pwhite(442.6021, 1327.8064)], inf), 2)], [0.707, 0.293].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pn(Pseq([1.996, 2.2822, 2.6857, 2.9766], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0, 0.1, 0], [(te_reps / 2).asInteger, (te_reps / 2).asInteger], \sin).discretize(44).asArray,      inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, 0.0129,
        \rel, 0.0949,
        \out, Pflatten(1, Pn(Pseq([~dryBus[0 % ~numPairs], 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.3458).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.68, \pan, (Pkey(\pan) + 0.73).clip(-1.0, 1.0))])
}
// TRIM 0.600 (render rms 0.04997, target 0.03), applied after admission 28 Sept
