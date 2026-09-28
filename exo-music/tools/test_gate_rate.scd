// HOW OFTEN DOES THE GATE ADMIT A MACHINE, BEFORE AND AFTER?
//
// The gate was measured on 5 Sept as the sole binding constraint on acquisition:
// 179 machines competing for ~21 distinguishable positions, one free playback
// slot in the whole space. This counts the admission rate at the LIVE
// minDeviation of 0.25, so the number is about the real factory and not about
// scaffolding.
//
// Two arms, and the comparison that matters is between them: the template can
// only ever be admitted on DURATION, because every template machine records the
// same (empty) shape signature and shapeDistance returns 0 for that pair. So the
// grammar arm's excess over the control is the shape rescue doing work, and
// nothing else.
//
// The ledger is restored by the caller afterwards -- this writes into
// mutable/bridged.json and mutable/written_machines.json as a side effect of
// MachineWriter taking its paths from the mutable dir.
//
// A CAPITAL LETTER IS A CLASS NAME, NOT A VARIABLE. This file declared `var N`
// and therefore did not compile -- sclang printed its banner, executed nothing,
// created no output file and reported no error. It looked exactly like a hang,
// and it wasted a long time across three sittings on 5 Sept before the control
// (test_grammar_arm.scd, which uses only lowercase names) was re-run and still
// passed, proving the fault was content and not environment.
//
// Same family as nearestAround and the unwired PatternGrammar: sclang accepting
// something and silently doing nothing. The rule is small and absolute --
// variables are lowercase, always.
//
//     sclang -l /tmp/harness_conf.yaml tools/test_gate_rate.scd
(
var root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music",
    outDir = "/tmp/gaterate", sandbox, op, mw, gram, weights, mem, nDraws = 20, run;


// ---- SANDBOX THE MUTABLE DIR ------------------------------------------------
// MachineWriter takes ledgerPath and specPath from the directory it is given,
// REGARDLESS of where its output .scd goes. Pointing it at mutable/ therefore
// rewrites bridged.json and written_machines.json underneath a live factory
// that reads both every ten windows. On 5 Sept this ran against a playing
// factory and had to be killed; the files were restored from git, but the race
// was real and would eventually have written a spec file the factory then read.
//
// So the harness works on a COPY. Nothing it does can reach the running system.
sandbox = "/tmp/mutable_sandbox";
("rm -rf " ++ sandbox).systemCmd;
("mkdir -p " ++ sandbox).systemCmd;
("cp " ++ root ++ "/mutable/weights.json " ++ root ++ "/mutable/memory.json "
    ++ root ++ "/mutable/written_machines.json " ++ root ++ "/mutable/bridged.json "
    ++ sandbox ++ "/").systemCmd;

File.mkdir(outDir);
("rm -f " ++ outDir ++ "/*.scd").systemCmd;

op = TransferOperator.new;
mem = (root ++ "/mutable/memory.json").parseYAMLFile;
if (mem.notNil and: { mem["operator"].notNil }) { op.loadDict(mem["operator"]); op.compute };

weights = (root ++ "/mutable/weights.json").parseYAMLFile;
weights = weights !? { weights["machines"] };
block {
    var ws = (root ++ "/mutable/written_machines.json").parseYAMLFile, merged;
    merged = Dictionary.new(600);
    weights.keysValuesDo { |k, v| merged.put(k.asString, v) };
    if (ws.notNil) {
        ws.keysValuesDo { |k, v|
            var parts = k.asString.split($|), nm, fld, d;
            if (parts.size == 2) {
                nm = parts[0]; fld = parts[1];
                d = merged[nm];
                if (d.isNil) { d = Dictionary.new(8); merged.put(nm, d) };
                d.put(fld, v);
            };
        };
    };
    weights = merged;
};

gram = PatternGrammar.new(3);

run = { |label, useGram|
    var ok = 0, shapes = Dictionary.new, reasons = Dictionary.new;
    // a FRESH writer per arm, so the ledger the first arm fills does not
    // starve the second -- otherwise the arms would differ in how much of the
    // pair space was left, and not only in the grammar
    mw = MachineWriter.new(sandbox, 0.25);
    nDraws.do {
        var made = mw.propose(op, weights, outDir, "random",
            if (useGram) { gram } { nil },
            if (useGram) { [1.0, 1.114, 1.246, 1.427] } { nil },
            1.35);
        if (made.notNil) {
            ok = ok + 1;
        } {
            var r = mw.lastReason.asString;
            // bucket the reason, dropping the numbers so they group
            r = if (r.contains("AND shape")) { "refused: duration AND shape" } {
                if (r.contains("within minDeviation")) { "refused: duration (no shape rescue)" } {
                    if (r.contains("endpoint")) { "refused: endpoint not in specs" } {
                        "refused: " ++ r.keep(40) } } };
            reasons[r] = (reasons[r] ? 0) + 1;
        };
    };
    ("  " ++ label ++ ": " ++ ok ++ " / " ++ nDraws ++ " admitted at minDeviation 0.25").postln;
    reasons.keysValuesDo { |k, v| ("      " ++ v ++ "x  " ++ k).postln };
    ok
};

"".postln;
"  ADMISSION RATE AT THE LIVE GATE".postln;
"".postln;
run.value("CONTROL (template, duration only)", false);
"".postln;
run.value("GRAMMAR (shape rescue available)", true);
"".postln;
"  The template can only ever pass on DURATION: every template machine records".postln;
"  the same empty signature and shapeDistance returns 0 for that pair, which is".postln;
"  what stops the stock form duplicating itself. So any excess in the grammar".postln;
"  arm is the shape rescue and nothing else.".postln;
0.exit;
)
