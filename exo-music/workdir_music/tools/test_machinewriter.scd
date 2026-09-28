// Does MachineWriter repeat itself?
//
// The six-hour run of 26 Aug wrote 154 bridges across SEVEN distinct
// transitions -- `sc -> bu` 77 times, `pu -> hm` 51 times, a 95% duplicate
// rate. Nothing detected it for six hours, because every downstream measure
// counted machine NAMES and 154 names looked like a widening vocabulary.
//
// This test exists so that class of defect fails in ten seconds instead of six
// hours. It calls propose() repeatedly against a synthetic operator and asserts
// that no transition is ever bridged twice.
//
//   sclang -l tools/live_conf_test.yaml tools/test_machinewriter.scd
(
var op, mw, dir, specs, made, seen, dupes = 0, n = 40, nilAt = nil;

dir = "/tmp/mwtest";
File.mkdir(dir);
(dir ++ "/*.scd").pathMatch.do { |p| File.delete(p) };

// A synthetic operator: 8 cells, plenty of observations, deliberately uneven so
// some pairs are much rarer than others -- which is exactly the condition under
// which the old code locked on.
op = TransferOperator.new;
8.do { |i| 200.do {
    var a = ("m" ++ i).asSymbol,
        b = ("m" ++ (i + 1 + 3.rand % 8)).asSymbol;
    op.observe(a);
} };
40.do { op.observe(\m0); op.observe(\m3) };   // make m0->m3 common
op.compute;

// Dictionary, NOT IdentityDictionary: propose() looks up specs[a.asString], and
// an IdentityDictionary keyed by Strings compares by identity, so every lookup
// misses and propose() silently returns nil. The first version of this test did
// exactly that and "passed" by never writing anything. Same failure class as the
// String/Symbol dispatch bug that made 19 of 22 machines inaudible for two days.
specs = Dictionary.new;
9.do { |i| specs[("m" ++ i)] = Dictionary[
    "dur" -> (0.05 + (i * 0.4)).asString ] };

mw = MachineWriter.new;
seen = IdentityDictionary.new;

n.do { |i|
    made = mw.propose(op, specs, dir, "gap");
    if (made.isNil) {
        if (nilAt.isNil) { nilAt = i };
    } {
        var k = (made[1].asString ++ ">" ++ made[2].asString).asSymbol;
        if (seen[k].notNil) {
            dupes = dupes + 1;
            ("  DUPLICATE " ++ k ++ " (first written at call " ++ seen[k] ++ ")").postln;
        } { seen[k] = i };
    };
};

"".postln;
("  calls              " ++ n).postln;
("  distinct pairs     " ++ seen.size).postln;
("  duplicates         " ++ dupes).postln;
("  stopped writing at " ++ (nilAt ? "never")).postln;
"".postln;
// A test that asserts nothing must FAIL, not pass. The first version returned
// nil on every call and reported PASS.
// ORDER MATTERS. Duplicates are checked FIRST. The vacuity guard was ahead of
// it in the first version, so running against the old logic -- 1 distinct pair,
// 39 duplicates -- reported "VACUOUS" instead of naming the defect it had just
// caught. A test that detects the right failure and prints the wrong reason is
// how six diagnoses got spent on a sample rate printed at the top of every log.
if (dupes > 0) {
    ("  FAIL: MachineWriter re-bridged " ++ dupes ++ " pair(s) across "
        ++ n ++ " calls, using only " ++ seen.size
        ++ " distinct transition(s). This is the 26 Aug defect.").postln;
} {
    if (seen.size < 5) {
        ("  FAIL (VACUOUS): only " ++ seen.size ++ " bridges were ever proposed, so "
            ++ "nothing was tested. Check the operator fixture and the specs keys.").postln;
    } {
        "  PASS: no transition bridged twice.".postln;
        if (nilAt.notNil) {
            ("  and it correctly STOPPED at call " ++ nilAt
                ++ " rather than repeating.").postln;
        };
    };
};

// The random arm must retire pairs too, or the control compares one arm that
// repeats against one that does not, and the difference is the bug.
mw = MachineWriter.new;
seen = IdentityDictionary.new; dupes = 0;
n.do { |i|
    made = mw.propose(op, specs, dir, "random");
    if (made.notNil) {
        var k = (made[1].asString ++ ">" ++ made[2].asString).asSymbol;
        if (seen[k].notNil) { dupes = dupes + 1 } { seen[k] = i };
    };
};
("  random arm: " ++ seen.size ++ " distinct, " ++ dupes ++ " duplicates  "
    ++ if (dupes > 0) { "FAIL" } {
        if (seen.size < 5) { "FAIL (VACUOUS)" } { "PASS" } }).postln;

0.exit;
)
