// Diagnoses the two machines that verify_machines.scd reports silent.
// No .try, so the interpreter prints the actual error.
(
var sd, h, b, args, nGrains = 130, root = WORKDIR;
thisThread.randSeed = 20260819;
sd = SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
        env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
    sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env); });
SynthDescLib.global.add(sd.asSynthDesc);
~sampleSize = 1.0; ~numPairs = 1;
~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;
b = BehaviorTrimmed.new(NetAddr("127.0.0.1", 5005));
h = Handler.new;
args = Dictionary[ \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
    \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016,
    \mainpitch -> 'D5', \avgrolloff -> 1560 ];

"=== lu: calling lushPlayer directly, no error guard".postln;
h.settings([\lu, args]);
~capturedPattern = nil;
h.lushPlayer((0..(nGrains-1)));
("lu captured: " ++ ~capturedPattern.class).postln;

"".postln;
"=== ry: inspecting the dur and rate streams".postln;
h.settings([\ry, args]);
~capturedPattern = nil;
h.rytmPlayer((0..(nGrains-1)));
("ry captured: " ++ ~capturedPattern.class).postln;
if (~capturedPattern.notNil) {
    var pairs = ~capturedPattern.patternpairs, i = 0;
    while { i < (pairs.size - 1) } {
        var k = pairs[i], v = pairs[i+1], st, first;
        if (k.isKindOf(Symbol)) {
            st = v.asStream;
            first = { st.next(Event.default.copy) }.try;
            ("  " ++ k ++ " -> " ++ v.class ++ "  first=" ++ first).postln;
        };
        i = i + 2;
    };
};
0.exit;
)
