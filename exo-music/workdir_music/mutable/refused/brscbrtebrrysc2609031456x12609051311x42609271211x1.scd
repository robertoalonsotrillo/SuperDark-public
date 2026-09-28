// brscbrtebrrysc2609031456x12609051311x42609271211x1 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition sc -> brtebrrysc2609031456x12609051311x4 had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.36 between them:
//   sc median event 0.094 s
//   brtebrrysc2609031456x12609051311x4 median event 0.0985 s
//   this   0.0956 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (0.437), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-gp;rate<-bu;cutoff<-grammar;pan<-grammar;amp<-gp;out<-grammar;env<-grammar(sustained);layers=1;src=grainbuf;stages=combl+freqshift
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=grainbuf;stages=combl+freqshift
SynthDef(\sg_brscbrtebrrysc2609031456x12609051311x42609271211x1, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE grainbuf; STAGES combl+freqshift -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03), rel.max(0.01)], [1, -1]), doneAction: 2);
        sig = GrainBuf.ar(1, Impulse.kr(3.0), 0.3185, buf, rate.clip(0.25, 4.0), LFNoise2.kr(0.3151).range(0, 1), 4, 0, -1) * 1.6;
        sig = (sig * 0.44) + (CombL.ar(sig, 0.5, 0.113, 0.597) * 0.56);
        sig = (sig * 0.56) + (FreqShift.ar(sig, 161.0) * 0.44);
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.7647,
        scale = args.at(\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \minmax),
        centre = args.at(\avgcent).linlin(1200, 6000, 300, 2400, clip: \minmax);
    var main;
    var bu_dense = args.at(\density).linlin(0.0, 10.0, 20, 1, clip: \minmax),
  bu_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  bu_reps = rrand(1, 5),
  bu_velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 1.6, clip: \minmax),
  bu_rates = [1.0, bu_velocity],
  bu_bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
  bu_freq = rrand(1, bu_dense),
  bu_altfreq = rrand(1, bu_dense),
  bu_atk = 0.1;
    var gp_freq = args.at(\mainpitch).asString.pitchcps,
  gp_choose = rrand(0, 4),
  gp_dense = args.at(\density).linlin(0.0, 5.0, 5, 1, clip: \minmax),
  gp_cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
  gp_reps = rrand(1, 5),
  gp_rates = [0.125, 0.25, 0.5, 1.0],
  gp_bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
  gp_rate = gp_rates[gp_bright.asInteger],
  gp_atk = 0.1;

    main = Pbind(
        \instrument, \sg_brscbrtebrrysc2609031456x12609051311x42609271211x1,
        \buf, Pshuf(buf, inf),
        \dur, Pflatten(1, Pn(Pseq([Pwhite(1, gp_dense, inf), 0.7647], 1), inf)).max(0.01).min(6.0),
        \cutoff, Pn(Pwrand([Pwhite(405.9241, 1217.7722), Pseq([Pseg(Pseq([1406.6297, 2109.9446, 421.9889], inf), Pseq([3.3154, 12.2992], inf), \exp), Pn(Pgeom(1914.6989, 0.926, 3), inf), Prand([Pwhite(713.918, 2141.7541), 2517.976, 1206.5839], inf), 1644.6385], inf), Pwrand([Pwhite(646.8913, 1940.6739), Prand([Pwhite(503.5008, 1510.5025), Pwhite(1039.0223, 3117.0668)], inf)], [0.376, 0.624].normalizeSum, inf)], [0.318, 0.168, 0.514].normalizeSum, inf), inf).max(80).min(9000),
        \rate, Pflatten(1, Pn(Pseq([Pseq([     (bu_rates[0]!bu_reps),     (bu_rates[1]!bu_reps),    ], rrand(3, 20)), 0.437], 1), inf)).collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } }),
        \pan, Pwhite(-0.75, 0.75),
        \amp, Pflatten(1, Pn(Pseq([Pwhite(0.01, 0.08), 0.2], 1), inf)).max(0.0005).min(0.5),
        \atk, 0.382,
        \rel, 1.147,
        \out, Pflatten(1, Pseq([((~dryBus ? [0])[0] ! 6), ((~reverbMidBus ? [0])[0] ! 1), ((~dryBus ? [0])[0] ! 6), ((~dryBus ? [0])[0] ! 2)], inf))
    );
    main
}
