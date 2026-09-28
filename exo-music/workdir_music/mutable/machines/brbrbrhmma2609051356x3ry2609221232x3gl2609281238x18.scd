// brbrbrhmma2609051356x3ry2609221232x3gl2609281238x18 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brbrhmma2609051356x3ry2609221232x3 -> gl had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at -0.83 between them:
//   brbrhmma2609051356x3ry2609221232x3 median event 0.078 s
//   gl median event 0.05 s
//   this   0.1127 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.351), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-me;cutoff<-sc;pan<-te;amp<-grammar;out<-te;env<-ht;layers=1;src=formant;stages=softclip
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=formant;stages=softclip
SynthDef(\sg_brbrbrhmma2609051356x3ry2609221232x3gl2609281238x18, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE formant; STAGES softclip -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03).min(0.05), rel.max(1.58)], [1, -1]), doneAction: 2);
        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 1, doneAction: 0);
        sig = Mix.new([Formlet.ar(exc, 422.9 * rate.clip(0.5, 2.0), 0.005, 0.527), Formlet.ar(exc, 994.2 * rate.clip(0.5, 2.0), 0.005, 0.527), Formlet.ar(exc, 1757.9 * rate.clip(0.5, 2.0), 0.005, 0.527)]) * 0.087;
        sig = (sig * 0.35) + ((sig * 4.0).tanh * 0.5 * 0.65);
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), (amp * 0.153).clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.1127,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var ht_freq = args.at(\mainpitch)
   .asString
   .pitchcps
   .linlin(0, 10000, 2, 0.01, clip: \mixmax),
  ht_resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
  ht_bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
  ht_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
  ht_reps = rrand(6, 35).asInteger,
  ht_atk = 0.1;
    var me_dur = args.at(\windowsize).linlin(0, 5, 0.18, 0.6, clip: \minmax),
  me_bright = args.at(\avgcent).linlin(0, 10000, 600, 5000, clip: \minmax),
  me_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
  
  me_body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.75, clip: \minmax),
  me_motif = [0, 2, 4, 2, 7, 5, 4, 0],   
  me_atk = 0.01;
    var sc_dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
  sc_dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
  sc_bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
  sc_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  sc_width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
  sc_resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
  sc_noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
  sc_velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
  sc_atk = 0.1;
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
        \instrument, \sg_brbrbrhmma2609051356x3ry2609221232x3gl2609281238x18,
        \buf, Pshuf(buf, inf),
        \dur, Pn(Pn(Pgeom(0.1127, 0.846, 5), inf), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([sc_cent, 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pstutter(     Pwrand([1, 2, 3], [0.6, 0.3, 0.1], inf),     Pseq(me_motif.collect({ |d| 2 ** (d / 12) }), inf)), 0.3513], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(     rrand(-1, 1),     (rrand(-1, 1) + 0.2)      .linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),     inf), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pn((Pwhite(0.12, 0.28) * 0.64), inf).max(0.0005).min(0.5),
        \atk, (ht_atk).clip(0.003, 4.0),
        \rel, ((~sampleSize * 2) - ht_atk).clip(0.01, 8.0),
        \out, Pflatten(1, Pn(Pseq([Pseq([     (~dryBus[0 % ~numPairs]!3),     (~reverbShortBus[rrand(0, 4) % ~numPairs]!(te_noise.asInteger))    ], inf), 0], 1), inf)).collect({ |o| o.asArray.first ? 0 })
    );
    main
}
// TRIM 0.153 (render rms 0.19646, target 0.03)
