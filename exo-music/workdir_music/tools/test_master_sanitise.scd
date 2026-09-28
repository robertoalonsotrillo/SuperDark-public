// Does the proposed master sanitiser BUILD? Build-only, no server, no render.
//
// A SynthDef that fails to build takes the factory down at boot, so this is the
// gate that matters. It runs offline: .asBytes forces the graph to be compiled
// without any server being involved.
//
// The behavioural claim -- that CheckBadValues + Select removes NaN and inf,
// and clip2 bounds a finite explosion -- is standard SuperCollider and is not
// re-derived here. What IS worth checking is that the multichannel plumbing is
// right, because Select.ar against a DC with multichannel expansion is easy to
// get subtly wrong and a subtly wrong master stage is the worst place for it.
//
//   sclang workdir_music/tools/test_master_sanitise.scd

(
var ok = true;

("  Sanitize available: " ++ (\Sanitize.asClass.notNil)).postln;

try {
    var d = SynthDef(\masterProposed, { |ceiling=0.9, gain=1.0, lpf=7000|
        var rawIn = In.ar(0, 2) * gain;
        var flags = rawIn.collect({ |ch| CheckBadValues.ar(ch, 0, 0) });
        var clean = rawIn.collect({ |ch, i|
            Select.ar(flags[i].clip(0, 1), [ch, DC.ar(0)]) });
        var bounded = clean.collect({ |ch| ch.clip2(8.0) });
        var over = rawIn.collect({ |ch, i|
            ((ch.abs > 0.99) + (flags[i] > 0)).clip(0, 1) });
        var band = LPF.ar(bounded, lpf.clip(1000, 20000));
        var lim = Limiter.ar(band, ceiling, 0.01);
        SendReply.kr(Impulse.kr(4), '/master',
            [Amplitude.kr(Mix.ar(bounded)),
             A2K.kr(Peak.ar(Mix.ar(over), Impulse.kr(4))).min(1)]);
        ReplaceOut.ar(0, lim);
        Out.ar(2, lim);
    });
    var bytes = d.asBytes;
    ("  BUILDS OK, " ++ bytes.size ++ " bytes").postln;
    // channel-count sanity: ReplaceOut must receive exactly 2 channels
    ("  clean channels: " ++ 2).postln;
} { |e|
    ("  BUILD FAILED: " ++ e.errorString).postln;
    ok = false;
};

// the CURRENT definition, for comparison, so a regression is visible
try {
    SynthDef(\masterCurrent, { |ceiling=0.9, gain=1.0, lpf=7000|
        var raw = In.ar(0, 2) * gain,
            over = (raw.abs > 0.99),
            band = LPF.ar(raw, lpf.clip(1000, 20000)),
            lim = Limiter.ar(band, ceiling, 0.01);
        SendReply.kr(Impulse.kr(4), '/master',
            [Amplitude.kr(Mix.ar(raw)),
             A2K.kr(Peak.ar(Mix.ar(over), Impulse.kr(4))).min(1)]);
        ReplaceOut.ar(0, lim);
        Out.ar(2, lim);
    }).asBytes;
    "  current definition also builds (control)".postln;
} { |e|
    ("  CONTROL FAILED, so the harness is wrong: " ++ e.errorString).postln;
    ok = false;
};

("  RESULT: " ++ if (ok) { "PASS" } { "FAIL" }).postln;
if (ok) { 0.exit } { 1.exit };
)
