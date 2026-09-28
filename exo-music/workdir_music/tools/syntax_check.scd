// Compile live_factory.scd without running it.
//
// `.compile` parses and builds the function and stops there: no server, no
// port, no FIFO, no file written. Safe beside a live factory, and it catches
// the class of mistake that has cost this project whole boots -- a var declared
// after a statement, an unbalanced brace, a capitalised identifier read as a
// class name.
//
//   sclang workdir_music/tools/syntax_check.scd <path.scd>

(
var path = thisProcess.argv[0]
    ?? { "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music"
         "/workdir_music/tools/live_factory.scd" };
var f = File(path, "r"), src, fn;
if (f.isOpen.not) {
    ("CANNOT OPEN " ++ path).postln; 1.exit;
};
src = f.readAllString; f.close;

// The file is a TEMPLATE, not valid SuperCollider on its own: run_live.sh
// substitutes seven placeholders before running it. The first version of this
// checker did four of them and reported a syntax error at
// `server.options.numInputBusChannels = 0`, which is the line after the bare
// name OUTDEVICE. The pre-harness file failed identically, which is the only
// reason the checker was not believed. A control arm, again.
//
// Mirrors run_live.sh:185 exactly. If that line changes, this must follow.
src = src.replace("MACRODIR",   "\"/tmp/sc_syntax_check/macro\"")
         .replace("MIDDIR",     "\"/tmp/sc_syntax_check/mid\"")
         .replace("MUTABLEDIR", "\"mutable\"")
         .replace("SCPORT",     "57110")
         .replace("OUTDEVICE",  "")            // empty means system default
         .replace("WORKDIR",    "\"/tmp/sc_syntax_check\"")
         .replace("GRAINDIR",   "\"/tmp/sc_syntax_check/g\"")
         .replace("NGRAINS",    "10");

fn = src.compile;
if (fn.isNil) {
    ("COMPILE FAILED: " ++ path).postln;
    1.exit;
} {
    ("COMPILE OK: " ++ path ++ "  (" ++ src.size ++ " chars)").postln;
    0.exit;
};
)
