// Does \playback still BUILD with the voice probe in it? Build-only, no server.
//
// Same argument as test_master_sanitise.scd: a SynthDef that fails to build
// takes the factory down at boot, and .compile passing says only that the text
// parses. .asBytes forces the graph to be built.
//
// The thing most likely to be wrong here is the SendReply: its trigger must be
// control-rate, and Peak.ar into A2K.kr into a comparison is easy to get subtly
// wrong in a way that parses fine and throws at graph-build time.
//
//   sclang workdir_music/tools/test_voice_probe.scd

(
var ok = true;

try {
    var d = SynthDef(\playbackProbed, { |rate=1, atk=0.1, rel=0.4, cutoff=500,
                                        pan=0, buf, rq=4.0, amp=1.0, out=0|
        var life = atk.max(0.03) + rel,
            bdur = BufDur.ir(buf) / rate.abs.max(0.01),
            lp   = (life > (bdur * 1.5)),
            rt   = BufRateScale.ir(buf) * rate
                     * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
            sig  = PlayBuf.ar(1, buf, rt, loop: lp, doneAction: 0),
            env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]),
                             doneAction: 2);
        sig = BPF.ar(sig, cutoff, rq.clip(0.5, 2.5));
        sig = Pan2.ar(sig, pan, amp);
        sig = sig * env;
        SendReply.kr(
            Impulse.kr(8) * (A2K.kr(Peak.ar(Mix.ar(sig.abs), Impulse.ar(8))) > 1.0),
            '/voiceblow',
            [A2K.kr(Peak.ar(Mix.ar(sig.abs), Impulse.ar(8))),
             cutoff, rate, amp, rq, buf, rel]);
        Out.ar(out, sig);
    });
    ("  PROBED BUILDS OK, " ++ d.asBytes.size ++ " bytes").postln;
} { |e|
    ("  BUILD FAILED: " ++ e.errorString).postln;
    ok = false;
};

// the UNPROBED definition, so a failure here says the harness is wrong rather
// than the edit. A control arm, as with every other check in this project.
try {
    SynthDef(\playbackPlain, { |rate=1, atk=0.1, rel=0.4, cutoff=500,
                               pan=0, buf, rq=4.0, amp=1.0, out=0|
        var life = atk.max(0.03) + rel,
            bdur = BufDur.ir(buf) / rate.abs.max(0.01),
            lp   = (life > (bdur * 1.5)),
            rt   = BufRateScale.ir(buf) * rate
                     * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
            sig  = PlayBuf.ar(1, buf, rt, loop: lp, doneAction: 0),
            env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]),
                             doneAction: 2);
        sig = BPF.ar(sig, cutoff, rq.clip(0.5, 2.5));
        sig = Pan2.ar(sig, pan, amp);
        Out.ar(out, sig * env);
    }).asBytes;
    "  control (unprobed) also builds".postln;
} { |e|
    ("  CONTROL FAILED, so this harness is wrong: " ++ e.errorString).postln;
    ok = false;
};

("  RESULT: " ++ if (ok) { "PASS" } { "FAIL" }).postln;
if (ok) { 0.exit } { 1.exit };
)
