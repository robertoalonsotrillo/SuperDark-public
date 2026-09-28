(
var sd, h, b, args, nGrains = 130, root = WORKDIR, s0, n = 0;
thisThread.randSeed = 20260819;
sd = SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
        env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
    sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env); });
SynthDescLib.global.add(sd.asSynthDesc);
~sampleSize = 1.0; ~numPairs = 1;
~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;
b = BehaviorTrimmed.new(NetAddr("127.0.0.1", 5005)); h = Handler.new;
args = Dictionary[ \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
    \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016, \mainpitch -> 'D5', \avgrolloff -> 1560 ];
~capturedPattern = nil;
{ h.settings([\sc, args]); h.stateMachine((0..(nGrains-1))) }.try;
s0 = ~capturedPattern.asScore(4.0, 0.0);
"=== first 6 score entries, full structure:".postln;
s0.score.do { |e| if (n < 6) { e.asCompileString.postln; n = n + 1 } };
("entries: " ++ s0.score.size).postln;
("entry sizes seen: " ++ s0.score.collect({ |e| e.size }).asSet.asArray.asString).postln;
0.exit;
)
