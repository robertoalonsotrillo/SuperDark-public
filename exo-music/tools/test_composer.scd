// Do composed machines compile, stream safely, and get through the gate?
//
// 22 Sept 2026. The writer now composes each slot from a fragment of an
// original or a grammar term, routes to the four buses, draws an envelope
// profile and stacks 1-3 layers. Every one of those is code emitted into a
// playing factory, so before any of it goes live this harness:
//   1. compiles all 160 fragments on their own, with their preludes;
//   2. writes N machines into a sandbox through the real MachineWriter, with
//      the gate open, at fragment_weight 0.5;
//   3. loads each, runs 60 events of its stream, and checks every value the
//      SynthDefs would receive is a number inside the range they survive;
//   4. asks the LIVE gate (0.25 / 0.5) how many of them it would have let in.
// Nothing here touches mutable/. Everything happens under /tmp.
//
//   sclang -l /tmp/sctest.yaml tools/test_composer.scd
(
var root, sandbox, outDir, frags, op, specs, mwOpen, mwLive, gram, sim, names,
    nFragOk = 0, nFragBad = 0, made = List.new, nCompileBad = 0, nStreamBad = 0,
    nRouted = 0, nLayered = 0, nFrag = 0, nDsp = 0, nGate = 0, nTried = 0, args, bufs,
    say = { |ok, what| (if (ok) { "  ok    " } { "  FAIL  " } ++ what).postln },
    nMach = 300, pass = true, t0;

root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music";
sandbox = "/tmp/composer_sandbox"; outDir = sandbox ++ "/machines";
("rm -rf " ++ sandbox).systemCmd;
("mkdir -p " ++ outDir).systemCmd;
("cp " ++ root ++ "/mutable/weights.json " ++ root ++ "/mutable/written_machines.json "
    ++ root ++ "/mutable/fragments.json " ++ sandbox ++ "/").systemCmd;
("echo '{}' > " ++ sandbox ++ "/bridged.json").systemCmd;
// a second copy that the writer never touches, so the live gate below is
// asked against the specs as they were BEFORE these 300 were written; the
// first run of this test scored 0% because each machine had become its own
// nearest neighbour through written_machines.json
("rm -rf " ++ sandbox ++ "_live && cp -R " ++ sandbox ++ " " ++ sandbox ++ "_live").systemCmd;

// the globals the originals' fragments read; buses as the live factory sets them
~sampleSize = 1.0; ~numPairs = 1; ~fr = 20;
~dryBus = [0]; ~reverbShortBus = [16]; ~reverbMidBus = [18]; ~reverbLongBus = [20];

"=== composer ===".postln;
~prog = { |m| var f = File("/tmp/composer_progress.txt", "a"); f.write(m ++ "\n"); f.close };
~prog.("start");

// ---- 1. every fragment compiles on its own ----------------------------------
frags = (sandbox ++ "/fragments.json").parseYAMLFile["machines"];
frags.keysValuesDo { |m, e|
    var pre = (e["prelude"] ? "").asString;
    e["slots"].keysValuesDo { |slot, expr|
        var src = "{ |buf, args| " ++ (if (pre.isEmpty) { "" } { "var " ++ pre ++ "; " })
            ++ "var x = " ++ expr ++ "; x }";
        if (src.compile.isNil) { nFragBad = nFragBad + 1; ("    does not compile: " ++ m ++ "." ++ slot).postln }
        { nFragOk = nFragOk + 1 };
    };
};
~prog.("fragments done " ++ nFragOk ++ "/" ++ nFragBad);
("  fragments: " ++ nFragOk ++ " stand alone, " ++ nFragBad ++ " do not (the writer drops those at load; see its own report below)").postln;

// ---- 2. write N machines through the real writer -----------------------------
names = ["sc", "lu", "so", "ma", "cr", "te", "ry", "an", "hp", "st", "ht", "gl",
         "cp", "wa", "gp", "bu", "dr", "pu", "hm", "me"];
op = TransferOperator.new;
600.do { op.observe((names.choose ++ "@slow").asSymbol) };
op.compute;
specs = Dictionary.new(400);
(sandbox ++ "/weights.json").parseYAMLFile["machines"].keysValuesDo { |k, v| specs.put(k.asString, v) };
(sandbox ++ "/written_machines.json").parseYAMLFile.keysValuesDo { |k, v|
    var p = k.asString.split($|), d;
    if (p.size == 2) {
        d = specs[p[0]]; if (d.isNil) { d = Dictionary.new(8); specs.put(p[0], d) }; d.put(p[1], v) } };
gram = PatternGrammar.new(3);
sim = [1.0, 1.144, 1.346, 1.492];
mwOpen = MachineWriter.new(sandbox, 0.0001, 0.0);   // gate open: this tests the emitter
mwOpen.fragmentWeight = 0.5;
mwOpen.dspWeight = 0.5;                            // B8 rung 1
mwLive = MachineWriter.new(sandbox ++ "_live", 0.25, 0.5);   // the live gate, on the untouched copy
t0 = Main.elapsedTime;
nMach.do {
    var r = mwOpen.propose(op, specs, outDir, "random", gram, sim, [1.0, 1.144, 1.346].choose);
    if (r.notNil) { made.add((name: r[0], dur: r[3], inst: r[5], comp: mwOpen.lastComposition)) };
};
~prog.("wrote " ++ made.size);
say.(made.size >= (nMach * 0.8), "wrote " ++ made.size ++ " of " ++ nMach ++ " requested in "
    ++ (Main.elapsedTime - t0).round(0.1) ++ " s (last reason: " ++ mwOpen.lastReason ++ ")");

// ---- 3. load, stream, check every value ------------------------------------
args = Dictionary[\windowsize -> 0.4, \percpitch -> 0.3, \avgflat -> 0.09, \density -> 1.5,
                  \avgcent -> 2400.0, \avgrms -> 0.2, \mainpitch -> 220.0, \avgrolloff -> 4300.0];
bufs = [0, 1, 2, 3];
made.do { |m|
    var path = outDir ++ "/" ++ m[\name] ++ ".scd", txt = File.readAllString(path), fn, pat, st, ev,
        bad = nil, outs = Set.new, layered = txt.contains("Ppar(");
    if (txt.contains("reverb")) { nRouted = nRouted + 1 };
    if (layered) { nLayered = nLayered + 1 };
    if (txt.contains("\\resfz") or: { txt.contains("\\dlyfb") } or: { txt.contains("\\blurhz") }) { nDsp = nDsp + 1 };
    if (m[\comp].contains("<-") and: { m[\comp].find("<-grammar").notNil.not or: { m[\comp].findRegexp("<-[a-z][a-z](;|$)").notEmpty } }) { nFrag = nFrag + 1 };
    ~prog.("load " ++ m[\name] ++ " " ++ m[\comp]);
    fn = txt.compile;
    if (fn.isNil) { nCompileBad = nCompileBad + 1; ("    does not compile: " ++ m[\name] ++ "  [" ++ m[\comp] ++ "]").postln }
    {
        try {
            pat = fn.value.value(bufs, args);
            st = pat.asStream;
            60.do { |i|
                if (bad.isNil) {
                    ev = st.next(Event.default);
                    if (ev.isNil) { bad = "stream ended at event " ++ i }
                    {
                        if (ev[\dur].isNumber.not or: { ev[\dur] <= 0 } or: { ev[\dur] > 12 }) { bad = "dur " ++ ev[\dur] };
                        if (ev[\rate].isNumber.not or: { ev[\rate].abs < 0.2 } or: { ev[\rate].abs > 4.5 }) { bad = "rate " ++ ev[\rate] };
                        if (ev[\amp].isNumber.not or: { ev[\amp] < 0 } or: { ev[\amp] > 0.6 }) { bad = "amp " ++ ev[\amp] };
                        if (ev[\cutoff].isNumber.not or: { ev[\cutoff] < 60 } or: { ev[\cutoff] > 9500 }) { bad = "cutoff " ++ ev[\cutoff] };
                        if (ev[\atk].isNumber.not or: { ev[\atk] <= 0 }) { bad = "atk " ++ ev[\atk] };
                        if (ev[\rel].isNumber.not or: { ev[\rel] <= 0 }) { bad = "rel " ++ ev[\rel] };
                        if (ev[\out].isNumber.not) { bad = "out " ++ ev[\out] } { outs.add(ev[\out]) };
                        if (ev[\pan].isNumber.not or: { ev[\pan].abs > 1.0001 }) { bad = "pan " ++ ev[\pan] };
                    };
                };
            };
        } { |e| bad = "threw " ++ e.errorString };
        if (bad.notNil) { nStreamBad = nStreamBad + 1; ("    unsafe: " ++ m[\name] ++ "  " ++ bad ++ "  [" ++ m[\comp] ++ "]").postln };
    };
    // 4. the live gate, on this machine's signature against the current specs
    nTried = nTried + 1;
    if (mwLive.deviates(m[\dur], specs, m[\inst], mwLive.shapeOf(txt))) { nGate = nGate + 1 };
};
say.(nCompileBad == 0, "all written machines compile (" ++ nCompileBad ++ " failed)");
say.(nStreamBad == 0, "all streams safe for 60 events (" ++ nStreamBad ++ " unsafe)");
say.(nRouted > 0, "routed to a reverb bus: " ++ nRouted ++ " of " ++ made.size);
say.(nLayered > 0, "layered (Ppar): " ++ nLayered ++ " of " ++ made.size);
say.(nDsp > 0, "set their own processing stages: " ++ nDsp ++ " of " ++ made.size);
say.(nFrag > 0, "carry at least one fragment of an original: " ++ nFrag ++ " of " ++ made.size);
("  live gate (0.25 / 0.5) would admit " ++ nGate ++ " of " ++ nTried
    ++ " (" ++ (100.0 * nGate / nTried.max(1)).round(0.1) ++ "%)").postln;
("  example: " ++ (made.first !? { |m| m[\name] ++ "  " ++ m[\comp] } ? "-")).postln;

pass = (nCompileBad == 0) and: { nStreamBad == 0 } and: { made.size >= (nMach * 0.8) };
"".postln;
(if (pass) { "ALL PASS" } { "SOME FAILED" }).postln;
0.exit;
)
