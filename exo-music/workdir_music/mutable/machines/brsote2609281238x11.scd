// brsote2609281238x11 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition so -> te had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.62 between them:
//   so median event 0.092 s
//   te median event 0.11 s
//   this   0.1027 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.685), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-te;rate<-an;cutoff<-ma;pan<-grammar;amp<-cp;out<-grammar;env<-grammar(swell);layers=1;src=klank;stages=none
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=klank;stages=none
SynthDef(\sg_brsote2609281238x11, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE klank; STAGES none -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03).min(0.05), rel.max(1.97)], [1, -1]), doneAction: 2);
        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 0, doneAction: 0)
            * EnvGen.ar(Env.perc(0.001, 0.0594), 1);
        sig = DynKlank.ar(`[[400.0, 1200.0, 1800.0, 1600.0, 3000.0, 3600.0] * rate.clip(0.25, 4.0), [1.0, 0.5, 0.333, 0.25, 0.2, 0.167], [1.97, 0.39, 1.93, 1.05, 1.32, 1.0]], exc) * 0.12;
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.1027,
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
    var cp_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  cp_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  cp_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  cp_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  cp_reps = rrand(6, 35).asInteger,
  cp_atk = 0.1;
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
        \instrument, \sg_brsote2609281238x11,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([rrand(te_temp / 2, te_temp), 0.1027], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([ma_cent, ma_cent * 2, ma_cent / 2], [rrand(2, 10), rrand(2, 40)], \sin).discretize(128).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pwrand(     [an_rate, (-1 * an_rate)],     [2, 2].normalizeSum,     an_reps), 2.6846], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq(      Env([0.01, 0.08, 0.03], [rrand(0.1, 10), rrand(4, 19)], \sin).discretize(69).asArray,      inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, 0.0633,
        \rel, 0.0495,
        \out, Pflatten(1, Pseq([((~reverbShortBus ? [0])[0] ! 5), ((~reverbShortBus ? [0])[0] ! 6)], inf))
    );
    main
}
