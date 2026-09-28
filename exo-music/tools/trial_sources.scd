// B8 RUNG 3, second half (27 Sept 2026): the factory TRIALS the architect's
// catalogue of candidate sources offline. For each catalogue source it writes
// machines through the real MachineWriter with that source forced, and renders
// each through tools/check_machine.sh, the live admission check, into a sandbox.
// Nothing here touches mutable/ or the live server. tools/trial_propose.py then
// reads the verdicts and the n5 evidence and writes proposals.
//
//   sclang -l <conf with the current lib/> tools/trial_sources.scd
(
var root, sandbox, outDir, specs, op, gram, sim, mw, sgram, names, perSrc = 4, log;
root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music";
sandbox = "/tmp/trial_sources"; outDir = sandbox ++ "/machines";
("rm -rf " ++ sandbox).systemCmd;
("mkdir -p " ++ outDir ++ " " ++ sandbox ++ "/admitted").systemCmd;
("cp " ++ root ++ "/mutable/weights.json " ++ root ++ "/mutable/written_machines.json "
    ++ root ++ "/mutable/fragments.json " ++ root ++ "/mutable/policy.json " ++ sandbox ++ "/").systemCmd;
("cp " ++ root ++ "/mutable/kind_baseline.json " ++ sandbox ++ "/ 2>/dev/null").systemCmd;
("echo '{}' > " ++ sandbox ++ "/bridged.json").systemCmd;
~sampleSize = 1.0; ~numPairs = 1; ~fr = 20;
~dryBus = [0]; ~reverbShortBus = [16]; ~reverbMidBus = [18]; ~reverbLongBus = [20];
log = File(sandbox ++ "/trial.log", "w");
names = ["sc", "lu", "so", "ma", "cr", "te", "ry", "an", "hp", "st", "ht", "gl",
         "cp", "wa", "gp", "bu", "dr", "pu", "hm", "me"];
op = TransferOperator.new;
600.do { op.observe((names.choose ++ "@slow").asSymbol) };
op.compute;
specs = Dictionary.new(400);
(sandbox ++ "/weights.json").parseYAMLFile["machines"].keysValuesDo { |k, v| specs.put(k.asString, v) };
gram = PatternGrammar.new(3);
sim = [1.0, 1.144, 1.346, 1.492];
mw = MachineWriter.new(sandbox, 0.0001, 0.0);
mw.fragmentWeight = 0.5; mw.dspWeight = 0.5;
sgram = SynthGrammar.new;
mw.synthGrammar = sgram; mw.synthWeight = 1.0;
sgram.catalogue.do { |src|
    var got = 0, tries = 0;
    sgram.forceSource = src;
    while { (got < perSrc) and: { tries < 60 } } {
        var r = mw.propose(op, specs, outDir, "random", gram, sim, [1.0, 1.144, 1.346].choose), txt, cmd, out;
        tries = tries + 1;
        if (r.notNil and: { mw.lastComposition.contains("src=" ++ src ++ ";") }) {
            got = got + 1;
            cmd = "OUTDIR=" ++ (sandbox ++ "/renders").quote ++ " sh "
                ++ (thisProcess.nowExecutingPath.dirname ++ "/check_machine.sh").quote ++ " "
                ++ r[6].quote ++ " " ++ (sandbox ++ "/admitted").quote ++ " 2>&1 | tail -2";
            out = cmd.unixCmdGetStdOut.stripWhiteSpace.replace("\n", " | ");
            log.write(src.asString ++ "\t" ++ r[0] ++ "\t" ++ out ++ "\n");
            ("  " ++ src ++ "  " ++ r[0] ++ "  " ++ out).postln;
        };
    };
    if (got < perSrc) { log.write(src.asString ++ "\t-\tONLY " ++ got ++ " written in " ++ tries ++ "\n") };
};
sgram.forceSource = nil;
log.close;
"TRIAL DONE".postln;
0.exit;
)
