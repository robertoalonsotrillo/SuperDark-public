// BPF bandwidth against Nyquist: reproduce the fault, then show the fix removes it.
//
// WHY THIS EXISTS AND THE EARLIER SWEEP DOES NOT SUFFICE.
// test_bpf_gain.scd swept cutoff from 0 Hz to 8 kHz at rq = 0.5 and reported a
// peak gain of 0.61x, on which BPF was declared exonerated. That test was wrong.
// rq = 0.5 is the NARROWEST setting, and I picked it believing narrow meant high
// Q meant most dangerous. The opposite is true here: rq is bandwidth divided by
// centre frequency, so the hazard is WIDE rq at HIGH cutoff, where the product
// passes Nyquist and the filter's coefficients leave the stable region.
//
//   rq.clip(0.5, 2.5) bounds the RATIO. Nothing bounds the BANDWIDTH.
//   At 44100 Hz, Nyquist is 22050, so cutoff * 2.5 > 22050 whenever
//   cutoff > 8820 Hz.
//
// The live probe caught a voice at cutoff 9680 with amp 0.08 producing 3.9e17.
// 9680 * 2.5 = 24200, which is 2150 Hz over Nyquist.
//
// ARMS, both at rq 2.5, the clip ceiling, which is the corner that matters
//   A  current  BPF.ar(sig, cutoff, rq.clip(0.5, 2.5))
//   B  fixed    bandwidth clipped below Nyquist as well as the ratio
//
// A must blow up above 8820 Hz or this test is not reproducing the fault and
// nothing it says about the fix can be believed.
//
//   echo A > /tmp/bw_arm.txt && sclang workdir_music/tools/test_bpf_bandwidth.scd

(
var sr = 44100, seg = 1.5, root = thisProcess.nowExecutingPath.dirname.dirname,
    cutoffs, files, msgs, total, arm;

arm = File.readAllString("/tmp/bw_arm.txt").stripWhiteSpace.asSymbol;

// straddles the 8820 Hz threshold deliberately, with fine spacing across it
cutoffs = [1000, 4000, 7000, 8000, 8500, 8800, 8900, 9200, 9680,
           10500, 12000, 15000, 18000];

files = (root ++ "/grains_play_macro/*.wav").pathMatch;
if (files.size < 1) { "FATAL: no grains".postln; 1.exit };
("arm " ++ arm ++ ", " ++ cutoffs.size ++ " cutoffs at rq 2.5").postln;

SynthDef(\bwCur, { |buf, cutoff=500, rq=2.5, amp=0.08, out=0|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 1, doneAction: 0),
        env = EnvGen.kr(Env.linen(0.03, seg - 0.1, 0.05), doneAction: 2);
    sig = BPF.ar(sig, cutoff, rq.clip(0.5, 2.5));          // AS IT SHIPS
    Out.ar(out, Pan2.ar(sig, 0, amp) * env);
}).store;

SynthDef(\bwFix, { |buf, cutoff=500, rq=2.5, amp=0.08, out=0|
    var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 1, doneAction: 0),
        env = EnvGen.kr(Env.linen(0.03, seg - 0.1, 0.05), doneAction: 2),
        cf  = cutoff.clip(20, 18000);
    // 20000 and not 22050: a margin below Nyquist, because the coefficients are
    // already ill-conditioned approaching it rather than only beyond it.
    sig = BPF.ar(sig, cf, rq.clip(0.5, 2.5).min(20000 / cf));
    Out.ar(out, Pan2.ar(sig, 0, amp) * env);
}).store;

msgs = List.new;
msgs.add([0.0, ['/b_allocRead', 10, files[0], 0, 0]]);
cutoffs.do { |c, i|
    msgs.add([seg * i + 0.1,
        ['/s_new', if (arm == \A) { \bwCur } { \bwFix }, 2000 + i, 0, 0,
         \buf, 10, \cutoff, c, \rq, 2.5]]);
};
total = seg * cutoffs.size + 1.0;
msgs.add([total, ['/c_set', 0, 0]]);
File.use("/tmp/bw_cutoffs.txt", "w", { |f|
    f.write(cutoffs.collect({ |c| c.asString }).join(" ")) });

Score(msgs.asArray.sort({ |a, b| a[0] <= b[0] })).recordNRT(
    outputFilePath: "/tmp/bw_" ++ arm ++ ".wav", sampleRate: sr,
    headerFormat: "WAV", sampleFormat: "float",
    options: ServerOptions.new.numOutputBusChannels_(2),
    duration: total + 2,
    action: { ("wrote /tmp/bw_" ++ arm ++ ".wav").postln; 0.exit });
)
