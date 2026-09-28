// Renders one generation using whatever behaviour/BehaviorTrimmed.sc currently says.
// Fixed: input events, corpus, seed, duration, handler, evaluator.
// Variable: the behaviour file, which is the only thing the agent may edit.
(
var sdPlayback, sdHP, sdGran, h, b, lines, prelude, all, ev, transitions,
    dur = 30.0, seed = SEEDVAL, evSkip = SKIPVAL, root = WORKDIR, out = OUTWAV, nGrains = NGRAINS,
    skipped = 0, noPattern = 0;

thisThread.randSeed = seed;

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
        fenv = EnvGen.kr(Env([cutoff/2, cutoff, cutoff/2],[atk,rel],\sin,1)),
        sig = GrainBuf.ar(2, Impulse.kr(freq), 0.2, buf, rate, LFNoise2.kr(0.1).range(0,1), 2,
            (pan * LFNoise2.kr(0.1).range(-1,1)), -1);
    sig = BPF.ar(sig, fenv); Out.ar(out, sig * env) });
[sdPlayback, sdHP, sdGran].do { |s| SynthDescLib.global.add(s.asSynthDesc) };

~sampleSize = 1.0; ~numPairs = 1;
~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;

b = BehaviorTrimmed.new(NetAddr("127.0.0.1", 5005));
h = Handler.new;
transitions = List.new();
~lastState = nil;
lines = File.readAllString(root ++ "/events.csv").split($\n).reject({|l| l.isEmpty});
// claim 164: every render opened identically because the seed, the event
// stream and the first window were all fixed. evSkip drops the first N
// events so a blind test cannot be gamed by recognising the opening.
// evSkip = 0 and seed = 20260819 reproduce every earlier render exactly.
if (evSkip > 0) { lines = lines.drop(evSkip) };
lines.do { |l|
    var p = l.split($,), r;
    var pitch = if(p[6] == "unpitched", { \unpitched }, { p[6].asSymbol });
    r = b.receiver([ \a, p[0].asFloat, p[1].asFloat, p[2].asFloat, p[3].asFloat,
                     p[4].asFloat, p[5].asFloat, pitch ]);
    if (r[0] != ~lastState) { transitions.add([ p[0].asFloat, r[0], r[1] ]); ~lastState = r[0] };
};
("TRANSITIONS " ++ transitions.size).postln;
if (transitions.size == 0) { "STAGE ASSERTION FAILED: zero transitions".postln; 1.exit };

prelude = [ [0.0, [\d_recv, sdPlayback.asBytes]],
            [0.0, [\d_recv, sdHP.asBytes]],
            [0.0, [\d_recv, sdGran.asBytes]] ];
nGrains.do { |i| prelude = prelude.add([0.0,
    [\b_allocRead, i, root ++ "/" ++ GRAINDIR ++ "/g" ++ i.asString.padLeft(2, "0") ++ ".wav", 0, -1]]) };

all = prelude.copy; ev = 0;
transitions.do { |t, i|
    var time = t[0], state = MACHINE, args = t[2], span, s0;
    if (time < dur) {
        span = if (i < (transitions.size - 1), { min(transitions[i+1][0] - time, 4.0) }, { 4.0 });
        span = max(span, 0.5);
        ~capturedPattern = nil;
        { h.settings([state, args]); h.stateMachine((0..(nGrains-1))) }.try;
        if (~capturedPattern.notNil) {
            s0 = { ~capturedPattern.asScore(span, time) }.try;
            if (s0.isKindOf(Score)) {
                all = all ++ s0.score.select({ |e| e[0].isNumber and: { e[1][0] != \c_set } });
                ev = ev + 1;
            } { skipped = skipped + 1 };
        } { noPattern = noPattern + 1 };
    };
};
("PATTERNS " ++ ev ++ "  SKIPPED " ++ skipped ++ "  NOPATTERN " ++ noPattern).postln;
if (ev == 0) { "STAGE ASSERTION FAILED: zero patterns scored".postln; 1.exit };

all = all.select({ |e| e[0].isNumber }).sort({ |x, y| x[0] <= y[0] });
all = all.add([dur, [\c_set, 0, 0]]);
("SCORE_ENTRIES " ++ all.size).postln;
Score(all).recordNRT(root ++ "/renders/_tmp.osc", out, nil,
    sampleRate: 44100, headerFormat: "WAV", sampleFormat: "int16",
    // numBuffers defaults to 1024. The 6000-grain rung allocates one buffer
    // per grain, so every index past 1023 silently failed and the render wrote
    // a ZERO-BYTE file while still posting RENDER_OK.
    options: ServerOptions.new.numOutputBusChannels_(2).numBuffers_(16384),
    duration: dur, action: { "RENDER_OK".postln; 0.exit });
)
