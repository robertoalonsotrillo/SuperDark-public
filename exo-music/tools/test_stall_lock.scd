// THE STARVED-LAYER LOCK, 28 Sept 2026: before and after.
//
// Live log of 27 Sept (live_260927_133543): 312 acquisition attempts, 302
// refused as near-copies of playbackHP machines, every refused candidate
// below 0.09 s, 1 machine written in 7.5 h. starvedLayer kept sending the
// writer to micro, micro could not be fed, and a refusal left it starved.
//
// Two arms on a sandbox copy of mutable/, gap mode, the live grammar and the
// live synth weights, same operator and vocabulary:
//   LOCKED   stallLimit huge   (the writer as it was on 27 Sept)
//   FREED    stallLimit 12     (the default the factory starts from)
// Counts admissions, the layer each attempt went to, and rung 2 machines.
//
//     sclang -l workdir_music/tools/live_conf.yaml tools/test_stall_lock.scd
(
var root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music",
    outDir = "/tmp/stall_lock", op, gram, weights, mem, policy, n = 96, run;

run = { |label, limit, reach = 0.0|
    var sandbox = "/tmp/stall_sandbox_" ++ limit, mw, ok = 0, rung2 = 0,
        tried = Dictionary.new, admitted = Dictionary.new, reasons = Dictionary.new;
    ("rm -rf " ++ sandbox ++ " " ++ outDir ++ limit).systemCmd;
    ("mkdir -p " ++ sandbox ++ "/machines " ++ sandbox ++ "/pending " ++ outDir ++ limit).systemCmd;
    ("cp " ++ root ++ "/mutable/weights.json " ++ root ++ "/mutable/memory.json "
        ++ root ++ "/mutable/written_machines.json " ++ root ++ "/mutable/bridged.json "
        ++ root ++ "/mutable/fragments.json " ++ root ++ "/mutable/policy.json "
        ++ sandbox ++ "/").systemCmd;
    mw = MachineWriter.new(sandbox, 0.25);
    mw.synthGrammar = SynthGrammar.new;
    mw.fragmentWeight = (policy["fragment_weight"] ? "0.0").asFloat;
    mw.dspWeight = (policy["dsp_slot_weight"] ? "0.0").asFloat;
    mw.synthWeight = (policy["synth_slot_weight"] ? "0.0").asFloat;
    mw.synthGrammar.extraSources = [\formant, \pluck];
    mw.synthGrammar.sourceWeights = IdentityDictionary[\playbuf -> 1, \grainbuf -> 1,
        \warp1 -> 0.5, \pitchshift -> 1, \klank -> 3, \wavetable -> 3];
    mw.stallLimit = limit;
    mw.reach = reach;
    n.do {
        var made = mw.propose(op, weights, outDir ++ limit, "gap", gram, nil, 1.0), l;
        l = (mw.lastLayer ? "none").asString;
        tried[l] = (tried[l] ? 0) + 1;
        if (made.notNil) {
            ok = ok + 1;
            admitted[l] = (admitted[l] ? 0) + 1;
            if (made.size > 6 and: { made[6].notNil }) { rung2 = rung2 + 1 };
            weights[made[0].asString] = Dictionary["dur" -> made[3].asString,
                "layer" -> made[4].asString];
        } {
            var r = mw.lastReason.asString;
            r = if (r.contains("AND shape")) { "near-copy " ++ r.copyToEnd(r.find("existing") ? 0).keep(28) ++ " " ++ (if (r.contains("<template>")) {"tmpl"} {"gram"}) } { r.keep(30) };
            reasons[r] = (reasons[r] ? 0) + 1;
        };
    };
    ("RESULT " ++ label ++ " limit " ++ limit ++ " reach " ++ reach ++ ": admitted " ++ ok ++ " / " ++ n
        ++ ", rung 2 " ++ rung2).postln;
    ("  tried    " ++ tried).postln;
    ("  admitted " ++ admitted).postln;
    ("  refused  " ++ reasons).postln;
};

op = TransferOperator.new;
mem = (root ++ "/mutable/memory.json").parseYAMLFile;
if (mem.notNil and: { mem["operator"].notNil }) { op.loadDict(mem["operator"]); op.compute };
policy = (root ++ "/mutable/policy.json").parseYAMLFile;
gram = PatternGrammar.new(3);

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

thisThread.randSeed = 280926;
run.value("LOCKED", 1000000);
thisThread.randSeed = 280926;
run.value("FREED", 12);
thisThread.randSeed = 280926;
run.value("REACH 1", 12, 1.0);
thisThread.randSeed = 280926;
run.value("REACH 2", 12, 2.0);
0.exit;
)
