// Does gain-staging dronePlayer actually remove the excursion, and what does it
// cost in level? NRT, offline, three arms, same seed, same buffers.
//
// WHY OFFLINE. The live factory is mid-arm on a pre-registered comparison. A
// change tested by putting it live and listening is the "configured vs running"
// failure this project has hit four times. This renders to a file and measures.
//
// ARMS
//   A  current           body = avgrms.linlin(0,1, 0.12,0.39)
//   B  overlap-normalised  body / temporalOverlap, where
//                          temporalOverlap = (1.2 + dur) / (0.7 * dur)
//                          i.e. envelope life over mean event interval. This is
//                          the factor run 40 did NOT account for: its x3 was for
//                          the three Ppar layers, which is a different thing.
//   C  B + per-layer limiter on a dedicated drone bus, so the layer cannot
//      exceed its budget however the voices align.
//
// WHAT IS MEASURED. Peak, RMS, and the fraction of samples over 0.99 -- that
// last one is what m3 actually counts, since `over` in the master SynthDef is
// computed on rawIn BEFORE clip2.
//
//   sclang workdir_music/tools/test_drone_gain.scd

(
var sr = 44100, dur = 60, root = thisProcess.nowExecutingPath.dirname.dirname,
    grainDir = root ++ "/grains_play_macro",
    files, bufs, score, arms, results;

files = (grainDir ++ "/*.wav").pathMatch;
if (files.size < 8) { ("FATAL: only " ++ files.size ++ " grains").postln; 1.exit };
files = files.copyRange(0, 23);
("using " ++ files.size ++ " macro grains from " ++ grainDir).postln;

// ---------------------------------------------------------------- the defs ---
// \playback, copied verbatim from live_factory.scd:1637 so the arms differ in
// gain staging and NOTHING else.
~playback = SynthDef(\pbTest, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0,
                                buf, rq=4.0, amp=1.0, out=0|
    var life = atk.max(0.03) + rel,
        bdur = BufDur.ir(buf) / rate.abs.max(0.01),
        lp   = (life > (bdur * 1.5)),
        rt   = BufRateScale.ir(buf) * rate * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
        sig  = PlayBuf.ar(1, buf, rt, loop: lp, doneAction: 0),
        env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction: 2);
    sig = BPF.ar(sig, cutoff, rq.clip(0.5, 2.5));
    sig = Pan2.ar(sig, pan, amp);
    Out.ar(out, sig * env);
});

// arm C's per-layer bound: the drone layer gets its own bus and a limiter set
// at its intended ceiling, then goes to the master. Peak is bounded without
// cutting average loudness, which is the whole point -- run 40 raised dr x3
// BECAUSE it was inaudible at -54.7 dBFS, and a flat gain cut gives that back.
~droneBus = SynthDef(\droneBusTest, { |in=16, out=0, ceiling=0.9|
    var sig = In.ar(in, 2);
    Out.ar(out, Limiter.ar(sig, ceiling, 0.01));
});

// --------------------------------------------------------------- the score ---
// One dronePlayer-shaped layer set, at the parameter corner that produced the
// live episodes: avgrms high (body at its ceiling), windowsize low (dur short,
// so overlap is worst), avgcent low (cutoff in the 90 Hz band where addition is
// coherent).
~mkScore = { |arm, bufAllocs|
    var dark = 90, body = 0.39, width = 1.0, atk = 1.2,
        wsize = 0.0,                                   // -> dur = 3.0, worst case
        d = wsize.linlin(0, 5, 3.0, 9.0),
        overlap = (1.2 + d) / (0.7 * d),
        gain = if (arm == \A) { body } { body / overlap },
        outBus = if (arm == \C) { 16 } { 0 },
        msgs = List.new, t = 0.0, rng, evN = 0;

    ("  arm " ++ arm ++ ": dur " ++ d ++ ", overlap " ++ overlap.round(0.01)
        ++ ", body " ++ gain.round(0.0001)).postln;

    msgs.add([0.0, ['/d_recv', ~playback.asBytes]]);
    if (arm == \C) {
        msgs.add([0.0, ['/d_recv', ~droneBus.asBytes]]);
        msgs.add([0.01, ['/s_new', \droneBusTest, 2000, 1, 0, \in, 16, \out, 0]]);
    };
    bufAllocs.do { |m| msgs.add(m) };

    // three layers at ratios 1.0 / 2.0 / 1.5, exactly as dronePlayer's Ppar
    [1.0, 2.0, 1.5].do { |ratio, li|
        var time = 0.0, step = 0, id = 3000 + (li * 1000);
        rng = Array.fill(512, { 0.4.rrand(1.0) });     // stands in for Pwhite
        while { time < dur } {
            var rate = 0.25 * ratio * (0.972 ** (step % 24)),
                cut  = if ((step % 24) < 12) { dark + (dark / 24 * (step % 12)) }
                       { (dark * 1.5) - (dark / 24 * (step % 12)) },
                amp  = gain * 0.6.rrand(1.0).linlin(0, 1, 0.6, 1.0),
                thisDur = d * rng[step % 512];
            msgs.add([time, ['/s_new', \pbTest, id + step, 0, 0,
                \rate, rate, \atk, atk, \rel, d, \cutoff, cut,
                \pan, width.neg.rrand(width), \buf, 100 + (step % files.size),
                \amp, gain, \out, outBus]]);
            evN = evN + 1;
            time = time + thisDur;
            step = step + 1;
        };
    };
    msgs.add([dur, ['/c_set', 0, 0]]);
    ("    " ++ evN ++ " events").postln;
    msgs.asArray.sort({ |a, b| a[0] <= b[0] });
};

// ------------------------------------------------------------------- render ---
~allocs = files.collect({ |f, i| [0.0, ['/b_allocRead', 100 + i, f, 0, 0]] });

// ONE ARM PER INVOCATION. Score.recordNRT is asynchronous and returns before
// the render finishes, so looping over three arms inside one sclang raced them
// and only the first ever landed. The wrapper calls this three times.
~arm = File.readAllString("/tmp/drone_arm.txt").stripWhiteSpace.asSymbol;
~out = "/tmp/drone_" ++ ~arm ++ ".wav";
("rendering arm " ++ ~arm ++ " -> " ++ ~out).postln;

Score(~mkScore.value(~arm, ~allocs)).recordNRT(
    outputFilePath: ~out, sampleRate: sr, headerFormat: "WAV",
    sampleFormat: "float", options: ServerOptions.new.numOutputBusChannels_(2),
    duration: dur + 12,
    action: { ("  wrote " ++ ~out).postln; 0.exit });
)
