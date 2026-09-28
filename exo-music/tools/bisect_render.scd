// BISECTION LADDER -- find where the sound enters.
//
// WHY THIS EXISTS
// A constant harsh texture, heard as "clipping", survived every one of these:
// the MP3 encoder (tested twice), the browser, Icecast, the SSH tunnel,
// BlackHole and its capture path (an idle device yields exact zeros), corpus
// clipping (the corpus was rebuilt, zero pinned samples), the voice floor,
// linear-to-cubic interpolation, a real doneAction repair, a 7 kHz lowpass, and
// a 12 dB gain cut. It is audible at -25 dBFS, so nothing is overflowing.
//
// Ten measurements of the live sum came back clean, because they were all taken
// at the wrong resolution or on the wrong stage. So stop measuring the whole
// and take the thing apart instead.
//
// EVERY RUNG IS RENDERED NON-REALTIME. No audio device, no CoreAudio, no
// BlackHole, no encoder, no scheduler jitter, no dropouts. If the sound appears
// in an NRT render it is in the SYNTHESIS, and the entire realtime and
// streaming apparatus is exonerated at once.
//
// Each rung adds exactly ONE thing to the rung above it. Listen down the ladder
// and the first rung where the sound appears is the thing that causes it.
//
//   R1  one grain, PlayBuf + envelope, no filter, one voice
//   R2  R1 with the BPF -- the \playback SynthDef exactly as the factory has it
//   R3  R2 played as a SEQUENCE along a grain path (the micro layer's motion)
//   R4  R3 with two concurrent voices
//   R5  R4 with four concurrent voices
//   R6  R5 through the master chain (gain, lowpass, limiter)
//
// R0 is rendered separately in Python: the raw grains concatenated with no
// engine at all. If R0 is clean and R1 is not, the fault is PlayBuf or the
// envelope. If R0 already has it, the fault is still in the material.
//
//   sclang -l tools/live_conf.yaml tools/bisect_render.scd
(
var root = thisProcess.argv[0] ? "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music";
var outDir = root ++ "/stream/bisect";
// BISECT_GRAINS lets a rung be re-rendered from a DIFFERENT corpus without
// editing this file, which is how the 22050-vs-44100 interpolation test is run:
// the same ladder, the same code, one variable changed.
var grainDir = "BISECT_GRAINS".getenv ?? { root ++ "/grains_lic_ev" };
var sr = 44100, dur = 20.0, nBufs = 64;
// BISECT_ATK / BISECT_REL: the envelope under each grain. The default 0.1/0.4
// is a 500 ms envelope over a 60 ms grain, so the audio ends 440 ms before the
// envelope does and PlayBuf sits past its end for that whole time. Setting
// these short enough to fit the grain tests whether that mismatch is what is
// generating transients, which the corpus audit cannot explain: only 0.44% of
// grains are flagged, yet R2 shows a transient every 3 seconds.
var atkS = ("BISECT_ATK".getenv ?? "0.1").asFloat;
var relS = ("BISECT_REL".getenv ?? "0.4").asFloat;
var opts, defs, mk, render, jobs;

("mkdir -p " ++ outDir.quote).systemCmd;

opts = ServerOptions.new
    .numOutputBusChannels_(2)
    .numInputBusChannels_(0)
    .sampleRate_(sr)
    .memSize_(65536);

// ---- the SynthDefs, copied verbatim from live_factory.scd -------------------
// \pbRaw is \playback with the filter removed, so R1 vs R2 isolates the BPF.
defs = IdentityDictionary[
    \pbRaw -> SynthDef(\pbRaw, { |rate=1, atk=0.1, rel=0.4, pan=0, buf, amp=1.0, out=0|
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:0),
            env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
        sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }),
    \pbFilt -> SynthDef(\pbFilt, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, amp=1.0, out=0|
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:0),
            env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
        sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }),
    // the master chain as it now stands: gain, lowpass, limiter
    \master -> SynthDef(\master, { |ceiling=0.9, gain=1.0, lpf=7000|
        var raw = In.ar(0, 2) * gain,
            band = LPF.ar(raw, lpf),
            lim = Limiter.ar(band, ceiling, 0.01);
        ReplaceOut.ar(0, lim);
    })
];

