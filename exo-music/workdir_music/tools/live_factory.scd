// =====================================================================
// THE FACTORY, RUNNING, WITH ITS BEHAVIOUR OUTSIDE ITSELF.
//
// No input. It starts itself, listens to its own output, and keeps going
// until it collapses or you kill it.
//
// What is different from a patch that loops:
//
//   mutable/weights.json    the 20 weight formulas, as data
//   mutable/policy.json     how weights become a choice, as data
//   mutable/machines/*.scd  machines as FUNCTIONS, loaded at runtime
//
// All three are re-read at a window boundary while the server keeps playing.
// SuperCollider cannot hot-reload a CLASS — recompiling the library destroys
// the server and every buffer with it — but it loads functions happily. So
// the mutable part had to move out of the class system, and it has.
//
// The consequence is the point: an agent can write a new machine into that
// directory, or change a coefficient, and the factory plays the change at the
// next window HAVING NEVER STOPPED. That is r > 0 in ¶75's sense — the
// factory running in excess of the governor's reconstitution speed.
//
// Two honest limits, stated so nobody claims otherwise later:
//   * Still not Class 3. The analyser, corpus and loading mechanism were all
//     provisioned by me, so derivations still terminate in my inputs (¶113).
//     A microphone in a room would change that. This does not.
//   * Runs 12-13 measured this loop converging by GENERATION 4. Watching
//     where and how it dies is the experiment, not a failure of it.
// =====================================================================
(
var root = WORKDIR, grainDir = GRAINDIR, nGrains = NGRAINS,
    server, bufs, b, h, logPath, logFile, startTime,
    // bytes handed to wlog, and the count at the last stat, so an
    // ORPHANED descriptor (open, inode gone) is detectable
    logBytes = 0, logChecked = 0,
    notes, noteName, mutableDir,
    weights, policy, runtimeMachines, mtimes,
    loadJSON, loadMutable, features, means, acc, accN,
    // a malformed entry in memory.json costs that entry and is counted, never
    // the whole boot -- see the block above loadMemory
    numeric, cleanFloats,
    prevWeights, recent, targets, currentState, prevState, live,
    // currentState is the OPERATOR's symbol and may carry an "@<bucket>"
    // suffix; currentMachine is the same thing as a playable machine name and
    // never does. See the block where both are assigned.
    currentMachine,
    audib, pending, saveAudibility, ampFloor,
    desc, dKeys, target, neighbourhood, nearest, grainPath, dvec, dn, pitchW,
    nearestAround,
    // the melodic dimension: the pitches the corpus affords, the drifting
    // tonic, and the hold counter that gives pitch a longer correlation time
    // than timbre. See the block beside dKeys.
    pitchHz, pitchN, tonicHz, tonicAge, pitchHold, pitchIdx, tonicLo, tonicHi,
    tonicSet, tonicIdx, buildTonics,
    coordOfHz, hzOfCoord, snapHz,
    // THE TWO CLASSES THAT WERE BUILT AND NEVER REFERENCED.
    //
    // PatternGrammar.sc and Simultaneity.sc both compile, both have their own
    // test files, and both appeared ZERO times in this file until 4 Sept.
    // sclang loads an unreferenced class in silence -- no warning, no error, the
    // banner prints and the factory runs -- so task 54 was marked complete when
    // the class compiled and nothing ever checked for a call site. That is the
    // same silent-failure class as `nearestAround` (declared, never declared in
    // the enclosing var block, executed nothing, cost two hours) and `resting`
    // (declared twice). Third instance. tools/check_call_sites.py now fails the
    // repo when a lib class has no caller, so a fourth cannot be shipped quietly.
    gram, sim, simTable, simWeight = 0, admitToSection, poolResetAt = -100, poolResets = 0,
    coordOfDegree, degreeAgainst, mkChord, opCompute, alphaSeen,
    world, worldAt, worldN,
    knobs, knobRanges, applyKnobs, saveKnobs, moveKnob, opEngaged = "-", acqTimes,
    coupleK = -1.0, restingLayers, voiceTarget, coupleLoggedWin = -1, restSlots = 0, slotPlan,
    section, sections, sectionAge, nextSection, pickSection,
    // WHERE THIS RUN HAS BEEN, newest last. NOT the same list as `sections`:
    // that is the archive, 1,575 centres remembered across 93 performances, and
    // a new section measured against all of it would be pushed into whatever
    // corner of the box the archive has never touched and would exhaust in an
    // hour. The fault measured on 6 Sept is WITHIN a run, at the half-hour
    // scale, so the memory that the pressure consults has to be that long and
    // no longer. Recalls are appended too: returning to a place is occupying it.
    occupied,

    nVoices = 2, evCtr = 0, winCtr = 0, nextWindow = 4, silentWindows = 0,
    running = true, reloads = 0,
    masterPeak = 0, clipReports = 0, masterReports = 0, voiceBlowCtr = 0,
    cutoffSeen,
    fireVoice, curArgs, played, voiceKeeper,
    // THE REQUEST SIDE. The log's existing amp field is Amplitude.kr on the
    // OUTPUT bus, so correlating it with silence was circular: it and masterPeak
    // are two statistics of the same signal. These count what was ASKED FOR --
    // how many voices fired, how many events they produced, and the amplitude
    // each event carried after the life-arc multiplier. Together they separate
    // three explanations for a silent window: nobody fired, voices fired but
    // produced no events, or events were produced at amplitudes near zero.
    //
    // RESTORED 3 Sept after I removed it by accident. Reverting the factory to
    // commit d05c4e0 was meant to undo one evening's changes, but d05c4e0
    // predates this instrumentation -- it was uncommitted working-tree work that
    // my first commit swept up. So the revert went back further than the state
    // the approved run actually used, and the 7.4 h overnight run logged zero
    // REQUEST lines. Revert to a known-good STATE, not to a commit that happens
    // to be nearby.
    fires = 0, evN = 0, evAmpSum = 0,
    // ---- THREE SLOTS, ONE PER TIMESCALE -----------------------------------
    // The factory held ONE machine at a time and redrew it every window. Layers
    // existed only as a label on whichever machine happened to be chosen, so
    // micro, mid and macro were ALTERNATIVES: choosing a macro behaviour meant
    // choosing NOT to have grains under it. Holding one slow machine alone is
    // silence with extra steps, which is exactly what happened when dwell was
    // switched on -- master peak exactly 0.000 for eleven consecutive windows.
    //
    // Roberto: "Large scale behaviours contain gestures that contain
    // micro-decisions, they can also work separately". So the three are
    // CONCURRENT, not exclusive. One slot per layer, each selecting from its own
    // layer, each holding for its own dwell, each sounding with its own span.
    // The macro slot turns over in minutes while the micro slot turns over every
    // window, so the material sustains AND moves.
    //
    // It also removes the silence structurally rather than by tuning: if the
    // macro slot's pattern runs out, mid and micro are still sounding.
    slotMach, slotDwell, slotRest, layerNames,
    // WHEN A LAYER LAST BECAME CONTINUOUSLY AUDIBLE. nil while it is silent.
    // Needed because the rest offer used to be reachable only from an EMPTY
    // slot, and a layer that is never empty is never offered one.
    slotSince,
    memPath, loadMemory, saveMemory, transitions, priorRuns = 0, lastSectionId, succ,
    trace, attend, attnReport,
    macroBufs, macroDesc, macroVec, macroN, macroSucc, macroPath, layerOf,
    // dur / layer / inst for every machine the FACTORY wrote, read from
    // mutable/written_machines.json. Kept beside weights, never merged into it.
    writtenSpecs, proposeSpecs,
    macroNb, op, mw, secOp, secOpPrev,
    midBufs, midDesc, midVec, midN, midSucc, midPath, midNb,
    wlog, logReopens = 0, lastNow = 0, clockJumps = 0,
    capDir, capIdx = 0, capName, runStamp;

notes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
noteName = { |freq| var midi, m;
    if (freq <= 0) { \unpitched } {
        midi = 69 + (12 * log2(freq / 440.0));
        if (midi.isNaN or: { midi < 12 } or: { midi > 120 }) { \unpitched } {
            m = midi.round.asInteger; (notes[m % 12] ++ ((m div: 12) - 1)).asSymbol }}};

features = [\density, \windowsize, \percpitch, \avgcent, \avgrolloff, \avgflat, \avgrms];
// MUTABLEDIR is substituted by run_live.sh and defaults to "mutable". A SHADOW
// factory gets its own -- otherwise the chaos monkey perturbing the shadow would
// be editing the live factory's policy.json, which is re-read every window by
// both. P318's economy needs each factory to own its mutable layer; a shared one
// is not an economy, it is one factory with two outputs.
mutableDir = root ++ "/" ++ MUTABLEDIR;

// ---- the mutable layer ----------------------------------------------
loadJSON = { |path|
    var f = File(path, "r"), s;
    if (f.isOpen) { s = f.readAllString; f.close; s.parseYAML } { nil }
};

// ---- THE FIVE KNOBS, HANDED TO THE FACTORY ---------------------------------
//
// 20 Sept 2026. The bracketed sequence of 19-20 Sept moved each of these five
// keys to the far end of a range and measured nothing beyond drift, with every
// arm gated clean on all ten invariants. That is the safety data: inside these
// ranges the factory does not clip, stall, go silent or blow up. So the RANGE
// stays the architect's constraint and the VALUE becomes the factory's means,
// which is the Class 3 division: the input is a norm with a bound, and how to
// sit inside it is the factory's.
//
// What the factory does with them: at each section boundary it moves ONE knob
// to a fresh uniform draw inside its range. r > 0 -- the walk has a step.
// It does NOT score the section and keep or revert the value. Three
// evaluation layers here have already been scalars to climb and all three
// narrowed the vocabulary (THE_REWARD_CHANNEL.md); a fourth is not added.
// The harness measures, the panel publishes, the kernel can stop it. What
// this can show that the bracketed design could not: whether a factory-owned
// path through these five, accumulated over hours, moves anything the fixed
// arms could not see. What it cannot show: which knob did it.
//
// The factory's values live in mutable/factory_knobs.json, NOT in policy.json,
// which stays the architect's file. The overlay is applied after every policy
// reload, so an architect edit to some other key does not silently reset the
// factory's five. knobs_to_factory "0" in policy.json switches the whole
// thing off and the next reload drops the overlay: the architect's values
// return and nothing needs a restart. Every move is a KNOB line in the log.
knobRanges = Dictionary[
    "operator_weight"  -> [0.0,  0.35],
    "attention_weight" -> [0.0,  0.15],
    "novelty_penalty"  -> [0.15, 0.40],
    "temperature"      -> [0.6,  1.0],
    "macro_bias"       -> [1.0,  2.5],
    // 27 Sept 2026: how fast memory forgets is a MEANS, so it is the
    // factory's, inside the architect's bounds (in sections, ~125 s each:
    // about 1.7 h to 70 h). Drawn log-uniformly below. The constraint that
    // stays the architect's: memory may not accumulate without bound.
    "memory_half_life" -> [50.0, 2000.0],
    // 27 Sept 2026: the share of new machines that author their own SynthDef
    // (B8 rung 2) is a means too. Bounds are the architect's.
    "synth_slot_weight" -> [0.1, 0.8],
    // 28 Sept 2026: how many refusals in a row before the writer stops
    // feeding a layer that cannot be fed (the starved-layer lock). A means.
    "acquire_stall_limit" -> [4.0, 48.0],
    // 28 Sept 2026: how far past its endpoints a bridge may land (log
    // duration), so the writer can leave the hull of what already plays.
    "acquire_reach" -> [0.0, 2.0],
    // 28 Sept 2026, SELECTION CEDED (B7 with A5). The macro form was four
    // values I set by hand: how hard a section damps outsiders (0.85), how
    // often it returns to a remembered section (0.35), how often a recalled
    // section swaps a member (0.0), and how long a section may last (6-18
    // windows). All four are means. Bounds are the architect's: a section
    // keeps a character (damping >= 0.5), memory recurs (return >= 0.1),
    // sections stay between about one and five minutes.
    "family_damping"      -> [0.5, 0.97],
    "section_return"      -> [0.1, 0.6],
    "section_mutate"      -> [0.0, 0.3],
    "section_windows_max" -> [10.0, 30.0]
];
knobs = Dictionary.new;
applyKnobs = {
    if ((policy["knobs_to_factory"] ? "0").asString == "1") {
        var k = loadJSON.value(mutableDir ++ "/factory_knobs.json");
        if (k.isKindOf(Dictionary)) {
            k.keysValuesDo { |key, v|
                var r = knobRanges[key.asString];
                if (r.notNil) {
                    var x = v.asString.asFloat.clip(r[0], r[1]);
                    knobs[key.asString] = x;
                    // put at an EXISTING key only: a parseYAML dictionary
                    // refuses a put at a new one, and all five exist
                    if (policy[key.asString].notNil) { policy[key.asString] = x.asString };
                };
            };
        };
    } { knobs = Dictionary.new };
};
saveKnobs = {
    var f = File(mutableDir ++ "/factory_knobs.json.tmp", "w"), first = true;
    if (f.isOpen) {
        f.write("{\n  \"_comment\": \"The factory's own values for the five knobs "
            ++ "it was handed on 20 Sept 2026, inside the ranges the bracketed "
            ++ "run showed safe. Written by the factory at section boundaries; "
            ++ "not hand-edited. Ignored unless policy knobs_to_factory is 1.\"");
        knobs.keys.asArray.sort.do { |k|
            f.write(",\n  \"" ++ k ++ "\": \"" ++ knobs[k].round(0.0001) ++ "\"") };
        f.write("\n}\n"); f.close;
        File.delete(mutableDir ++ "/factory_knobs.json");
        File.copy(mutableDir ++ "/factory_knobs.json.tmp", mutableDir ++ "/factory_knobs.json");
        File.delete(mutableDir ++ "/factory_knobs.json.tmp");
    };
};
moveKnob = { |win, sectionId|
    var key, r, old, new;
    if ((policy["knobs_to_factory"] ? "0").asString == "1") {
        key = knobRanges.keys.asArray.choose;
        r = knobRanges[key];
        old = (policy[key] ? r[0]).asString.asFloat;
        new = if (key == "memory_half_life" or: { key == "acquire_stall_limit" })
            { exprand(r[0], r[1]).round(1) } { rrand(r[0], r[1]).round(0.0001) };
        knobs[key] = new;
        if (policy[key].notNil) { policy[key] = new.asString };
        saveKnobs.value;
        wlog.value("KNOB " ++ win ++ "," ++ key ++ "," ++ old ++ "," ++ new
            ++ "," ++ sectionId ++ "\n");
    };
};

// The factory writes its own findings back into the mutable layer. This is
// the first thing other than me to write to mutable/, and it is what an agent
// on the other end would read to know which machines are worth anything.
saveAudibility = {
    var f = File(mutableDir ++ "/audibility.json", "w"), first = true;
    if (f.isOpen) {
        f.write("{\n  \"_comment\": \"Learned by the factory from its own output. "
            ++ "1.0 = reliably audible, 0.0 = never produced sound. Written every "
            ++ "window; not hand-edited.\",\n  \"machines\": {\n");
        audib.keys.asArray.sort.do { |k|
            if (first.not) { f.write(",\n") }; first = false;
            f.write("    \"" ++ k ++ "\": " ++ audib[k].round(0.001));
        };
        f.write("\n  }\n}\n"); f.close;
    };
};

// ---- PERFORMANCE MEMORY ---------------------------------------------
// Until now NOTHING survived a run. The four timescales the factory had --
// running means (~15 s), `recent` (12 machines), sections (the run), and the
// audibility score -- all died with the process. audibility.json looked like
// persistence but was opened "w" only and never read back, so every boot
// reseeded from a literal. The factory remembered facts about ITSELF and
// nothing about what it had PLAYED.
//
// memory.json is the first thing that crosses a run boundary. It holds the
// regions of the corpus the factory has occupied, the machine families it used
// there, and which section followed which. A later run can therefore RETURN to
// a region an earlier performance found, instead of rediscovering the corpus
// from nothing each time.
//
// IT IS RECALL, NOT PREFERENCE, and that distinction is the whole design.
// Amplitude is recorded per section as an observation and is NOT allowed to
// weight selection. Runs 53-58 measured what happens when a self-generated
// score steers choice: it becomes a positive feedback loop and the factory
// converges onto what it already does loudly. A memory that preferred its own
// successes would rebuild that engine with a longer time constant. So
// memory_bias exists, defaults to 0.0, and is there to be TESTED rather than
// switched on.
//
// The honest limit: this raises r in P75's sense, because the factory now runs
// on state the governor did not provision this run. It does not make it Class 3
// -- the corpus, the analyser and this file are still mine (P113).
memPath = mutableDir ++ "/memory.json";

// ---- ATTENTION OVER THE FACTORY'S OWN HISTORY ------------------------
// The section graph above is a first-order Markov chain over a quantisation I
// imposed: regions I chose to call sections, and counts of what followed what.
// Interpretable and cheap, but first-order, and it can only recall what it
// happened to label.
//
// This is the other structure, and it is attention WITHOUT a transformer and
// without training. Query is the factory's current position in descriptor
// space; keys are every position it has ever occupied, across runs; values are
// the machine that actually played there; weights are a softmax over
// similarity. No learned parameters, so nothing is imported from outside and
// P113 is not made worse. Fully printable, so the audit strand can see exactly
// which past moments are being recalled at any instant.
//
// The symmetry is the point: grainPath already navigates the CORPUS by
// proximity in this same descriptor space. This navigates the factory's OWN
// HISTORY by proximity in it. One geometry, two axes -- material and memory.
//
// attention_weight DEFAULTS TO 0.0. "Recall what followed states like this one"
// is imitation of its own past, and if it steers hard it is a convergence
// engine with a longer time constant than the audibility loop that narrowed
// runs 53-58. Retrieval is not preference. The weight exists to be tested.
// ---- TWO LAYERS -----------------------------------------------------
// Measured median event duration across the vocabulary spans 0.013 s (ma, cr)
// to 11.4 s (bu). Nearly a thousandfold, and no single grain length can serve
// it. At 0.5 s grains the fast machines smeared five overlapping grains into
// every event -- "a broken radio". At 0.06 s the slow machines became isolated
// clicks separated by silence -- "fragments just got even shorter". Both are
// the same mismatch seen from opposite ends.
//
// So the corpus is two corpora. A machine is handed grains at the scale its own
// rhythm works at: 60 ms onset-aligned for the eleven fast machines, 2 s for the
// nine slow ones. The assignment is read from weights.json, where it was written
// from dump_events measurements rather than chosen by hand.
// THE FACTORY'S OWN MACHINES ARE CONSULTED SECOND, AND UNTIL 3 SEPT NOT AT ALL.
//
// This read `weights` and nothing else, and fell back to "micro" for anything
// it could not find there. weights.json holds the twenty machines the architect
// wrote, so all 156 machines the FACTORY has written were called micro -- and
// micro is not a label. It decides three things at once: the machine is handed
// the 60 ms grain corpus in fireVoice, it is cut at voice_span_micro, and it is
// only ever eligible for the micro slot.
//
// Their measured event rates run 0.46 s to 8.0 s. A machine emitting one event
// every six seconds, handed 60 ms grains and stopped after twelve, makes two
// short sounds and nothing else. Roberto, 3 Sept: "a huge amount of really
// short outbursts... no held sounds, no phrases, no longer-term melodic or
// harmonic construction, just pure rhythm."
//
// weights wins where both know a machine, so this can only add knowledge about
// machines the architect never wrote.
layerOf = { |m|
    var spec = weights !? { weights[m.asString] },
        lay = spec !? { spec["layer"] };
    if (lay.isNil and: { writtenSpecs.notNil }) {
        lay = writtenSpecs[m.asString] !? { |d| d["layer"] };
    };
    if (lay.notNil) { lay.asString } { "micro" };
};

attend = { |q|
    var w = Dictionary.new, temp = (policy["attention_temperature"] ? "0.15").asFloat,
        sims, mx, tot;
    attnReport = nil;
    if (trace.size > 4 and: { q.notNil }) {
        sims = trace.collect { |e|
            var d = 0; q.do { |v, i| d = d + ((v - e[\state][i]).squared) };
            d.sqrt.neg / max(1e-6, temp)          // negative distance, scaled
        };
        mx = sims.maxItem;
        sims = sims.collect { |s| (s - mx).exp };  // softmax, shifted for stability
        tot = sims.sum;
        if (tot > 0) {
            sims.do { |s, i|
                var m = trace[i][\machine];
                w[m] = (w[m] ? 0) + (s / tot);
            };
            // what is being recalled, for the log: the three nearest past moments
            attnReport = (0 .. trace.size - 1).sort({ |a, b| sims[a] > sims[b] })
                .keep(3).collect({ |i| trace[i][\machine].asString
                    ++ "@" ++ trace[i][\run] ++ ":" ++ (sims[i] / tot).round(0.001) });
        };
    };
    w
};

// ONE BAD ENTRY MUST NOT COST THE FACTORY. 15 Sept 2026.
//
// A boot died here, fatal at file level, before scsynth came up:
//
//   var st = (e["s"] ? []).collect({ |v| v.asFloat });
//   ERROR: Message 'asFloat' not understood.
//   RECEIVER: Dictionary[ (s -> [0.588, ...]), (m -> ry), (r -> 76) ]
//
// A trace entry's `s` held a Dictionary where six floats belong, in an array
// reading [cp, r, 76, Dictionary[...], s, 0.588] -- the shape of a parser that
// lost an entry boundary and inlined the next object. Python read the same file
// cleanly, and a five-trial parseYAML probe of the CURRENT file found 8,000 of
// 8,000 well formed, so the specific corruption was not reproduced. The file
// that crashed had already been overwritten by the next run, which is its own
// lesson: nothing kept a copy of the input that broke the boot.
//
// Root cause unknown, and that is exactly why this guard exists. The line below
// trusted the parse completely, so one malformed element anywhere in 8,000
// entries took down the whole factory. Now it costs that entry and is COUNTED,
// so the same event next time leaves a number in the log instead of a corpse.
// The count is the point: a silent skip would be the inert-mechanism failure
// again.
numeric = { |v| v.isNumber or: { v.isString and: { v.asString.asFloat.isNumber } } };
cleanFloats = { |raw|
    if (raw.isArray.not) { nil } {
        if (raw.every({ |v| numeric.value(v) })) { raw.collect({ |v| v.asFloat }) } { nil }
    };
};

loadMemory = {
    var m = loadJSON.value(memPath), n = 0, droppedTrace = 0, droppedSect = 0;
    transitions = Dictionary.new;
    trace = List.new;
    if (m.notNil) {
        (m["trace"] ? []).do { |e|
            var st = cleanFloats.value(e !? { e["s"] } ? []);
            if (st.isNil) { droppedTrace = droppedTrace + 1 } {
            if (st.size == dKeys.size) {
                trace.add(IdentityDictionary[\state -> st,
                    \machine -> (e["m"] ? "sc").asSymbol,
                    \run -> (e["r"] ? "0").asInteger]);
            }};
        };
        priorRuns = (m["runs"] ? "0").asInteger;
        (m["sections"] ? []).do { |s|
            var centre = cleanFloats.value(s !? { s["centre"] } ? []) ? [];
            // a memory written against a different descriptor space is not
            // comparable; drop it rather than silently mixing geometries
            if (centre.isEmpty and: { (s !? { s["centre"] }).notNil }) {
                droppedSect = droppedSect + 1 };
            if (centre.size == dKeys.size) {
                sections.add(IdentityDictionary[
                    \id      -> sections.size,
                    \centre  -> centre,
                    \voices  -> (s["voices"] ? "2").asInteger,
                    \family  -> (s["family"] ? []).collect({ |v| v.asSymbol }),
                    \visits  -> (s["visits"] ? "0").asInteger,
                    \ampSum  -> (s["ampSum"] ? "0").asFloat,
                    \ampN    -> (s["ampN"] ? "0").asInteger,
                    \recalled -> true ]);
                n = n + 1;
            };
        };
        (m["transitions"] ? Dictionary.new).keysValuesDo { |k, v|
            transitions[k.asString] = v.asFloat };
        op.loadDict(m["operator"]);
        opCompute.value(op);
    };
    ("MEMORY " ++ n ++ " sections recalled from " ++ priorRuns ++ " prior run(s), "
        ++ transitions.size ++ " transitions, " ++ trace.size ++ " trace states").postln;
    // LOUD, AND IT KEEPS THE EVIDENCE. A malformed entry used to be fatal; now
    // it is survivable, and the danger flips from a dead factory to a quiet one
    // that reads a degraded memory as if nothing happened. So say it, and copy
    // the offending file aside: the boot that died on 15 Sept could not be
    // diagnosed because the next run had already overwritten its input.
    if ((droppedTrace > 0) or: { droppedSect > 0 }) {
        var keep = memPath ++ ".malformed_" ++ Date.getDate.stamp;
        ("MEMORY_MALFORMED " ++ droppedTrace ++ " trace, " ++ droppedSect
            ++ " sections dropped as unparseable. Kept the input at "
            ++ keep).postln;
        ("/bin/cp -f " ++ memPath.quote ++ " " ++ keep.quote).systemCmd;
        // loadMemory can run before the window log is open, so this is guarded:
        // a nil wlog here would turn a recovered boot back into a dead one
        if (wlog.notNil) {
            wlog.value("MEMORY_MALFORMED " ++ droppedTrace ++ ","
                ++ droppedSect ++ "\n") };
    };
    op.report.postln;
    n
};

saveMemory = {
    // WRITE ASIDE, THEN RENAME. THIS FILE BRICKED THE FACTORY FOR A DAY.
    //
    // 7 Sept 2026, 13:56. This opened memPath with "w", which TRUNCATES the live
    // file, and then wrote 712 KB into it incrementally. The factory was killed
    // partway through, so memory.json was left ending on a bare `{"s":`. Every
    // boot after that threw
    //
    //   ERROR: Primitive '_String_ParseYAML' failed.
    //   yaml-cpp: error at line 7456, column 1: end of map flow not found
    //
    // and stopped before the factory started. sclang then sat at 0% CPU with no
    // scsynth, which looks exactly like a hang. FIVE boots were attributed to a
    // wedged CoreAudio state, to the splitter being started in the wrong order,
    // and to VB-Cable enumerating with one channel -- and a reboot appeared to
    // fix it once, which it did not: that boot simply happened before the file
    // was corrupted. The audio subsystem was never the problem.
    //
    // A rename within a filesystem is atomic, so a reader sees either the old
    // complete file or the new complete one, never a half-written one. The same
    // pattern is already used twice in this project for exactly this reason:
    // fifo_splitter writes segments as .part and renames, and publish_state
    // writes state.json to .tmp and replaces. Memory is the file that persists
    // across every run and it was the one without the guard.
    //
    // The cost of a kill is now the loss of ONE section's worth of memory --
    // whatever happened since the last section change -- instead of all of it.
    var tmpPath = memPath ++ ".tmp",
        f = File(tmpPath, "w"), first = true;
    if (f.isOpen) {
        f.write("{\n  \"_comment\": \"What the factory has PLAYED, across runs. "
            ++ "Regions of the corpus it has occupied, the machine families used "
            ++ "there, and which section followed which. Recall only: amplitude is "
            ++ "recorded as an observation and does not weight selection, because "
            ++ "runs 53-58 measured a self-generated score becoming a convergence "
            ++ "engine. Written at every section change.\",\n");
        f.write("  \"runs\": " ++ (priorRuns + 1) ++ ",\n  \"sections\": [\n");
        sections.do { |s, i|
            if (i > 0) { f.write(",\n") };
            f.write("    {\"centre\": [" ++ s[\centre].collect({ |v| v.round(0.0001) }).join(", ")
                ++ "], \"voices\": " ++ s[\voices]
                ++ ", \"family\": [" ++ s[\family].collect({ |m| "\"" ++ m ++ "\"" }).join(", ")
                ++ "], \"visits\": " ++ (s[\visits] ? 0)
                ++ ", \"ampSum\": " ++ (s[\ampSum] ? 0).round(0.00001)
                ++ ", \"ampN\": " ++ (s[\ampN] ? 0) ++ "}");
        };
        f.write("\n  ],\n  \"transitions\": {\n");
        transitions.keys.asArray.sort.do { |k|
            if (first.not) { f.write(",\n") }; first = false;
            f.write("    \"" ++ k ++ "\": " ++ transitions[k].round(0.0001));
        };
        f.write("\n  },\n");
        // the operator's counted tendencies, so it is a property of the
        // factory's whole history rather than of one performance
        f.write("  \"operator\": {\n");
        block {
            var firstA = true;
            op.counts.keysValuesDo { |a, row|
                var firstB = true;
                if (firstA.not) { f.write(",\n") }; firstA = false;
                f.write("    \"" ++ a ++ "\": {");
                row.keysValuesDo { |b, v|
                    if (firstB.not) { f.write(", ") }; firstB = false;
                    // EFFECTIVE counts, in today's units. With a half-life on,
                    // raw counts carry the weight they were recorded at, which
                    // grows geometrically and is never persisted; saving them
                    // raw meant the next boot reloaded them against wNow=1.0
                    // and every new observation was worth nothing beside them.
                    // op.effective divides by wNow so the file is always
                    // self-consistent and reload needs nothing else. With no
                    // half-life it returns v unchanged.
                    f.write("\"" ++ b ++ "\": " ++ op.effective(v));
                };
                f.write("}");
            };
        };
        f.write("\n  },\n");
        // the trajectory itself, capped so the file stays readable. The tail is
        // kept rather than the head: recent history is what attention queries.
        f.write("  \"trace\": [\n");
        block { |brk|
            var cap = (policy !? { policy["trace_max"] } ? "3000").asInteger,
                t = if (trace.size > cap) { trace.copyRange(trace.size - cap, trace.size - 1) } { trace };
            t.do { |e, i|
                if (i > 0) { f.write(",\n") };
                f.write("    {\"s\": [" ++ e[\state].collect({ |v| v.round(0.001) }).join(", ")
                    ++ "], \"m\": \"" ++ e[\machine] ++ "\", \"r\": " ++ e[\run] ++ "}");
            };
        };
        f.write("\n  ]\n}\n"); f.close;
        // PUBLISH ONLY A CLOSED FILE. The rename happens after f.close, so the
        // bytes are on disk before anything can read them under the real name.
        // If the process dies before this line, memory.json is untouched and the
        // only casualty is a stray .tmp.
        ("/bin/mv -f " ++ tmpPath.quote ++ " " ++ memPath.quote).systemCmd;
    };
};

loadMutable = { |verbose = false|
    var wPath = mutableDir ++ "/weights.json",
        pPath = mutableDir ++ "/policy.json",
        sPath = mutableDir ++ "/written_machines.json",
        changed = false, w, p, s, files, n;

    // weights
    if (File.mtime(wPath) != (mtimes[\weights] ? 0)) {
        w = loadJSON.value(wPath);
        if (w.notNil) { weights = w["machines"]; mtimes[\weights] = File.mtime(wPath);
            changed = true; if (verbose) { "  reloaded weights.json".postln };
            // reloading weights REPLACES the dictionary, discarding the merge
            // below. Forget the spec mtime so the merge is redone against the
            // new object; otherwise editing weights.json silently returns every
            // factory-written machine to the micro pool until the next restart.
            mtimes[\wspecs] = nil };
    };
    // THE FACTORY'S OWN MACHINES, AND WHY THIS LINE IS THE WHOLE FAULT.
    //
    // layerOf reads `weights` and nothing else, and falls back to "micro" for
    // anything it cannot find there. weights.json holds the twenty machines the
    // architect wrote. So all 156 machines the FACTORY has written were called
    // micro -- and being called micro is not a label, it decides three things
    // at once: the machine is handed the 60 ms grain corpus, it is cut at
    // voice_span_micro, and it is only ever eligible for the micro slot.
    //
    // Their measured event rates run from 0.46 s to 8.0 s. A machine emitting
    // one event every six seconds, handed 60 ms grains and stopped after twelve,
    // produces two short sounds and then nothing. Roberto, listening 3 Sept:
    // "a huge amount of really short outbursts... no held sounds, no phrases,
    // no longer-term melodic or harmonic construction, just pure rhythm."
    // That is not a shortcoming of the material. It is 148 long-form machines
    // being played through the short-form path.
    //
    // The three slots made this visible by making it matter. While every layer
    // behaved identically the misclassification cost nothing; now the macro slot
    // selects from four machines and the micro slot from a hundred and sixty.
    //
    // Merged UNDER weights, never over: an entry the architect wrote wins, so
    // this can only add knowledge about machines weights.json has never heard of.
    // Descriptive fields only -- dur, layer, inst -- so selection weighting is
    // untouched.
    // KEPT SEPARATE FROM `weights`, NOT MERGED INTO IT.
    // The first version wrote into `weights` directly and died on the boot of
    // 3 Sept with "Primitive '_BasicPut' failed" -- whatever parseYAML returns
    // for that file does not accept a put at a new key. It also does not need
    // to: a second dictionary that layerOf consults AFTER weights gives the
    // same precedence (architect first, factory second) without touching an
    // object whose type is decided elsewhere.
    if (File.exists(sPath) and: { File.mtime(sPath) != (mtimes[\wspecs] ? 0) }) {
        s = loadJSON.value(sPath);
        mtimes[\wspecs] = File.mtime(sPath);
        if (s.notNil) {
            n = Dictionary.new;
            s.keysValuesDo { |k, v|
                var ks = k.asString, i = ks.find("|"), nm, fld;
                if (i.notNil) {
                    nm = ks.copyRange(0, i - 1);
                    fld = ks.copyRange(i + 1, ks.size - 1);
                    if (n[nm].isNil) { n[nm] = Dictionary.new };
                    n[nm][fld] = v.asString;
                };
            };
            writtenSpecs = n;
            changed = true;
            if (verbose) { ("  written_machines.json: " ++ writtenSpecs.size
                ++ " factory machines now carry their own layer").postln };
        };
    };

    // ---- THE SPEC VIEW THE ACQUISITION CHANNEL GETS ------------------------
    //
    // propose() resolves BOTH endpoints of a candidate transition against the
    // specs it is handed, and returns nil if either misses. It was handed
    // `weights` -- the twenty machines in weights.json -- while the operator
    // routinely knows 180+ states, because every machine the factory has ever
    // written is a state it can occupy. So roughly 89% of the pairs the
    // operator could bridge failed the lookup before the deviation gate or the
    // retirement ledger got a say, and the factory could only ever bridge
    // within the architect's original vocabulary.
    //
    // That was never a decision. writtenSpecs already holds exactly the missing
    // information, un-flattened, twenty lines above; it simply was not passed.
    // Measured 5 Sept with tools/test_grammar_arm.scd: 20 of 173 candidate
    // cells resolvable before, 166 of 173 after.
    //
    // A THIRD DICTIONARY, because neither source can absorb the other. `weights`
    // comes from parseYAML and raises "_BasicPut failed" on a put at a new key,
    // which is why writtenSpecs exists separately in the first place. Rebuilt
    // only when one of them changed, so this costs nothing per window.
    //
    // PRECEDENCE IS ARCHITECT FIRST, FACTORY SECOND -- the same order layerOf
    // uses, so a machine defined in both places reads the same way everywhere.
    //
    // This does NOT loosen any gate. deviates() already consulted loadSpecs and
    // so already knew about written machines; the retirement ledger still
    // refuses a pair it has bridged before. What changes is only which
    // transitions are ELIGIBLE to be considered.
    if (changed) {
        var merged = Dictionary.new(800);
        if (weights.notNil) {
            weights.keysValuesDo { |k, v| merged.put(k.asString, v) } };
        if (writtenSpecs.notNil) {
            writtenSpecs.keysValuesDo { |k, v|
                if (merged[k.asString].isNil) { merged.put(k.asString, v) } } };
        proposeSpecs = merged;
        if (verbose) { ("  acquisition specs: " ++ proposeSpecs.size
            ++ " machines eligible as bridge endpoints ("
            ++ (weights !? { weights.size } ? 0) ++ " architect + "
            ++ (writtenSpecs !? { writtenSpecs.size } ? 0) ++ " written)").postln };
    };
    // policy
    if (File.mtime(pPath) != (mtimes[\policy] ? 0)) {
        p = loadJSON.value(pPath);
        if (p.notNil) { policy = p; mtimes[\policy] = File.mtime(pPath);
            changed = true; if (verbose) { "  reloaded policy.json".postln };
            // the factory's five knobs sit on top of the architect's file
            applyKnobs.value;
            if (knobs.size > 0 and: { verbose }) { ("  factory knobs: "
                ++ knobs.keys.asArray.sort.collect({ |k| k ++ "=" ++ knobs[k] }).join(" ")).postln };
            // the centres were built with a default because policy did not
            // exist yet at corpus-load time; rebuild them now that it does, and
            // on every later edit, so tonic_centres is a live value and not an
            // ornament in a file
            if (buildTonics.notNil and: { pitchHz.notNil }) {
                buildTonics.value((policy["tonic_centres"] ? "5").asInteger);
                if (verbose) { ("  tonic centres: "
                    ++ tonicSet.collect({ |h| h.round(0.1) }).join(" ")).postln };
            };
            // ---- THE VERTICAL TABLE, REBUILT ON EVERY POLICY EDIT ----------
            //
            // Built HERE and not at corpus-load time for the reason recorded
            // beside buildTonics: policy is nil while the corpus loads, and
            // three separate additions have now assumed otherwise. It is
            // rebuilt on every edit so simultaneity_weight and
            // simultaneity_degrees are live values instead of ornaments.
            //
            // FED raw_hz, NOT NORMALISED RANKS. The first attempt handed this
            // class desc["norm"]["pitch"], and a rank is not an interval: the
            // quotient of two ranks is a number with no acoustic meaning, the
            // table came back [1.0], and the degenerate-table guard inside
            // PatternGrammar was what caught it. pitchHz is the sorted list of
            // real fundamentals and is the only input for which ps[i]/ps[0] is
            // an interval at all.
            if (sim.notNil and: { pitchHz.notNil }) {
                // THE MODE IS SET HERE, NOT AT CONSTRUCTION. FOURTH INSTANCE.
                //
                // sim is built at line ~709 with
                //     (policy !? { policy["simultaneity_mode"] } ? "corpus")
                // and `policy` IS NIL AT THAT POINT -- loadMutable, which
                // assigns it, does not run until line ~1978. So `!?` returns nil,
                // the default wins, and simultaneity_mode was silently pinned to
                // "corpus" no matter what the file said. Caught 5 Sept only
                // because the boot line printed the corpus quantiles
                // (1.0 1.114 1.246 1.412 ...) while the policy said `just`.
                //
                // This file has an initialisation ORDER and this is now the
                // FOURTH addition to assume otherwise, after buildTonics, the
                // writtenSpecs merge and the gram deferral. The pattern is
                // always the same: read policy at construction, get nil, take a
                // default, and produce a knob that appears in policy.json and
                // does nothing. Assign it on every policy load instead, which
                // also makes the mode switchable without a restart.
                sim.mode = (policy["simultaneity_mode"] ? "corpus").asSymbol;
                simWeight = (policy["simultaneity_weight"] ? "0.0").asFloat.clip(0, 1);
                sim.buildTable(pitchHz,
                    (policy["simultaneity_degrees"] ? "4").asInteger.clip(2, 7));
                simTable = sim.tableFor(simWeight);
                if (verbose) {
                    ("  vertical: weight " ++ simWeight
                        ++ "  table " ++ sim.offered.collect({ |r| r.round(0.001) }).join(" ")
                        ++ (if (simTable.isNil) { "  (OFFERED TO NOTHING -- control arm)" } { "  LIVE" })
                    ).postln };
            } };
    };
    // machines: every .scd in mutable/machines, loaded as a Function
    files = (mutableDir ++ "/machines/*.scd").pathMatch;
    files.do { |path|
        var name = PathName(path).fileNameWithoutExtension.asSymbol,
            mt = File.mtime(path), fn;
        if (mt != (mtimes[name] ? 0)) {
            fn = { path.load }.try;
            if (fn.isKindOf(Function)) {
                runtimeMachines[name] = fn; mtimes[name] = mt; changed = true;
                if (verbose) { ("  loaded machine " ++ name).postln };
                wlog.value("LOADED_MACHINE " ++ name ++ "\n");
            } {
                ("  REJECTED " ++ name ++ ": file must evaluate to a Function").postln;
                wlog.value("REJECTED_MACHINE " ++ name ++ "\n");
            };
        };
    };
    // machines whose file has gone are forgotten
    runtimeMachines.keys.do { |k|
        if (files.detect({ |p| PathName(p).fileNameWithoutExtension.asSymbol == k }).isNil) {
            runtimeMachines.removeAt(k); mtimes.removeAt(k); changed = true;
            if (verbose) { ("  dropped machine " ++ k).postln };
        };
    };
    if (changed) { reloads = reloads + 1 };
    changed
};

// Server.local. A private Server on another port was tried, to survive a
// wedged sclang holding scsynth's single client slot, and it boot-looped on
// "Requested notification messages" without ever entering waitForBoot's
// function. The wedged process turned out to hold no port at all, so the
// collision was simply two live sclangs; run_live.sh now refuses to start
// while another one is running, which is the actual fix.
// A dedicated port, not Server.local's 57110.
//
// killall -9 during a CoreAudio call leaves processes wedged in uninterruptible
// state (STAT UNE/UE). They ignore SIGKILL and persist for the session, and a
// wedged scsynth keeps port 57110, so every later boot loops forever on
// "/notify : already registered" without ever reaching the factory. Three had
// accumulated by mid-afternoon. SCPORT lets a run step around them; only a
// reboot actually clears them.
server = Server(("factory" ++ SCPORT).asSymbol, NetAddr("127.0.0.1", SCPORT));
Server.default = server;
server.options.numBuffers = 16384;
server.options.maxNodes = 65536;
server.options.memSize = 512 * 1024;
// 4 when running into the aggregate device (Built-in + BlackHole), 2 otherwise.
server.options.numOutputBusChannels = ("SC_OUTCH".getenv ?? "2").asInteger;
// THE CORPUS IS 22050 Hz. At a 44100 server BufRateScale is exactly 0.5; at
// 48000 it is 0.459375, so every grain is resampled at a non-integer ratio by
// PlayBuf's interpolator, adding low-level broadband noise to EVERY sound.
// The offline renders are 44100 and sound clean through the same headphones;
// the live server takes 48000 from the AirPods and does not. That difference
// is immune to every factory parameter, which is why nothing changed it.
server.options.sampleRate = 44100;
// HARDWARE BUFFER. Set from SC_HWBUF so the streaming path can be given slack
// without editing this file.
//
// BlackHole and VB-Cable are loopback drivers with NO HARDWARE CLOCK: a ring
// buffer between two independent clients, scsynth writing and ffmpeg reading,
// each on its own timer. When they drift the ring slips and a block is lost.
// Measured 31 Aug on the SAME audio, captured two ways at once:
//     SuperCollider's own recording   clicks/s 0.40   worst  44.6
//     ffmpeg reading BlackHole        clicks/s 4.32   worst 163.0
// and Roberto confirmed by ear that the built-in speakers, with no virtual
// device anywhere in the chain, are clean. The factory was never the problem;
// three days of corpus work went into a signal path that measures fine the
// moment the loopback is removed.
//
// A larger hardware buffer gives the ring more slack per callback, so a given
// amount of drift costs fewer dropped blocks. It is a MITIGATION and not a
// clock: the real fix is an aggregate device that puts BlackHole on the
// built-in output's clock with drift correction enabled.
server.options.hardwareBufferSize = ("SC_HWBUF".getenv ?? "512").asInteger;
// SC opens the DEFAULT INPUT at boot. When that input is the AirPods, macOS
// drops them from A2DP to the hands-free profile and the whole transport
// becomes 24 kHz through a speech codec -- which is the "patina". Naming an
// output device that has no headset mode keeps the link in high quality.
// OUTDEVICE is substituted by run_live.sh; empty means "system default".
OUTDEVICE
// No input. The factory listens to its own OUTPUT bus, which is internal;
// opening an input device only produces a sample-rate mismatch here.
server.options.numInputBusChannels = 0;

logPath = root ++ "/renders/live_" ++ Date.getDate.stamp ++ ".log";
logFile = File(logPath, "w");
("LOG " ++ logPath).postln;

// EVERY write to the window log goes through here.
//
// On 28 Aug the shadow factory's log stopped at window 716 while the factory
// itself ran on to 775 and beyond: heartbeats printed, machines were written
// to disk, audio kept playing. lsof showed the log file ABSENT from the
// process's open descriptors -- the handle had been closed out from under the
// factory -- and File.write on a closed File in SuperCollider does not raise,
// it silently does nothing. So the run continued and its record did not, and
// the loss was invisible for an hour. Worse, chaos.py reads its window counter
// from this file, so a dead log froze the counter at 716 and the chaos monkey
// held a perturbation that could never expire.
//
// The cause is still open, so this does not assume one. It checks the handle
// before every write and reopens if it is gone. APPEND, never "w": reopening
// with "w" would truncate the very record it is trying to repair.
//
// The reopen is announced on stdout AND marked in the log, because the thing
// that made this expensive was not the failure but its silence.
// AND isOpen WAS NOT ENOUGH, WHICH COST 2.5 HOURS ON 4 SEPT.
//
// The run of 09:29 reached window 710 and its log held twelve MASTER lines. The
// window loop was calling this 710 times; the writes went nowhere. isOpen
// reported TRUE the whole way, because a file handle whose inode has been
// removed or whose volume was remounted is still a valid open descriptor -- it
// simply points at nothing. The check tested whether the handle was CLOSED, and
// the handle was not closed. It was orphaned.
//
// The factory meanwhile ran perfectly: patterns playing, segments written,
// stream up. Two and a half hours of a run with no record of itself, reported
// healthy by every mechanism watching it. That is the same shape as the sleep
// contamination of 28 Aug -- the failure was not the fault, it was that nothing
// noticed.
//
// So the test is now on the FILE and not on the handle: track how many bytes
// have been written and compare against the size on disk. A handle writing into
// a vanished inode leaves the on-disk file short, which is detectable; a healthy
// handle keeps the two within a flush of each other. Checked once per window
// rather than per write, because it is a stat() and the log takes a dozen writes
// a window.
wlog = { |s|
    var dead = logFile.isNil or: { logFile.isOpen.not };
    logBytes = logBytes + s.size;
    // the size check is the one that catches an orphaned descriptor
    if (dead.not and: { (logBytes - logChecked) > 4096 }) {
        var onDisk = if (File.exists(logPath)) { File.fileSize(logPath) } { -1 };
        logChecked = logBytes;
        if (onDisk < (logBytes * 0.5)) {
            dead = true;
            ("LOG ORPHANED at window " ++ winCtr ++ ": wrote " ++ logBytes
                ++ " bytes, file holds " ++ onDisk
                ++ " -- the handle was open and pointing at nothing").postln;
        };
    };
    if (dead) {
        { logFile.close }.try;
        logFile = File(logPath, "a");
        logReopens = logReopens + 1;
        ("LOG REOPENED #" ++ logReopens ++ " at window " ++ winCtr
            ++ " -- the handle had died; writes were being dropped").postln;
        if (logFile.isOpen) {
            logFile.write("# LOG_REOPENED " ++ logReopens ++ " win " ++ winCtr ++ "\n");
            logBytes = File.fileSize(logPath);
            logChecked = logBytes;
        };
    };
    logFile.write(s);
    logFile.flush;
};

mtimes = IdentityDictionary.new;
alphaSeen = IdentityDictionary.new;
runtimeMachines = IdentityDictionary.new;
recent = List.new;
// ---- WHICH OPERATOR SOLVER ------------------------------------------------
//
// compute is O(n^2) dense; computeSparse is O(nnz + n) and returns the SAME
// stationary distribution -- verified against the live memory by
// tools/test_sparse_operator.scd, max difference 0.0, gap agreeing to 2e-5.
//
// Measured 5 Sept, same 6,086 observations spread over a wider alphabet:
//
//       cells    dense     sparse
//         190     0.75 s    0.16 s
//         374     2.90 s    0.19 s
//         726    10.58 s    0.24 s
//
// The sparse cost is FLAT because nnz does not grow when the alphabet widens.
// That is the whole reason this exists: the operator watches only the micro slot
// because a triple alphabet would put n near 726, and at 10.6 s every three
// windows that was impossible. At 0.24 s it is not.
//
// A FLAG, defaulting to the dense path, because the charter's bounds were all
// derived under it. Verified equal is not the same as run for a week.
opCompute = { |o|
    if ((policy !? { policy["operator_sparse"] } ? "0").asString == "1")
    { o.computeSparse } { o.compute };
};

op = TransferOperator.new;   // P222-224, in lib/TransferOperator.sc
// The mutable dir is passed so the bridged ledger PERSISTS across runs. Without
// it the retirement rule is per-run, which is not retirement: the pair carrying
// the most negative residual wins again on every boot, and the 26 Aug pattern of
// 154 bridges across 7 transitions returns one run at a time.
// WHICH LAYERS EXIST AT ALL. 15 Sept 2026, for the M-C isolation run.
//
// This was the literal ["macro", "mid", "micro"] and could not be narrowed from
// policy, which is why isolating one layer looked impossible. Three separate
// places made it impossible together and the first two are the ones that matter:
//
//   1. the fill loop gives "one each first" (`vi < layerNames.size`), so the
//      first three voices are one per layer whatever `voice_fill` says
//   2. the fallback `m ? (slotMach[\micro] ? currentState)` resurrects micro for
//      ANY layer that has no machine, including a resting one, so resting a
//      layer does not silence it
//   3. `voice_fill` only ever governed the SPARE voices
//
// So this is read at BOOT and not hot-reloaded, deliberately. Changing the set
// of layers mid-run would leave voices sounding from a layer that no longer
// exists, and slot state keyed to it, and a window log whose earlier half
// describes a different instrument. That is the unmarked seam again. A layer
// change is a restart and is recorded as one.
//
// Ordinary value is "macro mid micro". "macro" alone is the isolation run.
//
// READ FROM THE FILE, NOT FROM `policy`. The first attempt wrote
// `policy !? { policy["layers_active"] }` here and the isolation silently did
// not happen: `policy` is assigned at line ~524, inside the reload function,
// which has not been called yet at this point in the boot. So the guard fell
// through to the default, the factory came up with all three layers, and
// nothing in the log said the setting had been ignored. Caught in two minutes
// only because VOICES was checked before the run was believed. A policy read
// that silently defaults is the same shape as a panel that shows green because
// its source is gone.
layerNames = ((loadJSON.value(mutableDir ++ "/policy.json")
               !? { |d| d["layers_active"] }) ? "macro mid micro")
    .asString.split($ ).reject({ |s| s.size < 2 });
if (layerNames.isEmpty) { layerNames = ["macro", "mid", "micro"] };
("LAYERS_ACTIVE " ++ layerNames.join(" ")).postln;
slotMach = IdentityDictionary.new;
slotDwell = IdentityDictionary.new;
// when each layer may sound again -- a wall-clock deadline, so a rest is a
// musical duration and not a count of 0.25 s keeper ticks
slotRest = IdentityDictionary.new;
slotSince = IdentityDictionary.new;
// A WRITTEN MACHINE IS ADMITTED TO THE SECTION IT WAS BORN IN. Called on
// ACQUIRED for rung 0/1 machines and from the render callback for rung 2
// ones (24 Sept); the rationale, written 25 Aug at the call site:
// ADMIT IT TO THE SECTION IT WAS BORN IN.
//
// Without this a written machine is selectable in name
// only. A section fixes a family of 4-8 machines out of
// ~35 when it is created, and everything outside that
// family is dropped 85% of the time, so a machine that
// did not exist when the section formed has to wait for
// a NEW section and then win a six-in-thirty-five
// lottery. Worse, 29% of sections are RECALLED from
// memory.json, whose families were fixed in earlier
// performances and can never contain it at all.
//
// memory.json persists and grows, so the archive of old
// families expands with every run and the share of
// sections able to admit anything new keeps shrinking.
// The acquisition mechanism was losing to the memory
// mechanism, and memory wins by accumulating: the longer
// the factory runs, the less able it becomes to adopt
// what it writes for itself. Measured 25 Aug 2026 --
// across six runs, 41 bridges written, 9 ever selected,
// 5 ever sounded, roughly one in eight.
//
// The operator found this hole in the dynamics OF THE
// REGION THE FACTORY IS IN NOW, so the machine belongs
// to that region. This is the narrow fix. The wider one
// -- letting a RECALLED section swap a family member for
// something that did not exist when it formed, so a
// remembered place changes with what the factory has
// become -- is a claim about memory rather than a repair,
// and is deferred deliberately.
admitToSection = { |nm|
    if (section.notNil and: { section[\family].includes(nm).not }) {
        section[\family] = section[\family] ++ [nm];
        wlog.value("FAMILY_ADMIT " ++ winCtr ++ "," ++ nm ++ "," ++ section[\id] ++ "\n");
    };
};

mw = MachineWriter.new(mutableDir,
    (policy !? { policy["machine_min_deviation"] } ? "0.25").asFloat);

// ---- THE GRAMMAR AND THE VERTICAL TABLE, NOW ACTUALLY CONSTRUCTED ---------
//
// MachineWriter.propose already takes `grammar`, `simTable` and `ratio`, and its
// own header describes three arms differing by what is passed in. The call site
// in this file passed four arguments, so every machine ever written took the
// control arm and the other two existed on paper. Constructing them here is the
// whole of the wiring; the arms were built on 2 Sept.
//
// DEPTH 3, NOT MORE. The grammar's own guard rails hold at any depth, but the
// emitted expression grows exponentially and tools/test_grammar.scd was run at
// 3. A deeper tree is a change to make against a measurement, not a default.
gram = PatternGrammar.new(3);
// B8 RUNG 2, 24 Sept 2026: the grammar over the SOURCE. A written machine may
// author its own SynthDef (six sources, bounded stages, Limiter inside).
// Gated by policy synth_slot_weight, read every attempt below, default 0, so
// this boot is the composed writer as before until the key is raised. A rung
// 2 machine goes to mutable/pending/ and is admitted only after
// tools/check_machine.sh has rendered it offline (see the ACQUIRED block).
mw.synthGrammar = SynthGrammar.new;

// Simultaneity's observation half is free and its offer half is gated by
// simultaneity_weight, which defaults to 0.0. At 0 tableFor returns nil, the
// writer takes the control arm, and this build is bit-identical to the measured
// hour -- the same discipline as the DSP layer shipping fully dry.
sim = Simultaneity.new((policy !? { policy["simultaneity_mode"] } ? "corpus").asSymbol);

// ---- THE SECTION OPERATOR: P222-224 AT THE SCALE WHERE IT LANDS ------------
//
// The machine-level operator turns over in ~33 s. Measured on the 6 h run:
// spectral gap median 0.341, so |lambda2| = 0.659 and the mixing time is 2.9
// windows. It is a SECONDS-scale mechanism. Reading it as a source of long-form
// structure was a category error.
//
// Everything the factory has operates below ~2.2 minutes:
//   event 0.013-11 s · voice <=20 s · window ~11 s · operator ~33 s · section ~2.2 min
// and above that, nothing. A six-hour run is 166 sections with no relation
// whatever between section 3 and section 140. Roberto: "we want to think about
// longer structural events, say 5 minutes, 10, 50, 5 hours."
//
// This is the SAME CLASS, observing sections instead of machines. TransferOperator
// takes symbols and knows nothing about what they mean, so nothing is
// reimplemented and no new constant is introduced -- which matters, because five
// inherited constants have already turned out to be wrong here and a stipulated
// "movement" layer would be a sixth.
//
// MEASURED OFFLINE FIRST, on the 6 h log, before building this:
//   observed gap 0.1903   shuffled null median 0.2257 (p5 0.1952)
//   p(null <= observed) = 0.037     mixing time 5.3 sections = 12 min
// So section-to-section structure is real and lives at ~12 minutes, in exactly
// the empty band. Weak -- p=0.037, one run, 165 transitions over 115 states --
// but it beat its own null, which is the difference between building toward
// something and building on hope.
//
// ZERO INFLUENCE. It observes, computes and logs; it steers nothing. E3, the
// audibility score and the machine-level operator all became convergence
// engines, and this is the fourth self-generated criterion of the same kind.
// section_operator_weight exists in policy.json and defaults to 0.0.
secOp = TransferOperator.new;
secOpPrev = nil;
played = List.new;   // machines fired since the last window, for the verdict
live = List.new;   // EventStreamPlayers currently sounding, oldest first

// ---- AUDIBILITY, LEARNED FROM ITS OWN OUTPUT ------------------------
// Six of the sixteen original machines are inaudible and three of those
// still have no known cause. Every policy knob turned this evening ran into
// the same wall: the voice range asks for six and gets two because dead
// machines fill the slots; longer sections make each dead selection cost
// more; the collapse guard fires sooner. Patching around a vocabulary
// problem does not fix the vocabulary.
//
// So the factory finds out for itself. A machine selected at window W is
// judged by the amplitude measured at W+1. Below the floor, its audibility
// decays; above, it recovers. The score multiplies its selection weight.
//
// Two properties worth stating. It needs NO DIAGNOSIS, so it handles st, gp
// and bu without my having cracked them, and it handles machines an agent
// writes later that nobody has vetted. And the criterion is generated from
// the factory's OWN OUTPUT rather than fitted to Roberto's ear, so unlike E3
// it does not cap the factory at what the governor already knows how to want
// (¶109).
// Seeded from the run-40 census, where all 20 machines were rendered in
// isolation and measured. This is data the factory could have gathered itself,
// so seeding it is a shortcut and not a smuggled criterion; every value is
// overwritten by the factory's own verdicts within a few windows. Without it
// the factory has to rediscover six silent machines by starving on them, and
// the collapse guard kills it at 35 s before the learning can pay off.
audib = IdentityDictionary[
    \cr -> 0.95, \gl -> 0.95, \wa -> 0.9,  \ht -> 0.9,  \ry -> 0.9,
    \sc -> 0.9,  \cp -> 0.8,  \ma -> 0.8,  \so -> 0.6,  \lu -> 0.6,
    \dr -> 0.9,  \pu -> 0.9,  \hm -> 0.9,  \me -> 0.9,
    \te -> 0.4,  \an -> 0.4,  \st -> 0.2,  \hp -> 0.1,
    \gp -> 0.1,  \bu -> 0.05 ];
pending = nil;                     // [machine, ...] awaiting their verdict
ampFloor = 0.0004;

// ---- CONCATENATIVE SELECTION ----------------------------------------
// Every machine picks grains with Pshuf(buf, inf): a uniform random draw over
// the WHOLE corpus, so consecutive grains come from unrelated tracks every
// 50-300 ms. Roberto: "the spectral coherence is not sustained." It cannot be:
// the mechanism that would sustain it has never existed. This is granular
// playback with a shuffle, not concatenative synthesis.
//
// The fix does not touch the 22 machines. Instead of changing how each one
// picks, the factory hands them a NEIGHBOURHOOD rather than the whole corpus:
// the k grains nearest a moving target in five-dimensional descriptor space.
// Pshuf over a coherent subset gives coherence, and every machine keeps
// working unchanged.
//
// The target DRIFTS by a small step each window, so timbre moves along a
// trajectory instead of either sitting still or jumping. Step size is policy,
// which means an agent can change how the factory traverses its own corpus
// while it plays.
// TIMBRAL dimensions only. rms was in here and it was a mistake: with level
// as a distance dimension, a tight neighbourhood is a LOUDNESS CLUSTER, so a
// target that drifts into the quiet half draws 64 grains from the quietest
// third of the corpus and the factory goes silent while playing perfectly.
// Measured: neighbourhood 64 gave 0 of 4 windows audible with the target at
// rms 0.28-0.37; the whole corpus gave 3 of 13 with the same code.
// Loudness is not timbre. Level belongs to the envelope, not to the match.
// PITCH IS IN THE SPACE NOW. Archon analyses seven descriptors including
// pitch; every corpus before grains_ev had none, and the path walked
// centroid/flatness/median/zcr only. Selection was pitch-blind, which is why
// nothing the factory assembled was ever harmonic or tonal: the axis along
// which tonality lives was not in the geometry. Corpora without a pitch column
// fall back to the old four keys and behave exactly as before.
// The space the path walks. pc0..pc4 are MFCC statistics, standardised and
// PCA-reduced (tools/analyse_mfcc.py); pitch is carried through because it is
// not recoverable from MFCCs and is the axis harmonic coherence lives on.
//
// The five hand-picked scalars this replaces could not distinguish musical
// continuity from recording identity: consecutive grains of the same music sat
// 0.338 apart and DISTANT grains of the same recording sat 0.337 apart. The
// space knew which file a grain came from and nothing else. In the new space
// those are 0.232 and 0.322 against 0.400 for unrelated tracks -- correctly
// ordered for the first time.
dKeys = ["pc0", "pc1", "pc2", "pc3", "pc4", "pitch"];
target = nil;

// ---- PITCH IS A DIFFERENT KIND OF COORDINATE ------------------------------
//
// THE WALK WAS ISOTROPIC, AND THAT IS WHY THERE WAS NO MELODY TO FIND.
// Measured 3 Sept over 19 runs and 8,948 windows: pitch persistence 0.894
// against sibling dimensions at 0.891, 0.893, 0.897, 0.899, with an identical
// step size of 0.0300. Every dimension got the same line --
//     v = v + rrand(step.neg, step) + ((c - v) * pull)
// -- so pitch was moved by exactly the rule that moves the third principal
// component of a cepstrum. Asking such a walk for melodic continuation is
// asking a random walk to be a tune. There was never a latent tonality being
// missed; there was no melodic dimension in the space at all.
//
// Two independent anisotropies, and both are needed:
//
// 1. IN THE METRIC. Pitch is one of six equally-weighted dimensions, so it
//    contributes a sixth of the distance and the grain actually chosen is
//    decided by timbre. Moving the pitch coordinate therefore had almost no
//    effect on what sounded, which is a second reason nothing melodic emerged.
//    pitch_weight scales that term.
//
// 2. IN THE DYNAMICS. Pitch holds, then moves by an interval, and is pulled
//    toward a tonic that itself drifts on the macro timescale. Timbre keeps
//    drifting continuously every window. That difference in CORRELATION TIME
//    is what a melodic line is: a value that persists long enough to be heard
//    as a note, and moves by steps small enough to be heard as motion.
//
// WHAT IS NOT IMPOSED. No tuning system, no scale, no key. Steps are taken in
// log frequency and then SNAPPED TO THE NEAREST PITCH THE CORPUS ACTUALLY
// CONTAINS, so the available degrees are whatever 2,295 pitched grains across
// 4.6 octaves happen to afford. If a scale emerges it will be the corpus's,
// not 12-TET's, which matters for material largely transferred from 78s.
// The step-size distribution IS a stipulation: mostly small, occasionally a
// leap, because that is what makes motion audible as motion. It is recorded as
// one and has not been measured against a listener.
pitchHz = nil;      // sorted Hz of every pitched grain, the available degrees
pitchN = 0;
tonicHz = nil;      // the centre the walk is pulled toward
tonicAge = 0;
pitchHold = 0;      // windows remaining before pitch is allowed to move again

// ---- C-I: THE WORLD -------------------------------------------------------
// P36 requires a process the factory does not generate and the governor does
// not specify. Until now numInputBusChannels was 0 and the only exogenous thing
// here was a corpus I chose, so the roadmap records C-I as FAILING.
//
// `tools/world_listen.py` opens a live input, runs the SAME mfcc_stats the
// corpus was built with, projects through the SAME stored PCA basis, and
// rescales by the SAME per-component 0..1 bounds -- recovered by least squares
// and checked to 5e-6 against held-out grains. So `world` below is a POSITION IN
// THE CORPUS GEOMETRY, directly comparable to `target` and to every section
// centre. That is what makes the joint chain of Day 2 meaningful rather than an
// arbitrary product of two unrelated spaces.
//
// The analysis is deliberately NOT in SuperCollider. MFCC.kr uses a different
// filterbank and band count, so projecting it through this basis would yield
// five plausible numbers that mean nothing, with no error raised. And keeping
// capture in ffmpeg means SC never opens an input device -- which is what
// renegotiated the headphones to a hands-free profile and put the whole
// transport at 24 kHz for seven consecutive wrong diagnoses.
world = nil;          // [pc0..pc4, rms], 0..1 in corpus coordinates
worldAt = 0;          // Main.elapsedTime of the last packet
worldN = 0;           // packets this run, so a dead channel is visible

// 3. SECTIONS. Everything above was Markovian: each window read the present
// moment and chose. Nothing persisted, so nothing could build, and Roberto
// heard "no underpinning behavioural pattern building up, overlapping, or
// being sustained, just random concatenation".
//
// A section is a slow state lasting minutes: a region of the corpus, a voice
// density, and a family of machines it favours. It changes rarely, and it can
// RETURN to a section already visited — which is what makes recurrence, and
// therefore memory, possible for a listener.
sections = List.new;
occupied = List.new;
// recall before the first section is chosen, so pickSection's RETURN branch can
// reach regions found in earlier performances rather than only this one
loadMemory.value;
section = nil;
sectionAge = 0;
nextSection = 8;

// ---- A SECTION'S CHORD ------------------------------------------------------
// ---- THE SECTION'S CHORD: FROM DYAD TO VERTICAL CONTINUITY ---------
//
// Measured 5 Sept: the vertical mechanism steers reliably -- 85% of
// steered voices land within 30 cents of the ratio the table asked for
// -- but what it produces is a DYAD, and only at the moment a voice is
// born. It related each new voice to `sounding.minItem`, the lowest
// voice currently going, which may expire seconds later and leave the
// interval stranded. Nothing related the third voice to the first two.
// That is why the population statistic was weak (36.0% near a just
// table against 25.6% for a random one) while the direct one was strong.
//
// A section already carries a PERSISTENT ROOT. Entering one sets
// tonicHz from section[\centre][pitchIdx], snapped to the nearest tonic
// centre, and holds it (line ~2172). The root outlives its voices and
// returns when the section is recalled. It was sitting there unused by
// the vertical layer.
//
// So a section now also fixes a SET of ratios above that root. Every
// voice born inside it takes a member, so three voices sounding
// together are members of one chord BY CONSTRUCTION rather than by
// luck, harmonic rhythm becomes section turnover, and a recalled
// section brings its harmony back with it -- which is the performance
// memory thread, not a new mechanism.
//
// SIZE IS DRAWN, NOT FIXED. Roberto, 5 Sept: "can we establish a
// probability chain, where 1 to 3 are the most probable, 4 less and so
// on". So the chord's WIDTH varies between sections and the factory
// gets variety of harmonic DENSITY as well as of content: a size-1
// section puts everything on one pitch class, size 4+ arrives as rare
// colour. Weights are a policy string, so this bound can be proposed
// against like every other.
//
// NOT A CONSONANCE CONTROLLER, which Simultaneity's header refuses.
// Nothing scores a chord and nothing prefers one over another; the set
// is DRAWN from the corpus-derived table. There is no smooth scalar
// here for a selector to climb to a drone.
                // DISTINCT members, and 1.0 is always in: a chord without its
                // own root is a rootless voicing the factory has no way to
                // hear as one, since every voice is placed against the root.
                //
                // ROUNDED BEFORE DEDUPE. asSet alone let 1.0 through twice --
                // measured in the shadow as "CHORD 97,2,1.0|1.0", a two-note
                // chord that is one note. Simultaneity's own table does the
                // same thing for the same reason (quantiles of a real pitch
                // distribution collapse), and a Set keyed on raw Floats does
                // not catch members that differ in the last bits.
                //
                // AND THE OTHERS ARE DRAWN, NOT TAKEN FROM THE BOTTOM. The
                // first version was .sort.keep(k), which always returns the k
                // LOWEST members, so every chord of a given size was the same
                // chord and no spread voicing could ever occur. The root is
                // kept by construction; the rest are a random subset.
//
// CALLED FOR RECALLED SECTIONS TOO, not only new ones. Measured on the live run
// of 5 Sept: 74 section entries, 50 new and 24 recalled. A third of sections
// would otherwise have carried no chord and quietly fallen back to the old
// dyad behaviour, so the mechanism would have been on for two thirds of the
// music and nobody would have seen why. Once a section has a chord it keeps it,
// which is what makes a recalled section bring its harmony back with it.
mkChord = { |s0|
    var ws, tot, r, k, tab, others;
    if (s0.notNil and: { s0[\chord].isNil }) {
        tab = simTable ?? { sim !? { sim.offered } };
        if (tab.isNil or: { tab.size < 2 }) { s0[\chord] = nil } {
            ws = (policy !? { policy["chord_size_weights"] } ? "1 1 1 0.45 0.2 0.09 0.04")
                    .asString.split($ ).collect(_.asFloat).select({ |x| x > 0 });
            if (ws.size < 1) { ws = [1, 1, 1] };
            ws = ws.keep(tab.size.min(ws.size));
            tot = ws.sum;
            r = 1.0.rand * tot; k = 0;
            ws.do { |x, i| if (r >= 0) { k = i; r = r - x } };
            k = (k + 1).clip(1, tab.size);
            // ---- DEDUPE IN CENTS, NEVER BY FLOAT EQUALITY -------------------
            //
            // Two versions shipped a chord containing 1.0 twice --
            // "CHORD 60,3,1.0|1.0|1.246", three notes that are two.
            //
            // THE CAUSE, once the source table was finally logged beside the
            // chord instead of being inferred from it:
            //
            //     CHORD 12,3,1.0|1.114|1.427,from,1.0002|1.1136|1.2456|1.4274
            //
            // The table's root member is 1.0002, NOT 1.0. reject({ |x| x == 1.0 })
            // never matched it, so `others` kept it, and [1.0] ++ others gave two
            // members 0.3 cents apart. Both printed as "1.0" because the CHORD
            // line and the boot line each rounded to three decimals -- two logs
            // rounding away the one digit that mattered, which is why two
            // successive diagnoses (sclang's Float.round; near-duplicates inside
            // the table) were both wrong and both plausible.
            //
            // Comparing in CENTS ends the class of problem and is the right unit
            // anyway: two ratios within five cents are the same interval to any
            // ear, so this is a musical statement and not a numerical patch. The
            // root is excluded by distance from unison rather than by equality,
            // which is what makes 1.0002 register as the root it is.
            others = List.new;
            tab.scramble.do { |x|
                var isRoot = (1200 * log2(x)).abs < 5,
                    tooNear = others.any({ |y| (1200 * log2(x / y)).abs < 5 });
                if (isRoot.not and: { tooNear.not }) { others.add(x) };
            };
            others = others.asArray;
            s0[\chord] = ([1.0] ++ others.keep(k - 1)).sort;
            // THE SOURCE TABLE IS LOGGED WITH THE CHORD, because two attempts
            // to explain a duplicate root from the chord alone were both wrong.
            // The first blamed sclang's Float.round (an isolation test showed
            // 1.0.round(0.0001) == 1.0 is true and the old code produces
            // distinct chords from a clean table); the second blamed
            // near-duplicates inside the table (the boot line showed it was
            // exactly 1.0 1.114 1.246 1.427). Both were inferred from the
            // output instead of read from the input. Whatever `tab` actually
            // was at this call, it is now in the record.
            // THE WINDOW INDEX LEADS, so a chord can be paired with the
            // simultaneities that sounded under it. Without it the public panel
            // can only ask whether intervals land on ratios the chord layer has
            // used at some point, which is a weaker question than whether they
            // land on the chord IN FORCE.
            wlog.value("CHORD " ++ winCtr ++ "," ++ s0[\id] ++ "," ++ s0[\chord].size ++ ","
                ++ s0[\chord].collect({ |x| x.round(0.001) }).join("|")
                ++ ",from," ++ tab.collect({ |x| x.round(0.0001) }).join("|") ++ "\n");
        };
    };
    s0
};

pickSection = { |avail|
    var reuse = (policy["section_return"] ? "0.35").asFloat;
    if (sections.size > 1 and: { 1.0.rand < reuse }) {
        // RETURN. The only mechanism here by which anything recurs.
        //
        // This drew UNIFORMLY from every remembered section, which does not
        // survive a memory that grows. Ten accumulation runs took the archive
        // from 7 sections to 54, so the chance of revisiting any PARTICULAR
        // region fell from 5% to 0.6%: the deeper the memory, the less it
        // recurs. An archive of a thousand regions would effectively have none.
        //
        // The transition table fixes it without crossing into preference. The
        // factory returns to a region that historically FOLLOWED where it is
        // now, weighted by how often. That is still recall -- what came after
        // what -- and not a judgement that any region was good, so it does not
        // reintroduce the feedback loop that narrowed runs 53-58. It also gives
        // the memory sequence rather than leaving it a bag of places.
        var s0, cands, wts, mut, outsiders, fresh, incoming, dropped;
        cands = List.new; wts = List.new;
        if (lastSectionId.notNil) {
            sections.do { |s|
                var n = transitions[lastSectionId.asString ++ ">" ++ s[\id].asString] ? 0;
                if (n > 0) { cands.add(s); wts.add(n) };
            };
        };
        if (cands.size > 0) {
            s0 = cands[wts.asArray.normalizeSum.windex];
            wlog.value("# SECTION return(seq) " ++ lastSectionId ++ " -> " ++ s0[\id]
                ++ " of " ++ cands.size ++ " known successors\n");
        } {
            // nothing has followed this region yet, so fall back to uniform,
            // over the places some surviving path still reaches when memory
            // forgets (27 Sept), else over the whole archive as before
            var live = if ((policy["memory_half_life"] ? "0").asFloat > 0) {
                var ids = Set.new;
                transitions.keys.do { |k| k.split($>).do { |x| ids.add(x) } };
                sections.select({ |s| ids.includes(s[\id].asString) })
            } { [] };
            s0 = if (live.size > 0) { live.choose } { sections[sections.size.rand] };
            wlog.value("# SECTION return(unseen) -> " ++ s0[\id] ++ "\n");
        };

        // A REMEMBERED PLACE CHANGES WITH WHAT THE FACTORY HAS BECOME.
        //
        // Measured 25 Aug 2026: a section fixes a family of 4-8 machines out of
        // ~35 at creation, and everything outside it is dropped 85% of the time.
        // 29% of sections are RECALLED, and a recalled family was fixed in an
        // earlier performance, so it can NEVER contain a machine the factory has
        // written since. memory.json persists and grows -- some forty-five
        // performances -- so the archive of unreachable families expands every
        // run. The acquisition mechanism was losing to the memory mechanism, and
        // memory wins by accumulating: the longer the factory runs, the less able
        // it becomes to adopt anything it makes for itself. 41 bridges written
        // across six runs, 9 ever selected, 5 ever sounded.
        //
        // Admitting a new machine to the section it was BORN in was tried first
        // and is insufficient on its own: within twenty-one windows the factory
        // had already recalled an older region and left the new machine behind.
        //
        // So on recall, one family slot turns over. Both choices are UNIFORM --
        // which member leaves is a coin toss, not a judgement that it was weak.
        // That matters: E3 and the audibility score both died from ranking
        // content by quality, and a rule that dropped the "worst" member would be
        // the same mistake wearing a different hat. The only bias is toward
        // machines the factory wrote itself, which is the population the whole
        // mechanism exists to give a route into selection.
        //
        // PRE-REGISTERED, 25 Aug 2026, before the first run:
        //   Written machines should reach selection at a rate closer to their
        //   share of the vocabulary than the ~1-in-8 measured above. If the
        //   selection rate does NOT move, the section family is not the binding
        //   constraint and the diagnosis is wrong.
        //   Score with convergence2.py as well: if vocabulary or entropy FALLS
        //   as mutation rises, a mechanism built to widen the factory is
        //   narrowing it, which is the third time a self-generated rule has done
        //   that and the more publishable result.
        //
        // LIMIT, stated so it is not overread: "postdates this section" is
        // approximated by the `br` name prefix. A bridge written before a given
        // section formed is treated as new to it anyway. Recording birth windows
        // per machine would be exact; this is not, and it errs toward admitting.
        mut = (policy["section_mutate"] ? "0.0").asFloat;
        if (1.0.rand < mut and: { s0[\family].size > 1 }) {
            outsiders = avail.reject({ |m| s0[\family].includes(m) });
            fresh = outsiders.select({ |m| m.asString.beginsWith("br") });
            incoming = if (fresh.size > 0) { fresh.choose } {
                if (outsiders.size > 0) { outsiders.choose } { nil } };
            if (incoming.notNil) {
                dropped = s0[\family].choose;
                s0[\family] = s0[\family].reject({ |m| m == dropped }) ++ [incoming];
                wlog.value("SECTION_MUTATE " ++ s0[\id] ++ "," ++ dropped
                    ++ "," ++ incoming ++ "\n");
            };
        };
        mkChord.value(s0);
        s0
    } {
        // ---- NOVELTY PRESSURE ON A NEW SECTION'S CENTRE ---------------------
        //
        // WHAT IS BEING FIXED, measured 6 Sept 2026 and recorded in
        // .lab/measurements/2026-09-06_recurrence_result.md. Against a loop and
        // 140 unrelated artists as calibration arms, the factory's position on
        // the diverse-to-loop axis is 0.10 at a one-minute match window, 0.21 at
        // five minutes, 0.33 at fifteen, and 0.74 at half an hour. It varies
        // locally and repeats globally. Roberto, after an hour of listening on
        // 5 Sept: "I can identify most behaviours, it does not surprise me
        // anymore."
        //
        // WHY HERE AND NOT IN THE PER-WINDOW WALK. The drift step already
        // produces one-minute variety at position 0.10; there is nothing to win
        // there and a repulsion applied every window would fight section_pull
        // and dissolve the section as a unit. The half-hour scale IS the section
        // scale: measured on the 7.9 h run of 4 Sept, 229 sections in 28,572 s,
        // one section every 125 s, so half an hour is about fourteen of them.
        //
        // WHY THE CENTRE WAS THE CULPRIT. It was `rrand(0.15, 0.85)` per
        // dimension, drawn independently every time: a uniform point in a
        // six-dimensional box with NO knowledge of where this run has already
        // been. 68% of sections are drawn this way (155 of 229 on 4 Sept; the
        // other 32% are deliberate recalls). Uniform draws in a bounded box land
        // near each other often, and nothing here noticed.
        //
        // WHAT THIS DOES. Draw `novelty_pressure` candidate centres instead of
        // one and keep whichever is furthest from the last `novelty_horizon`
        // places this run has occupied. Best-of-K, not a new law of motion: the
        // draw is the same draw and its support is unchanged, so every
        // calibration that rests on the centre distribution still holds, and at
        // K=1 this is bit-for-bit the old behaviour.
        //
        // WHAT IT DELIBERATELY LEAVES ALONE. Recall. 35% of sections are chosen
        // by the transition table to return to a remembered region, and that is
        // the mechanism by which the factory has a memory a listener can hear.
        // Pushing new sections away from recent ones does not weaken it; it
        // stops the OTHER two thirds landing on top of it by accident.
        //
        // THE DISTANCE IS THE ONE ALREADY HERE. The novelty_threshold proposal
        // block below computes nearest-neighbour centre distance against the
        // archive and has done since 26 Aug -- it just logs it. This is the same
        // quantity, scoped to the run instead of to all history, and acted on.
        // NOT `novelty_penalty`, AND NOT `novelty_threshold`. Three different
        // things would otherwise share a prefix in one policy file:
        //   novelty_penalty   damps a MACHINE used in the last history_len
        //                     windows, at the selection site near line 2500
        //   novelty_threshold flags a section centre far from the ARCHIVE and
        //                     writes a charter proposal, changing nothing
        //   section_spread_*  this, which changes where a new section GOES
        // Named apart because the first thing anyone will do with a policy key
        // called novelty_pressure is confuse it with the one called
        // novelty_penalty, and the second thing will be to explain a result with
        // the wrong mechanism.
        var s0, kDraws, horizon, recent, bestC, bestD = -1, firstD = -1;
        kDraws  = (policy["section_spread_k"] ? "1").asInteger.max(1);
        horizon = (policy["section_spread_horizon"] ? "16").asInteger.max(1);
        recent  = occupied.asArray;
        if (recent.size > horizon) { recent = recent.keep(horizon.neg) };
        kDraws.do { |t|
            var c = Array.fill(dKeys.size, { rrand(0.15, 0.85) }), d = inf;
            // distance to the NEAREST recent place, which is the quantity to
            // push up. Mean distance would be maximised by sitting in the middle
            // of the box, which is where everything already is.
            recent.do { |p|
                var acc = 0;
                if (p.size == c.size) {
                    p.do { |v, j| acc = acc + (v - c[j]).squared };
                    d = min(d, acc.sqrt);
                };
            };
            // no comparable neighbour yet -- the first section of a run, or a
            // stored centre of a different width. Score it 0 so every candidate
            // ties and the first draw wins, which is the old behaviour exactly.
            // Testing `d == inf` and not `recent.size == 0` because a width
            // mismatch leaves d at inf with a non-empty list, and `inf` would
            // then be written into the log and compared as if it were a distance.
            if (d == inf) { d = 0 };
            if (t == 0) { firstD = d };
            if (d > bestD) { bestD = d; bestC = c };
        };
        s0 = IdentityDictionary[
            \id -> sections.size,
            \centre -> bestC,
            \voices -> rrand((policy["voices_min"] ? "1").asInteger,
                             (policy["voices_max"] ? "4").asInteger),
            \family -> avail.scramble.keep(rrand(4, 8)) ];
        // LOG THE FIRST DRAW BESIDE THE CHOSEN ONE. Without the discarded
        // candidate there is no way to tell a pressure that is working from a
        // pressure that is inert: at K=1 the two figures are equal by
        // construction, and if they stay equal at K=8 the selection is not
        // selecting. This is the arm the evaluation reads, and it is the check
        // that PatternGrammar went without for two weeks while it was unwired.
        if (kDraws > 1) {
            wlog.value("SPREAD " ++ winCtr ++ "," ++ s0[\id] ++ "," ++ kDraws
                ++ "," ++ recent.size ++ "," ++ firstD.round(0.0001)
                ++ "," ++ bestD.round(0.0001) ++ "\n");
        };

        mkChord.value(s0);

        // ---- P290 VERSION DESIGN: RECOGNISE A GENUINELY NEW CONFIGURATION ----
        //
        // "a descriptive medium, read off the factory's wake, in which genuinely
        // new configurations can be recognized and held as versions, anchored
        // into a singular unit by the architect's commitment against further
        // alteration."
        //
        // The first attempt at this fitted a hidden-state model to the wake and
        // failed cleanly: held-out log-likelihood per symbol was -3.0437 for an
        // HMM against -3.0087 for a unigram, so the latent state was WORSE than
        // no latent state. There is little sequential regime structure here to
        // cluster. But P290 does not ask for regimes -- it asks for NOVELTY, and
        // for the holding to be "the architect's commitment", an authored act
        // rather than a discovered cluster.
        //
        // So: novelty is distance from every configuration the factory has ever
        // occupied. A section IS a configuration -- a centre in descriptor
        // space, a family, a voice count -- so this costs one pass over the
        // section archive, not per-event work. Calibrated on the 6 h wake of
        // 26 Aug: 118 sections, nearest-neighbour centre distances p5 0.160,
        // p50 0.266, p95 0.353, max 0.397. A threshold of 0.34 flags roughly one
        // section in ten, about 11 per six-hour run.
        //
        // What is proposed is NOT adopted. P536 cedes the metrics layer to the
        // factory's contributory arm; adoption is a governance act that bumps
        // the charter edition, and P518 makes that a new version of the factory.
        // The factory proposes; the architect commits.
        block { |brk|
            var thr = (policy["novelty_threshold"] ? "0.34").asFloat, d = inf, f;
            if (thr <= 0 or: { sections.size < 5 }) { brk.value };
            sections.do { |s|
                var c = s[\centre], acc = 0;
                if (c.notNil and: { c.size == s0[\centre].size }) {
                    c.do { |v, j| acc = acc + (v - s0[\centre][j]).squared };
                    d = min(d, acc.sqrt);
                };
            };
            if (d <= thr) { brk.value };
            wlog.value("NOVEL " ++ s0[\id] ++ "," ++ d.round(0.0001) ++ ","
                ++ s0[\centre].collect({ |v| v.round(0.001) }).join("|") ++ ","
                ++ s0[\voices] ++ "," ++ s0[\family].join("|") ++ "\n");
            // append one JSON object per line: a proposal file that survives a
            // crash mid-write, unlike a single re-serialised array
            f = File(mutableDir ++ "/charter_proposals.jsonl", "a");
            if (f.isOpen) {
                f.write("{\"proposed_at\":" ++ winCtr
                    ++ ",\"section\":" ++ s0[\id]
                    ++ ",\"novelty\":" ++ d.round(0.0001)
                    ++ ",\"threshold\":" ++ thr
                    ++ ",\"norm\":\"n2_varied\""
                    ++ ",\"kind\":\"coverage_holdout\""
                    ++ ",\"centre\":[" ++ s0[\centre].collect({ |v| v.round(0.001) }).join(",") ++ "]"
                    ++ ",\"voices\":" ++ s0[\voices]
                    ++ ",\"family\":[\"" ++ s0[\family].join("\",\"") ++ "\"]"
                    ++ ",\"rationale\":\"reached a region of descriptor space "
                    ++ d.round(0.001) ++ " from anything previously occupied; "
                    ++ "proposes that future versions still reach it\"}\n");
                f.close;
            };
        };

        // VOICE DENSITY, proposed on the same novelty rule.
        //
        // m6_texture asks whether the median concurrent voice count sits in
        // [2,5] while policy.json pins voices to [voices_min, voices_max]. The
        // bound sits outside the clamp, so the metric CANNOT depart: it restates
        // a setting and passed ten runs of ten by arithmetic. P518 wants
        // "acceptable probability states", and a quantity with no probability of
        // departing is not one.
        //
        // The repair is to widen the clamp so the factory chooses, and let the
        // charter bound record what it has DEMONSTRATED while the other norms
        // held. Roberto, 1 Sept: "we can provide a starting point but let the
        // factory propose (and update) the metric."
        //
        // It proposes the OUTLIER, never its average. A factory proposing
        // "acceptable density = what I currently do" would ratify itself, which
        // is a mirror and not a criterion, and is how a self-generated criterion
        // became a convergence engine three times here. So: a density this
        // factory has not used before, reached while it was actually sounding.
        // Silence is excluded because a silent section can carry any voice count
        // and would propose densities the factory never really played.
        block { |brk|
            var v = s0[\voices], seen = false, f;
            if (v.isNil or: { sections.size < 5 }) { brk.value };
            // SILENCE GUARD. The section record carries id, centre, voices and
            // family and NO amplitude, so the first version of this line tested
            // s0[\amp], which is always nil -- the guard could never fire and
            // silence would have proposed densities the factory never played.
            // masterPeak is what m1_not_silent thresholds, at the same 0.004,
            // so the two agree on what counts as sounding.
            if (masterPeak < 0.004) { brk.value };
            sections.do { |s| if (s[\voices] == v) { seen = true } };
            if (seen) { brk.value };
            wlog.value("VOICE_NOVEL " ++ s0[\id] ++ "," ++ v ++ "\n");
            f = File(mutableDir ++ "/charter_proposals.jsonl", "a");
            if (f.isOpen) {
                f.write("{\"proposed_at\":" ++ winCtr
                    ++ ",\"section\":" ++ s0[\id]
                    ++ ",\"norm\":\"n3_coherent\""
                    ++ ",\"kind\":\"voice_range\""
                    ++ ",\"voices\":" ++ v
                    ++ ",\"policy_min\":" ++ (policy["voices_min"] ? "2")
                    ++ ",\"policy_max\":" ++ (policy["voices_max"] ? "4")
                    ++ ",\"rationale\":\"sounded at a median of " ++ v
                    ++ " concurrent voices, a density not used in any previous "
                    ++ "section of this run; proposes that future versions still "
                    ++ "be permitted it\"}\n");
                f.close;
            };
        };

        sections.add(s0);
        wlog.value("# SECTION new " ++ s0[\id] ++ " voices " ++ s0[\voices]
            ++ " family " ++ s0[\family] ++ "\n");
        s0
    }
};

// 1. THE PATH. Not the k nearest to a point — a WALK. Start at the grain
// nearest the target, then repeatedly step to the nearest grain not yet used.
// Handed to machines in order (and the live copy uses Pseq, not Pshuf), so
// consecutive grains are adjacent in descriptor space and continuity exists at
// the 50 ms scale rather than only at the window scale.
grainPath = { |k|
    var pool, path, cur, dist2, pw = pitchW.value;
    // Weighted the same way as `nearest`, and it has to be: the target selects
    // the seed and this walk selects everything after it, so an unweighted walk
    // here would drift off the requested pitch within a few grains and the
    // melodic dimension would survive exactly one grain per window.
    dist2 = { |i, j|
        var acc = 0, a = dvec[i], bb = dvec[j];
        dKeys.size.do { |x|
            var d2 = (a[x] - bb[x]).squared;
            acc = acc + (if (x == pitchIdx) { d2 * pw } { d2 });
        };
        acc
    };
    // HARD CAP. The walk is O(k * pool), and with neighbourhood at 600 that was
    // ~360,000 distance calls per window on the language thread. A path longer
    // than a hundred grains is 50 s of audio anyway, far more than one voice
    // consumes in its span.
    // path_max was hard-coded at 64, which silently OVERRODE policy's
    // neighbourhood: 600. So every live voice cycled the same 64 grains, in
    // fixed nearest-neighbour order, overlapping about 17 deep. Correlated
    // grains repeating on a cycle comb-filter; the offline renders shuffle 600
    // uncorrelated grains and do not. Now a policy value, so it can be moved
    // while the factory plays.
    k = k.min((policy["path_max"] ? "64").asInteger);
    pool = nearest.value((k * 3).min(dn));
    path = List.new;
    cur = pool[0];
    path.add(cur);
    pool = pool.copy.reject({ |x| x == cur });
    (k - 1).do {
        var best = nil, bd = 1e9, nxt;
        // CONTINUE, if the corpus knows what came next.
        //
        // Until the sequential corpus, no grain knew which track it came from
        // or where in it, so the factory could not play two consecutive moments
        // of the same music -- not as a policy, but because the information did
        // not exist. Every event cut to a different piece in a different key at
        // a different tempo, five to ten times a second. Roberto: "rapid
        // concatenative transitions, like a broken radio shifting among FM
        // frequencies... nothing harmonic or tonal."
        //
        // succ[i] is the next slice of the SAME track. Following it keeps line,
        // harmony and tempo intact. This is the difference between concatenative
        // synthesis and shuffling, and `continuity` is where the factory decides
        // between continuing a phrase and cutting away from it.
        // deliberately NOT restricted to the nearest-neighbour pool: continuing
        // a phrase is exactly the case where the next grain should be allowed to
        // be timbrally distant, because it is the same music continuing.
        nxt = succ !? { succ[cur] };
        if (nxt.notNil
            and: { 1.0.rand < (policy["micro_continuity"] ? policy["continuity"] ? "0.5").asFloat }
            and: { path.includes(nxt).not }) {
            best = nxt;
        } {
            pool.do { |cand|
                var d = dist2.value(cand, cur);
                if (d < bd) { bd = d; best = cand };
            };
        };
        if (best.notNil) {
            path.add(best); cur = best;
            pool = pool.reject({ |x| x == best });
        };
    };
    path.asArray
};

// ANISOTROPY IN THE METRIC, not only in the walk.
//
// Pitch was one of six equally-weighted dimensions, so it carried a sixth of
// the distance and the grain actually handed to a machine was decided by
// timbre. Moving the pitch coordinate therefore had almost no effect on what
// sounded -- which is the second reason nothing melodic ever emerged, and the
// one that would have defeated the new walk on its own. A melodic dimension
// that does not select the grain is a number in a log file.
//
// pitch_weight multiplies the SQUARED term, so 4.0 is a doubling of pitch
// distance in the same units as the others. It is a stipulation and it trades:
// too high and the factory hands over grains that match in pitch and clash in
// timbre, which is a different kind of incoherence. Default 4.0 puts pitch at
// roughly two fifths of the total instead of one sixth.
pitchW = { (policy !? { policy["pitch_weight"] } ? "4.0").asFloat };

nearestAround = { |vecs, nv, centre, k|
    var pw = pitchW.value,
        dist = Array.fill(nv, { |i|
            var acc = 0, v = vecs[i];
            centre.size.do { |j|
                var d2 = (v[j] - centre[j]).squared;
                acc = acc + (if (j == pitchIdx) { d2 * pw } { d2 });
            };
            acc
        });
    dist.order.keep(k.min(nv))
};

nearest = { |k|
    var pw = pitchW.value,
        dist = Array.fill(dn, { |i|
        var acc = 0, v = dvec[i];
        dKeys.size.do { |j|
            var d2 = (v[j] - target[j]).squared;
            acc = acc + (if (j == pitchIdx) { d2 * pw } { d2 });
        };
        acc
    });
    dist.order.keep(k).collect({ |i| desc["index"][i].asInteger })
};

server.waitForBoot({

    SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                          res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
        // doneAction was 2 on BOTH the PlayBuf and the envelope, so whichever
        // finished first freed the synth. With rate > 1 the buffer runs out
        // while the envelope is still open, and the output stops dead at
        // whatever amplitude it had reached: a click on every grain. Only the
        // envelope may free the synth now, because only the envelope is
        // guaranteed to be at zero when it ends.
        // APPLIED 30 Aug. The comment above described this fix and the code
        // never carried it: PlayBuf still held doneAction:2, so it could still
        // free the synth first and cut the output dead mid-envelope. Roberto
        // heard it for hours as "super short clipping sounds" while eight
        // measurements came back clean -- a click lasting one sample does not
        // register against a 10 ms local envelope, which is what those tests
        // compared against.
        // ATTACK FLOOR. A fast amplitude ramp multiplied into broadband
        // material produces sidebands, and at 4 ms those land squarely in the
        // band a listener hears as a click. Measured 31 Aug, time-locked to
        // known onsets, high-frequency energy AT the onset over the 12 ms
        // before it, same grains and same code throughout:
        //     atk   4 ms  ->  714     (p90 13980)
        //     atk  15 ms  ->  297
        //     atk  30 ms  ->  142
        //     atk  60 ms  ->   86
        //     atk 120 ms  ->   35
        //     atk 200 ms  ->   27
        // Monotonic across a 27x spread. Two machines of 82 sat below this
        // floor -- grind at 0.004 and sift at 0.02 -- and between them account
        // for 291 appearances in the window logs.
        //
        // The floor lives HERE and not in those two files so that a machine
        // written later cannot reintroduce the fault by asking for a 4 ms
        // onset. It is the same argument as putting the attenuation in
        // write_grain instead of trusting each builder to clip correctly.
        //
        // 0.03 is a TRADE, not a discovered knee: the curve decays smoothly
        // with no elbow to find. It buys a 5x reduction in splatter while
        // staying percussive enough that grind still bites. Raising it further
        // keeps helping and keeps costing attack definition.
        // THE ENVELOPE AND THE BUFFER HAD NO RELATIONSHIP, AND THE SYNTH SPENT
        // MOST OF ITS LIFE OUTPUTTING SILENCE.
        //
        // The synth lives for atk + rel, because only the envelope frees it.
        // PlayBuf has doneAction:0 and no loop, so when the buffer runs out it
        // goes quiet and the synth sits there until the envelope ends. A macro
        // machine gets atk = dur*0.15 and rel = dur*0.7, so an event interval of
        // 6 s is a 5.1 s envelope. Against a 2 s buffer that is two seconds of
        // one recording played straight through at rate 1.0, then three seconds
        // of nothing. Against `bu` at 11.4 s it is two seconds and then eight.
        //
        // Invisible for two weeks because MACRO was empty and every buffer was
        // 60 ms -- shorter than any envelope, so the fault expressed as short
        // bursts rather than as quotation. Measured on three minutes of the
        // delivered stream, 3 Sept: median sounding run 0.06 s, median gap
        // 0.06 s, 74% of frames below a tenth of peak. Both of that day's
        // complaints -- "vertical lines with gaps in between" and "several
        // seconds of the original audio" -- are this one line seen at two
        // different buffer lengths.
        //
        // LOOP ONLY WHEN THE ENVELOPE OUTLIVES THE MATERIAL BY HALF AGAIN.
        // 1.5x and not 1.0x so the micro layer is provably untouched: a 60 ms
        // grain under a 65 ms envelope stays the one-shot it has always been,
        // and micro_continuity 0.9 keeps doing the fusing it was raised to do.
        //
        // And when it does loop, the rate drifts on a slow noise, so a held
        // grain is not the same fragment played four times. This is deliberately
        // small -- it blurs a repeat, it does not disguise a recording. Grain
        // length is what stops material being quotable, and that is being fixed
        // in the corpus rather than papered over here.
        var life = atk.max(0.03) + rel,
            bdur = BufDur.ir(buf) / rate.abs.max(0.01),
            lp   = (life > (bdur * 1.5)),
            rt   = BufRateScale.ir(buf) * rate
                     * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
            // A NEGATIVE RATE STARTS AT THE END. sciarrinoPlayer and others
            // send -1.0 for reversed grains; from startPos 0 a reversed
            // PlayBuf reads into nothing and the event is silent unless the
            // grain happens to loop. 22 Sept: startPos follows the sign.
            sig  = PlayBuf.ar(1, buf, rt, loop: lp,
                              startPos: (rt < 0) * (BufFrames.ir(buf) - 1),
                              doneAction:0),
            env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction:2);
        // rq WAS DECLARED 4.0 AND NEVER PASSED, so every voice in the factory ran
        // through a band-pass four times narrower than the one this SynthDef says
        // it wants. BPF's rq is bandwidth over centre frequency and SuperCollider
        // defaults it to 1.0, about one octave; the declared 4.0 is roughly four
        // times wider.
        //
        // WHAT THAT COST. Every voice on every layer ends here, and the machines
        // set \cutoff from their own grain's spectral centroid, so whatever went
        // in came out as a narrow band around one frequency. The corpus was never
        // the limit: measured 12 Sept, the self-ingested pool is WIDER than the
        // archive at every layer (+27% ev, +37% mid, +61% macro). The variety was
        // there and was discarded at the last stage. Roberto, hearing it: "there
        // is not too much structural or spectral variety".
        //
        // Same family as self_ingest_weight unread, PatternGrammar unwired,
        // rest_macro unaskable and judges.py --cells absent: a parameter that
        // exists, carries an intended value, and is never reached.
        //
        // AND 4.0 IS TOO WIDE, WHICH IS AUDIBLE AS NOISE. Roberto, minutes after
        // it went live: "all of a sudden it goes into pure noise."
        //
        // rq is bandwidth DIVIDED BY centre frequency, so it scales with cutoff.
        // The machines set \cutoff from each grain's spectral centroid, so a
        // voice centred at 3 kHz gets a 12 kHz bandwidth at rq 4.0 -- wider than
        // the whole band this material occupies. The filter stops filtering and
        // the raw granular material comes through unshaped.
        //
        // So 1.0 was too narrow, one colour; 4.0 is transparent for any bright
        // voice. The value is bounded here rather than left at the declared
        // default, and the ceiling is the point: whatever a machine asks for, a
        // voice cannot open the filter past the edge of usefulness.
        //
        // 2.5 IS A STIPULATION AND THE THIRD VALUE TRIED. Measured on the delivered
        // stream, percent of energy by band and spectral flatness:
        //
        //   rq unpassed (1.0)   34.5 / 15.3 / 23.3 / 26.9   flatness 0.043
        //   rq 4.0              10.8 / 14.2 / 26.1 / 48.8   flatness 0.140   NOISE
        //   rq clipped to 1.5   30.0 / 21.5 / 22.6 / 25.9   flatness 0.042   = old
        //
        // 1.5 is close enough to 1.0 to change nothing; 4.0 is about two octaves
        // of bandwidth, which for already-broadband granular material is barely
        // filtering, and Roberto heard that as pure noise. The usable range is
        // between, and it is narrow. The honest test is an hour of
        // it. Tune by editing this number; it needs a restart because SynthDef
        // argument defaults are fixed when the def is built.
        // THE BANDWIDTH, NOT ONLY THE RATIO. 16 Sept 2026.
        //
        // rq is bandwidth DIVIDED BY centre frequency, so rq.clip(0.5, 2.5)
        // bounds the RATIO and bounds the bandwidth not at all. At 44100 Hz,
        // Nyquist is 22050, and cutoff * 2.5 passes it whenever
        //
        //     cutoff > 8820 Hz
        //
        // above which BPF's coefficients leave the stable region and the filter
        // diverges. Measured, test_bpf_bandwidth.scd, same grain throughout:
        //
        //     cutoff 8800  (bw 22000)   peak 0.0568
        //     cutoff 8900  (bw 22250)   peak 6.29e12
        //     cutoff 9680  (bw 24200)   peak 1.35e18
        //     cutoff 18000 (bw 45000)   peak 9.78e28
        //
        // The boundary is Nyquist exactly. THIS IS THE BLOW-UP: the voice probe
        // caught a live voice at cutoff 9680 with amp 0.08 emitting 3.9e17, and
        // brstgp5 asks for `centre * 1.7` on a Pseg with no ceiling.
        //
        // It took six wrong explanations to get here -- grains, reverb, NaN,
        // polyphony, amp, the DSP stage -- and a seventh near miss: an earlier
        // sweep tested cutoff at rq 0.5 and cleared BPF, because 0.5 is the
        // NARROWEST setting and I had the hazard backwards. Wide rq at high
        // cutoff is the dangerous corner, and that sweep never visited it.
        //
        // 20000 rather than 22050 leaves a margin, because the coefficients are
        // already ill-conditioned approaching Nyquist and not only beyond it.
        // Below 8000 Hz this changes nothing: arms agreed to four decimals.
        sig = BPF.ar(sig, cutoff.clip(20, 18000),
                     rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        // ---- THE THREE STAGES, PER MACHINE (B8 rung 1, 22 Sept 2026) --------
        // The same res/dly/blur as \playgran, same coefficients, same bounds,
        // all defaulting to dry, so every machine written before today is
        // byte-for-byte what it was. A written machine may now set its own
        // depths (PatternGrammar.dsp), bounded there at res 0.5, dly 0.5,
        // blur 0.8, feedback 0.75. Mixed against dry: no setting is silent.
        // DRY BY CONSTRUCTION (26 Sept 2026). The res/dly/blur stages live in
        // \playbackFX; a dry voice allocates no delay line. On 25 Sept one
        // written machine (micro events at 20 a second with a 3-9 s release)
        // exhausted the 512 MB real-time pool through this def's CombL,
        // 128 KB per voice, dry or not, and the factory stalled for twelve
        // hours. The writer emits the FX def only when a machine draws stages.
        sig = Pan2.ar(sig, pan, amp);
        sig = sig * env;
        // VOICE PROBE (#106), 16 Sept. FOUR explanations of the blow-up have now
        // been refuted, each by evidence that was cheap to gather and that I
        // proposed a mechanism without gathering first:
        //   corrupt grains   -- all 48,162 grains in every pool cap at 0.9990
        //   reverb feedback  -- all four reverb buses are literally [0]
        //   polyphony        -- BLOWUP windows average 1.11 macro voices against
        //                       2.01 elsewhere; one blew up at macro=0
        //   BPF gain         -- swept 0 Hz to 8 kHz at rq 0.5, peak gain 0.61x,
        //                       never above unity even at cutoff 0
        // and amp, and the DSP stage, are both bounded by their callers.
        //
        // So a SINGLE voice reaches past 8.0 while every parameter feeding it is
        // in range. This stops the guessing: the voice reports its own peak and
        // the exact parameters it was given, and the sclang side stamps the
        // machine that asked. Threshold 1.0 -- one voice alone should never
        // approach full scale, since amp is bounded at 0.70 across every machine.
        SendReply.kr(
            Impulse.kr(8) * (A2K.kr(Peak.ar(Mix.ar(sig.abs), Impulse.ar(8))) > 1.0),
            '/voiceblow',
            [A2K.kr(Peak.ar(Mix.ar(sig.abs), Impulse.ar(8))),
             cutoff, rate, amp, rq, buf, rel]);
        // WHAT THE FACTORY ASKED FOR, AS OPPOSED TO WHAT IT GOT (#109).
        //
        // The Nyquist clip above makes an out-of-envelope cutoff harmless. It
        // also makes it INVISIBLE, and a silently trimmed request is how the
        // blow-up survived for weeks: the value that broke the filter was never
        // written down anywhere, so every attempt to find its source was a
        // search through source code for something that might not be in it.
        //
        // A whole day was spent reading machine definitions to find what could
        // request 9680 Hz. Nothing found could. brstgp5 tops out at 4080, fma1
        // at 2623, the factory's own macro line at 484, the Handler paths at
        // 3360 and 1120. The request is real -- the probe measured it -- and it
        // is not in the source I can read.
        //
        // So this reports the request itself, whenever it leaves the envelope
        // \playback is designed for, whether or not anything audible goes wrong.
        // 8000 and not 8820: report BEFORE the hazard, so the margin is visible
        // rather than only the breach. The sclang side stamps the machine.
        SendReply.kr(Impulse.kr(2) * ((cutoff > 8000) + (cutoff < 20)).clip(0, 1),
            '/cutoffclamp', [cutoff, rq, rate, buf]);
        Out.ar(out, sig);
    }).add;

    SynthDef(\playbackFX, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                          res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
        // doneAction was 2 on BOTH the PlayBuf and the envelope, so whichever
        // finished first freed the synth. With rate > 1 the buffer runs out
        // while the envelope is still open, and the output stops dead at
        // whatever amplitude it had reached: a click on every grain. Only the
        // envelope may free the synth now, because only the envelope is
        // guaranteed to be at zero when it ends.
        // APPLIED 30 Aug. The comment above described this fix and the code
        // never carried it: PlayBuf still held doneAction:2, so it could still
        // free the synth first and cut the output dead mid-envelope. Roberto
        // heard it for hours as "super short clipping sounds" while eight
        // measurements came back clean -- a click lasting one sample does not
        // register against a 10 ms local envelope, which is what those tests
        // compared against.
        // ATTACK FLOOR. A fast amplitude ramp multiplied into broadband
        // material produces sidebands, and at 4 ms those land squarely in the
        // band a listener hears as a click. Measured 31 Aug, time-locked to
        // known onsets, high-frequency energy AT the onset over the 12 ms
        // before it, same grains and same code throughout:
        //     atk   4 ms  ->  714     (p90 13980)
        //     atk  15 ms  ->  297
        //     atk  30 ms  ->  142
        //     atk  60 ms  ->   86
        //     atk 120 ms  ->   35
        //     atk 200 ms  ->   27
        // Monotonic across a 27x spread. Two machines of 82 sat below this
        // floor -- grind at 0.004 and sift at 0.02 -- and between them account
        // for 291 appearances in the window logs.
        //
        // The floor lives HERE and not in those two files so that a machine
        // written later cannot reintroduce the fault by asking for a 4 ms
        // onset. It is the same argument as putting the attenuation in
        // write_grain instead of trusting each builder to clip correctly.
        //
        // 0.03 is a TRADE, not a discovered knee: the curve decays smoothly
        // with no elbow to find. It buys a 5x reduction in splatter while
        // staying percussive enough that grind still bites. Raising it further
        // keeps helping and keeps costing attack definition.
        // THE ENVELOPE AND THE BUFFER HAD NO RELATIONSHIP, AND THE SYNTH SPENT
        // MOST OF ITS LIFE OUTPUTTING SILENCE.
        //
        // The synth lives for atk + rel, because only the envelope frees it.
        // PlayBuf has doneAction:0 and no loop, so when the buffer runs out it
        // goes quiet and the synth sits there until the envelope ends. A macro
        // machine gets atk = dur*0.15 and rel = dur*0.7, so an event interval of
        // 6 s is a 5.1 s envelope. Against a 2 s buffer that is two seconds of
        // one recording played straight through at rate 1.0, then three seconds
        // of nothing. Against `bu` at 11.4 s it is two seconds and then eight.
        //
        // Invisible for two weeks because MACRO was empty and every buffer was
        // 60 ms -- shorter than any envelope, so the fault expressed as short
        // bursts rather than as quotation. Measured on three minutes of the
        // delivered stream, 3 Sept: median sounding run 0.06 s, median gap
        // 0.06 s, 74% of frames below a tenth of peak. Both of that day's
        // complaints -- "vertical lines with gaps in between" and "several
        // seconds of the original audio" -- are this one line seen at two
        // different buffer lengths.
        //
        // LOOP ONLY WHEN THE ENVELOPE OUTLIVES THE MATERIAL BY HALF AGAIN.
        // 1.5x and not 1.0x so the micro layer is provably untouched: a 60 ms
        // grain under a 65 ms envelope stays the one-shot it has always been,
        // and micro_continuity 0.9 keeps doing the fusing it was raised to do.
        //
        // And when it does loop, the rate drifts on a slow noise, so a held
        // grain is not the same fragment played four times. This is deliberately
        // small -- it blurs a repeat, it does not disguise a recording. Grain
        // length is what stops material being quotable, and that is being fixed
        // in the corpus rather than papered over here.
        var life = atk.max(0.03) + rel,
            bdur = BufDur.ir(buf) / rate.abs.max(0.01),
            lp   = (life > (bdur * 1.5)),
            rt   = BufRateScale.ir(buf) * rate
                     * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
            // A NEGATIVE RATE STARTS AT THE END. sciarrinoPlayer and others
            // send -1.0 for reversed grains; from startPos 0 a reversed
            // PlayBuf reads into nothing and the event is silent unless the
            // grain happens to loop. 22 Sept: startPos follows the sign.
            sig  = PlayBuf.ar(1, buf, rt, loop: lp,
                              startPos: (rt < 0) * (BufFrames.ir(buf) - 1),
                              doneAction:0),
            env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction:2);
        // rq WAS DECLARED 4.0 AND NEVER PASSED, so every voice in the factory ran
        // through a band-pass four times narrower than the one this SynthDef says
        // it wants. BPF's rq is bandwidth over centre frequency and SuperCollider
        // defaults it to 1.0, about one octave; the declared 4.0 is roughly four
        // times wider.
        //
        // WHAT THAT COST. Every voice on every layer ends here, and the machines
        // set \cutoff from their own grain's spectral centroid, so whatever went
        // in came out as a narrow band around one frequency. The corpus was never
        // the limit: measured 12 Sept, the self-ingested pool is WIDER than the
        // archive at every layer (+27% ev, +37% mid, +61% macro). The variety was
        // there and was discarded at the last stage. Roberto, hearing it: "there
        // is not too much structural or spectral variety".
        //
        // Same family as self_ingest_weight unread, PatternGrammar unwired,
        // rest_macro unaskable and judges.py --cells absent: a parameter that
        // exists, carries an intended value, and is never reached.
        //
        // AND 4.0 IS TOO WIDE, WHICH IS AUDIBLE AS NOISE. Roberto, minutes after
        // it went live: "all of a sudden it goes into pure noise."
        //
        // rq is bandwidth DIVIDED BY centre frequency, so it scales with cutoff.
        // The machines set \cutoff from each grain's spectral centroid, so a
        // voice centred at 3 kHz gets a 12 kHz bandwidth at rq 4.0 -- wider than
        // the whole band this material occupies. The filter stops filtering and
        // the raw granular material comes through unshaped.
        //
        // So 1.0 was too narrow, one colour; 4.0 is transparent for any bright
        // voice. The value is bounded here rather than left at the declared
        // default, and the ceiling is the point: whatever a machine asks for, a
        // voice cannot open the filter past the edge of usefulness.
        //
        // 2.5 IS A STIPULATION AND THE THIRD VALUE TRIED. Measured on the delivered
        // stream, percent of energy by band and spectral flatness:
        //
        //   rq unpassed (1.0)   34.5 / 15.3 / 23.3 / 26.9   flatness 0.043
        //   rq 4.0              10.8 / 14.2 / 26.1 / 48.8   flatness 0.140   NOISE
        //   rq clipped to 1.5   30.0 / 21.5 / 22.6 / 25.9   flatness 0.042   = old
        //
        // 1.5 is close enough to 1.0 to change nothing; 4.0 is about two octaves
        // of bandwidth, which for already-broadband granular material is barely
        // filtering, and Roberto heard that as pure noise. The usable range is
        // between, and it is narrow. The honest test is an hour of
        // it. Tune by editing this number; it needs a restart because SynthDef
        // argument defaults are fixed when the def is built.
        // THE BANDWIDTH, NOT ONLY THE RATIO. 16 Sept 2026.
        //
        // rq is bandwidth DIVIDED BY centre frequency, so rq.clip(0.5, 2.5)
        // bounds the RATIO and bounds the bandwidth not at all. At 44100 Hz,
        // Nyquist is 22050, and cutoff * 2.5 passes it whenever
        //
        //     cutoff > 8820 Hz
        //
        // above which BPF's coefficients leave the stable region and the filter
        // diverges. Measured, test_bpf_bandwidth.scd, same grain throughout:
        //
        //     cutoff 8800  (bw 22000)   peak 0.0568
        //     cutoff 8900  (bw 22250)   peak 6.29e12
        //     cutoff 9680  (bw 24200)   peak 1.35e18
        //     cutoff 18000 (bw 45000)   peak 9.78e28
        //
        // The boundary is Nyquist exactly. THIS IS THE BLOW-UP: the voice probe
        // caught a live voice at cutoff 9680 with amp 0.08 emitting 3.9e17, and
        // brstgp5 asks for `centre * 1.7` on a Pseg with no ceiling.
        //
        // It took six wrong explanations to get here -- grains, reverb, NaN,
        // polyphony, amp, the DSP stage -- and a seventh near miss: an earlier
        // sweep tested cutoff at rq 0.5 and cleared BPF, because 0.5 is the
        // NARROWEST setting and I had the hazard backwards. Wide rq at high
        // cutoff is the dangerous corner, and that sweep never visited it.
        //
        // 20000 rather than 22050 leaves a margin, because the coefficients are
        // already ill-conditioned approaching Nyquist and not only beyond it.
        // Below 8000 Hz this changes nothing: arms agreed to four decimals.
        sig = BPF.ar(sig, cutoff.clip(20, 18000),
                     rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));
        // ---- THE THREE STAGES, PER MACHINE (B8 rung 1, 22 Sept 2026) --------
        // The same res/dly/blur as \playgran, same coefficients, same bounds,
        // all defaulting to dry, so every machine written before today is
        // byte-for-byte what it was. A written machine may now set its own
        // depths (PatternGrammar.dsp), bounded there at res 0.5, dly 0.5,
        // blur 0.8, feedback 0.75. Mixed against dry: no setting is silent.
        sig = (sig * (1 - (res + dly).clip(0, 1)))
            + (Ringz.ar(sig, resfz.clip(60, 6000), resrt.clip(0.02, 3.0)) * 0.08 * res)
            // 0.5 s, NOT 2.0. CombL allocates its whole delay line from the
            // server's real-time pool per synth. At 2 s stereo that is ~350 KB
            // for every \playback voice, dry ones included, and the originals
            // fire dozens a second: the pool emptied in 70 minutes on 23 Sept
            // (rung 1's first boot), every s_new failed, the stream went
            // silent for four hours. The grammar never draws dlyt above 0.4 s.
            + (CombL.ar(sig, 0.5, dlyt.clip(0.005, 0.45),
                        dlyt.clip(0.005, 0.45) * 8 * dlyfb.clip(0, 0.85)) * dly);
        sig = XFade2.ar(sig, LPF.ar(sig, blurhz.clip(200, 12000)), (blur * 2 - 1).clip(-1, 1));
        sig = Pan2.ar(sig, pan, amp);
        sig = sig * env;
        // VOICE PROBE (#106), 16 Sept. FOUR explanations of the blow-up have now
        // been refuted, each by evidence that was cheap to gather and that I
        // proposed a mechanism without gathering first:
        //   corrupt grains   -- all 48,162 grains in every pool cap at 0.9990
        //   reverb feedback  -- all four reverb buses are literally [0]
        //   polyphony        -- BLOWUP windows average 1.11 macro voices against
        //                       2.01 elsewhere; one blew up at macro=0
        //   BPF gain         -- swept 0 Hz to 8 kHz at rq 0.5, peak gain 0.61x,
        //                       never above unity even at cutoff 0
        // and amp, and the DSP stage, are both bounded by their callers.
        //
        // So a SINGLE voice reaches past 8.0 while every parameter feeding it is
        // in range. This stops the guessing: the voice reports its own peak and
        // the exact parameters it was given, and the sclang side stamps the
        // machine that asked. Threshold 1.0 -- one voice alone should never
        // approach full scale, since amp is bounded at 0.70 across every machine.
        SendReply.kr(
            Impulse.kr(8) * (A2K.kr(Peak.ar(Mix.ar(sig.abs), Impulse.ar(8))) > 1.0),
            '/voiceblow',
            [A2K.kr(Peak.ar(Mix.ar(sig.abs), Impulse.ar(8))),
             cutoff, rate, amp, rq, buf, rel]);
        // WHAT THE FACTORY ASKED FOR, AS OPPOSED TO WHAT IT GOT (#109).
        //
        // The Nyquist clip above makes an out-of-envelope cutoff harmless. It
        // also makes it INVISIBLE, and a silently trimmed request is how the
        // blow-up survived for weeks: the value that broke the filter was never
        // written down anywhere, so every attempt to find its source was a
        // search through source code for something that might not be in it.
        //
        // A whole day was spent reading machine definitions to find what could
        // request 9680 Hz. Nothing found could. brstgp5 tops out at 4080, fma1
        // at 2623, the factory's own macro line at 484, the Handler paths at
        // 3360 and 1120. The request is real -- the probe measured it -- and it
        // is not in the source I can read.
        //
        // So this reports the request itself, whenever it leaves the envelope
        // \playback is designed for, whether or not anything audible goes wrong.
        // 8000 and not 8820: report BEFORE the hazard, so the margin is visible
        // rather than only the breach. The sclang side stamps the machine.
        SendReply.kr(Impulse.kr(2) * ((cutoff > 8000) + (cutoff < 20)).clip(0, 1),
            '/cutoffclamp', [cutoff, rq, rate, buf]);
        Out.ar(out, sig);
    }).add;
    SynthDef(\playbackHP, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                            res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
        // doneAction was 2 on BOTH the PlayBuf and the envelope, so whichever
        // finished first freed the synth. With rate > 1 the buffer runs out
        // while the envelope is still open, and the output stops dead at
        // whatever amplitude it had reached: a click on every grain. Only the
        // envelope may free the synth now, because only the envelope is
        // guaranteed to be at zero when it ends.
        // APPLIED 30 Aug -- same fix as \playback above, same reason.
        // ATTACK FLOOR. A fast amplitude ramp multiplied into broadband
        // material produces sidebands, and at 4 ms those land squarely in the
        // band a listener hears as a click. Measured 31 Aug, time-locked to
        // known onsets, high-frequency energy AT the onset over the 12 ms
        // before it, same grains and same code throughout:
        //     atk   4 ms  ->  714     (p90 13980)
        //     atk  15 ms  ->  297
        //     atk  30 ms  ->  142
        //     atk  60 ms  ->   86
        //     atk 120 ms  ->   35
        //     atk 200 ms  ->   27
        // Monotonic across a 27x spread. Two machines of 82 sat below this
        // floor -- grind at 0.004 and sift at 0.02 -- and between them account
        // for 291 appearances in the window logs.
        //
        // The floor lives HERE and not in those two files so that a machine
        // written later cannot reintroduce the fault by asking for a 4 ms
        // onset. It is the same argument as putting the attenuation in
        // write_grain instead of trusting each builder to clip correctly.
        //
        // 0.03 is a TRADE, not a discovered knee: the curve decays smoothly
        // with no elbow to find. It buys a 5x reduction in splatter while
        // staying percussive enough that grind still bites. Raising it further
        // keeps helping and keeps costing attack definition.
        // Same envelope/buffer fix as \playback above, same reason. This SynthDef
        // is chosen for machines below 0.09 s, so in practice it never loops --
        // but leaving one of two playback paths able to output silence for most
        // of its life is how the two paths came to disagree in the first place.
        var life = atk.max(0.03) + rel,
            bdur = BufDur.ir(buf) / rate.abs.max(0.01),
            lp   = (life > (bdur * 1.5)),
            rt   = BufRateScale.ir(buf) * rate
                     * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
            // A NEGATIVE RATE STARTS AT THE END. sciarrinoPlayer and others
            // send -1.0 for reversed grains; from startPos 0 a reversed
            // PlayBuf reads into nothing and the event is silent unless the
            // grain happens to loop. 22 Sept: startPos follows the sign.
            sig  = PlayBuf.ar(1, buf, rt, loop: lp,
                              startPos: (rt < 0) * (BufFrames.ir(buf) - 1),
                              doneAction:0),
            env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction:2);
        sig = HPF.ar(sig, cutoff);
        // ---- THE THREE STAGES, PER MACHINE (B8 rung 1, 22 Sept 2026) --------
        // The same res/dly/blur as \playgran, same coefficients, same bounds,
        // all defaulting to dry, so every machine written before today is
        // byte-for-byte what it was. A written machine may now set its own
        // depths (PatternGrammar.dsp), bounded there at res 0.5, dly 0.5,
        // blur 0.8, feedback 0.75. Mixed against dry: no setting is silent.
        // DRY BY CONSTRUCTION (26 Sept 2026). The res/dly/blur stages live in
        // \playbackHPFX; a dry voice allocates no delay line. On 25 Sept one
        // written machine (micro events at 20 a second with a 3-9 s release)
        // exhausted the 512 MB real-time pool through this def's CombL,
        // 128 KB per voice, dry or not, and the factory stalled for twelve
        // hours. The writer emits the FX def only when a machine draws stages.
        sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;

    SynthDef(\playbackHPFX, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,
                            res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|
        // doneAction was 2 on BOTH the PlayBuf and the envelope, so whichever
        // finished first freed the synth. With rate > 1 the buffer runs out
        // while the envelope is still open, and the output stops dead at
        // whatever amplitude it had reached: a click on every grain. Only the
        // envelope may free the synth now, because only the envelope is
        // guaranteed to be at zero when it ends.
        // APPLIED 30 Aug -- same fix as \playback above, same reason.
        // ATTACK FLOOR. A fast amplitude ramp multiplied into broadband
        // material produces sidebands, and at 4 ms those land squarely in the
        // band a listener hears as a click. Measured 31 Aug, time-locked to
        // known onsets, high-frequency energy AT the onset over the 12 ms
        // before it, same grains and same code throughout:
        //     atk   4 ms  ->  714     (p90 13980)
        //     atk  15 ms  ->  297
        //     atk  30 ms  ->  142
        //     atk  60 ms  ->   86
        //     atk 120 ms  ->   35
        //     atk 200 ms  ->   27
        // Monotonic across a 27x spread. Two machines of 82 sat below this
        // floor -- grind at 0.004 and sift at 0.02 -- and between them account
        // for 291 appearances in the window logs.
        //
        // The floor lives HERE and not in those two files so that a machine
        // written later cannot reintroduce the fault by asking for a 4 ms
        // onset. It is the same argument as putting the attenuation in
        // write_grain instead of trusting each builder to clip correctly.
        //
        // 0.03 is a TRADE, not a discovered knee: the curve decays smoothly
        // with no elbow to find. It buys a 5x reduction in splatter while
        // staying percussive enough that grind still bites. Raising it further
        // keeps helping and keeps costing attack definition.
        // Same envelope/buffer fix as \playback above, same reason. This SynthDef
        // is chosen for machines below 0.09 s, so in practice it never loops --
        // but leaving one of two playback paths able to output silence for most
        // of its life is how the two paths came to disagree in the first place.
        var life = atk.max(0.03) + rel,
            bdur = BufDur.ir(buf) / rate.abs.max(0.01),
            lp   = (life > (bdur * 1.5)),
            rt   = BufRateScale.ir(buf) * rate
                     * (1 + (lp * 0.06 * LFNoise2.kr(0.07))),
            // A NEGATIVE RATE STARTS AT THE END. sciarrinoPlayer and others
            // send -1.0 for reversed grains; from startPos 0 a reversed
            // PlayBuf reads into nothing and the event is silent unless the
            // grain happens to loop. 22 Sept: startPos follows the sign.
            sig  = PlayBuf.ar(1, buf, rt, loop: lp,
                              startPos: (rt < 0) * (BufFrames.ir(buf) - 1),
                              doneAction:0),
            env  = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction:2);
        sig = HPF.ar(sig, cutoff);
        // ---- THE THREE STAGES, PER MACHINE (B8 rung 1, 22 Sept 2026) --------
        // The same res/dly/blur as \playgran, same coefficients, same bounds,
        // all defaulting to dry, so every machine written before today is
        // byte-for-byte what it was. A written machine may now set its own
        // depths (PatternGrammar.dsp), bounded there at res 0.5, dly 0.5,
        // blur 0.8, feedback 0.75. Mixed against dry: no setting is silent.
        sig = (sig * (1 - (res + dly).clip(0, 1)))
            + (Ringz.ar(sig, resfz.clip(60, 6000), resrt.clip(0.02, 3.0)) * 0.08 * res)
            // 0.5 s, NOT 2.0. CombL allocates its whole delay line from the
            // server's real-time pool per synth. At 2 s stereo that is ~350 KB
            // for every \playback voice, dry ones included, and the originals
            // fire dozens a second: the pool emptied in 70 minutes on 23 Sept
            // (rung 1's first boot), every s_new failed, the stream went
            // silent for four hours. The grammar never draws dlyt above 0.4 s.
            + (CombL.ar(sig, 0.5, dlyt.clip(0.005, 0.45),
                        dlyt.clip(0.005, 0.45) * 8 * dlyfb.clip(0, 0.85)) * dly);
        sig = XFade2.ar(sig, LPF.ar(sig, blurhz.clip(200, 12000)), (blur * 2 - 1).clip(-1, 1));
        sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    // res/dly/blur are the three processing stages and every one of them
    // defaults to 0, which is fully dry. See the comment at the end of this
    // SynthDef for why the default is dry and what each stage is for.
    SynthDef(\playgran, { |out=0, freq=10, amp=0.3, rate=1.0, atk=0.5, rel=4, cutoff=1500,
                          buf, pan=0,
                          res=0, resfz=440, resrt=0.6,
                          dly=0, dlyt=0.12, dlyfb=0.4,
                          blur=0, blurhz=4000|
        var env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), levelScale:amp, doneAction:2),
            fenv = EnvGen.kr(Env([cutoff/2, cutoff, cutoff/2],[atk,rel],\sin,1), levelScale:amp),
            // interp 2 -> 4. GrainBuf's seventh argument is the interpolation
            // order: 2 is LINEAR, 4 is CUBIC. Linear interpolation on
            // pitch-shifted grain playback produces a constant, quiet,
            // clipping-like grit -- audible as "hiss" and invisible to every
            // conventional measurement, because it is not clipping, not a noise
            // floor and not a discontinuity. It is quantisation inside the
            // interpolator. Roberto heard it for hours while eight separate
            // measurements came back clean.
            //
            // NOTE, NOT FIXED HERE: GrainBuf does NOT apply BufRateScale, and
            // `rate` is passed raw. The corpus is 22050 Hz and the server runs
            // at 44100, so these grains play at DOUBLE SPEED, an octave above
            // pitch. The PlayBuf SynthDefs above do use BufRateScale.ir(buf),
            // so the two playback paths disagree with each other. Correcting it
            // means multiplying rate by BufRateScale.kr(buf) -- but that drops
            // every \playgran grain an octave and changes the music, so it is a
            // decision for Roberto rather than a silent fix. Playing at 2x is
            // also what makes the linear interpolation sound as bad as it does.
            sig = GrainBuf.ar(2, Impulse.kr(freq), 0.2, buf, rate,
                LFNoise2.kr(0.1).range(0,1), 4, (pan * LFNoise2.kr(0.1).range(-1,1)), -1);
        // Same Nyquist hazard as \playback:1757, and worse here because rq is
        // left at its default of 1.0 and fenv is an ENVELOPE rather than a fixed
        // value, so nothing guarantees where it lands. At rq 1.0 the divergence
        // threshold is a cutoff of 22050 Hz. Clipped for the same reason and
        // with the same margin; no envelope this stage is meant to trace goes
        // near 18 kHz, so this bounds only the pathological case.
        sig = BPF.ar(sig, fenv.clip(20, 18000));
        // the same request channel on the grain path (#109), HIGH SIDE ONLY.
        //
        // The first version also reported fenv < 20 and fired twelve times in
        // two windows at 6, 7, 8, 9, 10 and 12 Hz: this envelope sweeps up from
        // near zero at every cloud onset, so the low-side check trips on
        // ordinary behaviour. A channel that reports the ordinary buries the
        // exceptional, which is the fault it was built to cure.
        //
        // Kept on \playback, where cutoff is a discrete requested value and a
        // request of 6 Hz would be a real anomaly rather than an onset ramp.
        //
        // Worth its own note: BPF is being handed centre frequencies of 6 Hz at
        // every cloud onset. The clip makes that 20 Hz now. Before the clip it
        // went in raw, and a 2-pole filter at 6 Hz against a 44100 Hz rate is
        // ill-conditioned in the same direction as the Nyquist end.
        SendReply.kr(Impulse.kr(2) * (fenv > 8000),
            '/cutoffclamp', [fenv, -1, -1, -1]);
        // ---- THE PROCESSING STAGE -------------------------------------
        //
        // THERE WAS NO DSP IN THIS FACTORY AT ALL. Counted from source on
        // 3 Sept, every UGen in the system: PlayBuf x7, GrainBuf x3, BPF x2,
        // HPF x1, LPF x1, Pan2 x2, EnvGen x4, LFNoise2 x4, Impulse x4,
        // Limiter x1 -- and the FFT chain, which is analysis on the listener
        // bus. No reverb, delay, comb, allpass, pitch-shift, distortion,
        // compression, feedback or spectral processing anywhere. A voice was
        // read-a-buffer, one filter, pan, out. Four operations.
        //
        // That is why "every machine the factory had ever authored was the
        // same sound at a different speed" was still true after 156 machines:
        // the vocabulary could only vary WHEN things happened, never what they
        // sounded like. Roberto asked for "instrument first then processing"
        // weeks ago; the instrument half exists in three variants and the
        // processing half was never built.
        //
        // THREE STAGES, EACH DEFAULTING TO FULLY DRY. res/dly/blur are all 0
        // unless something asks, so this build is bit-identical to the
        // measured hour until a machine or the trajectory engages it. That is
        // deliberate: a processing layer that changes the sound the moment it
        // is added cannot be compared against the baseline it was added to
        // improve.
        //
        //   res   a resonant body. Ringz on a filtered copy, so the material
        //         acquires a pitch it did not have. This is the stage that can
        //         turn noise into tone, which is the one thing the corpus
        //         cannot supply on its own.
        //   dly   a comb with feedback. At short delays it is a resonator, at
        //         long ones an echo, and the continuum between is a single
        //         parameter -- which is what makes it worth having as an axis
        //         the factory can navigate rather than a preset.
        //   blur  a lowpass on the amplitude envelope, smearing attacks. The
        //         direct answer to 84.3% of runs being under 0.35 s: it does
        //         not lengthen an event, it removes its edge.
        //
        // Bounded on purpose. dlyfb is clipped to 0.85 so feedback cannot run
        // away, and the whole stage is mixed against dry rather than replacing
        // it, so no setting can produce silence. The 500-voice pile-up of
        // 23 Aug came from an unbounded parameter and is not being repeated.
        sig = (sig * (1 - (res + dly).clip(0, 1)))
            // 0.08, NOT 0.3. Ringz has enormous gain at resonance and it rises
            // with decay time, so a flat 0.3 took the master from 0.03 to 0.711
            // in five windows against a 0.80 ceiling -- close enough to trip the
            // never-tolerated clause on a stage that had been live for ninety
            // seconds. Measured safe at an effective 0.024; the coefficient
            // carries that and dsp_res reads as a normal 0-to-1 depth.
            + (Ringz.ar(sig, resfz.clip(60, 6000), resrt.clip(0.02, 3.0)) * 0.08 * res)
            // 0.5 s, NOT 2.0. CombL allocates its whole delay line from the
            // server's real-time pool per synth. At 2 s stereo that is ~350 KB
            // for every \playback voice, dry ones included, and the originals
            // fire dozens a second: the pool emptied in 70 minutes on 23 Sept
            // (rung 1's first boot), every s_new failed, the stream went
            // silent for four hours. The grammar never draws dlyt above 0.4 s.
            + (CombL.ar(sig, 0.5, dlyt.clip(0.005, 0.45),
                        dlyt.clip(0.005, 0.45) * 8 * dlyfb.clip(0, 0.85)) * dly);
        sig = XFade2.ar(sig, LPF.ar(sig, blurhz.clip(200, 12000)), (blur * 2 - 1).clip(-1, 1));
        Out.ar(out, sig * env);
    }).add;

    // The listener, on the factory's own output bus, at the tail of the graph.
    // ---- MASTER SAFETY -------------------------------------------------
    // Roberto, first audible run: "there is noise, like white noise as a layer
    // on top of everything, or maybe clipping". Offline this could not arise:
    // the renderer summed a bounded score and normalised afterwards. Live,
    // three voices with no master stage sum straight into bus 0 and nothing
    // stops them exceeding full scale, which reads as broadband hash.
    //
    // The limiter sits BEFORE \selfListen, so the factory listens to what
    // reaches the speakers rather than to a signal the speakers cannot
    // reproduce. It also reports how much it is having to catch, which
    // distinguishes a machine that MAKES noise from a sum that OVERLOADS:
    // clipFrac near 0 means the hash is a machine's character.
    SynthDef(\master, { |ceiling=0.9, gain=1.0, lpf=7000|
        // 60 ms grains deliver about an eighth of the energy per event that the
        // old 500 ms ones did, and no machine's \amp was recalibrated.
        //
        // THE LOWPASS IS A MASK, NOT A FIX, and should be labelled as one.
        // A residual click survives after the doneAction repair, and its source
        // has not been identified. Clicks are broadband; this material is not.
        // Measured on the live sum: 99.9% of the energy sits below 3.4 kHz and
        // 0.015% between 4 and 8 kHz. So a lowpass placed well above the music
        // removes most of a click's audible edge and costs almost nothing that
        // is actually being played.
        //
        // It is a policy knob so it can be dialled or disabled: set master_lpf
        // to 20000 to take it effectively out of the circuit and hear the
        // unmasked signal again. Turning it off is the honest control - if the
        // clicking returns at 20000 and vanishes at 7000, the lowpass is doing
        // the work and the underlying cause is still unfound.
        // ---- A LIMITER DOES NOT DEFEND AGAINST inf OR NaN. 16 Sept 2026 ----
        //
        // There has been a Limiter here since the first audible run, and the
        // factory still delivered full-scale bursts: segment
        // cap_260915_190813_0018.wav peaks at exactly 1.0000 with 437 samples
        // at or above 0.999, in two bursts of about 13 ms. Limiter.ar computes
        // gain reduction FROM the signal, so a non-finite sample propagates
        // through it untouched, and a finite explosion of 1e18 is still 1e18
        // for the length of its lookahead.
        //
        // 12 of 1423 windows across twelve runs reported a bus peak above 2.0,
        // the largest 1.48e25. So sanitise BEFORE limiting.
        //
        // AND THE CLIP METER WAS BLIND TO EXACTLY THESE EVENTS. `raw.abs > 0.99`
        // is FALSE for NaN, because every comparison with NaN is false. The
        // meter that exists to catch a broken transport could not see the worst
        // case it will ever meet. `over` now counts a bad value as an over,
        // which is the second time this meter has been found blind -- the first
        // was A2K.kr sampling one block in 64.
        //
        // NOTHING IS HIDDEN BY THIS. The event still registers in the clip
        // column and still reaches m3; what changes is that the listener gets a
        // bounded signal instead of 13 ms of full-scale hash. Sanitize exists in
        // this SuperCollider and would replace the Select, but CheckBadValues is
        // needed anyway for the flag, so one mechanism does both.
        var rawIn = In.ar(0, 2) * gain,
            flags = rawIn.collect({ |ch| CheckBadValues.ar(ch, 0, 0) }),
            // NaN and inf to silence; denormals are harmless and kept
            cleaned = rawIn.collect({ |ch, i|
                Select.ar(flags[i].clip(0, 1), [ch, DC.ar(0)]) }),
            // a finite value above 8x full scale is not music either, and
            // bounding it here lets the Limiter do gain reduction on a sane
            // signal instead of chasing 1e18
            raw = cleaned.collect({ |ch| ch.clip2(8.0) }),
            over = rawIn.collect({ |ch, i|
                ((ch.abs > 0.99) + (flags[i] > 0)).clip(0, 1) }),
            band = LPF.ar(raw, lpf.clip(1000, 20000)),
            lim = Limiter.ar(band, ceiling, 0.01);
        // THE CLIP METER WAS BLIND. `over` is computed at audio rate, correctly,
        // and was then read with A2K.kr, which takes ONE SAMPLE PER CONTROL
        // BLOCK - 1 in 64. It therefore missed about 63 of every 64 clipping
        // events, and reported clip=0.0 in every log line for an entire day
        // while the limiter was being driven several times over its ceiling.
        //
        // Peak.ar holds the maximum since the last trigger, so sampling it at
        // the same 4 Hz catches anything that happened in between.
        SendReply.kr(Impulse.kr(4), '/master',
            [Amplitude.kr(Mix.ar(raw)),
             A2K.kr(Peak.ar(Mix.ar(over), Impulse.kr(4))).min(1)]);
        ReplaceOut.ar(0, lim);
        // MIRROR TO CHANNELS 2-3 for the aggregate device.
        //
        // The fix for the loopback clicks is an Aggregate Device holding
        // Built-in Output and BlackHole, clocked by the built-in hardware with
        // drift correction on BlackHole -- that gives the loopback a real clock
        // instead of two clients guessing at each other. The aggregate presents
        // FOUR output channels, and which pair belongs to which sub-device
        // depends on the order they were added in Audio MIDI Setup, which is
        // not knowable from here.
        //
        // So write the same signal to both pairs. Whichever pair is BlackHole
        // gets the audio for the encoder, and the other reaches the speakers,
        // which is useful anyway: it is the monitoring path that finally
        // identified this fault. With numOutputBusChannels = 2 the second pair
        // is a private bus and this line costs nothing.
        Out.ar(2, lim);
    }).add;

    // ---- THE SEND BUSES THE ORIGINALS WERE WRITTEN FOR --------------------
    //
    // 22 Sept 2026. Every one of the twenty class machines routes its events
    // across ~dryBus, ~reverbShortBus, ~reverbMidBus and ~reverbLongBus:
    // sciarrinoPlayer sends bright events dry and resonant ones long, 38
    // reverb references across Handler_Local.sc. Since the first live run all
    // four were [0]. The routing was inert: every machine has been dry, and
    // the part of each original's idiom that gave it space -- which events
    // ring and which do not -- never reached the output. Sixteenth
    // built-and-inert instance, and the one that decided what the factory
    // sounds like.
    //
    // Three returns, each a FreeVerb2 at a different size, reading a private
    // stereo bus and writing to 0 ahead of \master, so the limiter and the
    // lowpass still bound everything. Wet only: the dry share is what a
    // machine sends to ~dryBus. LeakDC because reverb tails accumulate offset,
    // and a soft clip at 0.9 so a resonant burst cannot arrive at the master
    // limiter as a wall. Depth is fx_depth in policy.json, default 1.0 --
    // this is the originals' own routing at the level they were written for.
    SynthDef(\fxReturn, { |in, room=0.5, damp=0.5, depth=1.0|
        var sig = In.ar(in, 2),
            wet = FreeVerb2.ar(sig[0], sig[1], mix: 1.0, room: room, damp: damp);
        wet = LeakDC.ar(wet);
        wet = (wet * depth).softclip * 0.9;
        Out.ar(0, wet);
    }).add;

    SynthDef(\selfListen, { |thresh=0.2|
        var sig = Mix.ar(In.ar(0, 2)) * 0.5,
            chain = FFT(LocalBuf(2048), sig),
            onset = Onsets.kr(chain, thresh, \rcomplex),
            amp = Amplitude.kr(sig, 0.01, 0.2),
            pitchArr = Pitch.kr(sig, ampThreshold: 0.005);
        SendReply.kr(onset + Impulse.kr(4), '/desc',
            [amp, SpecCentroid.kr(chain), SpecFlatness.kr(chain),
             SpecPcile.kr(chain, 0.5), pitchArr[0], pitchArr[1], onset]);
    }).add;

    server.sync;

    // readChannel: the grains are stereo and the SynthDefs are PlayBuf.ar(1, ..)
    // BATCHED. Firing 600 async Buffer.readChannel calls at once overflows
    // scsynth's reply queue: the server dies and waitForBoot loops forever,
    // which looked like a hang with no error. 64 at a time with a sync between
    // batches loads 600 without complaint.
    bufs = Array.newClear(nGrains);
    nGrains.do { |i|
        bufs[i] = Buffer.readChannel(server,
            root ++ "/" ++ grainDir ++ "/g" ++ i.asString.padLeft(2,"0") ++ ".wav", 0, -1, [0]);
        if ((i + 1) % 64 == 0) {
            server.sync;
            ("  buffers " ++ (i + 1) ++ "/" ++ nGrains).postln;
        };
    };
    server.sync;

    // ASSERT THE BUFFERS ACTUALLY HOLD AUDIO. 600 loads in batches of 64; a
    // failed batch leaves Buffer objects that exist and contain nothing. A
    // whole-corpus draw hides that because most grains are fine; a 64-grain
    // neighbourhood landing inside a dead batch is silent while everything
    // reports success. That is the open defect from run 50, and this is the
    // test for it.
    block { |brk|
        var empty = 0, firstBad = nil, tot = 0;
        bufs.do { |bu, i|
            if (bu.isNil or: { bu.numFrames.isNil } or: { bu.numFrames < 1 }) {
                empty = empty + 1;
                if (firstBad.isNil) { firstBad = i };
            } { tot = tot + bu.numFrames };
        };
        ("BUFFERS " ++ bufs.size ++ "  empty " ++ empty
            ++ "  firstEmpty " ++ (firstBad ? "-")
            ++ "  totalFrames " ++ tot).postln;
        wlog.value("BUFFERS " ++ bufs.size ++ " empty " ++ empty ++ "\n");
        if (empty > 0) {
            ("  ^ " ++ empty ++ " of " ++ bufs.size
                ++ " buffers hold no audio. THIS is why small neighbourhoods "
                ++ "were silent.").postln;
        };
    };

    ("GRAINS " ++ bufs.size).postln;

    // PROVENANCE. manifest.json, written by build_grains_seq.py, records which
    // track each grain came from and its position in a consecutive run. succ[i]
    // is the next half-second of the same music. Corpora built by the old
    // build_grains.py have no manifest and simply get no continuity, so both
    // can be run and compared.
    block {
        var man = loadJSON.value(root ++ "/" ++ grainDir ++ "/manifest.json"), byKey, n = 0;
        succ = nil;
        if (man.notNil and: { man["manifest"].notNil }) {
            byKey = Dictionary.new;
            man["manifest"].do { |e|
                byKey[e["track"].asString ++ "/" ++ e["seq"].asString] = e["i"].asInteger };
            succ = Dictionary.new;
            man["manifest"].do { |e|
                var nx = byKey[e["track"].asString ++ "/" ++ (e["seq"].asInteger + 1).asString];
                if (nx.notNil) { succ[e["i"].asInteger] = nx; n = n + 1 };
            };
            ("CORPUS " ++ man["grains"] ++ " grains, " ++ man["tracks"] ++ " tracks, "
                ++ man["total_seconds"] ++ " s, runs of " ++ man["run_len"]
                ++ "; " ++ n ++ " successor links").postln;
        } {
            "CORPUS no manifest: no provenance, continuity unavailable".postln;
        };
    };

    // ---- MACRO LAYER -------------------------------------------------
    // A second corpus at 2 s, loaded alongside the micro one. MACRODIR is
    // substituted by run_live.sh and may be empty, in which case every machine
    // uses the micro layer and behaviour is exactly as before.
    block {
        var md = MACRODIR, d2, m2, byKey;
        macroBufs = nil; macroN = 0;
        if (md.notNil and: { md.size > 0 }) {
            d2 = loadJSON.value(root ++ "/" ++ md ++ "/descriptors.json");
            m2 = loadJSON.value(root ++ "/" ++ md ++ "/manifest.json");
            if (d2.notNil) {
                macroN = d2["index"].size;
                macroVec = Array.fill(macroN, { |i|
                    Array.fill(dKeys.size, { |j| (d2["norm"][dKeys[j]] ? d2["norm"]["centroid"])[i].asFloat }) });
                macroBufs = Array.newClear(macroN);
                macroN.do { |i|
                    macroBufs[i] = Buffer.readChannel(server,
                        root ++ "/" ++ md ++ "/g" ++ i.asString.padLeft(2, "0") ++ ".wav",
                        0, -1, [0]);
                    if ((i + 1) % 48 == 0) { server.sync };
                };
                server.sync;
                macroSucc = Dictionary.new;
                if (m2.notNil and: { m2["manifest"].notNil }) {
                    byKey = Dictionary.new;
                    m2["manifest"].do { |e|
                        byKey[e["track"].asString ++ "/" ++ e["seq"].asString] = e["i"].asInteger };
                    m2["manifest"].do { |e|
                        var nx = byKey[e["track"].asString ++ "/" ++ (e["seq"].asInteger + 1).asString];
                        if (nx.notNil) { macroSucc[e["i"].asInteger] = nx };
                    };
                };
                ("MACRO " ++ macroN ++ " grains at "
                    ++ (m2 !? { m2["grain_seconds"] } ? "?") ++ " s, "
                    ++ macroSucc.size ++ " successor links").postln;
            };
        } {
            "MACRO none: every machine uses the micro layer".postln;
        };
    };

    // ---- MID LAYER: THE GESTURE BAND -----------------------------------
    //
    // Two layers, 60 ms and 2 s, are 33x apart, and machines are assigned by
    // their measured event duration. That left `hp` (0.468 s) and `pu` (0.443 s)
    // on the MACRO layer: emitting every 0.44 s while drawing 2-second grains,
    // so grains overlap four deep and get truncated. Not a gesture, a smear.
    //
    // Roberto, hearing it: "it moves now between drone sections and those
    // continuous fragmentary onset sections, it would be good to have gestures
    // in between, onsets or events that happen at an in-between duration."
    //
    // The vocabulary is thin there too -- three machines of twenty between 0.2
    // and 1 s -- but thinness was not the reason it sounded absent. The machines
    // existed and were being handed the wrong material. A gesture-length event
    // needs a gesture-length grain, so: 400 ms, 1,800 grains, runs of 12 so
    // `continuity` has something to follow.
    block {
        var md = MIDDIR, d3, m3, byKey;
        midBufs = nil; midN = 0;
        if (md.notNil and: { md.size > 0 }) {
            d3 = loadJSON.value(root ++ "/" ++ md ++ "/descriptors.json");
            m3 = loadJSON.value(root ++ "/" ++ md ++ "/manifest.json");
            if (d3.notNil) {
                midN = d3["index"].size;
                midVec = Array.fill(midN, { |i|
                    Array.fill(dKeys.size, { |j| (d3["norm"][dKeys[j]] ? d3["norm"]["centroid"])[i].asFloat }) });
                midBufs = Array.newClear(midN);
                midN.do { |i|
                    midBufs[i] = Buffer.readChannel(server,
                        root ++ "/" ++ md ++ "/g" ++ i.asString.padLeft(2, "0") ++ ".wav",
                        0, -1, [0]);
                    if ((i + 1) % 48 == 0) { server.sync };
                };
                server.sync;
                midSucc = Dictionary.new;
                if (m3.notNil and: { m3["manifest"].notNil }) {
                    byKey = Dictionary.new;
                    m3["manifest"].do { |e|
                        byKey[e["track"].asString ++ "/" ++ e["seq"].asString] = e["i"].asInteger };
                    m3["manifest"].do { |e|
                        var nx = byKey[e["track"].asString ++ "/" ++ (e["seq"].asInteger + 1).asString];
                        if (nx.notNil) { midSucc[e["i"].asInteger] = nx };
                    };
                };
                ("MID " ++ midN ++ " grains at "
                    ++ (m3 !? { m3["grain_seconds"] } ? "?") ++ " s, "
                    ++ midSucc.size ++ " successor links").postln;
            };
        } {
            "MID none: the gesture band falls back to micro".postln;
        };
    };

    // nearest-neighbour walk over the macro corpus, same geometry as grainPath
    //
    // A CEILING ON HOW LONG THE FACTORY MAY QUOTE.
    //
    // macro_continuity is 0.75 and the macro grain is 2 s, so an unbounded run
    // follows the successor link four or five times and plays eight to ten
    // seconds of one recording, forwards, unaltered. Roberto, 3 Sept, first
    // hearing the macro corpus in use: "the factory is now sometimes playing
    // some samples that are not concatenative and a few seconds long, thus
    // recognizable."
    //
    // That is not a defect in the mechanism, it is the mechanism. Continuity is
    // what makes a phrase, and a phrase drawn from one source IS that source.
    // The 27 Aug argument for raising continuity to 0.75 stands: consecutive
    // grains from the same track are how eight seconds of continuous music
    // happens at all, and lowering it returns to a sequence of unrelated
    // two-second statements. So the run is capped instead of the probability
    // being lowered -- duration is kept and the quotation is bounded.
    //
    // BE HONEST ABOUT WHAT THIS IS. The cut now arrives on a counter rather
    // than for a musical reason, and macro_run_max is an architect stipulation
    // like dwell and span: chosen so the ceiling is AUDIBLE as a bound, not
    // measured against a listener. The measured alternative -- rate and filter
    // drift across a run, so the source is held but transformed -- is the
    // better answer and is not built. This is the cheap exact one.
    macroPath = { |k|
        var path = List.new, cur, pool, dist2, run = 1,
            runMax = (policy["macro_run_max"] ? "3").asInteger.max(1);
        if (macroVec.isNil) { nil } {
            dist2 = { |i, j| var acc = 0, a = macroVec[i], bb = macroVec[j];
                dKeys.size.do { |x| acc = acc + ((a[x] - bb[x]).squared) }; acc };
            pool = (0 .. macroN - 1).scramble.keep((k * 3).min(macroN)).asList;
            cur = pool[0]; path.add(cur); pool.remove(cur);
            (k - 1).do {
                var best = nil, bd = 1e9, nxt = macroSucc !? { macroSucc[cur] };
                if (nxt.notNil and: { run < runMax }
                    and: { 1.0.rand < (policy["macro_continuity"] ? policy["continuity"] ? "0.5").asFloat }
                    and: { path.includes(nxt).not }) {
                    best = nxt; run = run + 1;
                } {
                    pool.do { |c| var d = dist2.value(c, cur); if (d < bd) { bd = d; best = c } };
                    run = 1;                        // the run ended, wherever it went
                };
                if (best.notNil) { path.add(best); cur = best; pool.remove(best) };
            };
            path.asArray
        };
    };

    // Same walk on the gesture layer. `mid_continuity` sits between the two by
    // default because the perceptual role of a cut scales with grain length: at
    // 60 ms a cut to another track is the radio effect (micro 0.9, stay), at 2 s
    // a block is already a statement (macro 0.75 after 27 Aug, was 0.25). At
    // 400 ms it is a gesture, where a cut is neither noise nor an event.
    // Capped like the macro walk, and the ceiling is set in SECONDS not grains:
    // a mid grain is 0.4 s against macro's 2.0 s, so the same number of steps is
    // a fifth of the quotation. mid_run_max defaults to 6, about 2.4 s, which is
    // roughly where a gesture stops being a gesture and starts being a phrase
    // from a record. Micro is deliberately uncapped: at 60 ms, twenty
    // consecutive grains is 1.2 s and micro_continuity is 0.9 precisely BECAUSE
    // consecutive grains from one source fuse into a timbre instead of the radio
    // effect. Capping there would restore the fault it was raised to fix.
    midPath = { |k|
        var path = List.new, cur, pool, dist2, run = 1,
            runMax = (policy["mid_run_max"] ? "6").asInteger.max(1);
        if (midVec.isNil) { nil } {
            dist2 = { |i, j| var acc = 0, a = midVec[i], bb = midVec[j];
                dKeys.size.do { |x| acc = acc + ((a[x] - bb[x]).squared) }; acc };
            pool = (0 .. midN - 1).scramble.keep((k * 3).min(midN)).asList;
            cur = pool[0]; path.add(cur); pool.remove(cur);
            (k - 1).do {
                var best = nil, bd = 1e9, nxt = midSucc !? { midSucc[cur] };
                if (nxt.notNil and: { run < runMax }
                    and: { 1.0.rand < (policy["mid_continuity"] ? policy["continuity"] ? "0.6").asFloat }
                    and: { path.includes(nxt).not }) {
                    best = nxt; run = run + 1;
                } {
                    pool.do { |c| var d = dist2.value(c, cur); if (d < bd) { bd = d; best = c } };
                    run = 1;
                };
                if (best.notNil) { path.add(best); cur = best; pool.remove(best) };
            };
            path.asArray
        };
    };

    desc = loadJSON.value(root ++ "/" ++ grainDir ++ "/descriptors.json");
    if (desc.isNil) {
        "NO descriptors.json — falling back to the whole corpus (shuffle)".postln;
    } {
        // Flatten to plain Float arrays ONCE. The distance loop was doing
        // dictionary and string lookups per grain per dimension, inside the OSC
        // callback on the language thread: at k=600 that is ~360,000 lookups
        // per window, which blocks sclang for seconds and starves the factory.
        // corpora analysed before the MFCC pipeline keep working
        if (desc["norm"]["pc0"].isNil) {
            dKeys = ["centroid", "flatness", "median", "zcr"];
            if (desc["norm"]["pitch"].notNil) { dKeys = dKeys ++ ["pitch"] };
            ("  no PCA columns: falling back to " ++ dKeys.size ++ " raw descriptors").postln;
        };
        dn = desc["index"].size;
        dvec = Array.fill(dn, { |i|
            Array.fill(dKeys.size, { |j| desc["norm"][dKeys[j]][i].asFloat }) });
        ("DESCRIPTORS " ++ dn ++ " grains, " ++ dKeys.size
            ++ " dimensions, flattened").postln;
        target = Array.fill(dKeys.size, { rrand(0.3, 0.7) });

        // ---- THE DEGREES THE CORPUS AFFORDS ---------------------------
        // raw_hz was added on 3 Sept and until now nothing read it: the
        // factory navigated a NORMALISED RANK, which is why the shared
        // simultaneity table came back [1.0] -- ranks are not intervals and
        // cannot be. Sorting the pitched grains gives both directions of the
        // mapping at once, because the normalised pitch column IS the
        // empirical CDF of these values. Position in the sorted array over
        // its length is the coordinate; the value at that position is the Hz.
        //
        // 96-98% of grains carry a pitch and they span 4.6 octaves, 80.5 to
        // 2004.5 Hz. That is a melodic resource the factory has had all along
        // and has never once used as one.
        // detectIndex, NOT indexOf. SequenceableCollection.indexOf compares with
        // === , which on two String literals of the same content is false because
        // they are different objects -- so this returned nil and target[nil] = x
        // died on "Primitive '_BasicPut' failed. Index not an Integer". Exactly
        // the String identity failure already recorded in `propose`, where it
        // made 19 of 22 machines inaudible. Third time in this file.
        pitchIdx = dKeys.detectIndex({ |k| k.asString == "pitch" });
        pitchHz = nil;
        if (desc["raw_hz"].notNil and: { desc["raw_hz"]["pitch"].notNil }) {
            var all, top, nTop;
            all = desc["raw_hz"]["pitch"].collect({ |x| x.asFloat })
                    .select({ |x| x > 20 }).sort;
            // A SATURATED DETECTOR IS NOT A PITCH, AND 43% OF THIS CORPUS IS
            // SATURATED.
            //
            // Measured 4 Sept across all three corpora: 2004.55 Hz appears 979
            // times in the micro corpus, 765 in mid, 1287 in macro -- 42.7%,
            // 43.3% and 44.2% of every grain the analyser called pitched, at
            // EXACTLY the same value. That is the tracker's upper search bound
            // reporting that it found nothing, not a corpus that happens to sit
            // on one frequency. The floor is clean by comparison: 80.47 Hz
            // appears 4 times, 0.2%.
            //
            // Three consequences and each was live until now.
            //
            // hzOfCoord and coordOfHz are built from this array, so 43% of the
            // pitch COORDINATE mapped to one frequency: everything above the
            // 57th percentile was the same note. Every percentile from p80 to
            // p95 returned 2004.55.
            //
            // pitch_weight is 4.0, so the selector was strongly preferring
            // grains "at that pitch" -- an undifferentiated mass of a thousand
            // grains whose only shared property is that the detector failed on
            // them. The melodic dimension spent much of its range selecting for
            // analysis failure.
            //
            // And the tonic set was spaced across this range, so its top centre
            // WAS the saturation value. Over the night of 3-4 Sept the tonic sat
            // there for 114 of 224 moves, half the run centred on an artefact,
            // which is also why the interval histogram spikes at unison: voices
            // parked on one plateau are in unison with each other by
            // construction.
            //
            // Dropped, on the same principle by which a grain with no detected
            // pitch contributes nothing: the value is a marker that measurement
            // failed, and a failed measurement is not data. The test is
            // structural rather than a hardcoded 2004.55 -- the maximum, when it
            // accounts for more than a twentieth of the values -- so a corpus
            // built with a different tracker or a different bound is handled by
            // the same rule.
            top = all.last;
            nTop = all.count({ |x| x == top });
            if (all.size > 40 and: { nTop > (all.size * 0.05) }) {
                pitchHz = all.reject({ |x| x == top });
                ("PITCH saturation dropped: " ++ nTop ++ " grains at "
                    ++ top.round(0.01) ++ " Hz = "
                    ++ (100 * nTop / all.size).round(0.1) ++ "% of the pitched set"
                    ++ " -- the tracker's upper bound, not a pitch").postln;
            } {
                pitchHz = all;
            };
            pitchN = pitchHz.size;
        };
        if (pitchN > 32) {
            ("PITCH " ++ pitchN ++ " pitched grains, "
                ++ pitchHz[0].round(0.1) ++ "-" ++ pitchHz[pitchN-1].round(0.1)
                ++ " Hz, " ++ (pitchHz[pitchN-1] / pitchHz[0]).log2.round(0.1)
                ++ " octaves").postln;
            coordOfHz = { |hz|
                var lo = 0, hi = pitchN - 1, mid;
                while { lo < hi } {
                    mid = (lo + hi) div: 2;
                    if (pitchHz[mid] < hz) { lo = mid + 1 } { hi = mid };
                };
                (lo / max(1, pitchN - 1)).clip(0, 1)
            };
            hzOfCoord = { |c| pitchHz[(c.clip(0,1) * (pitchN - 1)).round.asInteger] };
            // snap to the nearest degree the corpus actually holds, so the
            // walk cannot ask for a pitch that does not exist in the material
            snapHz = { |hz| hzOfCoord.value(coordOfHz.value(hz)) };
            // A TONIC AT THE EDGE IS NOT A CENTRE.
            // First shadow run with sections wired: a section centre landed on
            // the corpus maximum, the tonic became 2004.6 Hz, and the line went
            // 1470 -> 1837 -> 1696 -> 2004.6 -> 2004.6 -> 2004.6 and stopped.
            // The pull had somewhere to draw it and the clip had nowhere to let
            // it go, so a melodic dimension became a ceiling. Also 2004.55 is
            // where the pitch detector tops out, so it is a large plateau in the
            // distribution rather than a real pitch. Tonics live inside the
            // 10th-90th percentile, which always leaves room on both sides.
            tonicLo = pitchHz[(pitchN * 0.10).asInteger];
            tonicHi = pitchHz[(pitchN * 0.90).asInteger];

            // A SET OF CENTRES THE FACTORY CAN RETURN TO, INSTEAD OF A FREE DRIFT.
            //
            // MEASURED, and it is the reason this exists. Over 230 windows the
            // factory returned to a simultaneity across a 12-window gap -- longer
            // than any voice can bridge -- 3.8% of the time against a chance rate
            // of 7.3% +/- 1.4. z = -2.53. NEGATIVE. It was not failing to build
            // harmony; it was moving AWAY from every vertical configuration it
            // reached, because the tonic drifted freely, sections reset it, and
            // the walk is aperiodic. The factory never came back.
            //
            // Roberto's decision was to let the factory LEARN vertical structure
            // by navigating toward simultaneities that recur. An operator cannot
            // navigate toward states it revisits LESS often than random.
            // Recurrence is the precondition, and the previous design forbade it.
            //
            // So the tonic moves BETWEEN a small set of centres rather than
            // wandering. This imposes no harmony: the centres are drawn from the
            // corpus's own pitch distribution, spaced evenly through it, and
            // nothing says which to prefer or in what order. It only makes
            // RETURN POSSIBLE. Whether the factory then favours any of them is
            // the question the census asks, and it is now a question that can
            // have a positive answer instead of one the architecture forbids.
            //
            // Spaced by percentile and not by interval, deliberately. Even
            // spacing in cents would be a tuning system arriving through the
            // back door; even spacing in the corpus's own distribution puts the
            // centres where this material actually has pitches.
            // POLICY IS NIL HERE. It is assigned inside loadMutable, which runs
            // AFTER the corpus is loaded, so reading policy["tonic_centres"] at
            // this point died on "Message 'at' not understood, RECEIVER: nil".
            // Same class as the `gram` deferral and the writtenSpecs merge: this
            // file has an initialisation ORDER and three separate additions have
            // now assumed otherwise.
            //
            // So the set is built by a function, called once here with the
            // default and again from loadMutable when the real policy arrives.
            // Building it with a literal and leaving it would make
            // tonic_centres a value that appears in policy.json and does
            // nothing, which is worse than not offering the knob.
            // SPACED IN LOG FREQUENCY AND THEN DEDUPED, not by percentile.
            //
            // Percentile spacing produced 116.1 275.6 1378.1 2004.6 2004.6 --
            // two centres on the same value. 2004.55 is where the pitch
            // detector TOPS OUT, so it is a plateau in the distribution rather
            // than a pitch, and any quantile above about the 85th lands on it.
            // A tonic set with a duplicate has fewer states than it claims, and
            // the whole point of this change is that states can be RETURNED TO,
            // so a miscounted set undermines the measurement it exists for.
            //
            // Even spacing in log frequency is REGISTER COVERAGE, not a tuning
            // system: it decides where the centres sit across the range and says
            // nothing about the intervals the walk takes between corpus degrees,
            // which remain whatever the material affords. Each centre is then
            // snapped to a pitch the corpus actually holds, and duplicates are
            // dropped -- so the set may come back smaller than asked for, and
            // the log prints what it actually built rather than what was
            // requested.
            buildTonics = { |n = 5|
                var k = n.clip(2, 12), lo = tonicLo.log2, hi = tonicHi.log2, seen;
                seen = List.new;
                k.do { |i|
                    var f = 2 ** (lo + ((hi - lo) * (i / max(1, k - 1)))),
                        h = snapHz.value(f);
                    if (seen.includes(h).not) { seen.add(h) };
                };
                tonicSet = seen.asArray.sort;
                tonicIdx = (tonicIdx ?? { tonicSet.size div: 2 })
                             .clip(0, tonicSet.size - 1);
                tonicHz = tonicSet[tonicIdx];
            };
            buildTonics.value(5);
            target[pitchIdx] = coordOfHz.value(tonicHz);
            ("PITCH tonic range " ++ tonicLo.round(0.1) ++ "-"
                ++ tonicHi.round(0.1) ++ " Hz, centres "
                ++ tonicSet.collect({ |h| h.round(0.1) }).join(" ")).postln;
        } {
            ("PITCH unavailable (" ++ pitchN ++ " pitched grains): the walk stays"
                ++ " isotropic and no melodic claim may be made from this run").postln;
        };
    };

    h = Handler.new;
    ~sampleSize = 1.0; ~numPairs = 1;
    ~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;

    "--- loading mutable layer".postln;
    loadMutable.value(true);
    if (weights.isNil) { "FATAL: no weights.json".postln; 1.exit };

    // THE OPERATOR'S HALF-LIFE, FROM POLICY, SET AFTER POLICY EXISTS.
    //
    // 18 Sept 2026. #45 "wire the forgetting operator" was marked done and the
    // machine operator had no half-life: TransferOperator supported one, and this
    // file never passed it -- zero references to decay or half-life anywhere in
    // it, and no policy key. Every caller passed nil, as the class's own comment
    // records. Built, and inert.
    //
    // What it was for showed up the same night. The operator was 61% dead
    // history -- 190 cells from before the 15 Sept state-space change that will
    // never be visited again -- sitting in the matrix as a second closed class
    // and pinning lambda2 at exactly 1. A half-life is what lets a state space
    // the factory has left fade out of the operator instead of steering it for
    // ever. The dead cells this time are pruned by hand; the half-life is so the
    // next time needs no hand.
    //
    // `op` is built at line ~825, before policy.json is loaded here, so the
    // value is applied by setHalflife rather than passed to *new. That is exact:
    // a half-life weights only observations recorded after it is set.
    //
    // 0 or absent means none, which reproduces the accumulating operator EXACTLY
    // and is what every run before today used. This is a behavioural change --
    // the operator steers selection at operator_weight 0.35 -- so it is a policy
    // knob, one_change_at_a_time sees it, and it is not flipped mid-comparison.
    block {
        var hl = (policy["operator_half_life"] ? "0").asFloat;
        op.setHalflife(if (hl > 0) { hl } { nil });
        ("OPERATOR half-life: " ++ (op.halflife ? "none (accumulating)")).postln;
        wlog.value("OPERATOR_HALFLIFE " ++ (op.halflife ? 0) ++ "\n");
    };

    // running means, seeded from BehaviorTrimmed's calibrated values so the
    // live factory starts where the class starts
    means = IdentityDictionary[
        \density -> 0.10, \windowsize -> 0.09, \percpitch -> 1.0, \avgcent -> 3132,
        \avgrolloff -> 1560, \avgflat -> 0.17, \avgrms -> 0.016 ];
    prevWeights = IdentityDictionary.new;
    acc = IdentityDictionary.new; features.do { |f| acc[f] = 0 }; accN = 0;
    currentState = \sc; currentMachine = \sc; prevState = nil;
    startTime = Main.elapsedTime;

    // The world arrives here, once a second, from world_listen.py. Nothing is
    // computed in this callback: doing O(k*n) work in an OSC handler froze the
    // factory once (~27,000 distance computations per 0.25 s). Store and return.
    // sclang does NOT reliably listen on 57120. It takes the first free port
    // from 57120 upward, so any earlier instance -- including a wedged one still
    // holding its socket -- pushes it along. On 25 Aug it landed on 57124 while
    // world_listen.py was sending to 57120, and the packets went nowhere with
    // nothing reporting a problem at either end. Print it, and log it, so the
    // world channel can be pointed at the right place instead of the default.
    ("LANGPORT " ++ NetAddr.langPort
        ++ "   world_listen.py --port " ++ NetAddr.langPort).postln;
    wlog.value("LANGPORT " ++ NetAddr.langPort ++ "\n");

    OSCdef(\world, { |msg|
        world = msg[1..].collect(_.asFloat);
        worldAt = Main.elapsedTime;
        worldN = worldN + 1;
    }, \world);

    OSCdef(\desc, { |msg|
        var amp = msg[3], cent = msg[4], flat = msg[5], roll = msg[6],
            freq = msg[7], hasPitch = msg[8], isOnset = msg[9] > 0,
            now = Main.elapsedTime - startTime;

        // SLEEP DETECTION.
        //
        // On 28 Aug this factory's clock jumped 20,309 seconds between window
        // 100 and window 105. The laptop slept around 01:55 and woke at
        // 07:33:56 -- confirmed in pmset, and confirmed by Roberto. On wake,
        // sclang's scheduler was 5.6 hours behind and flooded scsynth trying to
        // catch up: 77,491 `command FIFO full` messages, after which the server
        // was DROPPING commands. The factory then ran another 7.75 hours in that
        // state while every metric it owns reported it healthy -- MASTER lines
        // arriving, machines being written, audio playing. A second sleep at
        // 09:42 took the log file's descriptor with it.
        //
        // This OSCdef fires on every descriptor message, many times a window, so
        // a full minute without one is not a slow window. It is a stopped clock.
        //
        // Nothing here can stop a lid from closing. What it can do is refuse to
        // let the damage be SILENT, so that no analysis is ever again run across
        // a sleep without knowing that it did. The evidence cost of not having
        // this was one eight-hour run whose last 7.75 hours are uninterpretable.
        if (lastNow > 0 and: { (now - lastNow) > 60 }) {
            var jump = now - lastNow;
            clockJumps = clockJumps + 1;
            ("CLOCKJUMP " ++ jump.round(1) ++ "s at window " ++ winCtr
                ++ " -- the machine slept. The scheduler is that far behind and"
                ++ " will flood the server catching up; expect FIFO saturation"
                ++ " and dropped commands. TREAT EVERY WINDOW AFTER THIS AS"
                ++ " SUSPECT.").postln;
            wlog.value("CLOCKJUMP " ++ winCtr ++ "," ++ jump.round(0.1)
                ++ "," ++ clockJumps ++ "\n");
        };
        lastNow = now;

        if (winCtr < 2 and: { evCtr < 2 }) {
            // THE TEST. ~dryBus, ~sampleSize and ~numPairs are assigned inside
            // waitForBoot's function; the machines read them from inside THIS
            // OSCdef closure. If the closure runs in a different Environment
            // they are nil here, \out is nil, and every class machine plays
            // into nothing while reporting success.
            ("ENVTEST ~dryBus=" ++ ~dryBus ++ " ~numPairs=" ++ ~numPairs
                ++ " ~sampleSize=" ++ ~sampleSize
                ++ " ~reverbLongBus=" ++ ~reverbLongBus
                ++ " ~fr=" ++ ~fr).postln;
        };

        if (running) {
            if (amp < 0.00005) { silentWindows = silentWindows + 1 } { silentWindows = 0 };
            if (silentWindows > (policy["collapse_after"] ? "600").asInteger) {
                ("COLLAPSE silence at " ++ now.round(0.1) ++ " s, " ++ evCtr ++ " events").postln;
                wlog.value("COLLAPSE silence " ++ now ++ " " ++ evCtr ++ "\n");
                logFile.flush; running = false;
            };

            // accumulate this observation into the running window
            acc[\density] = acc[\density] + 1; acc[\windowsize] = acc[\windowsize] + 0.09;
            acc[\percpitch] = acc[\percpitch] + hasPitch;
            acc[\avgcent] = acc[\avgcent] + cent; acc[\avgrolloff] = acc[\avgrolloff] + roll;
            acc[\avgflat] = acc[\avgflat] + flat; acc[\avgrms] = acc[\avgrms] + amp;
            accN = accN + 1;
            if (isOnset) { evCtr = evCtr + 1 };

            // ---- window boundary: the whole selection happens from DATA ----
            if (accN >= nextWindow) {
                // NO `played` HERE. 23 Sept 2026: this var list declared a local
                // `played`, shadowing the outer one fireVoice appends to, so
                // `pending = played.copy` below copied an empty list on every
                // window and the audibility verdict never ran. audibility.json
                // was last written 22 Aug; every window line has carried 0.5
                // and "14 above 0.5" (the seed) since. Seventeenth inert
                // mechanism, and the one that was supposed to tell the factory
                // which of its own machines make sound.
                var newMeans, deltas, raw, chosen, temp, pen, hist, avail, line, machineArgs;

                // A DEAD START is possible and was measured: the analyser reads
                // silence, so avgrms and avgcent arrive as 0, so every amplitude
                // and filter mapping in every machine bottoms out, so the
                // factory plays as quietly as it can, which keeps the analyser
                // reading silence. The loop never lights.
                //
                // So a window that contained no audible material does not get
                // to overwrite the means. The factory keeps the values it had
                // until it can actually hear itself.
                newMeans = IdentityDictionary.new;
                if (acc[\avgrms] / accN < 0.0002) {
                    features.do { |f| newMeans[f] = means[f] };
                    wlog.value("# window " ++ winCtr ++ " inaudible, means held\n");
                } {
                    features.do { |f| newMeans[f] = acc[f] / accN };
                    newMeans[\density] = accN / max(0.001, nextWindow * 0.25);
                };

                deltas = IdentityDictionary.new;
                features.do { |f|
                    deltas[f] = (newMeans[f] / max(1e-9, means[f]))
                        .linlin(0, 2.0, -100, 100, clip: nil) };

                // every machine with an entry, plus every runtime machine.
                //
                // .asSymbol IS THE WHOLE FIX FOR THE LIVE SILENCE. `weights`
                // comes from parseYAML, whose keys are STRINGS; runtimeMachines
                // is keyed by SYMBOLS. So currentState was the String "ma", and
                // Handler.stateMachine dispatches with
                //     switch(state, \sc, {...}, \ma, {...}, ...)
                // where "ma" == \ma is false. The switch matched nothing and
                // returned nil. No exception, no warning: the machine simply
                // never ran. Only \sc sounded, because line 388 seeds it as a
                // literal Symbol, and the two runtime machines sounded because
                // their keys were already Symbols. Three sounding names out of
                // twenty-two is the "one window in six" that survived fifteen
                // other hypotheses.
                //
                // It poisoned two more things through the same mismatch. `audib`
                // is an IdentityDictionary keyed by Symbols, so audib["ma"] never
                // matched the census seeding and always fell back to 0.5, and
                // every write inserted a SECOND key under the String. The
                // audibility learning has been running against a copy of itself.
                avail = weights.keys.asArray.collect({ |k| k.asSymbol })
                        ++ runtimeMachines.keys.asArray;
                avail = avail.asSet.asArray.reject({ |m|
                    (policy["banned"] ? []).includes(m.asString) });

                // ---- the slow layer -----------------------------------------
                sectionAge = sectionAge + 1;
                if (section.isNil or: { sectionAge >= nextSection }) {
                    section = pickSection.value(avail);
                    // RECORD THE OCCUPANCY HERE, at the one place a section
                    // becomes current, so a recall counts exactly as much as a
                    // new draw. Doing it inside pickSection's new-section branch
                    // would have made the pressure blind to returns, and returns
                    // are 32% of sections -- the pressure would then push new
                    // centres away from other new centres while the factory
                    // walked back to a remembered region unnoticed.
                    //
                    // Trimmed to twice the horizon so a run of any length keeps
                    // this list small; the pressure never reads further back.
                    if (section.notNil and: { section[\centre].notNil }) {
                        var cap = 2 * (policy["section_spread_horizon"] ? "16")
                                        .asInteger.max(1);
                        occupied.add(section[\centre].copy);
                        while { occupied.size > cap } { occupied.removeAt(0) };
                    };
                    sectionAge = 0;
                    nextSection = rrand((policy["section_windows_min"] ? "6").asInteger,
                                        (policy["section_windows_max"] ? "18").asInteger);
                    // A SECTION CHANGE IS A MODULATION, NOT A TELEPORT.
                    //
                    // This replaced the WHOLE target, pitch included, so every
                    // section boundary threw the melodic line to wherever the
                    // section centre happened to sit -- measured on the first
                    // shadow run, a 1.9-octave jump at window 1, against a step
                    // limit of 0.5. A line that can be relocated arbitrarily
                    // every six to eighteen windows is not a line, and the
                    // anisotropy would have been undone by the slow layer as
                    // fast as the walk built it.
                    //
                    // The section still governs pitch, and should: a new region
                    // of the corpus is a new harmonic area. It sets the TONIC
                    // and the walk travels there under its own step law. So a
                    // section boundary is heard as a modulation -- a centre
                    // moving and a line following it -- instead of a cut.
                    if (desc.notNil) {
                        var keep = if (pitchHz.notNil and: { pitchIdx.notNil })
                                   { target[pitchIdx] } { nil };
                        target = section[\centre].copy;
                        if (keep.notNil) {
                            // the section names a REGION; snap it to the nearest
                            // centre so a section boundary lands the factory
                            // somewhere it can return to, instead of somewhere
                            // it will never see again
                            var want = hzOfCoord.value(section[\centre][pitchIdx]),
                                bi = 0, bd = 1e12;
                            tonicSet.do { |h, i|
                                var d = (h.log2 - want.log2).abs;
                                if (d < bd) { bd = d; bi = i } };
                            tonicIdx = bi;
                            tonicHz = tonicSet[tonicIdx];
                            tonicAge = 0;
                            target[pitchIdx] = keep;      // the line continues
                            wlog.value("TONIC " ++ winCtr ++ ","
                                ++ tonicHz.round(0.1) ++ ",section\n");
                        };
                    };
                    // record the move and the visit, then write memory out. The
                    // transition table is the only thing here that knows about
                    // ORDER between regions, which is what a later run would
                    // need to do more than sample the same places again.
                    section[\visits] = (section[\visits] ? 0) + 1;
                    // MEMORY FORGETS, 27 Sept 2026. The table had grown for 148
                    // runs (6,942 transitions over 5,178 sections) and never
                    // decayed, so a place last visited in August steered recall
                    // as hard as one visited an hour ago. With memory_half_life
                    // H > 0 (in sections; about 125 s each) every count is
                    // multiplied by 0.5^(1/H) at each new section and dropped
                    // below 0.05, so recent performance reshapes what the
                    // factory returns to and old paths fade. Nothing is deleted
                    // from the section archive: a place whose every path has
                    // faded is simply unreachable by return. 0 is the old,
                    // accumulating table, exactly.
                    block {
                        var hl = (policy["memory_half_life"] ? "0").asFloat, f, dead;
                        if (hl > 0) {
                            dead = List.new;
                            // FRONTIER AND CORE (SDF, "Primitives"): the surplus
                            // is generated at the frontier and retained at a core.
                            // A path taken once fades at H; a path the factory
                            // keeps returning to fades at H x (1 + log2 count),
                            // so reinforcement, and nothing the architect picks,
                            // decides what is kept.
                            transitions.keysValuesDo { |k, v|
                                var w = v * (0.5 ** (1 / (hl * (1 + v.max(1).log2))));
                                if (w < 0.05) { dead.add(k) } { transitions[k] = w } };
                            dead.do { |k| transitions.removeAt(k) };
                            if (dead.size > 0 or: { sections.size % 16 == 0 }) {
                                wlog.value("MEMDECAY " ++ winCtr ++ "," ++ hl ++ ","
                                    ++ transitions.size ++ "," ++ dead.size ++ "\n") };
                        };
                    };
                    if (lastSectionId.notNil) {
                        var key = lastSectionId.asString ++ ">" ++ section[\id].asString;
                        transitions[key] = (transitions[key] ? 0) + 1;
                    };
                    lastSectionId = section[\id];

                    // ---- SECTION OPERATOR observes here, once per section ----
                    //
                    // One observation per ~2.2 minutes, so a useful estimate needs
                    // HOURS. 166 sections in six hours; the offline estimate on that
                    // log beat its shuffled null at p=0.037 and put the mixing time
                    // at 5.3 sections, about 12 minutes. Anything shorter than an
                    // hour of running will be sparser than that and should not be
                    // read as structure -- which is why this logs its observation
                    // count alongside the gap, so a thin estimate is visible as thin
                    // rather than reported as a number.
                    //
                    // Cost is trivial: one observe() per section, and compute() only
                    // every 8th, because eigen-decomposition on a growing matrix is
                    // the kind of per-event work that froze the factory once.
                    secOp.observe(section[\id].asSymbol);
                    if (secOp.total > 8 and: { sections.size % 8 == 0 }) {
                        opCompute.value(secOp);
                        wlog.value("SECOP " ++ winCtr
                            ++ "," ++ secOp.gap.round(0.0001)
                            ++ "," ++ secOp.cells.size
                            ++ "," ++ secOp.total
                            ++ "," ++ (secOp.stationary !? { |s|
                                s.maxIndex !? { |i| secOp.cells[i] } } ? "-")
                            ++ "\n");
                    };
                    saveMemory.value;
                    // one of the five knobs moves, if they are the factory's
                    moveKnob.value(winCtr, section[\id]);
                    ("SECTION " ++ section[\id]
                        ++ (if (section[\recalled] == true) { " (RECALLED)" } { " (new)" })
                        ++ "  voices " ++ section[\voices]
                        ++ "  for " ++ nextSection ++ " windows").postln;
                };
                // machines outside the section's family are strongly damped, so
                // a section HAS a character instead of being a fresh draw
                // 28 Sept 2026 (B7 with A5): the damping was a hand-set 0.85.
                // How strongly a section keeps its character is a MEANS, so
                // it is a factory knob (family_damping). The architect's bound
                // is that a section has a character at all: never below 0.5.
                avail = avail.reject({ |m|
                    section[\family].includes(m).not
                        and: { (policy["family_damping"] ? "0.85").asFloat.clip(0.5, 0.99).coin } });
                if (avail.size < 2) { avail = section[\family] };

                temp = (policy["temperature"] ? "1.0").asFloat;
                pen  = (policy["novelty_penalty"] ? "0.0").asFloat;
                hist = (policy["history_len"] ? "12").asFloat;

                raw = avail.collect({ |m|
                    var spec = weights[m.asString], v, lo, hi, idx, dens;
                    if (spec.isNil) {
                        // A WRITTEN MACHINE, 22 Sept (B7): it inherits its
                        // endpoints' bias, coefficients and range at birth
                        // (MachineWriter.inheritWeights, stored flat in
                        // written_machines.json), so the live features move
                        // its weight the way they move an original's. Before
                        // today every written machine sat at a flat 5 with no
                        // response to anything: "selectable but never
                        // preferred", and selection favoured the originals by
                        // construction. Machines written before today carry no
                        // weights and keep the flat 5.
                        var ws = writtenSpecs !? { writtenSpecs[m.asString] };
                        if (ws.notNil and: { ws["bias"].notNil }) {
                            v = ((prevWeights[m] ? 0) * 100) + ws["bias"].asString.asFloat;
                            ws.keysValuesDo { |k, c|
                                var ks = k.asString;
                                if (ks.beginsWith("coef_")) {
                                    var f = ks.copyRange(5, ks.size - 1).asSymbol;
                                    if (deltas[f].notNil) { v = v + (deltas[f] * c.asString.asFloat) } } };
                            lo = (ws["range_lo"] ? "0.0").asString.asFloat;
                            hi = (ws["range_hi"] ? "1.0").asString.asFloat;
                        } {
                            v = ((prevWeights[m] ? 0) * 100) + 5; lo = 0.0; hi = 1.0;
                        };
                    } {
                        v = ((prevWeights[m] ? 0) * 100) + spec["bias"].asFloat;
                        spec["coef"].keysValuesDo { |k, c|
                            v = v + (deltas[k.asSymbol] * c.asFloat) };
                        lo = spec["range"][2].asFloat; hi = spec["range"][3].asFloat;
                    };
                    v = v.linlin(0, 100, lo, hi, clip: \minmax);
                    // novelty: the only self-directed term. It compares the
                    // factory against its OWN recent history, not against my
                    // taste, so it does not cap it at what I know how to want.
                    idx = recent.indexOf(m);
                    if (idx.notNil) { v = v * (1 - (pen * (1 - (idx / hist)).max(0))) };
                    // learned audibility. A machine never yet tried sits at 0.5,
                    // so it is neither favoured nor excluded before it has had
                    // a chance; `floor` keeps a rehabilitation path open so a
                    // machine that becomes audible later can climb back.
                    // audibility_influence scales how much the learned score is
                    // allowed to move selection. 1.0 is the behaviour that ran
                    // in run 53; 0.0 leaves the multiplier at 1 and the learning
                    // still updates and is still written out, but cannot steer.
                    // The ablation exists because run 53 converged at window 44
                    // and the likeliest engine is this line: a machine that
                    // sounds is weighted up, so it is selected more, so it keeps
                    // sounding. That loop was INERT until 22 August, when the
                    // String/Symbol repair made audib[m] match for the first
                    // time -- so the repair may have switched on the very
                    // convergence the anti-convergence machinery exists to stop.
                    // nine of twenty class machines are macro and all runtime
                    // machines default to micro, so long-form material is
                    // outnumbered three to one before selection begins
                    if (layerOf.value(m) == "macro") {
                        v = v * (policy["macro_bias"] ? "1.0").asFloat };

                    // ---- DENSITY BIAS: macro_bias corrects the wrong quantity.
                    //
                    // Measured 27 Aug on a warm run. By SELECTION the macro layer
                    // already dominates, 52% against 23%. By AUDIBLE EVENTS the
                    // micro layer takes 87%:
                    //
                    //   hm  selected 14x  1.143 s/event   0.9 events/s   3% of events
                    //   ma  selected  1x  0.013 s/event  76.9 events/s  18% of events
                    //
                    // `ma` chosen ONCE contributes six times more audible material
                    // than `hm` chosen fourteen times. macro_bias weights how often
                    // a machine is picked; what fills the sonic field is how fast it
                    // emits once picked, and those differ by up to 80x. So "half the
                    // sound should be long-form" is unreachable at any sane
                    // macro_bias -- the lever is attached to the wrong quantity.
                    // Roberto: "my concern is with the system's ability to sustain
                    // longer musical shapes instead of shorter coherent fragments."
                    //
                    // Events per second is 1/dur, and dur is already measured per
                    // machine in weights.json. Weighting by (dur/ref)^k makes event
                    // SHARE controllable: k=0 is the old behaviour, k=1 equalises
                    // the share of audible events between a slow machine and a fast
                    // one, and anything above that over-corrects toward drones.
                    // Runtime machines have no measured dur and are left alone
                    // rather than guessed at.
                    dens = (policy["density_bias"] ? "0.0").asFloat;
                    if (dens > 0 and: { spec.notNil } and: { spec["dur"].notNil }) {
                        v = v * ((spec["dur"].asFloat / 0.15).max(0.02).pow(dens));
                    };
                    v = v * (1 + ((policy["audibility_influence"] ? "1.0").asFloat
                        * ((audib[m] ? 0.5).max((policy["audibility_floor"] ? "0.05").asFloat) - 1)));
                    v.max(0.0)
                });

                if (temp != 1.0) { raw = raw.collect({ |v| v.pow(temp) }) };
                if (raw.sum <= 0) { raw = avail.collect({ 1.0 }) };
                raw = raw.normalizeSum;

                // ---- THE OPERATOR, BLENDED IN ------------------------------
                // The dominant eigenvector is a distribution the factory has
                // actually settled into, so blending toward it makes behaviour
                // PERSIST across windows instead of being drawn fresh each one.
                // The second mode then pulls the other way, its lobes trading
                // places at a rate the operator sets rather than a clock.
                block { |brk|
                    var ow = (policy["operator_weight"] ? "0.0").asFloat,
                        sw = (policy["operator_second"] ? "0.0").asFloat, dom, sec;
                    opEngaged = "off";
                    if (ow <= 0) { brk.value };
                    dom = op.dominantOver(avail);
                    // the OPERATOR log line carries this. From 15 to 20 Sept
                    // dom was nil on every window (the @bucket suffix) and
                    // nothing said so; the operator "ran" for five days and
                    // touched nothing. "nil" here again means the same thing.
                    opEngaged = if (dom.isNil) { "nil" } { "mixed" };
                    if (dom.isNil) { brk.value };
                    raw = raw.collect({ |v, i| (v * (1 - ow)) + (dom[i] * ow) });
                    if (sw > 0) {
                        sec = op.secondOver(avail);
                        if (sec.notNil) {
                            raw = raw.collect({ |v, i| (v * (1 + (sw * sec[i]))).max(0) });
                        };
                    };
                    raw = raw.normalizeSum;
                };

                // ---- ATTENTION, BLENDED IN ---------------------------------
                // A softmax over similarity between where the factory is NOW and
                // every state it has occupied, returning what played at those
                // states. Blended with the computed weights rather than
                // replacing them, at a weight that defaults to zero.
                block { |brk|
                    var aw = (policy["attention_weight"] ? "0.0").asFloat, rec, vec;
                    if (aw <= 0) { brk.value };
                    rec = attend.value(target);
                    if (rec.size < 1) { brk.value };
                    vec = avail.collect({ |m| rec[m] ? 0 });
                    if (vec.sum <= 0) { brk.value };
                    vec = vec.normalizeSum;
                    raw = raw.collect({ |v, i| (v * (1 - aw)) + (vec[i] * aw) }).normalizeSum;
                    if (attnReport.notNil and: { winCtr % 5 == 0 }) {
                        wlog.value("ATTEND " ++ winCtr ++ " " ++ attnReport.join(" ") ++ "\n");
                    };
                };

                // ---- RESCALE BEFORE HANDING TO MACHINES ---------------------
                // The offline census fed machines CORPUS statistics; live they
                // were being fed the factory's own OUTPUT BUS AMPLITUDE under
                // the same names. Every machine maps amplitude with
                //     args.at(\avgrms).linlin(0.0, 1.0, ...)
                // calibrated against a corpus figure of 0.016, and was
                // receiving a measured output level of ~0.005. So a quiet
                // factory instructs its machines to play quietly, which keeps
                // it quiet. That is the dead start again, in a form that does
                // not need total silence to bite: it only needs to sit below
                // where the mappings were calibrated, and it always does.
                //
                // Offline this cannot arise, because avgrms is a fixed property
                // of the corpus rather than of the output.
                //
                // So the factory still LISTENS to itself, but what it hears is
                // mapped onto the scale the machines expect. The feedback is
                // preserved; the units are corrected.
                machineArgs = IdentityDictionary[
                    \windowsize -> 0.09,
                    \percpitch  -> newMeans[\percpitch].clip(0, 1),
                    \avgflat    -> newMeans[\avgflat].linlin(0.0, 0.15, 0.05, 0.30, clip: \minmax),
                    \density    -> newMeans[\density].linlin(0.0, 8.0, 0.05, 1.20, clip: \minmax),
                    \avgcent    -> newMeans[\avgcent].linlin(200, 4000, 1200, 6000, clip: \minmax),
                    \avgrms     -> newMeans[\avgrms].linlin(0.0, 0.05, 0.05, 0.35, clip: \minmax),
                    \mainpitch  -> if (hasPitch > 0) { noteName.value(freq) } { \unpitched },
                    \avgrolloff -> newMeans[\avgrolloff].linlin(200, 4000, 800, 5000, clip: \minmax) ];

                // ---- verdict on the machines chosen LAST window --------------
                if (pending.notNil) {
                    var heard = acc[\avgrms] / max(1, accN) > ampFloor,
                        rate = (policy["audibility_rate"] ? "0.25").asFloat;
                    pending.do { |m|
                        var cur = audib[m] ? 0.5;
                        audib[m] = if (heard) { cur + ((1 - cur) * rate) }
                                            { cur * (1 - rate) };
                    };
                    saveAudibility.value;
                };

                // ---- FILL THE THREE SLOTS -------------------------------
                // Each layer holds its own machine for its own dwell. The
                // operator's weighting (raw/windex) picks the machine; the slot
                // only decides which layer's candidates it picks FROM and how
                // long the pick stands.
                layerNames.do { |lay|
                    var pool, pick, lo, hi;
                    if ((slotDwell[lay.asSymbol] ? 0) > 0
                        and: { slotMach[lay.asSymbol].notNil }) {
                        slotDwell[lay.asSymbol] = slotDwell[lay.asSymbol] - 1;
                    } {
                        // candidates of THIS layer only. If the layer is empty --
                        // and it will be, because weights.json classifies only
                        // the 20 originals and every written machine defaults to
                        // micro -- the slot stays empty rather than borrowing
                        // from another layer, which would collapse the three
                        // back into one.
                        pool = avail.select({ |m| layerOf.value(m) == lay });
                        if (pool.size > 0) {
                            // ON THE MACRO SLOT, PREFER MACHINES THAT CAN CARRY
                            // THE TRAJECTORY.
                            //
                            // hm, dr, gp and bu are CLASS machines. Handler's
                            // stateMachine builds Pkill patterns and plays them
                            // internally, so by the time it returns there is
                            // nothing left to wrap and they can receive neither
                            // the macro trajectory nor the processing stage. I
                            // read that path rather than guessing at it, and
                            // forcing it means editing every player method in
                            // Handler_Local -- which is the class of move that
                            // put a 2 s corpus in this factory.
                            //
                            // They are NOT removed. Dropping four machines to
                            // tidy a layer costs vocabulary breadth, which m4
                            // measures and which this project has spent weeks
                            // defending. Down-weighted instead, so the layer is
                            // mostly consistent with itself and the four still
                            // appear -- and when they do they sound thinner than
                            // their neighbours, which is audible evidence of a
                            // known limitation instead of a mystery.
                            pick = pool.wchoose(
                                pool.collect({ |m|
                                    var w = (prevWeights[m] ? 1.0).max(1e-6);
                                    if (lay == "macro"
                                        and: { runtimeMachines[m].isNil }) {
                                        w = w * (policy["macro_class_weight"] ? "0.25")
                                                  .asFloat };
                                    w.max(1e-6) })
                                    .normalizeSum);
                            slotMach[lay.asSymbol] = pick;
                            lo = (policy["dwell_" ++ lay ++ "_min"] ? "1").asInteger;
                            hi = (policy["dwell_" ++ lay ++ "_max"] ? "1").asInteger;
                            slotDwell[lay.asSymbol] = rrand(lo, max(lo, hi)) - 1;
                            wlog.value("SLOT " ++ winCtr ++ "," ++ lay ++ ","
                                ++ pick ++ "," ++ (slotDwell[lay.asSymbol] + 1) ++ "\n");
                        };
                    };
                };
                prevState = currentState;
                // currentState remains the fastest slot when one exists, so the
                // operator, m4, m5 and the machine writer keep measuring the
                // same quantity they always did. The macro and mid slots are
                // NOT observed by the operator: making the operator's alphabet a
                // triple would multiply its state space by ~170 twice over and
                // every bound derived from it would stop being comparable.
                // ---- WHAT THE OPERATOR IS ALLOWED TO SEE --------------
                //
                // This was the micro slot alone. Since micro is essentially
                // always occupied the fallback chain never fired, so the
                // factory's entire memory of its own dynamics was a memory of
                // its FASTEST layer. It could not notice a long-form behaviour,
                // and therefore could not find one thin and bridge toward it.
                // Roberto, after a long listen: "it does not surprise me
                // anymore." A self-model blind to two thirds of the music is a
                // reasonable place for that to come from.
                //
                // The stated reason was cost, and it was real: a full triple
                // alphabet is 184^3, and even a fourfold widening put the DENSE
                // solver at 10.6 s every three windows. With computeSparse that
                // same widening costs 0.24 s, because nnz is bounded by
                // observations and does not grow with the alphabet. So the
                // constraint was the representation, and it is gone.
                //
                // COARSE, NOT A TRIPLE. The macro slot enters as one of four
                // buckets -- resting, or its machine's own event duration in the
                // three bands layerOfDur already uses -- so the alphabet grows
                // about fourfold rather than by 184^2. What the operator gains
                // is "which micro behaviour, under what kind of macro", which is
                // the smallest thing that can represent a relation between
                // layers at all.
                //
                // THE BOUNDS DERIVED UNDER THE OLD ALPHABET DO NOT TRANSFER.
                // m7's spectral gap and the drift threshold T = 0.9996 were
                // measured on plain machine names. Once the state is a pair they
                // describe a different chain. This is the 0.9-threshold mistake
                // waiting to happen again, so the switch is logged as an
                // ALPHABET line and the old cells are left to the forgetting
                // operator's decay rather than silently blended.
                currentState = slotMach[\micro] ? slotMach[\mid]
                               ? slotMach[\macro] ? avail[raw.windex];
                // ONE NAME, TWO JOBS, AND THE SECOND BROKE WHEN THE FIRST GREW.
                //
                // 15 Sept 2026. Below, `operator_sees_macro` appends "@<bucket>"
                // so the OPERATOR's alphabet can see the macro slot's duration
                // band. Correct for the operator. But currentState is also the
                // fallback MACHINE handle in the voice-fill loop, and
                // `fma3@slow` is not a machine: stateMachine returns Nil,
                // fireVoice logs UNTRACKED and adds nothing to `live`, and the
                // loop cannot reach nVoices. Fifteen FILL_STALL in 453 windows,
                // every one on micro, every one a name ending @slow.
                //
                // So the machine handle is taken HERE, before the suffix, and
                // the suffixed symbol belongs to the operator alone.
                //
                // Scope, checked rather than assumed: audibility.json and
                // weights.json are keyed under a "machines" sub-object loaded
                // separately, and carry no "@" keys, so those lookups were
                // never affected. The leak reached the fill-loop fallback and
                // `recent`, and no further. An earlier note claiming audibility
                // was contaminated was wrong and is corrected in
                // .lab/measurements/2026-09-15_fill_stall_at_slow.md.
                currentMachine = currentState;
                if ((policy["operator_sees_macro"] ? "0").asString == "1") {
                    var mm = slotMach[\macro], bucket = "rest", du;
                    if (mm.notNil) {
                        du = (proposeSpecs !? { proposeSpecs[mm.asString] })
                             !? { |d| (d["dur"] ? "0").asFloat };
                        bucket = if (du.isNil or: { du <= 0 }) { "unk" } {
                            if (du < 0.155) { "fast" } {
                                if (du < 0.894) { "mid" } { "slow" } } };
                    };
                    if (alphaSeen[bucket.asSymbol].isNil) {
                        alphaSeen[bucket.asSymbol] = true;
                        wlog.value("ALPHABET " ++ winCtr ++ ",macro_bucket," ++ bucket ++ "\n");
                    };
                    currentState = (currentState.asString ++ "@" ++ bucket).asSymbol;
                };
                avail.do { |m, i| prevWeights[m] = raw[i] };

                // the trajectory, one entry per window: where it was, and what it
                // played there. This is what attention queries, and it accrues
                // whether or not attention is switched on -- so a run with the
                // weight at zero still LAYS DOWN memory for a later run to use.
                if (target.notNil) {
                    trace.add(IdentityDictionary[\state -> target.copy,
                        \machine -> currentMachine, \run -> priorRuns]);   // playable: attention replays this
                };

                // one transition per window: which behaviour followed which
                op.observe(currentState);
                if (winCtr % 3 == 0) { opCompute.value(op) };

                // ---- ACQUISITION -------------------------------------------
                // The factory writes a machine into the directory it reloads
                // from, WITHOUT STOPPING. The operator says where its own
                // dynamics are thin -- a transition it has never made -- and the
                // new machine bridges those two behaviours.
                //
                // Nothing but the factory decides that a machine should exist,
                // what its parameters are, or when it arrives. Until now this
                // channel had exactly one writer: me.
                //
                // Anti-convergent by construction, which matters: audibility
                // narrowed the vocabulary 9 -> 4 by weighting up what already
                // worked. This targets what the factory does NOT do.
                block { |brk|
                    var every = (policy["acquire_every"] ? "0").asInteger, made;
                    if (every < 1 or: { winCtr % every != 0 }) { brk.value };
                    // THE ARCHITECT'S CEILING ON RENEWAL, 28 Sept 2026. Once
                    // reach lets the writer leave the hull it can admit ten
                    // times as often, and a vocabulary that grows without
                    // bound dilutes selection. acquire_max_per_hour is a
                    // CONSTRAINT (the architect's, not a knob): the factory
                    // chooses how to renew, never how fast past this.
                    acqTimes = acqTimes ?? { List.new };
                    acqTimes = acqTimes.reject({ |t| (Main.elapsedTime - t) > 3600 }).asList;
                    if (acqTimes.size >= (policy["acquire_max_per_hour"] ? "3").asFloat) {
                        wlog.value("ACQCEIL " ++ winCtr ++ "," ++ acqTimes.size ++ "\n");
                        brk.value };
                    // THE THREE ARMS, SELECTED HERE AND NOWHERE ELSE.
                    //
                    // This call passed four arguments until 4 Sept, so grammar,
                    // simTable and ratio all took their defaults and every
                    // machine the factory has ever written -- 169 of them --
                    // was the hand-written template with different numbers in
                    // it. MachineWriter's header has described three arms since
                    // 2 Sept and only one of them was reachable.
                    //
                    //   grammar_weight 0.0   the template. The control, and the
                    //                        default, so this build still
                    //                        reproduces the measured hour.
                    //   grammar_weight > 0   the factory chooses the SHAPE of
                    //                        each slot expression, not only its
                    //                        constants.
                    //   + simTable           machines additionally draw rates
                    //                        from one table, so verticals relate.
                    //
                    // Drawn per machine rather than set per run: a run that
                    // wrote only grammar machines would confound the arm with
                    // everything else that changed today, and a mixed
                    // population lets machine_variance.py compare the two
                    // inside ONE run against the same corpus and operator.
                    // proposeSpecs, NOT weights. See the block that builds it in
                    // loadMutable: `weights` alone made 89% of the operator's
                    // candidate pairs unresolvable, so the factory could only
                    // bridge inside the architect's original twenty machines.
                    // COMPOSITION FROM THE ORIGINALS, 22 Sept: per slot, the
                    // probability that the writer takes a fragment of an
                    // original instead of a grammar term. 0 is the writer as
                    // it was. Read every attempt so it can be moved live.
                    mw.fragmentWeight = (policy["fragment_weight"] ? "0.0").asFloat.clip(0.0, 1.0);
                    // B8 rung 1: the probability a written machine sets its
                    // own res/dly/blur stages. 0 is dry, as before 22 Sept.
                    mw.dspWeight = (policy["dsp_slot_weight"] ? "0.0").asFloat.clip(0.0, 1.0);
                    // B8 rung 2: the probability a written machine authors
                    // its own SynthDef. 0 is the writer as it was.
                    mw.synthWeight = (policy["synth_slot_weight"] ? "0.0").asFloat.clip(0.0, 1.0);
                    mw.reach = (policy["acquire_reach"] ? "0.0").asFloat.clip(0.0, 4.0);
                    mw.stallLimit = (policy["acquire_stall_limit"] ? "12").asFloat.round(1).asInteger.clip(1, 1000);
                    // "klank 3 wavetable 3 ..." -> per-source weight, read
                    // every attempt; absent means uniform (27 Sept)
                    // sources the architect adopted from the catalogue (rung 3)
                    mw.synthGrammar.extraSources = (policy["synth_sources_adopted"] ? "")
                        .asString.split($ ).reject({ |x| x.size == 0 }).collect(_.asSymbol)
                        .select({ |x| mw.synthGrammar.catalogue.includes(x) });
                    mw.synthGrammar.sourceWeights = (policy["synth_source_weights"] ? "")
                        .asString.split($ ).reject({ |x| x.size == 0 }).clump(2)
                        .inject(IdentityDictionary.new, { |d, kv|
                            if (kv.size == 2) { d[kv[0].asSymbol] = kv[1].asFloat }; d });
                    made = mw.propose(op, proposeSpecs ?? { weights },
                        mutableDir ++ "/machines",
                        (policy["acquire_mode"] ? "gap"),
                        if (1.0.rand < (policy["grammar_weight"] ? "0.0").asFloat)
                            { gram } { nil },
                        simTable,
                        // the pitch ratio the machine is born at: where the
                        // walk's pitch coordinate currently sits against the
                        // tonic, which is the only pitch quantity that is a
                        // RELATION and not a position
                        // pitchIdx, NEVER A LITERAL 4. dKeys is ["pc0".."pc4",
                        // "pitch"] only when the corpus HAS a pitch column; the
                        // fallback basis is ["centroid","flatness","median",
                        // "zcr"] plus pitch, where pitch is index 4 by
                        // coincidence and nothing guarantees it stays there.
                        // The index is found by detectIndex at line ~1764 for
                        // exactly this reason and hardcoding it here would
                        // reintroduce the bug that block was written to kill.
                        if (tonicHz.notNil and: { tonicHz > 20 }
                            and: { pitchIdx.notNil } and: { hzOfCoord.notNil })
                            { (hzOfCoord.value(target[pitchIdx] ? 0.5) / tonicHz)
                                .clip(0.25, 4.0) }
                            { 1.0 });
                    // WHY IT DECLINED, WHEN IT DECLINES. Until 5 Sept a refused
                    // acquisition left no trace at all, so "the factory wrote
                    // two machines in twenty-four hours" was a fact with no
                    // diagnosis: the operator being young, every pair already
                    // bridged, an endpoint missing from specs, and the duration
                    // sitting inside minDeviation all looked identical from
                    // outside. Finding out which took six attempts and a
                    // purpose-built harness. Logged sparsely -- this fires on
                    // an acquire window, not every window -- so an hour of log
                    // now answers "what is stopping it" without another harness.
                    if (made.isNil) {
                        wlog.value("ACQFAIL " ++ winCtr ++ "," ++ mw.lastReason ++ "\n");
                    };
                    if (made.notNil) {
                        acqTimes.add(Main.elapsedTime);
                        ("ACQUIRED " ++ made[0] ++ "  bridging " ++ made[1] ++ " -> "
                            ++ made[2] ++ "  dur " ++ made[3].round(0.001)
                            ++ "  " ++ made[4]).postln;
                        wlog.value("ACQUIRED " ++ winCtr ++ "," ++ made[0] ++ ","
                            ++ made[1] ++ "," ++ made[2] ++ "," ++ made[3].round(0.0001)
                            ++ "," ++ made[4]
                            // what it is made of, from 22 Sept: slot<-source ...
                            ++ "," ++ mw.lastComposition ++ "\n");
                        // A RUNG 2 MACHINE IS NOT YET IN machines/. made[6] is
                        // its path under pending/; tools/check_machine.sh
                        // renders it offline (30 s, the live defs and returns,
                        // in a second sclang, never this server) and moves it
                        // into machines/ on a pass. unixCmd, so this thread
                        // never blocks: a synchronous render here would stall
                        // every scheduled event for seconds. The callback
                        // reloads and admits; a refusal forgets the spec so
                        // selection never sees a name with no file.
                        if (made.size > 6 and: { made[6].notNil }) {
                            var pname = made[0], ppath = made[6], pwin = winCtr,
                                cmd = "sh " ++ (root ++ "/../tools/check_machine.sh").quote ++ " "
                                    ++ ppath.quote ++ " " ++ (mutableDir ++ "/machines").quote;
                            wlog.value("PENDING " ++ winCtr ++ "," ++ pname ++ "\n");
                            cmd.unixCmd({ |code|
                                var v = File.exists("/tmp/check_machine/" ++ pname ++ ".verdict").if({
                                    File.readAllString("/tmp/check_machine/" ++ pname ++ ".verdict").stripWhiteSpace }, { "FAIL no verdict" });
                                if (code == 0 and: { v.beginsWith("PASS") }) {
                                    wlog.value("ADMITTED " ++ winCtr ++ "," ++ pname ++ "," ++ v.replace("PASS ", "").replace(" ", ",") ++ "\n");
                                    ("ADMITTED " ++ pname ++ "  " ++ v).postln;
                                    loadMutable.value(true);
                                    admitToSection.value(pname);
                                } {
                                    wlog.value("REFUSED_RENDER " ++ winCtr ++ "," ++ pname ++ "," ++ v.replace(",", ";") ++ "\n");
                                    ("REFUSED_RENDER " ++ pname ++ "  " ++ v).postln;
                                    mw.forgetSpec(pname);
                                    loadMutable.value(true);
                                };
                            });
                        } {
                            // it becomes selectable at the next reload, and the
                            // factory has never stopped
                            loadMutable.value(true);
                            admitToSection.value(made[0]);
                        };
                    };
                };

                // The world, per window, next to the target it pulled. This is
                // the raw material for the Day 1 acceptance test (roadmap 2.3):
                // cross-covariance of w_t against the factory's own output under
                // a circular-shift null. A dead channel must be VISIBLE rather
                // than averaged away, so packet count and staleness are logged
                // even when nothing arrived.
                if (world.notNil) {
                    wlog.value("WORLD " ++ winCtr ++ ","
                        ++ world.collect({ |v| v.round(0.0001) }).join(",")
                        ++ "," ++ worldN
                        ++ "," ++ (Main.elapsedTime - worldAt).round(0.01)
                        ++ "," ++ (target ? []).collect({ |v| v.round(0.0001) }).join("|")
                        ++ "\n");
                } {
                    if (winCtr % 10 == 0) {
                        wlog.value("WORLD " ++ winCtr ++ ",none\n");
                    };
                };

                // the PLAYABLE name: `recent` is searched at the fill loop for an
                // alternative machine, so a suffixed symbol here is a machine
                // that cannot be fired
                recent.addFirst(currentMachine);
                if (recent.size > hist) { recent.pop };

                means = newMeans;
                features.do { |f| acc[f] = 0 }; accN = 0;
                winCtr = winCtr + 1;

                nextWindow = rrand((policy["window_events_min"] ? "1").asInteger,
                                   (policy["window_events_max"] ? "30").asInteger);

                // Retiring and replacing voices is the voice keeper's job now.
                // It runs on its own clock, so a voice that ends is replaced at
                // once instead of waiting for the window to turn over. Windows
                // were running 18-25 s against a 14 s span, which left every
                // window with several seconds of nothing: silence produced by
                // arithmetic rather than by any musical decision.

                // ---- how many voices this window ---------------------------
                // How many voices this window. A range the factory moves
                // through, driven by its own measured density: sparse lately,
                // open up; dense lately, thin out. So voice density traverses
                // instead of sitting on a constant.
                nVoices = block { |brk|
                    var lo = (policy["voices_min"] ? "1").asInteger,
                        hi = (policy["voices_max"] ? "4").asInteger,
                        mode = (policy["voices_follow"] ? "inverse_density").asString, d;
                    if (section.notNil) { brk.value(section[\voices].clip(lo, hi)) };
                    if (mode == "fixed") { brk.value(lo) };
                    if (mode == "random") { brk.value(rrand(lo, hi)) };
                    // inverse_density: amp near the floor -> more voices
                    d = (newMeans[\avgrms] / 0.05).clip(0, 1);
                    brk.value((lo + ((hi - lo) * (1 - d))).round.asInteger.clip(lo, hi));
                };
                // ---- move the target, take the neighbourhood ---------------
                if (desc.notNil) {
                    // Per-machine traversal. The 22 machines differ in rhythm and
                    // envelope; not one of them differs in HOW IT MOVES THROUGH
                    // THE CORPUS, because until now there was no corpus geometry
                    // to move through. `drift` and `nb` in weights.json are that
                    // second axis, and they are data, so an agent can invent a
                    // traversal without writing a pattern at all.
                    var spec = weights[currentMachine.asString],
                        step = if (spec.notNil and: { spec["drift"].notNil })
                                { spec["drift"].asFloat }
                                { (policy["target_drift"] ? "0.08").asFloat };
                    // drift, but pulled back toward the section centre, so the
                    // factory explores a REGION instead of wandering off
                    // ---- THE MELODIC DIMENSION MOVES FIRST, AND DIFFERENTLY --
                    // Timbre keeps its continuous per-window drift below. Pitch
                    // HOLDS for pitch_hold windows and then takes one interval,
                    // pulled toward a tonic that drifts on the macro timescale.
                    // The difference in correlation time is the anisotropy: a
                    // value that persists long enough to be heard as a note and
                    // moves by steps small enough to be heard as motion.
                    if (pitchHz.notNil and: { pitchIdx.notNil }) {
                        tonicAge = tonicAge + 1;
                        if (tonicAge >= (policy["tonic_windows"] ? "40").asInteger) {
                            // THE TONIC DRIFTS, IT IS NOT FIXED. A fixed centre
                            // would be a key the architect chose; a random one
                            // per window would be no centre at all. It moves
                            // rarely and by little, so a passage has somewhere
                            // to return to and the piece is not in one key.
                            // STEP TO A NEIGHBOURING CENTRE, so the factory can
                            // come back. A free drift never revisits; a walk on
                            // a small set does, and adjacency keeps the move
                            // small enough to be heard as a modulation instead
                            // of a jump. Nothing here prefers any centre: the
                            // step is symmetric and the census is what would
                            // detect a preference if one ever emerged.
                            // REFLECT AT THE ENDS, DO NOT CLIP.
                            //
                            // A symmetric random walk on a line whose ends CLIP
                            // is not symmetric: at index 0 a step down stays at
                            // 0, so the boundary absorbs half its arrivals and
                            // the walk piles up there. Measured over the night
                            // of 3-4 Sept: 114 of 224 tonic moves sat on the top
                            // centre, 51% of the run on one of five states.
                            // (That centre was also the detector's saturation
                            // value, which is fixed separately -- two faults
                            // pointing at the same symptom, and fixing either
                            // alone would have left the other looking solved.)
                            //
                            // Reflecting keeps every centre equally reachable,
                            // which is the property the whole tonic-set change
                            // was for: the census asks whether the factory
                            // RETURNS, and a walk that parks at an end returns
                            // to one place and abandons the rest.
                            tonicAge = 0;
                            tonicIdx = tonicIdx + if (0.5.coin) { 1 } { -1 };
                            if (tonicIdx < 0) { tonicIdx = 1 };
                            if (tonicIdx > (tonicSet.size - 1)) {
                                tonicIdx = tonicSet.size - 2 };
                            tonicIdx = tonicIdx.clip(0, tonicSet.size - 1);
                            tonicHz = tonicSet[tonicIdx];
                            wlog.value("TONIC " ++ winCtr ++ ","
                                ++ tonicHz.round(0.1) ++ ",centre" ++ tonicIdx ++ "\n");
                        };
                        pitchHold = pitchHold - 1;
                        if (pitchHold <= 0) {
                            var cur = hzOfCoord.value(target[pitchIdx]),
                                // STEP SIZE IN OCTAVES, mostly small with an
                                // occasional leap. Squaring a uniform biases
                                // toward zero, so most moves are a step and a
                                // few are a gesture. A stipulation, recorded as
                                // one, and NOT quantised to any tuning system:
                                // the snap below uses the corpus's own degrees.
                                mag = (policy["pitch_step_oct"] ? "0.34").asFloat
                                        * (1.0.rand.squared),
                                dir = if (0.5.coin) { 1 } { -1 },
                                pull = (policy["tonic_pull"] ? "0.30").asFloat,
                                // move, then lean back toward the tonic in LOG
                                // frequency, because an interval is a ratio
                                nxt = (cur * (2 ** (mag * dir))),
                                lg = nxt.log2 + ((tonicHz.log2 - nxt.log2) * pull);
                            target[pitchIdx] = coordOfHz.value(
                                snapHz.value((2 ** lg)
                                    .clip(pitchHz[0], pitchHz[pitchN - 1])));
                            pitchHold = (policy["pitch_hold"] ? "3").asInteger.max(1);
                            wlog.value("PITCH " ++ winCtr ++ ","
                                ++ hzOfCoord.value(target[pitchIdx]).round(0.1)
                                ++ "," ++ tonicHz.round(0.1) ++ "\n");
                        };
                    };
                    target = target.collect({ |v, j|
                        var pull = (policy["section_pull"] ? "0.25").asFloat,
                            wp = (policy["world_pull"] ? "0.0").asFloat,
                            c = section[\centre][j], wv;
                        // pitch was moved above by its own law and must not be
                        // re-jittered here, or the anisotropy is undone by the
                        // very line that made the walk isotropic in the first
                        // place. This is the whole of the change at this site.
                        if (pitchHz.notNil and: { j == pitchIdx }) { v } {
                        v = v + rrand(step.neg, step) + ((c - v) * pull);
                        // C-I: THE WORLD PULLS THE TARGET.
                        //
                        // The world is a position in the same corpus geometry,
                        // so it can be reached for directly. This is the whole
                        // of the influence: the factory drifts toward where the
                        // room is in descriptor space, and everything else --
                        // which machine, which grains, how long -- stays its
                        // own. P36's "ambiguous field of potentials through
                        // which the factory's objectives can be derived", not a
                        // controller.
                        //
                        // world_pull defaults to 0.0 so a run can LOG the world
                        // without being steered by it, which is the control arm
                        // the Day 1 acceptance test needs. Only the first five
                        // components are positions; index 5 is rms and is not a
                        // coordinate. Stale packets are ignored: if the channel
                        // dies the factory must not keep leaning on a corpse.
                        if (wp > 0 and: { world.notNil }
                            and: { j < 5 } and: { j < world.size }
                            and: { (Main.elapsedTime - worldAt) < 5.0 }) {
                            wv = world[j];
                            v = v + ((wv - v) * wp);
                        };
                        v.clip(0, 1) } });
                    if (winCtr < 3) {
                        ("DIAG target=" ++ target ++ " nbSize=" ++
                         (if (neighbourhood.notNil) { neighbourhood.size } { "nil" })).postln;
                    };
                    neighbourhood = grainPath.value(
                        (if (spec.notNil and: { spec["nb"].notNil })
                            { spec["nb"].asInteger }
                            { (policy["neighbourhood"] ? "48").asInteger })
                        .min(bufs.size));
                } {
                    neighbourhood = (0 .. bufs.size - 1);
                };

                if (macroBufs.notNil) {
                    macroNb = macroPath.value(
                        (policy["path_max"] ? "96").asInteger.min(macroN));
                };
                if (midBufs.notNil) {
                    midNb = midPath.value(
                        (policy["path_max"] ? "96").asInteger.min(midN));
                };

                if (winCtr < 4) {
                    ("DIAG nb=" ++ neighbourhood.size ++ " first=" ++ neighbourhood.keep(4)
                        ++ " bufs?=" ++ neighbourhood.keep(3).collect({ |i| bufs[i].class })).postln;
                };
                // Voices are no longer fired here. curArgs is published for the
                // voice keeper, which maintains the population continuously.
                curArgs = machineArgs;

                // What this region sounded like, recorded as an OBSERVATION.
                // Nothing reads it back into selection. It is here so that a
                // later question -- does the factory return to loud regions, and
                // should it? -- can be asked from data rather than assumed.
                if (section.notNil) {
                    section[\ampSum] = (section[\ampSum] ? 0) + amp;
                    section[\ampN] = (section[\ampN] ? 0) + 1;
                };

                line = now.round(0.01).asString ++ "," ++ winCtr ++ "," ++ currentMachine
                    ++ "," ++ (if (runtimeMachines[currentMachine].notNil) {"runtime"} {"class"})
                    ++ "," ++ amp.round(0.00001) ++ "," ++ cent.round(0.1)
                    ++ "," ++ flat.round(0.0001) ++ "," ++ avail.size ++ "," ++ reloads ++ "," ++ live.size ++ "," ++ nVoices
                    ++ "," ++ (audib[currentMachine] ? 0.5).round(0.01)
                    ++ "," ++ audib.select({ |v| v > 0.5 }).size
                    ++ "," ++ (if (target.notNil) { target.collect({ |v| v.round(0.01) }).join("|") } { "-" })
                    ++ "," ++ (if (section.notNil) { section[\id] } { "-" })
                    ++ "," ++ sectionAge;
                // the keeper has been appending to `played` all window, so the
                // verdict covers every machine that actually sounded, not just
                // the ones chosen at the boundary
                pending = played.copy; played = List.new;

                wlog.value(line ++ "\n"); logFile.flush;

                if (winCtr % 5 == 0) {
                    ("t=" ++ now.round(0.1) ++ "s  win=" ++ winCtr ++ "  " ++ currentMachine
                        ++ "  amp=" ++ amp.round(0.0001) ++ "  pool=" ++ avail.size
                        ++ "  reloads=" ++ reloads ++ "  LIVE=" ++ live.size
                        ++ "  gap=" ++ op.gap.round(0.001)
                        ++ "  peak=" ++ masterPeak.round(0.001)
                        ++ "  clip=" ++ (clipReports / max(1, masterReports)).round(0.001)).postln;
                };
                wlog.value("OPERATOR " ++ winCtr ++ "," ++ op.gap.round(0.0001)
                    ++ "," ++ op.lambda2.round(0.0001) ++ "," ++ op.cells.size
                    ++ "," ++ (op.stationary !? { op.cells[op.stationary.maxIndex] } ? "-")
                    ++ "," ++ op.total
                    ++ "," ++ opEngaged ++ "\n");
                // REQUEST win,fires,events,meanAmp -- the demand side of the
                // window, to sit beside MASTER's supply side. Counters reset
                // here so each line covers exactly one window.
                wlog.value("REQUEST " ++ winCtr ++ "," ++ fires
                    ++ "," ++ evN
                    ++ "," ++ (evAmpSum / max(1, evN)).round(0.00001) ++ "\n");

                // ---- THE REWARD CHANNEL: THE FACTORY PRICES ITS OWN NEXT
                // WINDOW BEFORE IT HAPPENS ------------------------------------
                //
                // Every measure in this project is authored by me and computed
                // after the fact. Exo's continual-release proposal names the one
                // signal that is not: "Before starting a task, Exo writes down
                // what it expects... When the task ends, the evaluation rig
                // writes what actually happened. The gap is the score." It
                // arrives the moment the task ends, needs no human label, and is
                // measured against something the agent does not control.
                //
                // So: a PROBABILITY that the next window will be audible, formed
                // from the audibility the factory has learned for the machines
                // currently in its slots, and from how many voices are live. The
                // outcome is MASTER's peak against the same 0.004 that
                // m1_not_silent thresholds, so the actual is already recorded and
                // this adds a prediction and nothing else.
                //
                // Brier score against a base-rate forecaster, the same structure
                // judges.py uses and which passes its negative controls. A
                // forecast that cannot beat "always predict the base rate" is
                // honest and uninformative, and that is a finding too.
                //
                // NOTHING STEERS ON THIS. It is written, scored, and read. Wiring
                // it into selection would make it a self-generated criterion, and
                // runs 53-58 measured exactly that becoming a convergence engine.
                block { |brk|
                    var ms = layerNames.collect({ |l| slotMach[l.asSymbol] })
                                       .select({ |m| m.notNil }),
                        pa, nl = live.size;
                    if (ms.isEmpty) { brk.value };
                    // mean learned audibility of what is in the slots, tempered
                    // by whether anything is actually sounding
                    pa = ms.collect({ |m| (audib[m] ? 0.5) }).sum / ms.size;
                    if (nl < 1) { pa = pa * 0.25 };
                    wlog.value("FORECAST " ++ (winCtr + 1) ++ ","
                        ++ pa.clip(0.0, 1.0).round(0.0001) ++ ","
                        ++ nl ++ "," ++ ms.size ++ "\n");
                };
                // VOICES win,macro,mid,micro -- how the sounding population is
                // actually distributed across the three timescales.
                //
                // Nothing recorded this, and that is why it took a listener and
                // then a waveform analysis to find that the top-up loop was
                // pouring every spare voice into the micro slot. The panel
                // reported voice COUNT, the log reported which machine was
                // "engaged", and neither could show that eight of eleven voices
                // were the same 60 ms machine. A layered architecture has to log
                // its layers or its central claim is unfalsifiable from the data
                // it keeps.
                wlog.value("VOICES " ++ winCtr
                    ++ "," ++ live.count({ |e| (e[3] ? "") == "macro" })
                    ++ "," ++ live.count({ |e| (e[3] ? "") == "mid" })
                    ++ "," ++ live.count({ |e| (e[3] ? "") == "micro" }) ++ "\n");

                // THE DENOMINATOR (#107). Slot machines on EVERY window, not
                // only on the windows that went wrong.
                //
                // Until now the BLOWUP line was the only per-window record of
                // which machine held which slot, and that made every claim built
                // on it unfalsifiable. "macro=dr on 186 of 186 blow-ups" was
                // reported as a localisation on 16 Sept; with no base rate it
                // said nothing, and `dr` turned out not to be the diverging
                // voice at all. A field that appears only in the failure case
                // cannot distinguish a cause from the ordinary state of things.
                //
                // It also records the slot's ASSIGNED machine, which is not the
                // same as a sounding voice -- window 262 carried macro=dr with
                // zero macro voices live. Logging it every window is what makes
                // that difference visible instead of a trap.
                wlog.value("SLOTS " ++ winCtr ++ ","
                    ++ layerNames.collect({ |l|
                        (slotMach[l.asSymbol] ? "-") }).join(",") ++ "\n");

                // ---- THE VERTICAL DIMENSION, RECORDED BEFORE IT IS STEERED --
                //
                // There is no vertical coordination in this factory of any kind.
                // Each voice selects grains independently from its own layer, so
                // two voices sounding together do so by accident. Simultaneity.sc
                // was built for this and is switched off, and it failed anyway
                // because it was fed normalised pitch RANKS -- ranks are not
                // intervals, so its shared table came back [1.0].
                //
                // The decision, 3 Sept, was to let the factory LEARN vertical
                // structure rather than be given a consonance model: log which
                // simultaneities occur, let the judges score them, let the
                // operator navigate toward the ones that recur. That is slower
                // than imposing intervals and it is the project's own method --
                // the same reason m9_turnover went in descriptive and unbounded.
                //
                // So this is instrumentation and NOTHING ELSE. It steers no
                // selection and changes no sound. What it writes is the set of
                // pitches actually sounding, expressed as octave-folded RATIOS
                // against the lowest, which is the only form in which two
                // simultaneities from different registers are the same event.
                // Absolute Hz would make every chord unique and the distribution
                // unlearnable.
                //
                // A distribution has to exist before anything can be said to
                // prefer part of it. Until this has run for many hours there is
                // no harmonic claim to make, and that is the honest position.
                if (pitchHz.notNil) {
                    var hzs = live.collect({ |e| e[4] }).reject({ |x| x.isNil })
                                  .select({ |x| x > 20 }).sort,
                        base, rats;
                    if (hzs.size > 1) {
                        base = hzs[0];
                        rats = hzs.collect({ |h|
                            // fold into one octave: 1.0 <= r < 2.0
                            var r = h / base;
                            while { r >= 2.0 } { r = r / 2 };
                            while { r < 1.0 } { r = r * 2 };
                            r.round(0.001)
                        }).sort;
                        wlog.value("VERTICAL " ++ winCtr ++ ","
                            ++ base.round(0.1) ++ ","
                            ++ rats.join("|") ++ "\n");
                    };
                };
                fires = 0; evN = 0; evAmpSum = 0;
                wlog.value("MASTER " ++ winCtr ++ "," ++ masterPeak.round(0.001)
                    ++ "," ++ (clipReports / max(1, masterReports)).round(0.001) ++ "\n");
                masterPeak = 0; clipReports = 0; masterReports = 0;

                // check the mutable directory. This is where a change written
                // by an agent enters a factory that has not stopped playing.
                if (winCtr % (policy["reload_every_n_events"] ? "10").asInteger == 0) {
                    loadMutable.value(true);
                };
            };
        };
    }, '/desc');

    // ---- VOICES, MAINTAINED CONTINUOUSLY --------------------------------
    // Firing happened once per window, and a voice lasted voice_span. Those
    // two numbers came from different places -- the window from Archon's
    // event counter, the span from the offline renderer's 4 s cap -- and
    // nothing kept them in any relation. With windows at 18-25 s and a span
    // of 14 s, every window ended in several seconds of silence that no
    // decision had asked for. Roberto: "it has now gone silent."
    //
    // So the population is maintained instead of refreshed: whenever a voice
    // retires, another is started in its place. The window now only decides
    // WHAT is playing and HOW MANY; when a voice begins and ends is separate.
    // Spans are jittered so voices do not expire in lockstep and leave a hole.
    fireVoice = { |m|
        if (m.notNil and: { bufs.notNil }) {
            var lay = layerOf.value(m),
                span = ((policy["voice_span_" ++ lay]
                         ?? { policy["voice_span"] } ? "14.0").asFloat)
                       * rrand(0.7, 1.4),
                deadline = Main.elapsedTime + span,
                nb, handed, macroTraj, voiceHz,
                args = curArgs,
                vOff, vDeg, vPhase;
            vOff = nil; vDeg = 0; vPhase = 0.0;
            if (target.notNil) {
                var mag = (policy["voice_offset"] ? "0.18").asFloat.clip(0.0, 0.6), s = 0;
                vOff = Array.fill(target.size, { 1.0.sum3rand });
                vOff.do { |x| s = s + (x * x) };
                s = s.sqrt.max(1e-6);
                vOff = vOff.collect({ |x| x / s * mag });
                if (pitchIdx.notNil) { vOff[pitchIdx] = 0 };
            };
            if (pitchHz.notNil and: { tonicHz.notNil }) {
                var spread = (policy["voice_pitch_spread"] ? "0.5").asFloat,
                    want, sounding, anchor, vRatio, vAnchor;
                // ---- THE VERTICAL DIMENSION, NOW STEERING ------------------
                //
                // vDeg was rrand(-2, 2): a degree drawn with no reference to
                // anything already sounding, which is why the interval
                // histogram spiked at unison -- 1224 of 10161 intervals in the
                // 0-50 cent bin. Voices were in unison BY CONSTRUCTION and the
                // "harmony" anyone heard in the output was theirs.
                //
                // What changes: when the table is live, a new voice takes its
                // pitch as a ratio from the table ABOVE THE LOWEST VOICE
                // CURRENTLY SOUNDING, so the simultaneity it forms is a member
                // of the set the corpus's own fundamentals produced.
                //
                // AGAINST THE LOWEST AND NOT AGAINST THE TONIC. The tonic is
                // where the walk is; the lowest sounding voice is what a
                // listener actually hears the new voice against. Relating to
                // the tonic would reproduce the old behaviour with extra steps,
                // since every voice already drew from a spread around it.
                //
                // WHY THIS IS NOT A CONSONANCE CONTROLLER, which the
                // Simultaneity header is explicit about refusing. The table is
                // quantiles of the corpus's own pitch distribution folded into
                // one octave -- 7.73 semitones, not 7.00. Nothing scores an
                // interval, nothing prefers one member of the table over
                // another, and there is no smooth scalar to climb toward a
                // drone. It is SHARED STATE: voices relate because they draw
                // from one source, not because any voice queries another.
                //
                // simultaneity_weight 0.0 leaves simTable nil and this whole
                // branch unreachable, so the control arm is a missing table and
                // not a flag anyone has to remember to honour.
                sounding = live.collect({ |e| e[4] })
                               .reject({ |x| x.isNil })
                               .select({ |x| x > 20 });
                // ---- THE ROOT IS THE SECTION'S, NOT THE LOWEST VOICE --------
                //
                // anchor was sounding.minItem, the lowest voice going right
                // now, so a voice was tuned against something that could expire
                // seconds later and the third voice was related to nothing.
                // That is why the just-mode run gave a strong DIRECT result
                // (85% within 30 cents of the asked ratio) and a weak
                // POPULATION one (36.0% against 25.6% chance): the mechanism
                // only ever made dyads, one per birth.
                //
                // tonicHz is the root the SECTION fixes and holds -- set from
                // section[\centre][pitchIdx] at line ~2172, snapped to a tonic
                // centre, surviving its voices and returning when the section
                // is recalled. Placing every voice against it makes the voices
                // in a section members of one chord by construction.
                //
                // CHORD PICKS THE PITCH CLASS, SPREAD PICKS THE REGISTER. This
                // is the only reading of "keep both" that does not destroy the
                // chord: voice_pitch_spread at 0.5 reaches +/-5.8 semitones and
                // would obliterate any ratio applied to it. As octaves it gives
                // registral variety and leaves the harmony intact.
                //
                // THE OCTAVE SHIFT IS INTEGER, and that is load-bearing rather
                // than incidental: rrand(-1, 1) with Integer arguments returns
                // an Integer in sclang, so 2 ** rrand(-1,1) is exactly
                // {0.5, 1, 2}. That is why octave-folding recovered the asked
                // ratio to 9.3 cents. A continuous factor would detune every
                // voice and the measurement would fail for a reason having
                // nothing to do with the mechanism.
                //
                // NO LONGER REQUIRES sounding.size > 0. The old branch needed a
                // voice to relate to; a section root exists whether or not
                // anything is currently sounding, so the first voice of a
                // section is now placed as deliberately as the fourth.
                // A CHORD SECTION STEERS EVERY VOICE, not half of them.
                //
                // simultaneity_weight is 0.5, so 49% of births were placed by
                // the table and 51% by the old random-degree path. With a median
                // of five concurrent voices that leaves about half of them
                // sitting off the chord, smearing whatever the other half
                // establishes -- which would undercut the layer change above for
                // a reason that has nothing to do with layers.
                //
                // So the weight applies where there is no chord, and a section
                // that HOLDS one places all of its voices on it. The global
                // knob keeps its meaning for the sections that have no chord,
                // and chord sections stop fighting themselves.
                if (simTable.notNil and: { tonicHz.notNil } and: { tonicHz > 20 }
                    and: { 1.0.rand < (
                        if ((section !? { section[\chord] }) !? { |c| c.size > 1 } ?? false)
                        { 1.0 } { simWeight }) }) {
                    var chord = section !? { section[\chord] },
                        oct = (spread * 2).round.asInteger.clip(1, 3),
                        base, loOct, hiOct;
                    vRatio = if (chord.notNil and: { chord.size > 0 })
                             { chord.choose }
                             { simTable.choose };  // no chord yet: dyad, as before
                    vAnchor = tonicHz;
                    base = tonicHz * vRatio;
                    // ---- THE OCTAVE MUST LAND INSIDE THE CORPUS -------------
                    //
                    // Anchoring on tonicHz instead of the lowest sounding voice
                    // introduced a fault the old branch could not have: the
                    // tonic sits anywhere in the corpus band, so an octave DOWN
                    // from it can fall below the lowest pitch the corpus holds.
                    // want is then clipped, and a clip is not a snap -- measured
                    // in the shadow, asked 1.0 at 49.2 Hz came back as 80.5 Hz,
                    // 851 cents away, with the ratio destroyed.
                    //
                    // The lowest-voice anchor never had this problem because it
                    // was itself a sounding pitch, so an octave up was always
                    // safe. Choosing the octave from the range the corpus can
                    // actually hold keeps the registral variety and leaves the
                    // interval intact. If no octave fits, stay at unity rather
                    // than clip.
                    loOct = (pitchHz[0] / base).log2.ceil.asInteger;
                    hiOct = (pitchHz[pitchN - 1] / base).log2.floor.asInteger;
                    loOct = max(oct.neg, loOct);
                    hiOct = min(oct, hiOct);
                    want = base * (if (hiOct >= loOct) { 2 ** rrand(loOct, hiOct) } { 1 });
                    vDeg = 0;         // the ratio IS the degree in this arm
                } {
                    vDeg = rrand(-2, 2);
                    want = tonicHz * (2 ** (vDeg * spread / 12 * 4));
                };
                voiceHz = snapHz.value(want.clip(pitchHz[0], pitchHz[pitchN - 1]));
                // ---- WHAT SNAPPING DOES TO THE INTENTION --------------------
                //
                // Every voice is snapped to a pitch the corpus actually holds,
                // in BOTH arms. So an imposed interval is not what sounds: what
                // sounds is the nearest corpus pitch to it, and if the corpus is
                // sparse near that point the interval can be pulled a long way.
                //
                // This is the confound that made the first vertical measurement
                // uninterpretable on 5 Sept. Intervals landed on table members
                // at twice chance in BOTH arms, and there was no way to tell
                // whether the table was steering or whether snapping to
                // corpus-typical pitches produces corpus-typical intervals on
                // its own. Without this line a null result has two readings and
                // the experiment cannot conclude.
                //
                // want -> voiceHz in cents. Near zero means the corpus could
                // honour the intention; large means the snap overrode it, and
                // any imposed tuning is being erased downstream of the decision.
                // THE INTENDED RATIO IS LOGGED WITH IT, and this is what makes
                // the experiment able to conclude at all.
                //
                // VERTICAL logs the ratios of every sounding voice against the
                // current lowest. But the table relates ONE new voice to the
                // voice that was lowest AT ITS BIRTH, and by the time a window
                // is logged that anchor may have expired and the octave
                // randomisation has moved the voice again. So the interval
                // histogram is diluted by construction: most of what it counts
                // is pairs the table never had an opinion about. The first read
                // of this run showed 24.6% near a just member against 29.2%
                // near a corpus member, which under that dilution is not
                // evidence either way.
                //
                // vRatio is what the table ASKED FOR. The achieved ratio is
                // voiceHz/vAnchor. Comparing those two is a direct test of the
                // steering with no dilution and no confound, and it needed one
                // extra field.
                if (voiceHz.notNil and: { want.notNil } and: { want > 20 }) {
                    wlog.value("VSNAP " ++ winCtr ++ ","
                        ++ want.round(0.1) ++ "," ++ voiceHz.round(0.1) ++ ","
                        ++ (1200 * log2(voiceHz / want)).round(0.1) ++ ","
                        ++ (vRatio ? 0).round(0.0001) ++ ","
                        ++ (if (vAnchor.notNil and: { vAnchor > 20 })
                            { (voiceHz / vAnchor).round(0.0001) } { 0 })
                        ++ "\n");
                };
                // THE OBSERVATION HALF, WHICH RUNS IN BOTH ARMS. Simultaneity
                // counts what is actually sounding together, and it has to keep
                // counting while the table steers or there is no way to see
                // whether steering changed the distribution it was built from.
                if (sim.notNil and: { voiceHz.notNil } and: { tonicHz > 20 }) {
                    sim.fire(voiceHz / tonicHz, span, m, Main.elapsedTime);
                };
            };
            vPhase = 1.0.rand;

            // the machine's own measured rate decides which corpus it sees
            if (lay == "macro" and: { macroBufs.notNil }) {
                // A HELD NOTE NEEDS A SMALL SET OF PITCH-MATES, AND REPETITION.
                //
                // THE CONCATENATION FORBADE REPEATS, which is why no pitch could
                // ever be sustained. grainPath keeps `path.includes(nxt).not` and
                // `pool.remove(best)`, so every grain enters a path at most once;
                // the machine then plays that path with Pshuf(buf, inf), a
                // shuffle of DISTINCT grains. At path_max 120 and a macro IOI of
                // ~0.33 s a voice plays 120 different grains over forty seconds
                // before anything can recur, so the pitch changes on every event.
                // The walk could move the target wherever it liked and the
                // neighbourhood dissolved the pitch again immediately. Roberto:
                // "an overabundance of content at all levels but no melodic shape
                // (to do that would have to sustain the same pitch or sound for
                // long enough)."
                //
                // So a macro voice is handed a handful of grains chosen for being
                // near the target PITCH rather than near it in all six
                // dimensions, and Pshuf over six grains repeats every six events.
                // Overlapping repeats of pitch-mates read as ONE SUSTAINED TONE
                // whose timbre keeps moving -- the material stays rich and the
                // richness becomes timbre instead of melody. The trajectory then
                // moves that tone.
                //
                // NOTHING CAPS HOW LONG A PITCH LASTS. pitch_hold is a MINIMUM
                // number of windows before the walk may move; there is no
                // maximum, and a step that lands back on the same corpus degree
                // simply continues the note. How long a note lasts is the
                // trajectory's business, not a stipulation.
                //
                // micro and mid are untouched: path_max stays 120 there and the
                // fast layers lose none of their variety.
                var pk = (policy["macro_hold_grains"] ? "1").asInteger.clip(1, 24),
                    tp = if (pitchIdx.notNil and: { target.notNil })
                         { target[pitchIdx] } { nil },
                    ord;
                if (voiceHz.notNil and: { macroVec.notNil } and: { coordOfHz.notNil }) {
                    tp = coordOfHz.value(voiceHz);
                };
                // ---- MACRO SELECTED ON ONE DIMENSION OUT OF SEVEN -----------
                //
                // This sorted the whole macro corpus by |pitch - target| and took
                // the top pk. Mid and micro call nearestAround, which is a
                // neighbourhood in the FULL descriptor space with the pitch axis
                // weighted by pitch_weight. Macro was the only layer choosing its
                // material on a single coordinate, and pc0..pc4 and clarity --
                // measured 8 Sept as 65.5% of the corpus's spread -- played no
                // part in what it played.
                //
                // Roberto, 8 Sept: "the macro layer just keeps producing endless
                // sustained drone layers, the behaviour is sonically limited."
                //
                // WHY, AND THE FIRST EXPLANATION WAS WRONG. It was claimed that
                // pk=6 makes different targets return OVERLAPPING sets, so the
                // voices converge. Measured on the real corpus before this went
                // live, that is false: pools drawn at different targets overlap
                // 0.001 under the old rule and 0.012 under the new one. Both are
                // essentially disjoint. Overlap is not the mechanism.
                //
                // What the corpus actually says, 400 draws each:
                //
                //   rule  pk   within-pool sd   as % of corpus   pool overlap
                //   old    1         0.0000             0.0%           0.000
                //   old    6         0.1442            70.3%           0.001
                //   new    6         0.0844            41.1%           0.012
                //
                // Sorting on pitch alone leaves the other six axes UNCONSTRAINED,
                // so the six grains handed to a voice are a pitch-matched
                // grab-bag covering 70% of the corpus's spread. A voice that
                // samples most of the distribution sounds like the distribution,
                // and every voice then sounds like every other -- which is the
                // 300-1800 s position going 0.19 to 0.44 when pk went 1 to 6,
                // while 5-60 s improved 0.17 to 0.11.
                //
                // The full-vector neighbourhood is a COHERENT timbral region
                // instead: 41% of corpus spread, enough material to move within a
                // voice, tight enough that two voices at different targets are
                // regions rather than samples of the whole. That is the
                // hypothesis. It is not established, and the run decides it.
                //
                // THE PITCH SORT IS NOT DISCARDED, it is weighted. nearestAround
                // already multiplies the pitch term by pitch_weight (4.0), which
                // is what tasks 62 and 66 built for returning to a tonal centre.
                // The centre handed to it is the section target with the pitch
                // coordinate REPLACED by this voice's own tp, so the vertical
                // steering that gives each voice its degree is preserved exactly
                // and the other six dimensions start doing the work they already
                // do on mid and micro.
                //
                // macro_full_vector 0 restores the old single-axis sort, because
                // the trade above was measured against it and the comparison has
                // to stay runnable.
                if (tp.notNil and: { macroVec.notNil }
                    and: { (policy["macro_full_vector"] ? "1").asInteger == 1 }
                    and: { target.notNil }) {
                    var ctr = target.copy;
                    if (pitchIdx < ctr.size) { ctr[pitchIdx] = tp };
                    nb = nearestAround.value(macroVec, macroN, ctr, pk);
                } {
                if (tp.notNil and: { macroVec.notNil }) {
                    ord = (0 .. macroN - 1).sort({ |a, b|
                        (macroVec[a][pitchIdx] - tp).abs
                            < (macroVec[b][pitchIdx] - tp).abs });
                    nb = ord.keep(pk);
                } {
                    // no pitch column: fall back to the cached per-window path
                    nb = (macroNb ? (0 .. macroN - 1)).keep(pk);
                };
                };
                handed = nb.collect({ |i| macroBufs[i] }).reject({ |x| x.isNil });
                if (handed.size < 1) { handed = macroBufs };
            } {
                var ctr = if (vOff.notNil and: { target.notNil })
                          { target.collect({ |v, j| (v + vOff[j]).clip(0, 1) }) }
                          { nil },
                    k = (policy["voice_nb"] ? "48").asInteger;
                if (lay == "mid" and: { midBufs.notNil }) {
                    nb = if (ctr.notNil and: { midVec.notNil })
                         { nearestAround.value(midVec, midN, ctr, k) }
                         { midNb ? (0 .. midN - 1) };
                    handed = nb.collect({ |i| midBufs[i] }).reject({ |x| x.isNil });
                    if (handed.size < 1) { handed = midBufs };
                } {
                    nb = if (ctr.notNil and: { dvec.notNil })
                         { nearestAround.value(dvec, dn, ctr, k) }
                         { neighbourhood ? (0 .. bufs.size - 1) };
                    handed = nb.collect({ |i| bufs[i] }).reject({ |x| x.isNil });
                    if (handed.size < 1) { handed = bufs };
                };
            };
            played.add(m);
            fires = fires + 1;
            // WHAT PITCH THIS VOICE IS SOUNDING, so the vertical log has
            // something to record. Taken from the grains the voice was actually
            // handed rather than from the target, because the target is a
            // request and the handed set is what will be heard -- and on the
            // micro and mid layers those diverge, since only macro selects for
            // pitch proximity. A voice whose material has no detected pitch
            // contributes nothing to the chord, which is correct: it is noise
            // and noise has no place in an interval.
            voiceHz = nil;
            if (pitchHz.notNil and: { pitchIdx.notNil } and: { nb.notNil }
                and: { nb.size > 0 }) {
                var vecs = case
                    { lay == "macro" } { macroVec }
                    { lay == "mid" }   { midVec }
                    { true }           { dvec };
                if (vecs.notNil) {
                    var cs = nb.collect({ |i|
                        if (i < vecs.size) { vecs[i][pitchIdx] } { nil }
                    }).reject({ |x| x.isNil });
                    if (cs.size > 0) { voiceHz = hzOfCoord.value(cs.sum / cs.size) };
                };
            };
            // MACRO IS A SLOW CONTROL TRAJECTORY, NOT LONG MATERIAL.
            //
            // The layer was built as long grains -- 2 s, and before 3 Sept that
            // was 1200 unaltered two-second excerpts played at rate 1.0. Roberto,
            // on hearing it: "macro is looking for behaviours that generate sonic
            // or structural continuity... this is fully unrelated to behaviour."
            // He is right, and the confusion was mine: grain length is a property
            // of MATERIAL, and macro is a property of BEHAVIOUR. A behaviour is
            // slow because its control parameters move slowly, not because its
            // samples are long. Long samples make a sampler.
            //
            // So on the macro layer two things change and neither touches a
            // machine file:
            //
            // 1. EMISSION IS DENSE ENOUGH TO OVERLAP. A macro machine emitting
            //    one grain every 6 s has a 13% duty cycle at 0.8 s grains -- the
            //    gaps ARE the fault, and no continuity setting closes them
            //    because they are between events, not between grains. The IOI
            //    becomes grain/overlap, so grains cross-fade into a bed and no
            //    single one is audible as a grain. Continuity now comes from
            //    overlap, which is where it should have come from all along.
            //
            // 2. THE MACHINE'S OWN dur BECOMES THE TRAJECTORY PERIOD. It is no
            //    longer thrown away: a machine whose measured event interval was
            //    6 s now takes 6 * macro_traj_mult seconds to traverse its arc,
            //    so `bu` at 11.4 s is still the slowest thing in the vocabulary
            //    and a 0.9 s macro machine is still the quickest. The identity
            //    that dur encoded is preserved and moved to the timescale where
            //    it means something.
            //
            // The trajectory moves the spectral centre and the transposition on
            // independent slow paths, shaped \sin so there are no corners. This
            // is the FIRST half of macro-as-behaviour. The second half -- moving
            // the grain NEIGHBOURHOOD along a slow path so the material itself
            // drifts, and giving pitch its own anisotropy so that drift can be
            // melodic -- is not built, and the walk is still isotropic: measured
            // 3 Sept over 19 runs and 8,948 windows, pitch persistence 0.894
            // against sibling dimensions at 0.891-0.899 with identical step
            // size. Until that changes, this trajectory shapes the sound of the
            // macro layer but cannot yet make it say anything melodic.
            macroTraj = { |pat, mach|
                var spec = (weights !? { weights[mach.asString] })
                           ?? { writtenSpecs !? { writtenSpecs[mach.asString] } },
                    mdur = ((spec !? { spec["dur"] }) ? "2.0").asFloat.clip(0.2, 20.0),
                    per  = (mdur * (policy["macro_traj_mult"] ? "12").asFloat)
                             .clip(20.0, 300.0),
                    gdur = (policy["macro_grain_s"] ? "0.8").asFloat,
                    ovl  = (policy["macro_overlap"] ? "2.4").asFloat.max(1.0),
                    ioi  = (gdur / ovl).clip(0.05, 2.0),   // kept: see \dur below
                    // ONE grain per cloud, so GrainBuf's moving read position
                    // stays inside a single recording. Handing \playgran a
                    // shuffled set would put a different piece of music under
                    // every grain and undo the fusion that makes the tone.
                    // where the spectral centre travels, in log Hz so the path is
                    // even to the ear rather than even in Hz
                    c0   = (policy["macro_cut_lo"] ? "220").asFloat,
                    c1   = (policy["macro_cut_hi"] ? "3600").asFloat,
                    // transposition, kept inside a minor third either way: enough
                    // to stop a repeated grain reading as a repeat, not so much
                    // that the material is transposed out of its own register
                    rlo  = (policy["macro_rate_lo"] ? "0.86").asFloat,
                    rhi  = (policy["macro_rate_hi"] ? "1.16").asFloat,
                    // HOW MUCH OF EACH STAGE IS ENGAGED, SEPARATELY.
                    //
                    // One depth for all three was wrong and it took ninety
                    // seconds of listening to prove it. At 0.35 the layer went
                    // live and Roberto: "it has entered a crazy chunk
                    // behaviour, very fragmentary... it was really good and it
                    // went into this weird shit." Setting the single depth to
                    // 0.0 fixed it, which identified the LAYER and not the
                    // stage -- and turning off a resonator because a delay
                    // misbehaved is how a whole capability gets abandoned for
                    // one bad component.
                    //
                    // The comb is the obvious suspect and the reason is
                    // arithmetic, not taste: CombL at 0.02-0.45 s with feedback
                    // to 0.75 is an ECHO, and an echo of a factory whose median
                    // sounding run is 0.04 s repeats fragments at fragment
                    // spacing. It multiplies the exact fault the hour measured.
                    // A comb belongs on sustained material, which this factory
                    // does not yet mostly produce, so it stays at zero until it
                    // does.
                    //
                    // res and blur are the two that work WITH the problem: a
                    // resonant body gives noise a pitch, and an envelope blur
                    // removes the edge from a short event without lengthening
                    // it. Both are back on at low depth, and separately, so the
                    // next report names a stage instead of a layer.
                    dres = (policy["dsp_res"]  ? "0.30").asFloat.clip(0.0, 1.0),
                    ddly = (policy["dsp_dly"]  ? "0.0").asFloat.clip(0.0, 1.0),
                    dblr = (policy["dsp_blur"] ? "0.25").asFloat.clip(0.0, 1.0),
                    dall = (policy["dsp_depth"] ? "1.0").asFloat.clip(0.0, 1.0);
                // A HELD NOTE CANNOT BE CONCATENATED. IT HAS TO BE SYNTHESISED.
                //
                // Measured on 78 s of the delivered stream after the pitch-mate
                // change: the dominant partial's stable runs had a MEDIAN of
                // 0.03 s and a MAXIMUM of 0.36 s. Not one run reached half a
                // second. Handing a voice six grains that share a detected pitch
                // did nothing, and the reason is not a parameter: a 0.8 s grain
                // is a slice of polyphonic music, not a tone. Six such slices at
                // the same nominal pitch are six different pieces of music, and
                // the partial jumps at every splice. No selection rule fixes
                // that, because the discontinuity is in the material.
                //
                // \playgran is a granular sustainer that was already here and
                // almost unused -- 150 of 156 written machines are \playback,
                // six are \playgran. GrainBuf reads ONE buffer at a slowly
                // moving position, so a single 0.8 s slice becomes an
                // arbitrarily long sustained sound: overlapping short grains
                // from one place in one recording DO fuse, because they are the
                // same signal. That is the mechanism for a held pitch, and the
                // macro layer is where it belongs.
                //
                // So the macro layer inverts what \playback needed. \playback
                // wanted dense events because each one was a one-shot; \playgran
                // wants SPARSE, LONG events because each one already sustains.
                // dur goes from ~0.33 s to several seconds and atk/rel span most
                // of it, so consecutive clouds cross-fade instead of articulate.
                Pbindf(pat,
                    \instrument, \playgran,
                    // grains per second inside the cloud: high enough that the
                    // individual grain is not an event, which is the whole
                    // difference between a texture and a rhythm
                    \freq, Pwhite(14, 26),
                    // one cloud per several seconds, overlapping the next
                    \dur, Pwhite(per * 0.05, per * 0.11).clip(2.0, 12.0),
                    \atk, Pkey(\dur) * 0.45,
                    \rel, Pkey(\dur) * 0.9,
                    \cutoff, Pseg(Pseq([c0, c1, c0 * 2.2, c1 * 0.6], inf),
                                  Pseq([per * 0.4, per * 0.25, per * 0.35], inf),
                                  \sin, inf),
                    \rate, Pseg(Pseq([1.0, rhi, 1.0, rlo], inf),
                                Pseq([per * 0.31, per * 0.19, per * 0.27,
                                      per * 0.23], inf), \sin, inf),
                    // THE PROCESSING IS ON THE TRAJECTORY, NOT A PRESET.
                    // The three stages travel on their own slow paths at
                    // periods coprime with the spectral and rate paths above,
                    // so the combination does not cycle: a macro behaviour
                    // arrives at a resonance it has not had before rather than
                    // returning to a fixed sound every `per` seconds.
                    //
                    // The depths are held low. dsp_depth defaults to 0.35 and
                    // multiplies everything here, so the stage is present but
                    // does not dominate -- this is the first build in which any
                    // of it sounds at all, and a processing layer that arrives
                    // at full strength cannot be compared against the hour it
                    // was added to improve. Raise it once it has been heard.
                    // PER-VOICE PHASE: every voice ran the same trajectory from
                    // the same starting point, so the processing was a global
                    // colour rather than a source of difference between
                    // simultaneous voices. vPhase is assigned at birth.
                    \res,   Pseg(Pseq([0.0, dres * dall * 0.9, dres * dall * 0.1]
                                     .rotate((vPhase * 3).asInteger), inf),
                                 Pseq([per * 0.43, per * 0.57], inf), \sin, inf),
                    // the resonator follows the pitch trajectory, so what it
                    // rings at is the note the factory is on rather than a
                    // number in a synthdef
                    // rings at THIS VOICE'S note, not the shared tonic, or the
                    // one stage that can add pitch would put the SAME pitch
                    // under every voice and undo the degrees above
                    \resfz, Pfunc({ (voiceHz ? tonicHz ? 440).clip(60, 6000) }),
                    \resrt, Pseg(Pseq([0.25, 1.6], inf), Pseq([per * 0.61], inf), \sin, inf),
                    \dly,   Pseg(Pseq([0.0, ddly * dall * 0.7], inf),
                                 Pseq([per * 0.37, per * 0.29], inf), \sin, inf),
                    \dlyt,  Pseg(Pseq([0.02, 0.45], inf), Pseq([per * 0.71], inf), \sin, inf),
                    \dlyfb, Pseg(Pseq([0.2, 0.75], inf), Pseq([per * 0.53], inf), \sin, inf),
                    \blur,  Pseg(Pseq([0.0, dblr * dall].rotate((vPhase * 2).asInteger), inf),
                                 Pseq([per * 0.47, per * 0.31], inf), \sin, inf),
                    \blurhz, Pseg(Pseq([6000, 900], inf), Pseq([per * 0.67], inf), \sin, inf)
                )
            };
            if (runtimeMachines[m].notNil) {
                {
                    var ent = span * (policy["life_enter"] ? "0.25").asFloat,
                        rel = span * (policy["life_recede"] ? "0.45").asFloat,
                        arc = Pseg(Pseq([0.05, 1.0, 0.85, 0.0], 1),
                                   Pseq([ent, span - ent - rel, rel], 1), \sin, 1),
                        // Pbindf taps \amp AFTER the arc has multiplied it, so
                        // this is the amplitude each event is actually played
                        // with. The value is returned unchanged: the pattern is
                        // observed, never altered.
                        base = Pmul(\amp, arc, runtimeMachines[m].value(handed, args)),
                        // the trajectory sits INSIDE the life arc and OUTSIDE
                        // the machine, so the machine still chooses its material
                        // and its amplitude shape while the macro layer decides
                        // how densely and through what filter it is heard
                        shaped = if (lay == "macro") { macroTraj.value(base, m) } { base },
                        pl = Pbindf(shaped,
                            \amp, Pfunc({ |ev|
                                var a = (ev[\amp] ? 0).asFloat;
                                evN = evN + 1; evAmpSum = evAmpSum + a; a })
                        ).play;
                    if (pl.notNil) { live.add([pl, deadline, Main.elapsedTime, lay, voiceHz]) };
                }.try({ |err|
                    wlog.value("PLAY_FAIL " ++ m ++ " " ++ err.errorString ++ "\n") });
            } {
                {
                    var pl;
                    h.settings([m, args]);
                    // CLASS MACHINES DO NOT GET THE TRAJECTORY, AND THAT IS
                    // RECORDED RATHER THAN HIDDEN. h.stateMachine returns
                    // PLAYERS, not patterns, so there is nothing to wrap: by the
                    // time this returns the events are already scheduled. The
                    // handler's settings signature would have to carry the macro
                    // parameters instead, and I have not read that path, so
                    // guessing at it here would be the same move that put a
                    // 2 s corpus in the factory.
                    //
                    // The exposure is four machines: hm, dr, gp, bu. The other
                    // 148 on the macro layer were written by the factory, are
                    // runtime Functions, and are wrapped above. So the layer is
                    // consistent for 97% of its vocabulary and those four will
                    // still emit sparse one-shots until the handler path is read
                    // properly. Expect them to sound thinner than their
                    // neighbours; that is this note, not a new fault.
                    pl = h.stateMachine(handed);
                    // a machine may start more than one pattern; every one of
                    // them has to be bounded, or it becomes a permanent layer
                    pl = if (pl.isKindOf(Collection)) { pl.asArray } { [pl] };
                    pl.do { |p|
                        if (p.isKindOf(EventStreamPlayer)) { live.add([p, deadline, Main.elapsedTime, lay, voiceHz]) } {
                            wlog.value("UNTRACKED " ++ m ++ " " ++ p.class ++ "\n") };
                    };
                }.try({ |err|
                    wlog.value("PLAY_FAIL " ++ m ++ " " ++ err.errorString ++ "\n") });
            };
        };
    };

    voiceKeeper = Routine({
        loop {
            var now = Main.elapsedTime, ceiling;
            // RETIRE ON DEADLINE, OR ON A SETTLED PLAYER HAVING STOPPED.
            // Deadline alone let a finished pattern squat on its slot for the
            // whole span: at 20 s that was invisible because slots recycled
            // anyway, at 180 s it took the factory to exactly 0.000 for eleven
            // windows. The 1.5 s grace matters because a player that has not
            // STARTED also reports not-playing, and retiring on that killed
            // voices a quarter-second after birth -- heard as behaviours
            // halting half-way through.
            live.copy.do { |entry|
                var born = entry[2] ? 0,
                    done = ((now - born) > 1.5) and: { (entry[0].isPlaying ? true).not };
                if (now > entry[1] or: { done }) {
                    { entry[0].stop }.try; live.remove(entry);
                };
            };
            // safety ceiling, oldest first
            ceiling = (policy !? { policy["max_live_voices"] } ? "6").asInteger;
            while { live.size > ceiling } { { live[0][0].stop }.try; live.removeAt(0) };
            // replace, so the population tracks nVoices rather than the window
            // ONE VOICE PER SLOT, so the three timescales sound TOGETHER.
            // This used to fire nVoices voices all drawn from currentState and
            // its recent history -- different machines, but nothing guaranteed
            // different LAYERS, so a macro behaviour never had grains under it.
            if (curArgs.notNil) {
                // ---- A LAYER MAY BE ABSENT --------------------------------
                //
                // This refilled every slot the instant it emptied, so SILENCE IN
                // A LAYER WAS IMPOSSIBLE BY CONSTRUCTION. Measured over 376
                // windows on 4 Sept: micro had zero voices in ONE of them, and
                // that one was the startup window. Macro and mid the same. All
                // three layers were sounding 99.7% of the time, and micro was
                // almost always exactly one voice, continuously.
                //
                // Roberto, hearing it: "that endless broken radio effect on the
                // lower layer... does the micro ever go silent". It does not,
                // and it never could. This was his first request in the thread --
                // "the macro can stop now and then, the mid more often, and the
                // micro even more so" -- and it went unbuilt while I built the
                // measurement it was going to be gated on.
                //
                // WHY IT IS NOT GATED ON THAT MEASUREMENT, in the end. The plan
                // was to drop a layer when the sound had become repetitive.
                // tools/sonic_variety.py then reported the factory's recurrence
                // at CHANCE -- z = -0.17 against its own time-shuffled null --
                // so a repetition trigger would sit idle and the layer would
                // never fall silent. A mechanism whose condition is measured
                // never to occur is not a mechanism.
                //
                // So a slot that has finished its dwell may simply rest, for a
                // while, at a rate set per layer. The three rates are
                // stipulations and are recorded as such: nothing measures how
                // often a layer SHOULD be absent, and the honest test is whether
                // an hour of it sounds like breathing or like dropouts.
                // IN SECONDS, NOT IN KEEPER TICKS. This loop runs every 0.25 s,
                // so a rest counted in iterations would last a quarter second
                // and be inaudible as absence. A rest is a musical duration and
                // is held against the wall clock.
                layerNames.do { |lay|
                    var k = lay.asSymbol,
                        m = slotMach[k],
                        held = live.count({ |e| (e[3] ? "") == lay });
                    // ---- A LAYER THAT IS NEVER EMPTY IS NEVER OFFERED A REST --
                    //
                    // Roberto's original request was "the macro can stop now and
                    // then, the mid more often, and the micro even more so". The
                    // rest below delivered the exact inverse, and the log says so:
                    // over 2,233 windows on 8 Sept, macro rested ELEVEN times,
                    // 0.49% of refill moments, against a rest_macro of 0.10.
                    // Micro rested 1,320 times and mid 292.
                    //
                    // The reason is structural, not a wrong probability. The
                    // offer sits behind `held < 1`, so it is only ever made to a
                    // slot that has ALREADY fallen silent. Macro voices last 90 s
                    // (voice_span_macro) and macro takes half the spare voices
                    // (voice_fill), so the macro slot is essentially never empty
                    // and the branch is essentially never reached. rest_macro was
                    // not disabled; it was unreachable.
                    //
                    // Roberto, 8 Sept: "the macro layer just keeps producing
                    // endless sustained drone layers, the behaviour is sonically
                    // limited ... let macro not produce sound but still control
                    // behaviour."
                    //
                    // SO THE OFFER IS NOW MADE TO A SOUNDING LAYER TOO, after it
                    // has been continuously audible for rest_<lay>_after seconds.
                    // 0 keeps the old behaviour exactly, and that is the default
                    // for every layer, so only a layer given the knob changes.
                    //
                    // AND CONTROL SURVIVES THE SILENCE, which is the point.
                    // Resting does not clear slotMach, so the layer keeps its
                    // machine: the operator still sees it in currentState, the
                    // trajectory still runs, `recent` still carries it, and the
                    // section family is untouched. The layer stops SOUNDING and
                    // goes on STEERING. Only fireVoice is skipped.
                    if (held < 1) { slotSince[k] = nil } {
                        if (slotSince[k].isNil) { slotSince[k] = now };
                    };
                    block {
                        var after = (policy["rest_" ++ lay ++ "_after"] ? "0").asFloat,
                            p2 = (policy["rest_" ++ lay] ? "0.0").asFloat.clip(0, 0.9),
                            lo2 = (policy["rest_" ++ lay ++ "_min"] ? "4").asFloat,
                            hi2 = (policy["rest_" ++ lay ++ "_max"] ? "12").asFloat;
                        if (after > 0 and: { held > 0 }
                            and: { now >= (slotRest[k] ? 0) }
                            and: { slotSince[k].notNil }
                            and: { (now - slotSince[k]) > after }
                            and: { 1.0.rand < p2 }) {
                            slotRest[k] = now + rrand(lo2, max(lo2, hi2));
                            // RETIRE THROUGH THE NORMAL PATH. Setting the
                            // deadline to now lets the retire loop above stop the
                            // voice on its next tick, with whatever grace that
                            // path already provides. Calling .stop here would cut
                            // a 90 s grain dead and the click would be mine.
                            live.do { |e| if ((e[3] ? "") == lay) { e[1] = now } };
                            slotSince[k] = nil;
                            wlog.value("REST_HELD " ++ winCtr ++ "," ++ lay ++ ","
                                ++ (slotRest[k] - now).round(0.1) ++ "\n");
                        };
                    };
                    if (now < (slotRest[k] ? 0)) {
                        // resting: do nothing, and let the layer be silent
                    } {
                        if (m.notNil and: { held < 1 }) {
                            // the moment a layer would be refilled is the only
                            // moment it can be allowed to stay empty instead
                            var p = (policy["rest_" ++ lay] ? "0.0").asFloat.clip(0, 0.9),
                                lo = (policy["rest_" ++ lay ++ "_min"] ? "4").asFloat,
                                hi = (policy["rest_" ++ lay ++ "_max"] ? "12").asFloat;
                            // K > 0: while another layer rests, this layer's
                            // rest probability rises by K*(1-p), so rests
                            // tend to coincide (layer_coupling, 22 Sept)
                            if (coupleK > 0 and: { layerNames.any({ |l|
                                    (l != lay) and: { now < (slotRest[l.asSymbol] ? 0) } }) }) {
                                p = (p + (coupleK * (1 - p))).clip(0, 0.95) };
                            if (1.0.rand < p) {
                                slotRest[k] = now + rrand(lo, max(lo, hi));
                                wlog.value("REST " ++ winCtr ++ "," ++ lay ++ ","
                                    ++ (slotRest[k] - now).round(0.1) ++ "\n");
                            } {
                                fireVoice.value(m);
                            };
                        };
                    };
                };
                // TOP UP ACROSS THE THREE SLOTS, NOT INTO THE FASTEST ONE.
                //
                // This filled every spare voice from `currentState`, and
                // currentState is defined as
                //     slotMach[\micro] ? slotMach[\mid] ? slotMach[\macro]
                // so while the micro slot is occupied -- which is always -- it
                // IS the micro machine. Three slot voices then got five more
                // copies of the same micro machine, and the micro layer became
                // the entire texture with the other two buried under it.
                //
                // Worse, the copies were of ONE machine, so they all ran the
                // same rhythm and could not fill each other's gaps. Measured on
                // three minutes of the delivered stream, 3 Sept: median sounding
                // run 0.06 s, median gap 0.06 s, 384 bursts in 180 s, 74% of
                // frames below a tenth of peak. A micro machine whose event
                // interval exceeds the 60 ms grain emits a gapped pulse train by
                // construction; eight voices of the SAME train is that train
                // louder, not a texture. Roberto: "vertical lines with gaps in
                // between, pure radio effect... 0 variability... it just sounds
                // like random shit."
                //
                // Cycling macro, mid, micro means the spare voices thicken all
                // three timescales evenly, and `recent` still supplies variety
                // within a layer so a lane is not one machine doubled.
                // WEIGHTED TOWARD THE SLOW LAYERS, MEASURED FROM AN HOUR.
                //
                // Round-robin over three layers gave each a third of the spare
                // voices, and over the hour of 3 Sept that produced 84.3% of
                // sounding runs under 0.35 s and held pitch at 4.5% of sounding
                // time. The macro layer sustains -- longest continuous run in
                // the hour was 116 s -- and is simply outnumbered: the fast
                // layers emit far more events per voice, so equal VOICES is
                // wildly unequal EVENTS. Measured 27 Aug: by selection macro
                // took 52% and micro 23%, and by audible events micro took 87%.
                //
                // The cycle is now a fill pattern read from policy, so the
                // balance is one string and not a code change. "macro mid macro
                // micro" gives macro half the spare voices, mid a quarter, micro
                // a quarter -- and micro still has its own slot voice underneath
                // this, so it never disappears.
                //
                // A STIPULATION, and the honest test is the hour: share of
                // sounding time in held pitch >= 0.5 s, against the 4.5%
                // recorded in .lab/measurements/2026-09-03_1741_hour.md.
                // ---- LAYER COUPLING, 22 Sept 2026 -----------------------------
                //
                // Measured on five runs (.lab/measurements/2026-09-22_layer_coupling_baseline.md):
                // the three layers are anticorrelated in density, r -0.2 to
                // -0.4 at lag 0 against a null of 0.06-0.19, because this loop
                // refills a RESTING layer's share of nVoices from the other
                // layers, by count (layerNames[live.size]) and through the
                // fallback below. A hole in macro became a second micro. That
                // was a conserved budget nobody named, at the sign that makes
                // macro's silences audible and micro's invisible.
                //
                // layer_coupling K in [-1, +1] names it. -1: full compensation,
                // byte-for-byte the loop as it ran until today. 0: a resting
                // layer's slot stays empty for the rest's duration, so a rest
                // thins the texture instead of being substituted. +K: in
                // addition, while one layer rests the others' rest probability
                // rises by K*(1-p) at their next decision (see the keeper), so
                // rests tend to coincide: the nesting the ear asked for on
                // 19 Sept. Read every window; a restart is not needed to move
                // it. COUPLE line per window records K, resting layers, target.
                coupleK = (policy["layer_coupling"] ? "-1.0").asFloat.clip(-1.0, 1.0);
                restingLayers = layerNames.select({ |l| now < (slotRest[l.asSymbol] ? 0) });
                // K=-1 -> factor 0 -> target nVoices (today); K=0 -> factor 1
                // -> target nVoices minus the resting layers
                // 27 Sept 2026: K=0 was meant to leave EVERY slot a resting
                // layer owns empty. It subtracted one voice per resting layer,
                // and the fill cycle below then handed that layer's SPARE
                // slots ("macro mid macro micro") to the others, so a macro
                // rest still raised mid and micro: the refill survived at K=0
                // (rule 1 NOT MET, 24 Sept). The slot plan is now built once,
                // the same way the loop assigns slots, and every slot of a
                // resting layer is counted. K=-1 is unchanged (factor 0).
                slotPlan = block { |b|
                    var chd = section !? { section[\chord] },
                        fs = if (chd.notNil and: { chd.size > 1 } and: { simTable.notNil })
                             { policy["voice_fill_chord"] ? "macro mid macro mid" }
                             { policy["voice_fill"] ? "macro mid macro micro" },
                        f0 = fs.split($ ).reject({ |x| x.size < 2 }),
                        f1 = f0.select({ |x| layerNames.includesEqual(x) }),
                        fl = if (f1.isEmpty) { layerNames } { f1 };
                    b.value(nVoices.max(0).collect({ |j|
                        if (j < layerNames.size) { layerNames[j] }
                            { fl[(j - layerNames.size) % fl.size] } }));
                };
                restSlots = slotPlan.count({ |l| restingLayers.includesEqual(l) });
                voiceTarget = (nVoices - (restSlots * (1 + coupleK.min(0))))
                    .round.asInteger.max(0);
                // once per window: this block runs on the keeper's tick, and
                // the first boot wrote 25-70 COUPLE lines a window (23 Sept)
                if (coupleLoggedWin != winCtr) {
                    coupleLoggedWin = winCtr;
                    wlog.value("COUPLE " ++ winCtr ++ "," ++ coupleK ++ ","
                        ++ restingLayers.size ++ "," ++ voiceTarget ++ "," ++ nVoices ++ "," ++ restSlots ++ "\n");
                };
                while { live.size < voiceTarget } {
                    // ---- A CHORD SECTION FILLS FROM THE LAYERS THAT SUSTAIN --
                    //
                    // Measured on 60 s of the delivered stream, 5 Sept: the
                    // MEDIAN SOUNDING RUN IS 0.020 s and only 19.5% exceed
                    // 0.1 s. Pitch fusion needs roughly 100-200 ms of overlap,
                    // so a 20 ms grain is about two cycles of a 100 Hz tone --
                    // a click. Placing one click at 5:4 against another does not
                    // make a major third; it makes two clicks. Roberto, having
                    // listened: "I don't think I've heard a dyad or triad yet",
                    // and the panel agreed from the other side, reporting the
                    // vertical share inside the random band.
                    //
                    // The chord machinery was working on material that cannot
                    // carry it. So when a section holds a chord of two or more,
                    // the spare voices go to macro and mid -- 0.8 s and 0.35 s
                    // grains, 90 s and 40 s spans -- which are the layers that
                    // can hold a pitch long enough to be heard as one.
                    //
                    // ONLY IN CHORD SECTIONS, and only for the SPARE voices.
                    // Each layer still gets its first voice above, so micro
                    // never disappears and the fragmentary character survives
                    // everywhere else. A size-1 chord is a single pitch class
                    // and needs no help, so it keeps the ordinary fill.
                    //
                    // A STIPULATION like voice_fill itself. The test is whether
                    // an hour of chord sections contains audible intervals, not
                    // whether this paragraph is persuasive.
                    var chd = section !? { section[\chord] },
                        fillStr = if (chd.notNil and: { chd.size > 1 }
                                      and: { simTable.notNil })
                                  { policy["voice_fill_chord"] ? "macro mid macro mid" }
                                  { policy["voice_fill"] ? "macro mid macro micro" },
                        // The fill string names layers for the SPARE voices and
                        // is written independently of layers_active, so a fill
                        // of "macro mid macro micro" would reintroduce micro
                        // during an isolation run. Filter it to the active set,
                        // and fall back to that set if filtering empties it.
                        fill0 = fillStr.split($ ).reject({ |s| s.size < 2 }),
                        fill1 = fill0.select({ |s| layerNames.includes(s) }),
                        fill = if (fill1.isEmpty) { layerNames } { fill1 },
                        vi = live.size,
                        lay = if (vi < layerNames.size)
                              { layerNames[vi] }                  // one each first
                              { fill[(vi - layerNames.size) % fill.size] },
                        // A RESTING LAYER MUST NOT BE TOPPED UP. The keeper
                        // above may leave a slot deliberately empty; if this
                        // loop then fills it from the same slot machine, the
                        // rest lasts one tick and the layer is never actually
                        // absent -- the mechanism would be built and inert,
                        // which is how the self-ingest weight sat unread for a
                        // week.
                        resting = now < (slotRest[lay.asSymbol] ? 0),
                        m = if (resting) { nil } { slotMach[lay.asSymbol] };
                    // K > -1: a resting layer's slot is not handed to another
                    // layer. With the target already reduced by the resting
                    // count, a chosen layer that happens to be resting is
                    // swapped for the next active, non-resting layer in the
                    // cycle, so the refill goes where a voice is owed.
                    // 27 Sept: at K > -1 the voice goes to the vi-th slot the
                    // plan OWES (resting layers' slots removed), so no resting
                    // layer's share moves to another layer. Voices beyond the
                    // owed plan (only when -1 < K < 0) keep the old swap.
                    if (coupleK > -1.0) {
                        var owed = (slotPlan ? []).reject({ |l| restingLayers.includesEqual(l) });
                        if (vi < owed.size) {
                            lay = owed[vi]; resting = false; m = slotMach[lay.asSymbol];
                        } {
                            if (resting) {
                                var open = layerNames.reject({ |l| now < (slotRest[l.asSymbol] ? 0) });
                                if (open.notEmpty) { lay = open[vi % open.size]; resting = false;
                                    m = slotMach[lay.asSymbol] };
                            };
                        };
                    };
                    // within a layer, reach back through recent history rather
                    // than doubling the machine the slot is already sounding
                    if (m.notNil and: { vi >= layerNames.size }) {
                        var alt = recent.detect({ |r|
                            r.notNil and: { layerOf.value(r) == lay } and: { r != m } });
                        m = alt ? m;
                    };
                    // A layer with no machine yet must not stall the loop. The
                    // fallback used to be `slotMach[\micro]` written literally,
                    // which meant micro was resurrected for any empty slot even
                    // when micro was resting, and made isolating a layer
                    // impossible however the policy was set. It now falls back
                    // WITHIN the active set, so with layers_active "macro" the
                    // only thing that can fill a macro slot is macro.
                    m = m ? ((if (coupleK > -1.0)
                                { layerNames.reject({ |l| now < (slotRest[l.asSymbol] ? 0) }) }
                                { layerNames })
                                .collect({ |l| slotMach[l.asSymbol] })
                                .detect({ |x| x.notNil })
                             ? currentMachine);   // playable, never suffixed
                    // THIS GUARD WATCHED THE WRONG FAILURE AND THE LOOP HUNG.
                    //
                    // 6 Sept 2026, 17:30. The factory formed section 1579 asking
                    // for EIGHT voices, chose the class machine `an` to fill a
                    // spare slot, and `h.stateMachine` returned something that is
                    // not an EventStreamPlayer. fireVoice logs UNTRACKED for that
                    // and adds NOTHING to `live`, so live.size never reached
                    // nVoices and this `while` never terminated.
                    //
                    // sclang pegged one core at 98.7% inside a Routine, which
                    // stops the language entirely: no further windows, no further
                    // voices, and the sounding voices decayed to nothing. scsynth
                    // stayed alive at 0.2% holding the write end of the FIFO, so
                    // the splitter never saw a writer leave and its silence-fill
                    // never triggered. The relay went on serving a healthy 200 at
                    // -91 dB. Sixteen minutes of dead air, 42,619 UNTRACKED lines
                    // for one machine, and every process reporting itself up.
                    //
                    // The nil case was already guarded here, one line down, by
                    // shrinking nVoices -- so the shape of the failure had been
                    // anticipated and only one of its two causes was covered. A
                    // machine can also be non-nil, fire without error, and add no
                    // voice, and that is the case that hung.
                    //
                    // PROGRESS IS THE TEST, not whether the machine looked usable
                    // before it ran. If a fill attempt does not grow the
                    // population, this tick stops filling and the keeper tries
                    // again in 0.25 s with whatever the factory has become. The
                    // cost is a temporarily thinner texture, which is audible and
                    // recoverable; the cost of the loop was the whole factory.
                    if (m.isNil) { nVoices = live.size; voiceTarget = live.size } {
                        var before = live.size;
                        fireVoice.value(m);
                        if (live.size == before) {
                            wlog.value("FILL_STALL " ++ winCtr ++ "," ++ m ++ ","
                                ++ lay ++ "," ++ live.size ++ "," ++ nVoices ++ "\n");
                            nVoices = live.size; voiceTarget = live.size;
                        };
                    };
                };
            };
            0.25.wait;
        };
    }).play(AppClock);

    // ---- SERVER WATCHDOG, ON ITS OWN CLOCK -----------------------------
    // 17 September 2026, 06:02: scsynth segfaulted inside AppKit's
    // appearance-change handler and sclang kept running until at least 09:14 --
    // three hours -- writing 1,951 VSNAP and 477 REST lines for window 1422
    // alone, while nothing was rendered and nothing was heard. The process was
    // present, the log file was growing, its mtime was current, and the factory
    // log printed "OK: Playing State" throughout, with no error before or after.
    //
    // WHY IT IS HERE AND NOT IN THE WINDOW LOOP. The first version of this check
    // sat next to `winCtr = winCtr + 1`, at the window boundary. Tested against a
    // killed server on 17 Sept it NEVER FIRED: window turnover is driven by
    // analysis events arriving from the server, so when the server dies the
    // window stops turning over and any check living there stops running with
    // it. The detector had been wired to the code path that the fault disables.
    // Measured, not reasoned: windows froze at 6, the log went on growing with
    // VSNAP lines, and no SERVER_LOST was ever written.
    //
    // So it lives on AppClock beside the voice keeper -- the same independent
    // clock that went on writing for three hours, which is exactly the clock that
    // has to be able to notice.
    //
    // serverRunning is a sound signal here: tools/test_server_loss_detected.scd
    // boots a server, kills it with SIGKILL as a segfault would, and the flag
    // goes false after 0.26 s.
    //
    // Three consecutive misses at 5 s, not one. The alive thread can drop a reply
    // under load, and a false SERVER_DEAD that halts a good run is its own damage.
    Routine({
        var gone = 0;
        loop {
            5.0.wait;
            if (server.serverRunning.not) {
                gone = gone + 1;
                if (gone == 1) {
                    wlog.value("SERVER_LOST " ++ winCtr ++ ",first_miss\n");
                    ("SERVER_LOST at window " ++ winCtr
                        ++ ": scsynth stopped answering.").postln;
                };
                if (gone == 3) {
                    wlog.value("SERVER_DEAD " ++ winCtr ++ ",misses=" ++ gone ++ "\n");
                    ("SERVER_DEAD at window " ++ winCtr
                        ++ ": scsynth has not answered for " ++ (gone * 5)
                        ++ " s. Stopping, so this log cannot be read as a "
                        ++ "continuous run.").postln;
                    running = false;
                    { logFile.flush }.try;
                    // EXIT, rather than only clearing the flag. `running = false`
                    // gates the analysis block alone; VSNAP, REST and REST_HELD
                    // come from the voice keeper on this same clock and would go
                    // on writing, which is what produced three hours of phantom
                    // log. Exiting also makes the process table honest, lets the
                    // two-arm runner see a dead factory instead of a stalled one,
                    // and on the replica triggers the stopped-streaming email.
                    1.0.wait;
                    { logFile.flush }.try;
                    1.exit;
                };
            } {
                if (gone > 0) {
                    wlog.value("SERVER_BACK " ++ winCtr ++ ",misses=" ++ gone ++ "\n");
                    gone = 0;
                };
            };
        };
    }).play(AppClock);

    // master first, then the listener, so the factory hears the limited signal
    // THE CEILING IS NOW A POLICY VALUE, AND LOWER, BECAUSE m3 CANNOT SEE PAST
    // THE ENCODER.
    //
    // Measured over the hour of 3 Sept 17:41-18:42: the DELIVERED stream peaked
    // at 1.043 -- above full scale -- while m3_no_clipping read 0.0 in every one
    // of 410 windows. Both are correct. The limiter holds the SAMPLE peak at its
    // ceiling and m3 measures that signal; the MP3 encoder then reconstructs a
    // waveform whose INTERSAMPLE peaks exceed the samples it was given, and
    // nothing in the factory looks at the result.
    //
    // m3 is the never-tolerated clause. It is the one that stopped the factory
    // on 2 Sept. A never-tolerated bound with a blind spot on the side the
    // listener is actually on is a hole in the governance layer, not an audio
    // nuisance, and it is recorded as such in the charter.
    //
    // 0.85 is roughly -1.4 dBFS, which is the headroom mastering practice
    // leaves for exactly this reconstruction overshoot. It is a stipulation:
    // the right way to set it is to measure the delivered true peak and lower
    // the ceiling until it sits below unity, which is what
    // tools/delivered_peak.py exists to do.
    // THE THREE RETURNS, BEFORE THE MASTER. Pbind synths are added at the head
    // of the default group, these at its tail now, \master at its tail a
    // moment later: sources -> returns -> master, in that order. The bus
    // variables the originals read are set here, once the buses exist; until
    // this line they are [0], which is what they had always been.
    {
        var fd = (policy["fx_depth"] ? "1.0").asFloat.clip(0.0, 2.0), spacer,
            mk = { |room, damp|
                var b = Bus.audio(server, 2);
                Synth.tail(server.defaultGroup, \fxReturn,
                    [\in, b.index, \room, room, \damp, damp, \depth, fd]);
                b.index };
        // \master writes its output to bus 2 as well as 0 (the second pair
        // of the four-channel aggregate). With two output channels bus 2 is
        // the first private bus, so the first return allocated here landed
        // on it and the master signal fed the short reverb: a feedback path.
        // Seen at the 12:14 boot on 22 Sept (returns on 2/4/6). A spacer
        // keeps 2-3 clear whenever the device has fewer than four outputs.
        if (server.options.numOutputBusChannels < 4) { spacer = Bus.audio(server, 2) };
        ~reverbShortBus = [mk.value(0.35, 0.6)];
        ~reverbMidBus   = [mk.value(0.70, 0.5)];
        ~reverbLongBus  = [mk.value(0.93, 0.3)];
        ("--- fx returns: short " ++ ~reverbShortBus ++ " mid " ++ ~reverbMidBus
            ++ " long " ++ ~reverbLongBus ++ " depth " ++ fd).postln;
    }.value;

    Synth.tail(server.defaultGroup, \master,
        [\gain, (policy["master_gain"] ? "4.0").asFloat,
         \ceiling, (policy["master_ceiling"] ? "0.85").asFloat,
         \lpf,  (policy["master_lpf"] ? "7000").asFloat]);

    // Capture what actually reaches the speakers. The patina was diagnosed
    // twice from the CORPUS and from single-machine OFFLINE renders, and both
    // diagnoses were wrong: the grain fade did not remove it. Offline renders
    // carry almost no high-frequency energy (cr 0.0098 above 8 kHz, gl 0.0013),
    // so whatever it is, it is not visible in the material or in one machine
    // rendered alone. Measure the live sum instead of reasoning about it.
    // CAPTURE, ROTATED -- the substrate for self-ingestion.
    //
    // Rotation here is not housekeeping, it is the MECHANISM. SuperCollider
    // writes an AIFF's SSND chunk size only when the file is CLOSED, so a
    // growing capture is undecodable: ffprobe reports duration=N/A and ffmpeg
    // extracts nothing (measured 28 Aug -- two attempts returned 72 and 92
    // bytes). A chunk becomes ingestible at the moment it closes, and at no
    // point before. Nothing can granulate the live file.
    //
    // What this replaces: a single unbounded renders/live_capture.wav at
    // 1.27 GB/hour with a FIXED NAME, so every run silently overwrote the last
    // and two concurrent factories wrote the same path. It had reached 745 MB
    // before anyone looked.
    // capture_dir is a policy key so the captures land on the external SSD
    // rather than the internal disk. Roberto, 28 Aug: "the external SSD drive
    // will remain the storage device we use for this project, I don't want to
    // use my computer's limited internal memory."
    capDir = (policy["capture_dir"] ? (root ++ "/renders/capture")).asString;
    File.mkdir(capDir);
    runStamp = Date.getDate.stamp;
    capName = {
        capDir ++ "/cap_" ++ runStamp ++ "_"
            ++ capIdx.asString.padLeft(4, "0") ++ ".aiff";
    };
    // CAPTURE IS NO LONGER DONE HERE. Default off; set capture_in_sc to "1" only
    // to reproduce the failure described below.
    //
    // WHY IT MOVED OUT. Rotating with stopRecording/record produced a correct
    // FIRST chunk and then a 0-BYTE second chunk, on every run:
    //     cap_260830_163355_0000.aiff   202M
    //     cap_260830_163355_0001.aiff     0B
    // SuperCollider's Recorder frees its buffer on stop and re-prepares on the
    // next record, which needs a server.sync; the restart did not survive that
    // on an AppClock routine. Worse, the calls were wrapped in .try, so the
    // failure was SWALLOWED and the factory reported "CAPTURE rotating" while
    // recording nothing. Self-ingestion eats rotated captures, so it would have
    // silently starved after the first ten minutes of any run.
    //
    // ffmpeg's segment muxer does the same job and closes every file properly
    // by construction. Measured: 4 segments over 35 s, all non-empty, all with
    // valid durations, all decoding clean. It reads the same BlackHole device
    // the encoder already reads, which macOS permits.
    //
    // The general lesson, and the second time today: .try around an operation
    // whose success is never checked converts a loud failure into a silent one.
    // The capture is now started by stream/run_stream.sh, where it can be seen.
    // CAPTURE GOES INTO A NAMED PIPE, 1 Sept. Roberto: "but we are planning to
    // run this forever." Every file-based topology needed a periodic restart to
    // bound disk, and a restart contradicts kernel.json's k2_continuous -- "a
    // factory with a start and an end is a work; a factory that only runs
    // forward is a factory" -- and the public page's "you may never witness the
    // system beginning or ending". A pipe stores nothing, so nothing accumulates.
    //
    // RAW, NOT AIFF, AND THE REASON IS NOT STYLISTIC. AIFF rewrites its chunk
    // size at close by seeking back to the header, and a pipe has nowhere to
    // seek to. Raw carries no header at all. Verified through NRT before this
    // was written: 8.001 s arrived intact, peak exactly 0.200, both test tones
    // on frequency, largest sample-to-sample step 0.006.
    //
    // ENDIANNESS. libsndfile writes raw in HOST order, little on arm64. The old
    // AIFF path fed the encoder `-f f32be` because AIFF is big-endian; the FIFO
    // path must use f32le. Getting this wrong yields NaNs, not silence, so it
    // would be loud -- but it cost me one wrong measurement already today.
    //
    // START ORDER: opening a FIFO for write BLOCKS until a reader attaches, so
    // fifo_splitter.py must be running first or the factory hangs here at boot.
    if ((policy["capture_in_sc"] ? "0").asString == "1") {
        server.recHeaderFormat = "raw";
        server.recSampleFormat = "float";
        server.record(
            (policy["capture_fifo"] ? (capDir ++ "/live.fifo")).asString,
            numChannels: 2);
        ("CAPTURE -> FIFO "
            ++ (policy["capture_fifo"] ? (capDir ++ "/live.fifo"))).postln;
        CmdPeriod.doOnce({ { server.stopRecording }.try });
    } {
        ("CAPTURE handled by run_stream.sh (ffmpeg segment) -> " ++ capDir).postln;
    };
    Synth.tail(server.defaultGroup, \selfListen);
    // THE POOL RESET (26 Sept 2026). When scsynth's real-time pool is gone,
    // every /s_new fails and nothing recovers on its own: on 23 Sept the
    // stream was silent for four hours, on 25 Sept the factory stalled for
    // twelve, printing "alloc failed" 8.6 million times. The server reports
    // each failure on /fail. On the first one in any 30 s, every live player
    // is stopped so its voices end at their envelopes and the pool refills;
    // the keeper's top-up then rebuilds the texture from the slots. Logged
    // with the machines that were sounding, so the record names the cause
    // instead of the symptom. A machine that does this is the writer's
    // polyphony bound's business (MachineWriter.polyphonyOf); this is the
    // net under it.
    OSCdef(\poolfail, { |msg|
        var txt = msg[2].asString;
        if (txt.contains("alloc failed") and: { (Main.elapsedTime - poolResetAt) > 30 }) {
            poolResetAt = Main.elapsedTime;
            poolResets = poolResets + 1;
            live.do { |v| { v[0].stop }.try };
            wlog.value("POOL_RESET " ++ winCtr ++ "," ++ poolResets ++ ","
                ++ slotMach.values.collect(_.asString).join("|") ++ "\n");
            ("POOL_RESET " ++ poolResets ++ ": real-time pool exhausted; "
                ++ live.size ++ " players stopped; sounding: "
                ++ slotMach.values.collect(_.asString).join(" ")).postln;
        };
    }, '/fail', server.addr);

    OSCdef(\master, { |msg|
        // NAME THE BLOW-UP AT THE MOMENT IT HAPPENS. 16 Sept 2026.
        //
        // 12 of 1423 windows across twelve runs reported a bus peak above 2.0,
        // the largest 1.48e25, delivered to the listener as ~13 ms bursts of
        // hard-clipped full-scale audio. That is why m3_no_clipping has never
        // passed: it is a standing defect detector and it was right.
        //
        // Attribution failed on six events because all the log held was a
        // window number. Which layer's slot, which machine, and how many voices
        // were live is known HERE and nowhere else by the time the window
        // closes. Threshold 2.0: a normalised bus peak above it is not audio,
        // so this cannot fire on loud music.
        if (msg[3] > 2.0) {
            var slots = layerNames.collect({ |l|
                l ++ "=" ++ (slotMach[l.asSymbol] ? "-") }).join("|");
            wlog.value("BLOWUP " ++ winCtr ++ "," ++ msg[3]
                ++ "," ++ live.size ++ "," ++ slots
                ++ "," ++ (currentMachine ? "-") ++ "\n");
        };
        masterPeak = max(masterPeak, msg[3]);
        if (msg[4] > 0) { clipReports = clipReports + 1 };
        masterReports = masterReports + 1;
    }, '/master');

    // THE VOICE PROBE'S RECEIVER (#106). The SynthDef side is at \playback.
    //
    // /master says the BUS went past 2.0. It cannot say whether that was many
    // voices summing or one voice misbehaving, and the whole of 16 Sept was
    // spent refuting summation explanations: grains, reverb, polyphony, BPF
    // gain, amp, the DSP stage. VOICES showed blow-up windows average 1.11
    // macro voices against 2.01 elsewhere, so it is not summation.
    //
    // This fires from inside a single \playback synth when that ONE voice
    // exceeds full scale, and carries the parameters it was handed. If the
    // parameters are in range and the output is not, the fault is in the synth
    // graph; if a parameter is out of range, this names which and what asked.
    //
    // msg = [/voiceblow, nodeID, replyID, peak, cutoff, rate, amp, rq, buf, rel]
    OSCdef(\voiceblow, { |msg|
        var slots = layerNames.collect({ |l|
            l ++ "=" ++ (slotMach[l.asSymbol] ? "-") }).join("|");
        voiceBlowCtr = (voiceBlowCtr ? 0) + 1;
        // rate-limited: one voice ringing for nine seconds would otherwise write
        // 72 identical lines and bury the distinct events
        if ((voiceBlowCtr < 400) and: { (voiceBlowCtr % 4) == 1 }) {
            wlog.value("VOICEBLOW " ++ winCtr
                ++ ",peak=" ++ msg[3].round(0.001)
                ++ ",cutoff=" ++ msg[4].round(0.01)
                ++ ",rate=" ++ msg[5].round(0.0001)
                ++ ",amp=" ++ msg[6].round(0.0001)
                ++ ",rq=" ++ msg[7].round(0.001)
                ++ ",buf=" ++ msg[8].asInteger
                ++ ",rel=" ++ msg[9].round(0.01)
                ++ "," ++ slots
                ++ "," ++ (currentMachine ? "-") ++ "\n");
        };
    }, '/voiceblow');

    // THE REQUEST CHANNEL (#109). msg = [addr, node, id, cutoff, rq, rate, buf]
    //
    // This fires on a REQUEST outside \playback's envelope, not on a failure.
    // Nothing audible need be wrong: the Nyquist clip has already made the value
    // safe. What it records is the factory's reach -- what it wanted, before the
    // call site trimmed it -- which is the one thing no log held when the
    // blow-up was being hunted, and the reason that hunt took a day.
    //
    // Deduplicated on the rounded value, because a voice holding an
    // out-of-envelope cutoff for nine seconds is ONE fact, not eighteen.
    OSCdef(\cutoffclamp, { |msg|
        var v = msg[3].round(1).asInteger, seen;
        cutoffSeen = cutoffSeen ? IdentityDictionary.new;
        seen = cutoffSeen[v.asSymbol] ? 0;
        cutoffSeen[v.asSymbol] = seen + 1;
        // first sighting of a value is written in full; repeats are counted and
        // reported every a hundredth time, so a persistent request stays visible
        // without filling the log
        if ((seen == 0) or: { (seen % 100) == 0 }) {
            var slots = layerNames.collect({ |l|
                l ++ "=" ++ (slotMach[l.asSymbol] ? "-") }).join("|");
            wlog.value("CUTOFFREQ " ++ winCtr
                ++ ",cutoff=" ++ v
                ++ ",rq=" ++ msg[4].round(0.01)
                ++ ",rate=" ++ msg[5].round(0.001)
                ++ ",buf=" ++ msg[6].asInteger
                ++ ",n=" ++ (seen + 1)
                ++ "," ++ slots
                ++ "," ++ (currentMachine ? "-") ++ "\n");
        };
    }, '/cutoffclamp');

    "FACTORY RUNNING. Edit mutable/ while it plays. ctrl-C to stop.".postln;
    CmdPeriod.doOnce({ logFile.close });
});
)
