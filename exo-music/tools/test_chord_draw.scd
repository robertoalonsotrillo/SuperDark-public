// DOES THE SECTION CHORD DRAW DO WHAT IT CLAIMS?
//
// Waiting for the live factory to form sections is a slow and unreliable way to
// test this: sections arrive every few minutes, size 1 has ~26% probability, and
// two short shadow runs in a row both drew size 1 and exercised none of the
// logic that matters. This runs the same draw 400 times in a second.
//
// It duplicates the block in live_factory.scd around line 1055 rather than
// calling it, which is a real limitation -- the two can drift. It is here to
// check the ARITHMETIC and the invariants, not to prove the factory runs it.
//
// THREE INVARIANTS, each of which has already been violated once:
//   * no duplicate members. asSet on raw Floats let 1.0 through twice and the
//     shadow logged "CHORD 97,2,1.0|1.0", a two-note chord that is one note.
//   * the root is always present. Every voice is placed against the root, so a
//     rootless voicing is one the factory cannot hear as a chord.
//   * the non-root members VARY between draws of the same size. The first
//     version used .sort.keep(k), which returns the k LOWEST members, so every
//     chord of a given size was the same chord.
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
//     sclang -l /tmp/harness_conf.yaml tools/test_chord_draw.scd
(
var say, out = "/tmp/chorddraw.txt",
    tab = [1.0, 1.114, 1.246, 1.427, 1.557, 1.631, 1.812],
    wsStr = "1 1 1 0.45 0.2 0.09 0.04",
    nDraws = 400, sizes, seen, dupes = 0, rootless = 0, draw;

// STDOUT IS NOT RELIABLE FOR THESE HARNESSES. Two of them compiled, ran and
// printed nothing at all under `sclang -l conf file.scd`, which reads exactly
// like a hang and cost several minutes each. test_grammar.scd already writes
// to a file for this reason. Do the same.
("rm -f " ++ out).systemCmd;
say = { |t| var f = File(out, "a"); if (f.isOpen) { f.write(t ++ "\n"); f.close } };

sizes = Dictionary.new;
seen  = Dictionary.new;

draw = {
    var ws, tot, r, k, others, chord;
    ws = wsStr.split($ ).collect(_.asFloat).select({ |x| x > 0 });
    ws = ws.keep(tab.size.min(ws.size));
    tot = ws.sum;
    r = 1.0.rand * tot; k = 0;
    ws.do { |x, i| if (r >= 0) { k = i; r = r - x } };
    k = (k + 1).clip(1, tab.size);
    others = tab.collect({ |x| x.round(0.0001) })
                .asSet.asArray.reject({ |x| x == 1.0 }).scramble;
    chord = ([1.0] ++ others.keep(k - 1)).sort;
    chord
};

nDraws.do {
    var c = draw.value, key;
    sizes[c.size] = (sizes[c.size] ? 0) + 1;
    if (c.size != c.asSet.size) { dupes = dupes + 1 };
    if (c.includes(1.0).not) { rootless = rootless + 1 };
    key = c.size.asString ++ ":" ++ c.collect({ |x| x.round(0.001) }).join("|");
    seen[key] = (seen[key] ? 0) + 1;
};

say.value("");
say.value("  " ++ nDraws ++ " draws from a table of " ++ tab.size ++ " ratios");
say.value("  weights: " ++ wsStr);
say.value("");
say.value("  SIZE DISTRIBUTION  (1-3 should dominate, then decay)");
sizes.keys.asArray.sort.do { |k|
    var n = sizes[k], bar = String.fill((n / nDraws * 60).asInteger.max(0), $#);
    say.value("    size " ++ k ++ "  " ++ n ++ "  "
        ++ (100 * n / nDraws).round(0.1) ++ "%  " ++ bar);
};
say.value("");
say.value("  duplicate members : " ++ dupes ++ "   (must be 0)");
say.value("  rootless chords   : " ++ rootless ++ "   (must be 0)");
say.value("");
// VARIETY WITHIN A SIZE is the invariant the .sort.keep(k) version failed.
[2, 3, 4].do { |k|
    var forK = seen.keys.asArray.select({ |key| key.beginsWith(k.asString ++ ":") });
    if (forK.size > 0) {
        say.value("  distinct chords of size " ++ k ++ ": " ++ forK.size
            ++ "   (1 would mean the subset never varies)");
    };
};
say.value("");
if (dupes == 0 and: { rootless == 0 }) {
    say.value("  PASS on the invariants. This says the arithmetic is right; it does NOT");
    say.value("  say the factory runs this code, which only a CHORD line in a live log");
    say.value("  can show.");
} {
    say.value("  FAIL");
};
0.exit;
)
