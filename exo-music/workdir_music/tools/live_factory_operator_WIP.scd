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
// The operator lives in its OWN top-level block, using environment
// variables. The factory block is 1400 lines and SuperCollider compiles it
// as a single function; adding this to it pushed past a per-function limit
// and the whole file then executed NOTHING, with no error of any kind --
// the fourteenth 'reports success, produces nothing' defect in this project.
(
// ---- THE TRANSFER OPERATOR ------------------------------------------
// SuperDark Factory P222-224:
//
//   "partition the factory's observable behavior into cells... count how often
//    behavior in one cell leads to behavior in another. The table of those
//    counted tendencies is the operator... the operator's eigenstates are the
//    special maps that fade without changing shape: patterns of more or less
//    reliable behavior. The operator's spectral gap is the distance between
//    those few slow-fading patterns and everything beneath them."
//
// A cell here is a MACHINE -- the coarsest useful partition of observable
// behaviour, and dense enough to estimate from a few hundred windows. Counts
// accumulate across runs, so the operator is a property of the factory's whole
// history rather than of one performance.
//
// What each part becomes, musically:
//
//   pi        the leading eigenvector: the near-invariant distribution the
//             factory currently occupies. THE DOMINANT BEHAVIOUR. Selection
//             blended toward it stops being a fresh draw every window, which is
//             why random concatenation keeps returning.
//
//   w2        the second eigenvector: a pattern that fades at rate |lambda2|
//             without changing shape. Its positive and negative lobes are two
//             sub-populations that trade places as it decays and is renewed --
//             UNDERPINNING BEHAVIOURS MOVING IN AND OUT OF SYNC with the
//             dominant, at a rate the operator sets rather than a clock.
//
//   gap       1 - |lambda2|. Wide: one durable version, cleanly separated.
//             Narrow: versions bleeding into each other. P227 stable failure is
//             a gap frozen wide in a bad region; P230 thrash is a gap that never
//             settles; P229 learning death is a single cell with no variety.
//             The gap is therefore the diagnostic AND the coherence readout.
//
// STEERING DEFAULTS TO ZERO. Every self-generated criterion tried so far became
// a convergence engine: the audibility score narrowed the vocabulary 9 -> 4 and
// then stopped even buying sound. This one differs in kind -- it is a criterion
// over DYNAMICS, not content, so it does not say what to play -- but that is an
// argument, not a measurement, and it gets the same ablation before it is
// trusted.
~opObserve = { |from, to|
    if (from.notNil and: { to.notNil }) {
        var row = ~opCounts[from];
        if (row.isNil) { row = IdentityDictionary.new; ~opCounts[from] = row };
        row[to] = (row[to] ? 0) + 1;
    };
};

~opCompute = {
    var cells, n, P, v, w;
    cells = Set.new;
    ~opCounts.keysValuesDo { |a, row| cells.add(a); row.keysDo { |b| cells.add(b) } };
    cells = cells.asArray.sort({ |a, b| a.asString < b.asString });
    n = cells.size;
    if (n < 3) { ~opGap = 0; ~opPi = nil; ~opW2 = nil } {
        ~opCells = cells;
        P = Array.fill(n, { |i|
            var row = ~opCounts[cells[i]],
                r = Array.fill(n, { |j| ((row !? { row[cells[j]] }) ? 0).asFloat }),
                tot = r.sum;
            // an unobserved row is uniform, not zero, so the chain stays
            // irreducible and the stationary distribution is defined
            if (tot > 0) { r / tot } { Array.fill(n, { 1.0 / n }) };
        });

        // LEADING EIGENVECTOR: v <- vP. For a stochastic matrix lambda1 = 1 and
        // v converges to the near-invariant distribution the factory occupies.
        v = Array.fill(n, { 1.0 / n });
        60.do {
            var nv = Array.fill(n, 0);
            n.do { |i| n.do { |j| nv[j] = nv[j] + (v[i] * P[i][j]) } };
            v = nv / max(1e-12, nv.sum);
        };
        ~opPi = v;

        // SECOND EIGENVECTOR: start in the zero-sum subspace, which excludes the
        // lambda1 component, so iteration converges to the second mode and the
        // per-step decay ratio IS |lambda2|.
        w = Array.fill(n, { 1.0.rand2 });
        w = w - (w.sum / n);
        ~opLambda2 = 0;
        30.do {
            var nw = Array.fill(n, 0), a, b;
            n.do { |i| n.do { |j| nw[j] = nw[j] + (w[i] * P[i][j]) } };
            nw = nw - (nw.sum / n);
            a = w.squared.sum.sqrt; b = nw.squared.sum.sqrt;
            if (a > 1e-9) { ~opLambda2 = b / a };
            w = if (b > 1e-9) { nw / b } { nw };
        };
        ~opW2 = w;
        ~opGap = (1.0 - ~opLambda2).clip(0, 1);
    };
};


~opCounts = IdentityDictionary.new;
~opGap = 0; ~opLambda2 = 0; ~opPhase = 0;
)

