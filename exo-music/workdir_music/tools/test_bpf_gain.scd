// What is BPF's actual gain, as a function of cutoff, on this material?
//
// WHY THIS AND NOT LIVE INSTRUMENTATION. A single voice is reaching past 8.0
// from a buffer bounded at 0.999 with amp <= 0.39. The only gain element in
// \playback is BPF.ar(sig, cutoff, rq.clip(0.5, 2.5)) at live_factory.scd:1757,
// where rq is clipped and cutoff is NOT. That is a claim about one UGen with two
// parameters, so it can be measured directly instead of waiting for the fault to
// recur in a four-hour run.
//
// Two hypotheses about this bug have already been refuted by evidence that was
// cheap to gather. This gathers first.
//
// METHOD. One grain, played identically at each of a sweep of cutoff values,
// two seconds per value, rendered NRT. Gain is the ratio of output peak to the
// unfiltered peak of the same grain. The sweep runs well below the 90 Hz floor
// that dronePlayer can ask for, because the question is what happens when a
// WRITTEN machine asks for something the hand-written ones cannot -- a machine
// sets \cutoff from its own grain's spectral centroid, and nothing clips it.
//
//   echo A > /tmp/bpf_arm.txt && sclang workdir_music/tools/test_bpf_gain.scd

(
var sr = 44100, seg = 2.0, root = thisProcess.nowExecutingPath.dirname.dirname,
    cutoffs, files, msgs, total;

// deliberately spans the illegal and the merely low
cutoffs = [0.0, 0.001, 0.01, 0.1, 1.0, 5.0, 10.0, 20.0, 40.0, 60.0,
           90.0, 150.0, 300.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];

files = (root ++ "/grains_play_macro/*.wav").pathMatch;
if (files.size < 1) { "FATAL: no grains".postln; 1.exit };
("grain: " ++ files[0].basename).postln;
("sweeping " ++ cutoffs.size ++ " cutoff values, " ++ seg ++ " s each").postln;

// \playback's filter line, isolated. rq at 0.5, the clip floor, which is the
// narrowest and therefore highest-Q setting a voice can obtain.
SynthDef(\bpfProbe, { |buf, cutoff=500, rq=0.5, amp=0.39, out=0|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * 0.25, loop: 1, doneAction: 0),
        env = EnvGen.kr(Env.linen(0.03, seg - 0.1, 0.05), doneAction: 2);
    sig = BPF.ar(sig, cutoff, rq.clip(0.5, 2.5));
    Out.ar(out, Pan2.ar(sig, 0, amp) * env);
}).store;

// the control: the SAME grain with no filter at all, first segment, so the
// ratio has a denominator measured rather than assumed
SynthDef(\dryProbe, { |buf, amp=0.39, out=0|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * 0.25, loop: 1, doneAction: 0),
        env = EnvGen.kr(Env.linen(0.03, seg - 0.1, 0.05), doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0, amp) * env);
}).store;

msgs = List.new;
msgs.add([0.0, ['/b_allocRead', 10, files[0], 0, 0]]);
msgs.add([0.1, ['/s_new', \dryProbe, 1000, 0, 0, \buf, 10]]);
cutoffs.do { |c, i|
    msgs.add([seg * (i + 1) + 0.1,
        ['/s_new', \bpfProbe, 2000 + i, 0, 0, \buf, 10, \cutoff, c, \rq, 0.5]]);
};
total = seg * (cutoffs.size + 1) + 1.0;
msgs.add([total, ['/c_set', 0, 0]]);

File.use("/tmp/bpf_cutoffs.txt", "w", { |f|
    f.write(cutoffs.collect({ |c| c.asString }).join(" ")) });

Score(msgs.asArray.sort({ |a, b| a[0] <= b[0] })).recordNRT(
    outputFilePath: "/tmp/bpf_sweep.wav", sampleRate: sr, headerFormat: "WAV",
    sampleFormat: "float",
    options: ServerOptions.new.numOutputBusChannels_(2),
    duration: total + 2,
    action: { "wrote /tmp/bpf_sweep.wav".postln; 0.exit });
)
