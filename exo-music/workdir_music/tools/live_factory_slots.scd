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
    notes, noteName, mutableDir,
    weights, policy, runtimeMachines, mtimes,
    loadJSON, loadMutable, features, means, acc, accN,
    prevWeights, recent, targets, currentState, prevState, live,
    audib, pending, saveAudibility, ampFloor,
    desc, dKeys, target, neighbourhood, nearest, grainPath, dvec, dn,
    world, worldAt, worldN,
    section, sections, sectionAge, nextSection, pickSection,
    nVoices = 2, evCtr = 0, winCtr = 0, nextWindow = 4, silentWindows = 0,
    running = true, reloads = 0,
    masterPeak = 0, clipReports = 0, masterReports = 0,
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
    slotMach, slotDwell, layerNames,
    memPath, loadMemory, saveMemory, transitions, priorRuns = 0, lastSectionId, succ,
    trace, attend, attnReport,
    macroBufs, macroDesc, macroVec, macroN, macroSucc, macroPath, layerOf,
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
layerOf = { |m|
    var spec = weights !? { weights[m.asString] };
    if (spec.notNil and: { spec["layer"].notNil }) { spec["layer"].asString } { "micro" };
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

loadMemory = {
    var m = loadJSON.value(memPath), n = 0;
    transitions = Dictionary.new;
    trace = List.new;
    if (m.notNil) {
        (m["trace"] ? []).do { |e|
            var st = (e["s"] ? []).collect({ |v| v.asFloat });
            if (st.size == dKeys.size) {
                trace.add(IdentityDictionary[\state -> st,
                    \machine -> (e["m"] ? "sc").asSymbol,
                    \run -> (e["r"] ? "0").asInteger]);
            };
        };
        priorRuns = (m["runs"] ? "0").asInteger;
        (m["sections"] ? []).do { |s|
            var centre = (s["centre"] ? []).collect({ |v| v.asFloat });
            // a memory written against a different descriptor space is not
            // comparable; drop it rather than silently mixing geometries
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
            transitions[k.asString] = v.asInteger };
        op.loadDict(m["operator"]);
        op.compute;
    };
    ("MEMORY " ++ n ++ " sections recalled from " ++ priorRuns ++ " prior run(s), "
        ++ transitions.size ++ " transitions, " ++ trace.size ++ " trace states").postln;
    op.report.postln;
    n
};

saveMemory = {
    var f = File(memPath, "w"), first = true;
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
            f.write("    \"" ++ k ++ "\": " ++ transitions[k]);
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
                    f.write("\"" ++ b ++ "\": " ++ v);
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
    };
};