// ---- one rung --------------------------------------------------------------
// voices: how many concurrent players
// walk:   false = the same grain every time (isolates the grain from the path)
//         true  = step through consecutive grains (the micro layer's motion)
// filt:   use \pbFilt instead of \pbRaw
// master: append the master chain
mk = { |name, voices, walk, filt, master|
    var msgs = List.new, t = 0.0, id = 1000, ev = 0.16, defName;
    defName = if (filt) { \pbFilt } { \pbRaw };

    msgs.add([0.0, [\d_recv, defs[defName].asBytes]]);
    if (master) { msgs.add([0.0, [\d_recv, defs[\master].asBytes]]) };

    // TWO ways to render silence without an error, both of which I hit:
    //
    // 1. b_allocRead, not b_allocReadChannel. The grains are STEREO and the
    //    SynthDefs are PlayBuf.ar(1, ...), so scsynth prints "Buffer UGen
    //    channel mismatch: expected 1, yet buffer has 2 channels" and outputs
    //    nothing. live_factory.scd hits the same wall and uses
    //    Buffer.readChannel. The channel index is a TRAILING INT, not an
    //    array: [\b_allocReadChannel, buf, path, start, frames, 0].
    //
    // 2. The filenames are ZERO-PADDED TO TWO PLACES. build_grains_onset.py
    //    writes f"g{made:02d}.wav", so grain 0 is g00.wav, and grain 100 is
    //    g100.wav. Asking for "g0.wav" silently allocates nothing: the alloc
    //    fails, the buffer stays empty, PlayBuf reads zeros, scsynth exits 0
    //    and writes a full-length file of pure silence. The first two runs of
    //    this ladder produced exactly that and looked like successes.
    nBufs.do { |i|
        msgs.add([0.0, [\b_allocReadChannel, i,
            grainDir ++ "/g" ++ i.asString.padLeft(2, "0") ++ ".wav", 0, 0, 0]]);
    };

    // the master must sit at the tail so it processes the sum
    if (master) {
        msgs.add([0.0001, [\s_new, \master, 999, 1, 0,
            \gain, 1.0, \ceiling, 0.9, \lpf, 7000]]);
    };

    // Events at a fixed rate so rungs are directly comparable: the ONLY
    // difference between R3, R4 and R5 is how many voices sound at once.
    while { t < dur } {
        voices.do { |v|
            var b = if (walk) { (((t / ev).floor * voices + v).asInteger % nBufs) }
                    { (v % nBufs) };
            msgs.add([t + (v * 0.013), [\s_new, defName, id, 0, 0,
                \buf, b, \amp, 0.25, \pan, (v.linlin(0, voices.max(1), -0.6, 0.6)),
                \atk, atkS, \rel, relS, \cutoff, 500]]);
            id = id + 1;
        };
        t = t + ev;
    };
    msgs.add([dur + 1.0, [\c_set, 0, 0]]);
    Score(msgs.asArray)
};

// ---- render the ladder -----------------------------------------------------
// The first version of this table was NOT a bisection. R1 and R2 played ONE
// grain repeatedly and R3 played 64, so the step from R2 to R3 changed two
// things at once -- the material AND the motion -- and a jump there would have
// been unattributable. Every step below changes exactly one variable, and the
// single-grain case is kept as a CONTROL rather than as a rung.
jobs = [
    [ "R1_single_grain_control",  1, false, false, false ],  // one grain, no filter
    [ "R2_many_grains_no_filter", 1, true,  false, false ],  // + grain variety
    [ "R3_many_grains_filtered",  1, true,  true,  false ],  // + the BPF
    [ "R4_two_voices",            2, true,  true,  false ],  // + summing
    [ "R5_four_voices",           4, true,  true,  false ],  // + more summing
    [ "R6_four_plus_master",      4, true,  true,  true  ]   // + master chain
];

// recordNRT spawns scsynth asynchronously and returns immediately, which makes
// it useless in a script that exits. Write the OSC command file and invoke
// scsynth -N directly with systemCmd, which BLOCKS until the render is done.
jobs.do { |j|
    var name = j[0],
        path = outDir ++ "/" ++ name ++ ".wav",
        osc  = outDir ++ "/_" ++ name ++ ".osc",
        cmd, rc;
    ("  rendering " ++ name ++ " ...").postln;
    mk.value(name, j[1], j[2], j[3], j[4]).writeOSCFile(osc);
    cmd = "/Applications/SuperCollider.app/Contents/Resources/scsynth"
        + "-N" + osc.quote + "_" + path.quote + sr.asString
        + "WAV int24 -o 2 -m 65536";
    rc = cmd.systemCmd;
    if (rc == 0) {
        ("    -> " ++ name ++ ".wav").postln;
    } {
        ("    FAILED (" ++ rc ++ ") " ++ name).postln;
    };
};

"  ladder rendered".postln;
0.exit;
)
