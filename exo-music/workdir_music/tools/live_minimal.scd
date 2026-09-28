// MINIMAL LIVE TEST. One class machine, corpus-mean args, nothing else.
//
// Run 40's census measured cr at -28.5 dBFS and gl at -31.9 rendering in
// isolation via NRT. In the live factory the same machines are silent about
// five windows in six. Fourteen hypotheses have been killed testing inside the
// factory loop, which is the wrong place to test. This removes the loop
// entirely: boot, load, call the machine exactly as the offline census did,
// and measure the output bus.
//
// If a machine sounds here, the fault is in the factory loop.
// If it does not, the class-machine LIVE path is broken independently.
(
var root = WORKDIR, grainDir = GRAINDIR, nGrains = NGRAINS,
    server, bufs, h, args, machines, idx = 0, meter;

server = Server.local;
server.options.numBuffers = 16384;
server.options.maxNodes = 65536;
server.options.memSize = 512 * 1024;
server.options.numOutputBusChannels = 2;
server.options.numInputBusChannels = 0;

machines = [\cr, \gl, \sc, \ht, \ma];   // the loudest five in the census

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
    SynthDef(\meter, { SendReply.kr(Impulse.kr(2), '/lvl',
        [Amplitude.kr(Mix.ar(In.ar(0, 2)), 0.01, 0.3)]) }).add;
    server.sync;

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

    // EXACTLY the corpus-mean args the offline census used
    args = Dictionary[
        \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
        \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016,
        \mainpitch -> 'D5', \avgrolloff -> 1560 ];

    Synth.tail(server.defaultGroup, \meter);

    OSCdef(\lvl, { |msg|
        var a = msg[3];
        if (a > 0.0005) { ("    level " ++ a.round(0.0001)).postln };
    }, '/lvl');

    Routine({
        1.wait;
        machines.do { |m|
            var pl;
            ("=== " ++ m).postln;
            pl = { h.settings([m, args]); h.stateMachine(bufs) }.try({ |e|
                ("    THREW: " ++ e.errorString).postln; nil });
            ("    stateMachine returned: " ++ pl.class).postln;
            6.wait;
            if (pl.isKindOf(EventStreamPlayer)) { pl.stop };
            1.wait;
        };
        "=== done".postln;
        1.wait;
        0.exit;
    }).play(AppClock);
});
)
