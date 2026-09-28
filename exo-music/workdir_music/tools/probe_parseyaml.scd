// Does SuperCollider's parseYAML read memory.json the way Python does?
//
// 15 Sept 2026. A boot died at live_factory.scd:284,
//     var st = (e["s"] ? []).collect({ |v| v.asFloat });
// with a trace entry Dictionary appearing INSIDE the array that should hold six
// floats. Python reads the same file cleanly: 8,000 trace entries, zero
// malformed. So either parseYAML mangles it, or it mangles it sometimes.
//
// loadMemory runs on every boot and does not depend on layerNames, which is
// already an argument against the layers_active suspicion.
//
// This opens no server, binds no port and touches no file. Safe to run beside
// the live factory.
//
//   sclang workdir_music/tools/probe_parseyaml.scd

(
var path = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music"
           "/workdir_music/mutable/memory.json";
var trials = 5;

trials.do { |t|
    var f = File(path, "r"), s, m, trace, bad = 0, good = 0, firstBad = nil;
    if (f.isOpen.not) { ("trial " ++ t ++ ": cannot open").postln } {
        s = f.readAllString; f.close;
        m = s.parseYAML;
        if (m.isNil) { ("trial " ++ t ++ ": parseYAML returned nil").postln } {
            trace = m["trace"] ? [];
            trace.do { |e, i|
                var st = e !? { e["s"] };
                var ok = st.isArray and: {
                    st.every({ |v| v.isString or: { v.isNumber } })
                };
                if (ok) { good = good + 1 } {
                    bad = bad + 1;
                    if (firstBad.isNil) { firstBad = [i, e] };
                };
            };
            ("trial " ++ t
                ++ "  chars " ++ s.size
                ++ "  trace " ++ trace.size
                ++ "  wellformed " ++ good
                ++ "  MALFORMED " ++ bad).postln;
            if (firstBad.notNil) {
                ("   first malformed at index " ++ firstBad[0]).postln;
                ("   entry: " ++ firstBad[1]).postln;
            };
        };
    };
};

"".postln;
"If MALFORMED is 0 on every trial, parseYAML is innocent and the".postln;
"suspicion moves back to the single-layer path.".postln;
"If MALFORMED is nonzero and VARIES between trials, the parse is".postln;
"nondeterministic and loadMemory must stop trusting it.".postln;
0.exit;
)
