// ARG ISOLATION. Bisection step two.
//
// live_minimal.scd established that class machines DO sound live, using the
// corpus-mean args the offline census used. The factory calls the same
// machines the same way and is silent five windows in six. The args are one
// of the few remaining differences, and they differ in a way that only ever
// bites live: on a quiet output bus the factory measures no pitch, so it
// sends \mainpitch -> 'unpitched' and \percpitch -> 0.0, where the census
// always sent a real note.
//
// Six machines are run under each of six arg-sets, changing ONE field at a
// time from the known-good census values. Peak level over 6 s is reported.
// If a single field kills the sound, this finds it in one run.
(
var root = WORKDIR, grainDir = GRAINDIR, nGrains = NGRAINS,
    server, bufs, h, machines, sets, peak = 0, results;

server = Server.local;
server.options.numBuffers = 16384;
server.options.maxNodes = 65536;
server.options.memSize = 512 * 1024;
server.options.numOutputBusChannels = 2;
server.options.numInputBusChannels = 0;

machines = [\cr, \gl, \sc, \ht, \ma, \wa];

// the census baseline, known to sound
~base = Dictionary[
    \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
    \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016,
    \mainpitch -> 'D5', \avgrolloff -> 1560 ];

sets = [
    // name                      overrides on the baseline
    [ "A_census",                Dictionary[] ],
    [ "B_unpitched",             Dictionary[\mainpitch -> 'unpitched'] ],
    [ "C_percpitch0",            Dictionary[\percpitch -> 0.0] ],
    [ "D_rms_rescaled",          Dictionary[\avgrms -> 0.35] ],
    [ "E_quiet_bus_all",         Dictionary[\mainpitch -> 'unpitched', \percpitch -> 0.0,
                                            \avgrms -> 0.05, \density -> 0.05,
                                            \avgcent -> 1200, \avgrolloff -> 800,
                                            \avgflat -> 0.05] ],
    [ "F_loud_bus_all",          Dictionary[\percpitch -> 0.6, \avgrms -> 0.20,
                                            \density -> 0.60, \avgcent -> 3500,
                                            \avgrolloff -> 3000, \avgflat -> 0.20] ]
];

server.waitForBoot({
    SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0|
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
            env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
        sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    SynthDef(\playbackHP, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0|
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
            env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
        sig = HPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    SynthDef(\playgran, { |out=0, freq=10, amp=0.3, rate=1.0, atk=0.5, rel=4, cutoff=1500, buf, pan=0|
        var env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), levelScale:amp, doneAction:2),
            fenv = EnvGen.kr(Env([cutoff/2, cutoff, cutoff/2],[atk,rel],\sin,1)),
            sig = GrainBuf.ar(2, Impulse.kr(freq), 0.2, buf, rate,
                LFNoise2.kr(0.1).range(0,1), 2, (pan * LFNoise2.kr(0.1).range(-1,1)), -1);
        sig = BPF.ar(sig, fenv); Out.ar(out, sig * env);
    }).add;
    SynthDef(\meter, { SendReply.kr(Impulse.kr(10), '/lvl',
        [Amplitude.kr(Mix.ar(In.ar(0, 2)), 0.01, 0.3)]) }).add;
    server.sync;

    // does pitchcps even survive 'unpitched'?
    ("PITCHCPS 'unpitched' -> " ++ { 'unpitched'.asString.pitchcps }.try({ |e|
        "THREW: " ++ e.errorString })).postln;
    ("PITCHCPS 'D5'        -> " ++ { 'D5'.asString.pitchcps }.try).postln;

    bufs = Array.newClear(nGrains);
    nGrains.do { |i|
        bufs[i] = Buffer.readChannel(server,
            root ++ "/" ++ grainDir ++ "/g" ++ i.asString.padLeft(2,"0") ++ ".wav", 0, -1, [0]);
        if ((i + 1) % 64 == 0) { server.sync };
    };
    server.sync;
    ("buffers " ++ bufs.size ++ ", frames " ++ bufs[0].numFrames).postln;

    h = Handler.new;
    ~sampleSize = 1.0; ~numPairs = 1;
    ~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;

    Synth.tail(server.defaultGroup, \meter);
    OSCdef(\lvl, { |msg| peak = max(peak, msg[3]) }, '/lvl');

    results = List.new;

    Routine({
        1.wait;
        sets.do { |s|
            var name = s[0], over = s[1], row;
            row = List[name];
            machines.do { |m|
                var args = Dictionary.new, pl;
                ~base.keysValuesDo { |k, v| args[k] = v };
                over.keysValuesDo { |k, v| args[k] = v };
                peak = 0;
                pl = { h.settings([m, args]); h.stateMachine(bufs) }.try({ |e|
                    ("    " ++ name ++ " " ++ m ++ " THREW: " ++ e.errorString).postln; nil });
                if (name == "A_census") {
                    ("    " ++ m ++ " returned " ++ pl.class).postln };
                4.wait;
                row.add(peak.round(0.0001));
                // patch_returns.py makes stateMachine hand back the player, so
                // trials can be stopped WITHOUT server.freeAll -- which in the
                // first version of this test destroyed the \meter synth and
                // made every cell after the first read 0.0.
                if (pl.isKindOf(EventStreamPlayer)) { pl.stop } {
                    server.freeAll; server.sync;
                    Synth.tail(server.defaultGroup, \meter);  // freeAll kills the meter
                };
                0.8.wait;
            };
            results.add(row);
            (name.padRight(18) ++ row.copyRange(1, row.size-1).collect({ |v|
                v.asString.padLeft(9) }).join("")).postln;
        };
        "".postln;
        ("MACHINE".padRight(18) ++ machines.collect({ |m| m.asString.padLeft(9) }).join("")).postln;
        results.do { |r|
            (r[0].asString.padRight(18) ++ r.copyRange(1, r.size-1).collect({ |v|
                v.asString.padLeft(9) }).join("")).postln;
        };
        1.wait;
        0.exit;
    }).play(AppClock);
});
)
