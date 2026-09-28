// BUFFER-COUNT ISOLATION. Bisection step three.
//
// The factory logs, for the same corpus and the same args:
//     VOICE sc  handed=64 nil=0 -> EventStreamPlayer
//     VOICE ma  handed=64 nil=0 -> Nil
// while live_argtest, handing the whole 600, got an EventStreamPlayer from
// `ma` under all six argument regimes. No exception is raised in either case,
// so a machine is RETURNING NOTHING rather than failing.
//
// live_minimal tested 64 buffers against `cr` and `gl` only, and both sounded,
// which is why the buffer count was ruled out. This tests every machine at
// several sizes and prints what stateMachine hands back. No audio measurement:
// the question is only whether a player comes out.
(
var root = WORKDIR, grainDir = GRAINDIR, nGrains = NGRAINS,
    server, bufs, h, args, machines, sizes;

server = Server.local;
server.options.numBuffers = 16384;
server.options.maxNodes = 65536;
server.options.memSize = 512 * 1024;
server.options.numOutputBusChannels = 2;
server.options.numInputBusChannels = 0;

machines = [\sc, \lu, \so, \ma, \cr, \te, \ry, \an, \hp, \st,
            \ht, \gl, \cp, \wa, \gp, \bu, \dr, \pu, \hm, \me];
sizes = [600, 128, 64, 48, 32, 16, 8, 4, 2, 1];

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
    server.sync;

    bufs = Array.newClear(nGrains);
    nGrains.do { |i|
        bufs[i] = Buffer.readChannel(server,
            root ++ "/" ++ grainDir ++ "/g" ++ i.asString.padLeft(2,"0") ++ ".wav", 0, -1, [0]);
        if ((i + 1) % 64 == 0) { server.sync };
    };
    server.sync;
    ("buffers " ++ bufs.size).postln;

    h = Handler.new;
    ~sampleSize = 1.0; ~numPairs = 1;
    ~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;
    args = Dictionary[
        \windowsize -> 0.09, \percpitch -> 1.0, \avgflat -> 0.17,
        \density -> 0.10, \avgcent -> 3132, \avgrms -> 0.016,
        \mainpitch -> 'D5', \avgrolloff -> 1560 ];

    Routine({
        var rows = List.new;
        0.5.wait;
        machines.do { |m|
            var row = List[m.asString];
            sizes.do { |n|
                var handed = bufs.copyRange(0, n - 1), pl;
                pl = { h.settings([m, args]); h.stateMachine(handed) }.try({ |e| \THREW });
                row.add(case
                    { pl == \THREW } { "!" }
                    { pl.isKindOf(EventStreamPlayer) } { "." }
                    { pl.isNil } { "N" }
                    { "?" });
                if (pl.isKindOf(EventStreamPlayer)) { pl.stop };
                0.05.wait;
            };
            rows.add(row);
        };
        "".postln;
        ("        " ++ sizes.collect({ |n| n.asString.padLeft(5) }).join("")).postln;
        rows.do { |r|
            (r[0].padRight(8) ++ r.copyRange(1, r.size-1).collect({ |v|
                v.padLeft(5) }).join("")).postln;
        };
        ("        . = EventStreamPlayer   N = returned nil   ! = threw").postln;
        1.wait;
        0.exit;
    }).play(AppClock);
});
)
