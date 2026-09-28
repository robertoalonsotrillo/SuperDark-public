// Render one WRITTEN machine offline, with the live SynthDefs, the live
// returns and a fixed handful of grains, so it can be heard before selection
// happens to pick it. 22 Sept 2026, B9: nothing the composed writer makes had
// been heard by anyone.
//
// Driven by tools/audition.sh, which substitutes the four tokens below.
//   MACHINEPATH  the .scd under mutable/machines/
//   OUTWAV       where the wav goes
//   DEFSPATH     the live SynthDefs, lifted out of live_factory.scd by the wrapper
//   GRAINDIR     a corpus dir; the first 24 grains, always the same 24
// Non-real-time: Score.recordNRT. No server is booted; the live factory is
// untouched.
(
var dur = 30.0, nGrains = 24, seed = 20260922, machinePath = MACHINEPATH, out = OUTWAV,
    defsPath = DEFSPATH, grainDir = GRAINDIR, fn, pat, args, bufs, prelude, score, tail, ownDef;
thisThread.randSeed = seed;
~sampleSize = 1.0; ~numPairs = 1; ~fr = 20;
~dryBus = [0]; ~reverbShortBus = [4]; ~reverbMidBus = [6]; ~reverbLongBus = [8];

defsPath.load;          // defines ~sd_playback ~sd_playbackHP ~sd_playgran ~sd_fxReturn ~sd_master
[~sd_playback, ~sd_playbackFX, ~sd_playbackHP, ~sd_playbackHPFX, ~sd_playgran, ~sd_fxReturn, ~sd_master].do { |d| d.add };

args = Dictionary[\windowsize -> 0.4, \percpitch -> 0.3, \avgflat -> 0.09, \density -> 1.5,
                  \avgcent -> 2400.0, \avgrms -> 0.2, \mainpitch -> 220.0, \avgrolloff -> 4300.0];
bufs = (0..(nGrains - 1));

fn = machinePath.load;
if (fn.isNil) { ("AUDITION: cannot load " ++ machinePath).postln; 1.exit };
// a rung 2 machine (24 Sept) carries its own SynthDef at the top of the file;
// loading registered it in the desc lib, and the score has to send it too
ownDef = SynthDescLib.global[("sg_" ++ machinePath.basename.splitext[0]).asSymbol];
if (ownDef.notNil) { ("AUDITION: own SynthDef " ++ ownDef.name).postln };
pat = fn.value(bufs, args);
if (pat.isKindOf(Pattern).not) { "AUDITION: machine did not return a pattern".postln; 1.exit };

prelude = [
    [0.0, [\d_recv, ~sd_playback.asBytes]],
    [0.0, [\d_recv, ~sd_playbackFX.asBytes]],
    [0.0, [\d_recv, ~sd_playbackHP.asBytes]],
    [0.0, [\d_recv, ~sd_playbackHPFX.asBytes]],
    [0.0, [\d_recv, ~sd_playgran.asBytes]],
    [0.0, [\d_recv, ~sd_fxReturn.asBytes]],
    [0.0, [\d_recv, ~sd_master.asBytes]],
    [0.0, [\g_new, 1, 0, 0]],
    // the three returns, tail of group 1, then the master after them
    [0.0, [\s_new, \fxReturn, 1001, 1, 1, \in, 4, \room, 0.35, \damp, 0.6, \depth, 1.0]],
    [0.0, [\s_new, \fxReturn, 1002, 1, 1, \in, 6, \room, 0.70, \damp, 0.5, \depth, 1.0]],
    [0.0, [\s_new, \fxReturn, 1003, 1, 1, \in, 8, \room, 0.93, \damp, 0.3, \depth, 1.0]],
    [0.0, [\s_new, \master, 1004, 1, 1, \gain, 4.0, \ceiling, 0.85, \lpf, 7000]]
];
if (ownDef.notNil) { prelude = prelude.add([0.0, [\d_recv, ownDef.def.asBytes]]) };
nGrains.do { |i|
    // channel 0 only, as the factory does: the grains are stereo and both
    // PlayBuf.ar(1, ..) and GrainBuf want one channel; GrainBuf on a
    // two-channel buffer is silent (first audition, 22 Sept)
    prelude = prelude.add([0.0, [\b_allocReadChannel, i,
        grainDir ++ "/g" ++ i.asString.padLeft(2, "0") ++ ".wav", 0, -1, 0]]) };

// pattern events land at the head of group 1, ahead of the returns
score = pat.asScore(dur, 0.0, (group: 1, addAction: 0)).score;
score = score.reject({ |e| e[1][0] == \c_set });   // asScore's final tempo/quiet message
tail = [[dur + 3.0, [\c_set, 0, 0]]];

("AUDITION " ++ machinePath.basename ++ "  events " ++ (score.size) ++ "  ->  " ++ out).postln;
Score.recordNRT(prelude ++ score ++ tail, "/tmp/audition_" ++ machinePath.basename ++ ".osc", out,
    sampleRate: 44100, headerFormat: "WAV", sampleFormat: "int16",
    options: ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0).memSize_(65536),
    duration: dur + 3.0,
    action: { "RENDER_OK".postln; 0.exit });
)
