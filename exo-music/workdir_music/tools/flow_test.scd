// DOES THE SEQUENTIAL CORPUS ACTUALLY SOUND CONTINUOUS?
//
// No factory, no policy, no selection, no sections, no memory. Load the corpus,
// walk one track's grains in order, play them end to end at the rate the music
// runs. This is the control condition the whole sequential rebuild rests on and
// it should have been the first thing built.
//
// If this sounds like music playing forwards, then adjacency works and the
// problem is that every machine in the vocabulary consumes grains two to five
// times faster than the material runs -- a twelve-second phrase in under four
// seconds, layered on itself.
//
// If it does NOT sound continuous, the corpus rebuild is not the answer and I
// should stop proposing fixes at this level.
(
var root = WORKDIR, grainDir = GRAINDIR,
    server, bufs, man, runs, order, n;

server = Server(\flowtest, NetAddr("127.0.0.1", 57194));
Server.default = server;
server.options.numBuffers = 8192;
server.options.memSize = 256 * 1024;
server.options.numOutputBusChannels = 2;
server.options.numInputBusChannels = 0;
server.options.sampleRate = 44100;
server.options.outDevice = "MacBook Pro Speakers";
server.options.inDevice = "MacBook Pro Microphone";

// read the manifest and take the grains of a few whole tracks IN ORDER
man = { var f = File(root ++ "/" ++ grainDir ++ "/manifest.json", "r"), s;
    if (f.isOpen) { s = f.readAllString; f.close; s.parseYAML } { nil } }.value;

runs = Dictionary.new;
man["manifest"].do { |e|
    var r = e["run"].asString;
    runs[r] = (runs[r] ? List.new).add([e["seq"].asInteger, e["i"].asInteger]);
};
// MODE decides what "next grain" means, and the difference is the whole point.
//
//   source     consecutive grains of one track: this is PLAYBACK. Roberto,
//              hearing it: "just reproducing long fragments of music with no
//              concatenative synthesis whatsoever." Correct, and it proves the
//              adjacency works.
//
//   proximity  consecutive grains from DIFFERENT tracks, chosen as the nearest
//              unused neighbour in descriptor space, played end to end with no
//              overlap. Coherence comes from the SELECTION rather than from the
//              source. This is concatenative synthesis in the CataRT sense, and
//              it is the cell we have never run: every configuration so far was
//              either 0.5 s grains fired every 0.15 s (overlapping bursts) or
//              source order (playback).
order = List.new;
if (MODE == "source") {
    runs.keys.asArray.sort({ |a, b| a.asInteger < b.asInteger }).keep(4).do { |k|
        runs[k].asArray.sort({ |a, b| a[0] < b[0] }).do { |p| order.add(p[1]) };
    };
} {
    var desc, dv, dk, dn2, cur, pool, f;
    f = File(root ++ "/" ++ grainDir ++ "/descriptors.json", "r");
    desc = f.readAllString.parseYAML; f.close;
    dk = ["centroid", "flatness", "median", "zcr"];
    dn2 = desc["index"].size;
    dv = Array.fill(dn2, { |i| Array.fill(dk.size, { |j| desc["norm"][dk[j]][i].asFloat }) });
    pool = (0 .. dn2 - 1).asList;
    cur = dn2.rand;
    order.add(cur); pool.remove(cur);
    95.do {
        var best = nil, bd = 1e9;
        pool.do { |c|
            var d = 0; dk.size.do { |x| d = d + ((dv[c][x] - dv[cur][x]).squared) };
            if (d < bd) { bd = d; best = c };
        };
        if (best.notNil) { order.add(best); pool.remove(best); cur = best };
    };
};
order = order.asArray;
n = order.size;
("PLAYING " ++ n ++ " grains, mode " ++ MODE ++ ", = " ++ (n * 0.5) ++ " s of "
    ++ "continuous audio from 4 tracks").postln;

server.waitForBoot({
    SynthDef(\flowplay, { |buf, amp = 0.5, dur = 0.5|
        // no filter, no rate change, no colouring: the corpus as it is
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf), doneAction: 2),
            env = EnvGen.kr(Env.new([0, 1, 1, 0], [0.005, dur - 0.01, 0.005]),
                doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, 0));
    }).add;
    server.sync;

    bufs = Array.newClear(n);
    n.do { |k|
        bufs[k] = Buffer.readChannel(server,
            root ++ "/" ++ grainDir ++ "/g" ++ order[k].asString.padLeft(2, "0") ++ ".wav",
            0, -1, [0]);
        if ((k + 1) % 48 == 0) { server.sync; ("  " ++ (k + 1) ++ "/" ++ n).postln };
    };
    server.sync;
    "LOADED. playing end to end, one voice, no overlap.".postln;

    Pbind(
        \instrument, \flowplay,
        \buf, Pseq(bufs, 1),
        \dur, 0.5,
        \amp, 0.5
    ).play;
});
)
