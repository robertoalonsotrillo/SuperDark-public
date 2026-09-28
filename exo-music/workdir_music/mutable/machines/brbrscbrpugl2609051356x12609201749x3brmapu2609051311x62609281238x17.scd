// brbrscbrpugl2609051356x12609201749x3brmapu2609051311x62609281238x17 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brscbrpugl2609051356x12609201749x3 -> brmapu2609051311x6 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.64 between them:
//   brscbrpugl2609051356x12609201749x3 median event 0.102 s
//   brmapu2609051311x6 median event 0.0966 s
//   this   0.0985 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (1.597), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-lu;rate<-grammar;cutoff<-grammar;pan<-grammar;amp<-me;out<-grammar;env<-so;layers=2;src=pluck;stages=lpf
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=pluck;stages=lpf
SynthDef(\sg_brbrscbrpugl2609051356x12609201749x3brmapu2609051311x62609281238x17, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE pluck; STAGES lpf -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03).min(0.05), rel.max(0.63)], [1, -1]), doneAction: 2);
        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 0, doneAction: 0)
            * EnvGen.ar(Env.perc(0.001, 0.0087), 1);
        sig = Pluck.ar(exc, Impulse.kr(0), 0.05, (1 / (400.0 * rate.clip(0.25, 4.0))).clip(0.00067, 0.05), 0.63, 0.342) * 1.2;
        sig = (sig * 0.36) + (LPF.ar(sig, 1728.0) * 0.64);
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.0985,
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
    var me_dur = args.at(\windowsize).linlin(0, 5, 0.18, 0.6, clip: \minmax),
  me_bright = args.at(\avgcent).linlin(0, 10000, 600, 5000, clip: \minmax),
  me_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
  
  me_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.75, clip: \minmax),
  me_motif = [0, 2, 4, 2, 7, 5, 4, 0],   
  me_atk = 0.01;
    var so_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  so_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  so_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  so_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  so_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  so_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  so_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  so_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  so_reps = rrand(so_dense, so_dense * 7),
  so_granreps = rrand(0, 1),
  so_choose = rrand(0, 2),
  so_freq = args.at(\mainpitch).asString.pitchcps,
  so_atk = rrand(0.01, 0.4);

    main = Pbind(
        \instrument, \sg_brbrscbrpugl2609051356x12609201749x3brmapu2609051311x62609281238x17,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pseq([     Pwhite(0.01, 0.3, Pwhite(0, 10)),     Pwhite(4.0, 10.4, 1)    ], inf), 0.0985], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(1200.0, inf).max(80).min(9000),
        \rate, Pn(Pseq([1.5973, 1.8263, 2.1493, 2.3821], inf), inf).max(0.25).min(4.0),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pseq([me_body, me_body * 0.6, me_body * 0.8, me_body * 0.6], inf), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, (so_atk).clip(0.003, 4.0),
        \rel, (~sampleSize - so_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 5), ((~reverbShortBus ? [0])[0] ! 2)], inf))
    );
    Ppar([main,
        Pbindf(main, \rate, (Pkey(\rate) * 1.3458).clip(-4.0, 4.0), \amp, Pkey(\amp) * 0.46, \pan, (Pkey(\pan) + 0.31).clip(-1.0, 1.0))])
}
