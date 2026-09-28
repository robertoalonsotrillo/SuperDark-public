// brbrbrmapu2609051311x6brhpgl2609040130x22609211901x1sc2609281238x10 -- WRITTEN BY THE FACTORY, WHILE PLAYING.
//
// Not by me. The transfer operator found a hole in the factory's own
// dynamics: the transition brbrmapu2609051311x6brhpgl2609040130x22609211901x1 -> sc had been observed
// 0 times across its whole history.
// This machine is a BRIDGE between those two behaviours, placed where
// the factory has never found a way to move.
//
// Interpolated at 0.86 between them:
//   brbrmapu2609051311x6brhpgl2609040130x22609211901x1 median event 0.1197 s
//   sc median event 0.094 s
//   this   0.0973 s -> micro layer
//
// Anti-convergent by construction: it targets what the factory does
// NOT do, unlike the audibility score, which weighted up whatever
// already worked and took the vocabulary from nine machines to four.
// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.
// Each slot below is a term expanded from PatternGrammar to depth 3.
// Rate is anchored on the pitch ratio measured when this machine was
// written (2.433), drawn from the shared table [ 1.0, 1.144, 1.346, 1.492 ].
// COMPOSED: dur<-grammar;rate<-grammar;cutoff<-bu;pan<-gp;amp<-grammar;out<-grammar;env<-grammar(percussive);layers=1;src=wavetable;stages=combl+hpf
//   <-xx is a fragment of original xx (Handler_Local.sc, via
//   mutable/fragments.json); <-grammar is a term the grammar drew.
//
// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below
// was drawn by SynthGrammar for this machine alone -- src=wavetable;stages=combl+hpf
SynthDef(\sg_brbrbrmapu2609051311x6brhpgl2609040130x22609211901x1sc2609281238x10, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
    // SOURCE wavetable; STAGES combl+hpf -- drawn by SynthGrammar (B8 rung 2)
    var sig, env, life, bdur, lp, rt, exc, per, st;
    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03), rel.max(0.01)], [1, -1]), doneAction: 2);
        per = SampleRate.ir / (150.0 * rate.clip(0.25, 4.0)).clip(30, 2000);
        st = (BufFrames.ir(buf) * (0.173 + LFNoise2.kr(0.2405).range(0, 0.055))).clip(0, (BufFrames.ir(buf) - 2000).max(0));
        sig = LeakDC.ar(BufRd.ar(1, buf, Phasor.ar(0, 1, 0, per) + st, 1, 4)) * 1.5;
        sig = (sig * 0.58) + (CombL.ar(sig, 0.5, 0.0207, 0.102) * 0.42);
        sig = (sig * 0.52) + (HPF.ar(sig, 255.0) * 0.48);
        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));
}).add;

{ |buf, args|
    var ioi   = 0.7785,
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
        \instrument, \sg_brbrbrmapu2609051311x6brhpgl2609040130x22609211901x1sc2609281238x10,
        \buf, Pshuf(buf, inf),
        \dur, Pn((Pn(Pn(Pgeom(0.7785, 1.12, 6), inf), 2) * 1.28), inf).max(0.01).min(6.0),
        \cutoff, Pflatten(1, Pn(Pseq([Pseq(      Env([bu_cent, bu_cent * 5, bu_cent / 2], [rrand(3, 20), rrand(3, 20)], \sin).discretize(16).asArray,      inf), 1200.0], 1), inf)).max(80).min(9000),
        \rate, Pn(Pseq([2.4338, 2.7828, 3.2748, 3.6296], inf), inf).max(0.25).min(4.0),
        \pan, Pflatten(1, Pn(Pseq([Pwhite(-1, 1), 0.0], 1), inf)).clip(-1.0, 1.0),
        \amp, Pn(Pseg(Pseq([0.2, 0.28, 0.072], inf), Pseq([3.3741, 6.074], inf), \exp), inf).max(0.0005).min(0.5),
        \atk, 0.389,
        \rel, 1.168,
        \out, Pflatten(1, Pseq([((~reverbLongBus ? [0])[0] ! 4), ((~reverbShortBus ? [0])[0] ! 4), ((~reverbMidBus ? [0])[0] ! 2), ((~dryBus ? [0])[0] ! 6)], inf))
    );
    main
}
