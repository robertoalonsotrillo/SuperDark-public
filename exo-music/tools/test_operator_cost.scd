// Can the factory AFFORD this operator? Correctness was never the problem.
//
// The first decayed operator passed four correctness tests -- it forgot, it
// bounded its total, it disagreed with the undecayed twin -- and none of them
// asked what it cost. It walked every count in every row on every observation.
// It was wired into a live factory on the strength of correctness alone, and
// SuperCollider went to 60 GB with the machine following.
//
// So this measures TIME AND SIZE at the rate the factory actually runs, and it
// measures the undecayed operator alongside as the reference. A decayed operator
// that costs materially more per observation than the plain one does not ship.
//
//   ( ulimit -v 8000000; sclang -l tools/live_conf.yaml ../tools/test_operator_cost.scd )
(
var cells, n = 20000, run, plain, faded, ok = true;

cells = Array.fill(27, { |i| ("m" ++ i).asSymbol })
     ++ Array.fill(123, { |i| ("br" ++ i).asSymbol });

run = { |op, label|
    var t0, tObs = 0, tComp = 0, t, entries;
    Array.fill(n, { cells.choose }).do { |c, i|
        t = Main.elapsedTime; op.observe(c); tObs = tObs + (Main.elapsedTime - t);
        if (i % 3 == 0) {
            t = Main.elapsedTime; op.compute; tComp = tComp + (Main.elapsedTime - t);
        };
    };
    entries = op.counts.values.sum({ |r| r.size });
    ("  " ++ label.padRight(12)
        ++ "observe " ++ ((tObs / n * 1e6).round(0.1).asString ++ " us").padLeft(12)
        ++ "   compute " ++ ((tComp / (n/3) * 1e3).round(0.1).asString ++ " ms").padLeft(11)
        ++ "   cells " ++ op.cells.size.asString.padLeft(4)
        ++ "   entries " ++ entries.asString.padLeft(6)
        ++ "   total " ++ op.total.round(0.1).asString.padLeft(10)).postln;
    [tObs / n, entries];
};

("  " ++ n ++ " observations, vocabulary of " ++ cells.size
    ++ ", compute every 3rd -- the factory's own rate").postln;
"".postln;
plain = run.value(TransferOperator.new, "undecayed");
faded = run.value(TransferOperator.new(400), "halflife 400");
"".postln;

// 1. COST. The decayed operator must not be materially dearer per observation.
("  observe cost ratio (decayed / plain): "
    ++ (faded[0] / max(plain[0], 1e-12)).round(0.01)).postln;
if (faded[0] > (plain[0] * 3 + 5e-6)) {
    ok = false; "  FAIL: forgetting costs too much per observation".postln;
};

// 2. SIZE. Entries must not exceed the plain operator's: the decayed one holds a
//    window of history, so it can only ever know fewer transitions, never more.
if (faded[1] > plain[1]) {
    ok = false; "  FAIL: the decayed operator stores MORE than the plain one".postln;
};

// 3. It still forgets. A cell dropped early must leave the vocabulary.
block { |break|
    var op = TransferOperator.new(20);
    3.do { op.observe(\ghost) };
    2000.do { op.observe([\a, \b, \c].choose) };
    op.compute;
    ("  after 2000 observations without it, \\ghost present: "
        ++ op.cells.includes(\ghost)).postln;
    if (op.cells.includes(\ghost)) {
        ok = false; "  FAIL: never forgot an abandoned cell".postln;
    };
};

// 4. The undecayed path is untouched: integral counts, exactly as before.
block { |break|
    var op = TransferOperator.new;
    100.do { op.observe([\a, \b].choose) };
    ("  undecayed total after 100 observations: " ++ op.total
        ++ "  (must be exactly 99)").postln;
    if (op.total != 99) {
        ok = false; "  FAIL: the undecayed operator changed behaviour".postln;
    };
};

("\n  " ++ if (ok) { "ALL CHECKS PASS -- safe to wire in" }
    { "SOMETHING FAILED -- do not wire in" }).postln;
0.exit;
)
