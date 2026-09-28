// SynthGrammar per-source gain diagnostic (B8 rung 2, 24 Sept 2026): one def
// per source, no stages, fixed parameters, eight events over 10 s, peak and
// RMS of the NRT render per source. Used to balance the source scalings so
// no source is silent or dominant before it meets the admission check.
//   sclang -l /tmp/sctest.yaml tools/sg_gain_diag.scd
(
var sg = SynthGrammar.new, grainDir = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music/grains_lic_ev",
    results = Dictionary.new, todo, next;
thisThread.randSeed = 7;
todo = sg.sources.copy;
next = {
    var src, txt, fn, prelude, score, out;
    if (todo.isEmpty) {
        "GAINDIAG".postln; sg.sources.do { |s| ("  " ++ s ++ "  " ++ (results[s] ? "-")).postln }; 0.exit };
    src = todo.removeAt(0);
    txt = "SynthDef(\\diag_" ++ src ++ ", { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0|\n"
        ++ "    var sig, env, life, bdur, lp, rt, exc, per, st;\n"
        ++ "    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03), rel.max(0.01)], [1, -1]), doneAction: 2);\n"
        ++ sg.sourceText(src, (ioi: 0.5, centre: 1500))
        ++ "        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));\n"
        ++ "        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);\n"
        ++ "        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));\n"
        ++ "})";
    fn = txt.compile.value;
    prelude = [[0.0, [\d_recv, fn.asBytes]]];
    8.do { |i| prelude = prelude.add([0.0, [\b_allocReadChannel, i, grainDir ++ "/g" ++ i.asString.padLeft(2, "0") ++ ".wav", 0, -1, 0]]) };
    score = prelude ++ Array.fill(8, { |i| [i * 1.2, [\s_new, "diag_" ++ src, -1, 0, 0, \buf, i, \rate, 1.0, \atk, 0.05, \rel, 1.5, \cutoff, 1500, \rq, 4.0, \amp, 0.3, \pan, 0]] })
        ++ [[12.0, [\c_set, 0, 0]]];
    out = "/tmp/sg_diag_" ++ src ++ ".wav";
    Score.recordNRT(score, "/tmp/sg_diag_" ++ src ++ ".osc", out, sampleRate: 44100, headerFormat: "WAV", sampleFormat: "int16",
        options: ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0).memSize_(65536), duration: 12.0,
        action: {
            results[src] = ("python3 -c \"import wave,numpy as np,sys; w=wave.open('" ++ out ++ "'); x=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16)/32768.0; print('peak %.4f rms %.5f' % (abs(x).max(), np.sqrt((x*x).mean())))\"").unixCmdGetStdOut.stripWhiteSpace;
            next.value });
};
next.value;
)
