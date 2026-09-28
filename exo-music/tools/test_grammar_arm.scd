// DOES grammar_weight ACTUALLY CHANGE THE MACHINE THE FACTORY WRITES?
//
// test_grammar.scd proves PatternGrammar emits safe patterns. That is exactly
// the kind of evidence that passed for two days while the class was referenced
// nowhere, so it cannot be the evidence that the WIRING works. What was never
// tested is the link the factory actually uses:
//
//     policy["grammar_weight"] -> gram -> mw.propose(..., grammar, sim, ratio)
//                              -> a .scd file on disk
//
// This drives that link directly. No audio server, no corpora, no FIFO -- which
// also means it still runs when the external SSD is unmounted, as it was on the
// evening of 4 Sept when the first attempt to prove this died mid-run.
//
// TWO ARMS, ONE DIFFERENCE. Both calls are identical except for the `grammar`
// argument, which is the same discipline MachineWriter's own header describes.
// If the emitted files are identical, the argument does nothing and the wiring
// is decorative. If the grammar arm contains combinators the template cannot
// produce, the switch is real.
//
//     sclang -l /tmp/harness_conf.yaml tools/test_grammar_arm.scd
(
var root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music",
    outDir = "/tmp/gramarm", sandbox, op, mw, gram, weights, mem, f, txt,
    ctrl, treat, readAll, slotsOf, combinators;

// combinators the HAND-WRITTEN TEMPLATE never emits. Presence of any of these
// in an emitted file is proof the grammar produced it, since the template's
// vocabulary is Pseq/Pwhite/Pn only.
combinators = ["Pwrand", "Pgeom", "Pstutter", "Prand", "Pseg"];

readAll = { |path| var g = File(path, "r"), s; s = g.readAllString; g.close; s };


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

// ---- the operator, with the memory a real run accumulated -------------------
op = TransferOperator.new;
mem = Object.readArchive(root ++ "/mutable/memory.json");
if (mem.isNil) {
    // memory.json is JSON, not an archive; parseYAML reads it the way the
    // factory's loadJSON does
    mem = (root ++ "/mutable/memory.json").parseYAMLFile;
};
if (mem.notNil and: { mem["operator"].notNil }) {
    op.loadDict(mem["operator"]);
    // COMPUTE, or `cells` stays empty. loadDict restores the counts; `cells` is
    // built inside compute (line 139) from the observed set, so a freshly loaded
    // operator reports 184 source states and zero cells until this is called.
    // That is also why a short shadow run never acquires: live, the cells fill
    // from observation over many windows, and five observations per cell is a
    // lot of windows.
    op.compute;
    ("  operator loaded: " ++ mem["operator"].size ++ " source states, "
        ++ op.cells.size ++ " cells after compute").postln;
} {
    "  WARNING: no operator memory; propose will find no transitions".postln;
};

// w["machines"], NOT w. The factory does this at line 374 and the first version
// of this harness passed the whole file, so `specs` was the five top-level keys
// (_comment, _features, machines, _traversal, _layers) and every lookup missed.
weights = (root ++ "/mutable/weights.json").parseYAMLFile;
weights = weights !? { weights["machines"] };
("  base specs: " ++ (weights !? { weights.size } ? 0) ++ " machines").postln;

// MERGED WITH THE WRITTEN ONES, and this is worth flagging rather than hiding.
// propose resolves both endpoints of a transition against `specs` and returns
// nil if either is missing. The operator here knows 184 source states; the base
// vocabulary is 5. So the overwhelming majority of transitions the operator
// could bridge are unresolvable, which is a plausible reason the live factory
// wrote only two machines in twenty-four hours. Whether the FACTORY should also
// be merging written_machines.json before it calls propose is a real question
// and not one this harness should answer by itself.
// INTO A FRESH DICTIONARY, never by putting into the parsed one. A Dictionary
// returned by parseYAML is sized to its contents, and growing it raises
// "Primitive '_BasicPut' failed. Index out of range." That is already recorded
// in this project -- it is why writtenSpecs is a separate dict beside `weights`
// instead of merged into it -- and this harness reproduced it verbatim on the
// first run.
block { |brk|
    var ws = (root ++ "/mutable/written_machines.json").parseYAMLFile, merged;
    if (weights.isNil) { brk.value };
    merged = Dictionary.new(600);
    weights.keysValuesDo { |k, v| merged.put(k.asString, v) };
    // UN-FLATTENED. written_machines.json is stored FLAT -- its keys are
    // "brbudr10|dur", "brbudr10|layer", "brbudr10|inst" and not a nested dict
    // under "brbudr10". Merging it raw leaves specs["brbudr10"] nil, which is
    // exactly what propose looks up, so every written machine stays invisible
    // to the acquisition channel.
    if (ws.notNil) {
        ws.keysValuesDo { |k, v|
            var parts = k.asString.split($|), name, field, d;
            if (parts.size == 2) {
                name = parts[0]; field = parts[1];
                d = merged[name];
                if (d.isNil) { d = Dictionary.new(8); merged.put(name, d) };
                d.put(field, v);
            } {
                if (merged[k.asString].isNil) { merged.put(k.asString, v) };
            };
        };
    };
    weights = merged;
    ("  + written specs: " ++ weights.size ++ " total").postln;
};

// minDeviation 0.02 AND NOT THE LIVE 0.25, and this is scaffolding for the test
// rather than a proposal. `deviates` requires a new machine's duration to sit at
// least minDeviation in log10 from EVERY existing machine on the same instrument
// -- 0.25 is a factor of 1.78. With ~180 machines spread over roughly 2.8
// decades of duration there are only about eleven such slots in the whole space,
// and they are taken. So propose legitimately returns nil almost always, which
// is a far better explanation for "two machines written in twenty-four hours"
// than anything to do with the grammar.
//
// Whether 0.25 should be lowered on the live factory is a real question and NOT
// one this harness gets to answer: the gate is what stopped the 95% duplicate
// rate of 26 Aug, when 154 bridges were written across seven distinct
// transitions. Loosening it without a measurement would reopen that.
mw = MachineWriter.new(sandbox, 0.25);
gram = PatternGrammar.new(3);

// ---- WHY, if propose returns nil. Guessing at a nil return is how two hours
// ---- went on nearestAround; findRandom has five separate nil exits and they
// ---- mean completely different things.
block {
    var cells, t, row, col, ok, cand, nBridged = 0;
    cells = op.cells;
    ("  operator cells: " ++ (cells !? { cells.size } ? "nil")).postln;
    if (cells.notNil and: { cells.size >= 3 }) {
        t = mw.tallies(op); row = t[0]; col = t[1];
        ("  total observations: " ++ t[2]).postln;
        ok = cells.select { |c| ((row[c] ? 0) >= 5) or: { (col[c] ? 0) >= 5 } };
        ("  cells with >= 5 observations: " ++ ok.size ++ "  (findRandom needs 2)").postln;
        cand = List.new;
        ok.do { |x| ok.do { |y|
            if (x != y) {
                if (mw.bridged[mw.key(x, y)].isNil) { cand.add([x, y]) } { nBridged = nBridged + 1 };
            } } };
        ("  unbridged ordered pairs: " ++ cand.size
            ++ "   already bridged: " ++ nBridged).postln;
        if (cand.size < 1) {
            "  -> EVERY viable pair has been bridged before. The retirement rule".postln;
            "     is refusing to repeat itself, which is correct behaviour and".postln;
            "     means this test needs a pair the ledger has not seen.".postln;
        };
        // DO THE OPERATOR'S CELL NAMES EVEN MATCH THE SPEC KEYS? propose looks
        // each endpoint up in `specs` and returns nil if either misses, so a
        // naming mismatch here is indistinguishable from "no gap to bridge" --
        // and it would silently cap how often the factory can ever acquire.
        ("  sample cells: " ++ ok.keep(5).collect(_.asString).join(" ")).postln;
        ("  sample specs: " ++ weights.keys.asArray.sort.keep(5).join(" ")).postln;
        block {
            var hit = ok.select { |c| weights[c.asString].notNil };
            ("  cells RESOLVABLE against specs: " ++ hit.size ++ " of " ++ ok.size).postln;
            if (hit.size < 2) {
                "  -> THIS is the nil. The operator's states are not spec keys, so".postln;
                "     every candidate pair fails the lookup and propose can never".postln;
                "     return. Not a grammar problem at all.".postln;
            };
        };
    };
    "".postln;
};

// ---- ARM A: no grammar. The control, and what every machine written so far
// ---- has been.
// RETRIED, because findRandom draws a PAIR at random and most draws die on the
// deviation gate. A single attempt per arm would make the comparison a coin
// toss: the first run of this harness had the control return nil and the
// grammar succeed, which says nothing about either. Up to 40 attempts each, and
// the count is reported so a lucky draw is visible as one.
block {
    var n = 0;
    while { ctrl.isNil and: { n < 40 } } {
        ctrl = mw.propose(op, weights, outDir, "random", nil, nil, 1.0); n = n + 1 };
    ("  control arm: " ++ n ++ " attempt(s)").postln;
};
// ---- ARM B: the grammar, and a shared ratio table. Identical call otherwise.
block {
    var n = 0;
    while { treat.isNil and: { n < 40 } } {
        treat = mw.propose(op, weights, outDir, "random",
            gram, [1.0, 1.114, 1.246, 1.427], 1.35); n = n + 1 };
    ("  grammar arm: " ++ n ++ " attempt(s)").postln;
};

"".postln;
if (ctrl.isNil and: { treat.isNil }) {
    "  BOTH ARMS RETURNED NIL -- the operator has no transition to bridge, so".postln;
    "  this test says nothing about the grammar. Not a pass and not a failure.".postln;
} {
    slotsOf = { |name|
        var p = outDir ++ "/" ++ name ++ ".scd";
        if (File.exists(p)) { readAll.value(p) } { nil }
    };
    [["CONTROL (grammar nil)", ctrl], ["GRAMMAR (grammar set)", treat]].do { |pair|
        var label = pair[0], made = pair[1], src, hits;
        ("  ==== " ++ label ++ " ====").postln;
        if (made.isNil) { "    returned nil".postln } {
            src = slotsOf.value(made[0]);
            if (src.isNil) { "    NO FILE WRITTEN".postln } {
                hits = combinators.select { |c| src.contains(c) };
                ("    file    " ++ made[0] ++ ".scd  (" ++ src.size ++ " bytes)").postln;
                ("    beyond-template combinators: "
                    ++ (if (hits.isEmpty) { "NONE" } { hits.join(" ") })).postln;
                // the \dur line is the clearest single view of the slot's shape
                src.split($\n).do { |ln|
                    if (ln.contains("\\dur,")) {
                        ("    dur  " ++ ln.stripWhiteSpace.keep(150)).postln } };
                src.split($\n).do { |ln|
                    if (ln.contains("\\rate,")) {
                        ("    rate " ++ ln.stripWhiteSpace.keep(150)).postln } };
            };
        };
        "".postln;
    };
};
0.exit;
)
