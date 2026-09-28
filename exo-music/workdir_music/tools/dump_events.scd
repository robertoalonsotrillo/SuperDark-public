// Dumps the resolved event values for the machines the audibility census
// found silent. Reading the source produced a confident wrong answer twice
// today, so this measures what the pattern actually yields instead.
(
var sd, sdHP, sdGran, h, b, args, nGrains = 130, root = WORKDIR, keys, silent;

thisThread.randSeed = 20260819;
sd = SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
        env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
    sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env); });
sdHP = SynthDef(\playbackHP, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
        env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
    sig = HPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env); });
sdGran = SynthDef(\playgran, { |out=0, freq=10, amp=0.3, rate=1.0, atk=0.5, rel=4, cutoff=1500, buf, pan=0|
    var env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), levelScale:amp, doneAction:2),
        fenv = EnvGen.kr(Env([cutoff/2, cutoff, cutoff/2],[atk,rel],\sin,1), levelScale:amp),
        sig = GrainBuf.ar(2, Impulse.kr(freq), 0.2, buf, rate, LFNoise2.kr(0.1).range(0,1), 2,
            (pan * LFNoise2.kr(0.1).range(-1,1)), -1);
    sig = BPF.ar(sig, fenv); Out.ar(out, sig * env) });
[sd, sdHP, sdGran].do { |s| SynthDescLib.global.add(s.asSynthDesc) };

~sampleSize = 1.0; ~numPairs = 1;
~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;
b = BehaviorTrimmed.new(NetAddr("127.0.0.1", 5005));
h = Handler.new;
args = Dictionary[ \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
    \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016,
    \mainpitch -> 'D5', \avgrolloff -> 1560 ];

keys = [\instrument, \amp, \rate, \dur, \atk, \rel, \cutoff, \out, \freq, \buf];
// the six the census found inaudible, plus wa as a LOUD control
silent = [\st, \hp, \gp, \bu, \ht, \gl];  // 4 still-silent + 2 loud controls

silent.do { |m|
    var st, e, rows = 0;
    ("==== " ++ m).postln;
    ~capturedPattern = nil;
    { h.settings([m, args]); h.stateMachine((0..(nGrains-1))) }.try;
    if (~capturedPattern.isNil) { "  no pattern".postln } {
        st = ~capturedPattern.asStream;
        e = Event.default.copy;
        8.do {
            var out = { st.next(Event.default.copy) }.try;
            if (out.isKindOf(Event)) {
                var line = "  ";
                keys.do { |k|
                    var v = out.at(k);
                    if (v.notNil) {
                        if (k == \buf) { v = "buf" } { v = v.asString };
                        if (v.size > 22) { v = v.copyRange(0, 21) ++ ".." };
                        line = line ++ k ++ "=" ++ v ++ " ";
                    };
                };
                line.postln;
                rows = rows + 1;
            };
        };
        if (rows == 0) { "  stream yielded no events".postln };
    };
};
0.exit;
)