(
var root = WORKDIR, grainDir = GRAINDIR, nGrains = NGRAINS,
    server, bufs, b, h, logPath, logFile, startTime,
    notes, noteName, mutableDir,
    weights, policy, runtimeMachines, mtimes,
    loadJSON, loadMutable, features, means, acc, accN,
    prevWeights, recent, targets, currentState, prevState, live,
    audib, pending, saveAudibility, ampFloor,
    desc, dKeys, target, neighbourhood, nearest, grainPath, dvec, dn,
    section, sections, sectionAge, nextSection, pickSection,
    nVoices = 2, evCtr = 0, winCtr = 0, nextWindow = 4, silentWindows = 0,
    running = true, reloads = 0,
    masterPeak = 0, clipReports = 0, masterReports = 0,
    fireVoice, curArgs, played, voiceKeeper,
    memPath, loadMemory, saveMemory, transitions, priorRuns = 0, lastSectionId, succ,
    trace, attend, attnReport,
    macroBufs, macroDesc, macroVec, macroN, macroSucc, macroPath, layerOf,
    macroNb;

notes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
noteName = { |freq| var midi, m;
    if (freq <= 0) { \unpitched } {
        midi = 69 + (12 * log2(freq / 440.0));
        if (midi.isNaN or: { midi < 12 } or: { midi > 120 }) { \unpitched } {
            m = midi.round.asInteger; (notes[m % 12] ++ ((m div: 12) - 1)).asSymbol }}};

features = [\density, \windowsize, \percpitch, \avgcent, \avgrolloff, \avgflat, \avgrms];
mutableDir = root ++ "/mutable";

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
    };
    ("MEMORY " ++ n ++ " sections recalled from " ++ priorRuns ++ " prior run(s), "
        ++ transitions.size ++ " transitions, " ++ trace.size ++ " trace states").postln;
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
                logFile.write("LOADED_MACHINE " ++ name ++ "\n");
            } {
                ("  REJECTED " ++ name ++ ": file must evaluate to a Function").postln;
                logFile.write("REJECTED_MACHINE " ++ name ++ "\n");
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
server.options.numOutputBusChannels = 2;
// THE CORPUS IS 22050 Hz. At a 44100 server BufRateScale is exactly 0.5; at
// 48000 it is 0.459375, so every grain is resampled at a non-integer ratio by
// PlayBuf's interpolator, adding low-level broadband noise to EVERY sound.
// The offline renders are 44100 and sound clean through the same headphones;
// the live server takes 48000 from the AirPods and does not. That difference
// is immune to every factory parameter, which is why nothing changed it.
server.options.sampleRate = 44100;
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

mtimes = IdentityDictionary.new;
runtimeMachines = IdentityDictionary.new;
recent = List.new;
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
dKeys = ["centroid", "flatness", "median", "zcr", "pitch"];
target = nil;

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
        var s0, cands, wts;
        cands = List.new; wts = List.new;
        if (lastSectionId.notNil) {
            sections.do { |s|
                var n = transitions[lastSectionId.asString ++ ">" ++ s[\id].asString] ? 0;
                if (n > 0) { cands.add(s); wts.add(n) };
            };
        };
        if (cands.size > 0) {
            s0 = cands[wts.asArray.normalizeSum.windex];
            logFile.write("# SECTION return(seq) " ++ lastSectionId ++ " -> " ++ s0[\id]
                ++ " of " ++ cands.size ++ " known successors\n");
        } {
            // nothing has followed this region yet, so fall back to uniform
            s0 = sections[sections.size.rand];
            logFile.write("# SECTION return(unseen) -> " ++ s0[\id] ++ "\n");
        };
        s0
    } {
        var s0 = IdentityDictionary[
            \id -> sections.size,
            \centre -> Array.fill(dKeys.size, { rrand(0.15, 0.85) }),
            \voices -> rrand((policy["voices_min"] ? "1").asInteger,
                             (policy["voices_max"] ? "4").asInteger),
            \family -> avail.scramble.keep(rrand(4, 8)) ];
        sections.add(s0);
        logFile.write("# SECTION new " ++ s0[\id] ++ " voices " ++ s0[\voices]
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
            and: { 1.0.rand < (policy["micro_continuity"] ? policy["continuity"] ? "0.85").asFloat }
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
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
            env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
        sig = BPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    SynthDef(\playbackHP, { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0|
        // doneAction was 2 on BOTH the PlayBuf and the envelope, so whichever
        // finished first freed the synth. With rate > 1 the buffer runs out
        // while the envelope is still open, and the output stops dead at
        // whatever amplitude it had reached: a click on every grain. Only the
        // envelope may free the synth now, because only the envelope is
        // guaranteed to be at zero when it ends.
        var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),
            env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), doneAction:2);
        sig = HPF.ar(sig, cutoff); sig = Pan2.ar(sig, pan, amp); Out.ar(out, sig * env);
    }).add;
    SynthDef(\playgran, { |out=0, freq=10, amp=0.3, rate=1.0, atk=0.5, rel=4, cutoff=1500, buf, pan=0|
        var env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]), levelScale:amp, doneAction:2),
            fenv = EnvGen.kr(Env([cutoff/2, cutoff, cutoff/2],[atk,rel],\sin,1), levelScale:amp),
            sig = GrainBuf.ar(2, Impulse.kr(freq), 0.2, buf, rate,
                LFNoise2.kr(0.1).range(0,1), 2, (pan * LFNoise2.kr(0.1).range(-1,1)), -1);
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
    SynthDef(\master, { |ceiling=0.9, gain=1.0|
        // GAIN. Grains went from 500 ms to 60 ms, so the energy delivered per
        // event fell roughly eightfold, while every machine's \amp is still
        // calibrated against the old length. Roberto: "really quiet, very short
        // audio windows with gaps... a shape emerging but it can only be
        // perceived across the silences." The shape is the structure working;
        // the thinness is this. Applied before the limiter, which then catches
        // anything the lift overshoots.
        var raw = In.ar(0, 2) * gain,
            over = (raw.abs > 0.99),
            lim = Limiter.ar(raw, ceiling, 0.01);
        SendReply.kr(Impulse.kr(4), '/master',
            [Amplitude.kr(Mix.ar(raw)), A2K.kr(Mix.ar(over)).min(1)]);
        ReplaceOut.ar(0, lim);
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
        logFile.write("BUFFERS " ++ bufs.size ++ " empty " ++ empty ++ "\n");
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
                if (nxt.notNil and: { 1.0.rand < (policy["macro_continuity"] ? policy["continuity"] ? "0.35").asFloat }
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
        if (desc["norm"]["pitch"].isNil) {
            dKeys = ["centroid", "flatness", "median", "zcr"];
            "  no pitch column in this corpus: falling back to 4 dimensions".postln;
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

    OSCdef(\desc, { |msg|
        var amp = msg[3], cent = msg[4], flat = msg[5], roll = msg[6],
            freq = msg[7], hasPitch = msg[8], isOnset = msg[9] > 0,
            now = Main.elapsedTime - startTime;

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
                logFile.write("COLLAPSE silence " ++ now ++ " " ++ evCtr ++ "\n");
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
                    logFile.write("# window " ++ winCtr ++ " inaudible, means held\n");
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
                    var spec = weights[m.asString], v, lo, hi, idx;
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
                    // LAYER BALANCE. Nine of the twenty class machines are macro,
                    // and all runtime machines default to micro, so long-form
                    // material is outnumbered three to one before selection
                    // begins. Roberto: "getting better now, missing the longer
                    // events though." This is the dial for how much of the
                    // texture is sustained, and it is a compositional choice
                    // rather than a correction.
                    if (layerOf.value(m) == "macro") {
                        v = v * (policy["macro_bias"] ? "1.0").asFloat };
                    v = v * (1 + ((policy["audibility_influence"] ? "1.0").asFloat
                        * ((audib[m] ? 0.5).max((policy["audibility_floor"] ? "0.05").asFloat) - 1)));
                    v.max(0.0)
                });

                if (temp != 1.0) { raw = raw.collect({ |v| v.pow(temp) }) };
                if (raw.sum <= 0) { raw = avail.collect({ 1.0 }) };
                raw = raw.normalizeSum;

                // ---- THE OPERATOR, BLENDED IN ------------------------------
                // The dominant eigenvector is a distribution the factory has
                // actually settled into. Blending selection toward it is what
                // makes behaviour persist across windows instead of being drawn
                // fresh each time -- the absence of which is why random
                // concatenation keeps returning.
                //
                // The second eigenvector then pulls the OTHER way, and its two
                // lobes alternate as opPhase advances, so a sub-population moves
                // into sync with the dominant and back out of it at a rate the
                // operator sets. Underpinning behaviours, not a schedule.
                block { |brk|
                    var ow = (policy["operator_weight"] ? "0.0").asFloat,
                        sw = (policy["operator_second"] ? "0.0").asFloat,
                        vec, lobe;
                    if (ow <= 0 or: { ~opPi.isNil }) { brk.value };
                    vec = avail.collect({ |m|
                        var i = ~opCells.indexOf(m.asString);
                        if (i.notNil) { ~opPi[i] } { 0 } });
                    if (vec.sum <= 0) { brk.value };
                    vec = vec.normalizeSum;
                    raw = raw.collect({ |v, i| (v * (1 - ow)) + (vec[i] * ow) });

                    // the second mode, phase-rotated: its sign flips with
                    // opPhase, so each lobe takes its turn against the dominant
                    if (sw > 0 and: { ~opW2.notNil }) {
                        ~opPhase = opPhase + (1 - ~opGap).max(0.02);
                        lobe = (opPhase * 2pi).sin;
                        raw = raw.collect({ |v, i|
                            var j = ~opCells.indexOf(avail[i].asString),
                                m2 = if (j.notNil) { ~opW2[j] } { 0 };
                            (v * (1 + (sw * lobe * m2))).max(0)
                        });
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
                        logFile.write("ATTEND " ++ winCtr ++ " " ++ attnReport.join(" ") ++ "\n");
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

                prevState = currentState;
                currentState = avail[raw.windex];
                avail.do { |m, i| prevWeights[m] = raw[i] };

                // the trajectory, one entry per window: where it was, and what it
                // played there. This is what attention queries, and it accrues
                // whether or not attention is switched on -- so a run with the
                // weight at zero still LAYS DOWN memory for a later run to use.
                if (target.notNil) {
                    trace.add(IdentityDictionary[\state -> target.copy,
                        \machine -> currentState, \run -> priorRuns]);
                };

                // the operator sees one transition per window: which behaviour
                // followed which. This is the count table of P223.
                ~opObserve.value(opPrev, currentState);
                ~opPrev = currentState;
                if (winCtr % 3 == 0) { ~opCompute.value };

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
                            c = section[\centre][j];
                        (v + rrand(step.neg, step) + ((c - v) * pull)).clip(0, 1) });
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

                logFile.write(line ++ "\n"); logFile.flush;

                if (winCtr % 5 == 0) {
                    ("t=" ++ now.round(0.1) ++ "s  win=" ++ winCtr ++ "  " ++ currentState
                        ++ "  amp=" ++ amp.round(0.0001) ++ "  pool=" ++ avail.size
                        ++ "  reloads=" ++ reloads ++ "  LIVE=" ++ live.size
                        ++ "  peak=" ++ masterPeak.round(0.001)
                        ++ "  clip=" ++ (clipReports / max(1, masterReports)).round(0.001)
                        ++ "  gap=" ++ ~opGap.round(0.001)
                        ++ "  dom=" ++ (~opPi !? { ~opCells[~opPi.maxIndex] } ? "-")).postln;
                };
                logFile.write("OPERATOR " ++ winCtr ++ "," ++ ~opGap.round(0.0001)
                    ++ "," ++ ~opLambda2.round(0.0001)
                    ++ "," ++ (~opCells !? { opCells.size } ? 0)
                    ++ "," ++ (~opPi !? { ~opPi.maxItem.round(0.001) } ? 0)
                    ++ "," ++ (~opPi !? { ~opCells[~opPi.maxIndex] } ? "-") ++ "\n");
                logFile.write("MASTER " ++ winCtr ++ "," ++ masterPeak.round(0.001)
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
            var span = (policy["voice_span"] ? "14.0").asFloat * rrand(0.7, 1.4),
                deadline = Main.elapsedTime + span,
                lay = layerOf.value(m), nb, handed,
                args = curArgs;
            // the machine's own measured rate decides which corpus it sees
            if (lay == "macro" and: { macroBufs.notNil }) {
                // the cached per-window path, NOT a fresh walk. Computing it here
                // meant the voice keeper ran ~27,000 distance calculations every
                // 0.25 s on the language thread, which starved the window loop
                // and froze the factory at four windows.
                nb = macroNb ? (0 .. macroN - 1);
                handed = nb.collect({ |i| macroBufs[i] }).reject({ |x| x.isNil });
                if (handed.size < 1) { handed = macroBufs };
            } {
                nb = neighbourhood ? (0 .. bufs.size - 1);
                handed = nb.collect({ |i| bufs[i] }).reject({ |x| x.isNil });
                if (handed.size < 1) { handed = bufs };
            };
            played.add(m);
            if (runtimeMachines[m].notNil) {
                {
                    var ent = span * (policy["life_enter"] ? "0.25").asFloat,
                        rel = span * (policy["life_recede"] ? "0.45").asFloat,
                        arc = Pseg(Pseq([0.05, 1.0, 0.85, 0.0], 1),
                                   Pseq([ent, span - ent - rel, rel], 1), \sin, 1),
                        pl = Pmul(\amp, arc,
                            runtimeMachines[m].value(handed, args)).play;
                    if (pl.notNil) { live.add([pl, deadline]) };
                }.try({ |err|
                    logFile.write("PLAY_FAIL " ++ m ++ " " ++ err.errorString ++ "\n") });
            } {
                {
                    var pl;
                    h.settings([m, args]);
                    pl = h.stateMachine(handed);
                    // a machine may start more than one pattern; every one of
                    // them has to be bounded, or it becomes a permanent layer
                    pl = if (pl.isKindOf(Collection)) { pl.asArray } { [pl] };
                    pl.do { |p|
                        if (p.isKindOf(EventStreamPlayer)) { live.add([p, deadline]) } {
                            logFile.write("UNTRACKED " ++ m ++ " " ++ p.class ++ "\n") };
                    };
                }.try({ |err|
                    logFile.write("PLAY_FAIL " ++ m ++ " " ++ err.errorString ++ "\n") });
            };
        };
    };

    voiceKeeper = Routine({
        loop {
            var now = Main.elapsedTime, ceiling;
            // retire
            live.copy.do { |entry|
                if (now > entry[1]) { { entry[0].stop }.try; live.remove(entry) };
            };
            // safety ceiling, oldest first
            ceiling = (policy !? { policy["max_live_voices"] } ? "6").asInteger;
            while { live.size > ceiling } { { live[0][0].stop }.try; live.removeAt(0) };
            // replace, so the population tracks nVoices rather than the window
            if (curArgs.notNil) {
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
        [\gain, (policy["master_gain"] ? "4.0").asFloat]);

    // Capture what actually reaches the speakers. The patina was diagnosed
    // twice from the CORPUS and from single-machine OFFLINE renders, and both
    // diagnoses were wrong: the grain fade did not remove it. Offline renders
    // carry almost no high-frequency energy (cr 0.0098 above 8 kHz, gl 0.0013),
    // so whatever it is, it is not visible in the material or in one machine
    // rendered alone. Measure the live sum instead of reasoning about it.
    server.record(root ++ "/renders/live_capture.wav", numChannels: 2);
    CmdPeriod.doOnce({ { server.stopRecording }.try });
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
