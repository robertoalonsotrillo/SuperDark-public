// Asserts that every machine in `targets` produces a non-empty score when
// asked. No server render, so this does not hit claim 166's hang.
//
// This exists because the project has twice shipped machines that were
// selected, reported OK and produced no audio: pitchcps silenced five
// machines from run 04, and Ppar.play would have silenced all four generated
// machines had ArchonCapture not been extended.
(
var sdPlayback, sdHP, sdGran, h, b, nGrains = 130, root = WORKDIR,
    args, fails, results;

thisThread.randSeed = 20260819;

sdPlayback = SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out|
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
[sdPlayback, sdHP, sdGran].do { |s| SynthDescLib.global.add(s.asSynthDesc) };

~sampleSize = 1.0; ~numPairs = 1;
~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;

b = BehaviorTrimmed.new(NetAddr("127.0.0.1", 5005));
h = Handler.new;

// Feature values at the corpus means, so no machine is tested on an input
// that its own weight formula would never see.
args = Dictionary[
    \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
    \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016,
    \mainpitch -> 'D5', \avgrolloff -> 1560 ];

fails = 0;
b.targets.do { |m|
    var s0, n = 0, kind = "none";
    ~capturedPattern = nil;
    { h.settings([m, args]); h.stateMachine((0..(nGrains-1))) }.try;
    if (~capturedPattern.notNil) {
        kind = ~capturedPattern.class.asString;
        s0 = { ~capturedPattern.asScore(8.0, 0.0) }.try;
        if (s0.isKindOf(Score)) {
            n = s0.score.select({ |e| e[0].isNumber and: { e[1][0] != \c_set } }).size;
        };
    };
    if (n == 0) { fails = fails + 1;
        ("FAIL  " ++ m ++ "  pattern=" ++ kind ++ "  entries=0").postln }
    { ("ok    " ++ m ++ "  " ++ kind ++ "  entries=" ++ n).postln };
};

("MACHINES " ++ b.targets.size ++ "  SILENT " ++ fails).postln;
if (fails > 0,
	{ "STAGE ASSERTION FAILED: silent machines".postln; 1.exit },
	{ "VERIFY_OK".postln; 0.exit });
)