loadMutable = { |verbose = false|
    var wPath = mutableDir ++ "/weights.json",
        pPath = mutableDir ++ "/policy.json",
        changed = false, w, p, files;

    // weights
    if (File.mtime(wPath) != (mtimes[\weights] ? 0)) {
        w = loadJSON.value(wPath);
        if (w.notNil) { weights = w["machines"]; mtimes[\weights] = File.mtime(wPath);
            changed = true; if (verbose) { "  reloaded weights.json".postln } };
    };
    // policy
    if (File.mtime(pPath) != (mtimes[\policy] ? 0)) {
        p = loadJSON.value(pPath);
        if (p.notNil) { policy = p; mtimes[\policy] = File.mtime(pPath);
            changed = true; if (verbose) { "  reloaded policy.json".postln } };
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
wlog = { |s|
    if (logFile.isNil or: { logFile.isOpen.not }) {
        logFile = File(logPath, "a");
        logReopens = logReopens + 1;
        ("LOG REOPENED #" ++ logReopens ++ " at window " ++ winCtr
            ++ " -- the handle had died; writes were being dropped").postln;
        if (logFile.isOpen) {
            logFile.write("# LOG_REOPENED " ++ logReopens ++ " win " ++ winCtr ++ "\n");
        };
    };
    logFile.write(s);
    logFile.flush;
};

mtimes = IdentityDictionary.new;
runtimeMachines = IdentityDictionary.new;
recent = List.new;
op = TransferOperator.new;   // P222-224, in lib/TransferOperator.sc
// The mutable dir is passed so the bridged ledger PERSISTS across runs. Without
// it the retirement rule is per-run, which is not retirement: the pair carrying
// the most negative residual wins again on every boot, and the 26 Aug pattern of
// 154 bridges across 7 transitions returns one run at a time.
layerNames = ["macro", "mid", "micro"];
slotMach = IdentityDictionary.new;
slotDwell = IdentityDictionary.new;
mw = MachineWriter.new(mutableDir,
    (policy !? { policy["machine_min_deviation"] } ? "0.25").asFloat);

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
// recall before the first section is chosen, so pickSection's RETURN branch can
// reach regions found in earlier performances rather than only this one
loadMemory.value;
section = nil;
sectionAge = 0;
nextSection = 8;

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
            // nothing has followed this region yet, so fall back to uniform
            s0 = sections[sections.size.rand];
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
        s0
    } {
        var s0 = IdentityDictionary[
            \id -> sections.size,
            \centre -> Array.fill(dKeys.size, { rrand(0.15, 0.85) }),
            \voices -> rrand((policy["voices_min"] ? "1").asInteger,
                             (policy["voices_max"] ? "4").asInteger),
            \family -> avail.scramble.keep(rrand(4, 8)) ];

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
    var pool, path, cur, dist2;
    dist2 = { |i, j|
        var acc = 0, a = dvec[i], bb = dvec[j];
        dKeys.size.do { |x| acc = acc + ((a[x] - bb[x]).squared) };
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

nearest = { |k|
    var dist = Array.fill(dn, { |i|
        var acc = 0, v = dvec[i];
        dKeys.size.do { |j| acc = acc + ((v[j] - target[j]).squared) };
        acc
    });
    dist.order.keep(k).collect({ |i| desc["index"][i].asInteger })
};

server.waitForBoot({

    SynthDef(\playback, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0|
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
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:0),
            env = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction:2);
        sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    SynthDef(\playbackHP, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0|
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
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:0),
            env = EnvGen.kr(Env.new([0,1,0],[atk.max(0.03),rel],[1,-1]), doneAction:2);
        sig = HPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    SynthDef(\playgran, { |out=0, freq=10, amp=0.3, rate=1.0, atk=0.5, rel=4, cutoff=1500, buf, pan=0|
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
        sig = BPF.ar(sig, fenv); Out.ar(out, sig * env);
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
        var raw = In.ar(0, 2) * gain,
            over = (raw.abs > 0.99),
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
    macroPath = { |k|
        var path = List.new, cur, pool, dist2;
        if (macroVec.isNil) { nil } {
            dist2 = { |i, j| var acc = 0, a = macroVec[i], bb = macroVec[j];
                dKeys.size.do { |x| acc = acc + ((a[x] - bb[x]).squared) }; acc };
            pool = (0 .. macroN - 1).scramble.keep((k * 3).min(macroN)).asList;
            cur = pool[0]; path.add(cur); pool.remove(cur);
            (k - 1).do {
                var best = nil, bd = 1e9, nxt = macroSucc !? { macroSucc[cur] };
                if (nxt.notNil and: { 1.0.rand < (policy["macro_continuity"] ? policy["continuity"] ? "0.5").asFloat }
                    and: { path.includes(nxt).not }) { best = nxt } {
                    pool.do { |c| var d = dist2.value(c, cur); if (d < bd) { bd = d; best = c } };
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
    midPath = { |k|
        var path = List.new, cur, pool, dist2;
        if (midVec.isNil) { nil } {
            dist2 = { |i, j| var acc = 0, a = midVec[i], bb = midVec[j];
                dKeys.size.do { |x| acc = acc + ((a[x] - bb[x]).squared) }; acc };
            pool = (0 .. midN - 1).scramble.keep((k * 3).min(midN)).asList;
            cur = pool[0]; path.add(cur); pool.remove(cur);
            (k - 1).do {
                var best = nil, bd = 1e9, nxt = midSucc !? { midSucc[cur] };
                if (nxt.notNil and: { 1.0.rand < (policy["mid_continuity"] ? policy["continuity"] ? "0.6").asFloat }
                    and: { path.includes(nxt).not }) { best = nxt } {
                    pool.do { |c| var d = dist2.value(c, cur); if (d < bd) { bd = d; best = c } };
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
    };

    h = Handler.new;
    ~sampleSize = 1.0; ~numPairs = 1;
    ~dryBus = [0]; ~reverbShortBus = [0]; ~reverbLongBus = [0]; ~reverbMidBus = [0]; ~fr = 20;

    "--- loading mutable layer".postln;
    loadMutable.value(true);
    if (weights.isNil) { "FATAL: no weights.json".postln; 1.exit };

    // running means, seeded from BehaviorTrimmed's calibrated values so the
    // live factory starts where the class starts
    means = IdentityDictionary[
        \density -> 0.10, \windowsize -> 0.09, \percpitch -> 1.0, \avgcent -> 3132,
        \avgrolloff -> 1560, \avgflat -> 0.17, \avgrms -> 0.016 ];
    prevWeights = IdentityDictionary.new;
    acc = IdentityDictionary.new; features.do { |f| acc[f] = 0 }; accN = 0;
    currentState = \sc; prevState = nil;
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
                var newMeans, deltas, raw, chosen, temp, pen, hist, avail, line, played, machineArgs;

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
                    sectionAge = 0;
                    nextSection = rrand((policy["section_windows_min"] ? "6").asInteger,
                                        (policy["section_windows_max"] ? "18").asInteger);
                    if (desc.notNil) { target = section[\centre].copy };
                    // record the move and the visit, then write memory out. The
                    // transition table is the only thing here that knows about
                    // ORDER between regions, which is what a later run would
                    // need to do more than sample the same places again.
                    section[\visits] = (section[\visits] ? 0) + 1;
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
                        secOp.compute;
                        wlog.value("SECOP " ++ winCtr
                            ++ "," ++ secOp.gap.round(0.0001)
                            ++ "," ++ secOp.cells.size
                            ++ "," ++ secOp.total
                            ++ "," ++ (secOp.stationary !? { |s|
                                s.maxIndex !? { |i| secOp.cells[i] } } ? "-")
                            ++ "\n");
                    };
                    saveMemory.value;
                    ("SECTION " ++ section[\id]
                        ++ (if (section[\recalled] == true) { " (RECALLED)" } { " (new)" })
                        ++ "  voices " ++ section[\voices]
                        ++ "  for " ++ nextSection ++ " windows").postln;
                };
                // machines outside the section's family are strongly damped, so
                // a section HAS a character instead of being a fresh draw
                avail = avail.reject({ |m|
                    section[\family].includes(m).not and: { 0.85.coin } });
                if (avail.size < 2) { avail = section[\family] };

                temp = (policy["temperature"] ? "1.0").asFloat;
                pen  = (policy["novelty_penalty"] ? "0.0").asFloat;
                hist = (policy["history_len"] ? "12").asFloat;

                raw = avail.collect({ |m|
                    var spec = weights[m.asString], v, lo, hi, idx, dens;
                    if (spec.isNil) {
                        // a runtime machine with no weights entry is selectable
                        // but never preferred: bias only
                        v = ((prevWeights[m] ? 0) * 100) + 5; lo = 0.0; hi = 1.0;
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
                    if (ow <= 0) { brk.value };
                    dom = op.dominantOver(avail);
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
                            pick = pool.wchoose(
                                pool.collect({ |m| (prevWeights[m] ? 1.0).max(1e-6) })
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
                currentState = slotMach[\micro] ? slotMach[\mid]
                               ? slotMach[\macro] ? avail[raw.windex];
                avail.do { |m, i| prevWeights[m] = raw[i] };

                // the trajectory, one entry per window: where it was, and what it
                // played there. This is what attention queries, and it accrues
                // whether or not attention is switched on -- so a run with the
                // weight at zero still LAYS DOWN memory for a later run to use.
                if (target.notNil) {
                    trace.add(IdentityDictionary[\state -> target.copy,
                        \machine -> currentState, \run -> priorRuns]);
                };

                // one transition per window: which behaviour followed which
                op.observe(currentState);
                if (winCtr % 3 == 0) { op.compute };

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
                    made = mw.propose(op, weights, mutableDir ++ "/machines",
                        (policy["acquire_mode"] ? "gap"));
                    if (made.notNil) {
                        ("ACQUIRED " ++ made[0] ++ "  bridging " ++ made[1] ++ " -> "
                            ++ made[2] ++ "  dur " ++ made[3].round(0.001)
                            ++ "  " ++ made[4]).postln;
                        wlog.value("ACQUIRED " ++ winCtr ++ "," ++ made[0] ++ ","
                            ++ made[1] ++ "," ++ made[2] ++ "," ++ made[3].round(0.0001)
                            ++ "," ++ made[4] ++ "\n");
                        // it becomes selectable at the next reload, and the
                        // factory has never stopped
                        loadMutable.value(true);

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
                        if (section.notNil and: {
                            section[\family].includes(made[0]).not }) {
                            section[\family] = section[\family] ++ [made[0]];
                            wlog.value("FAMILY_ADMIT " ++ winCtr ++ ","
                                ++ made[0] ++ "," ++ section[\id] ++ "\n");
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

                recent.addFirst(currentState);
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
                    var spec = weights[currentState.asString],
                        step = if (spec.notNil and: { spec["drift"].notNil })
                                { spec["drift"].asFloat }
                                { (policy["target_drift"] ? "0.08").asFloat };
                    // drift, but pulled back toward the section centre, so the
                    // factory explores a REGION instead of wandering off
                    target = target.collect({ |v, j|
                        var pull = (policy["section_pull"] ? "0.25").asFloat,
                            wp = (policy["world_pull"] ? "0.0").asFloat,
                            c = section[\centre][j], wv;
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
                        v.clip(0, 1) });
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

                line = now.round(0.01).asString ++ "," ++ winCtr ++ "," ++ currentState
                    ++ "," ++ (if (runtimeMachines[currentState].notNil) {"runtime"} {"class"})
                    ++ "," ++ amp.round(0.00001) ++ "," ++ cent.round(0.1)
                    ++ "," ++ flat.round(0.0001) ++ "," ++ avail.size ++ "," ++ reloads ++ "," ++ live.size ++ "," ++ nVoices
                    ++ "," ++ (audib[currentState] ? 0.5).round(0.01)
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
                    ("t=" ++ now.round(0.1) ++ "s  win=" ++ winCtr ++ "  " ++ currentState
                        ++ "  amp=" ++ amp.round(0.0001) ++ "  pool=" ++ avail.size
                        ++ "  reloads=" ++ reloads ++ "  LIVE=" ++ live.size
                        ++ "  gap=" ++ op.gap.round(0.001)
                        ++ "  peak=" ++ masterPeak.round(0.001)
                        ++ "  clip=" ++ (clipReports / max(1, masterReports)).round(0.001)).postln;
                };
                wlog.value("OPERATOR " ++ winCtr ++ "," ++ op.gap.round(0.0001)
                    ++ "," ++ op.lambda2.round(0.0001) ++ "," ++ op.cells.size
                    ++ "," ++ (op.stationary !? { op.cells[op.stationary.maxIndex] } ? "-")
                    ++ "," ++ op.total ++ "\n");
                // REQUEST win,fires,events,meanAmp -- the demand side of the
                // window, to sit beside MASTER's supply side. Counters reset
                // here so each line covers exactly one window.
                wlog.value("REQUEST " ++ winCtr ++ "," ++ fires
                    ++ "," ++ evN
                    ++ "," ++ (evAmpSum / max(1, evN)).round(0.00001) ++ "\n");
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
                nb, handed,
                args = curArgs;
            // the machine's own measured rate decides which corpus it sees
            if (lay == "macro" and: { macroBufs.notNil }) {
                // the cached per-window path, NOT a fresh walk: computing it in
                // fireVoice meant ~27,000 distance calls every 0.25 s on the
                // language thread, which froze the factory at four windows
                nb = macroNb ? (0 .. macroN - 1);
                handed = nb.collect({ |i| macroBufs[i] }).reject({ |x| x.isNil });
                if (handed.size < 1) { handed = macroBufs };
            } { if (lay == "mid" and: { midBufs.notNil }) {
                nb = midNb ? (0 .. midN - 1);
                handed = nb.collect({ |i| midBufs[i] }).reject({ |x| x.isNil });
                if (handed.size < 1) { handed = midBufs };
            } {
                nb = neighbourhood ? (0 .. bufs.size - 1);
                handed = nb.collect({ |i| bufs[i] }).reject({ |x| x.isNil });
                if (handed.size < 1) { handed = bufs };
            } };
            played.add(m);
            fires = fires + 1;
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
                        pl = Pbindf(
                            Pmul(\amp, arc,
                                runtimeMachines[m].value(handed, args)),
                            \amp, Pfunc({ |ev|
                                var a = (ev[\amp] ? 0).asFloat;
                                evN = evN + 1; evAmpSum = evAmpSum + a; a })
                        ).play;
                    if (pl.notNil) { live.add([pl, deadline, Main.elapsedTime, lay]) };
                }.try({ |err|
                    wlog.value("PLAY_FAIL " ++ m ++ " " ++ err.errorString ++ "\n") });
            } {
                {
                    var pl;
                    h.settings([m, args]);
                    pl = h.stateMachine(handed);
                    // a machine may start more than one pattern; every one of
                    // them has to be bounded, or it becomes a permanent layer
                    pl = if (pl.isKindOf(Collection)) { pl.asArray } { [pl] };
                    pl.do { |p|
                        if (p.isKindOf(EventStreamPlayer)) { live.add([p, deadline, Main.elapsedTime, lay]) } {
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
                layerNames.do { |lay|
                    var m = slotMach[lay.asSymbol],
                        held = live.count({ |e| (e[3] ? "") == lay });
                    if (m.notNil and: { held < 1 }) { fireVoice.value(m) };
                };
                // and top up to nVoices from the fastest slot, so density is
                // still the factory's to choose through voices_follow
                while { live.size < nVoices } {
                    // the newest voice takes the current machine; older slots
                    // reach back through `recent`, so parallel voices are not
                    // the same machine twice
                    var vi = live.size,
                        m = case
                            { vi == 0 } { currentState }
                            { vi == 1 } { prevState ? currentState }
                            { recent[(vi - 1).min(max(0, recent.size - 1))] ? currentState };
                    fireVoice.value(m);
                };
            };
            0.25.wait;
        };
    }).play(AppClock);

    // master first, then the listener, so the factory hears the limited signal
    Synth.tail(server.defaultGroup, \master,
        [\gain, (policy["master_gain"] ? "4.0").asFloat,
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
    OSCdef(\master, { |msg|
        masterPeak = max(masterPeak, msg[3]);
        if (msg[4] > 0) { clipReports = clipReports + 1 };
        masterReports = masterReports + 1;
    }, '/master');
    "FACTORY RUNNING. Edit mutable/ while it plays. ctrl-C to stop.".postln;
    CmdPeriod.doOnce({ logFile.close });
});
)
