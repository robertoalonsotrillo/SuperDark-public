// Can the factory afford the forgetting operator AT THE RATE IT ACTUALLY RUNS?
//
// The previous attempt at this question asked the wrong one. It ran 20,000
// observations with an eigen-decomposition every third -- 13.5 billion
// interpreted operations, which is sixty-five HOURS of factory time compressed
// into one run. It never finished, and I read its slowness as a fault in the
// operator when it was a fault in the test.
//
// The factory observes once per window (11.7 s) and computes every third
// window (35 s). So the only question that matters is: what does ONE observe
// and ONE compute cost, at a realistic vocabulary size? If observe is
// microseconds and compute is well under a second, the factory can afford two
// operators as easily as one, and the earlier crash was not about cost.
//
//   ( ulimit -v 8000000; sclang -l /tmp/optest_conf.yaml tools/test_operator_rate.scd )
(
var cells, warm = 900, reps = 40, t, tObs, tComp, plain, faded, report;

cells = Array.fill(27, { |i| ("m" ++ i).asSymbol })
     ++ Array.fill(123, { |i| ("br" ++ i).asSymbol });

// Build each operator up to a realistic state FIRST, without timing, so the
// measurement is of steady-state cost rather than of an empty dictionary.
report = { |op, label|
    warm.do { op.observe(cells.choose) };
    op.compute;

    tObs = 0;
    reps.do {
        t = Main.elapsedTime;
        op.observe(cells.choose);
        tObs = tObs + (Main.elapsedTime - t);
    };
    tComp = 0;
    reps.do {
        t = Main.elapsedTime;
        op.compute;
        tComp = tComp + (Main.elapsedTime - t);
    };
    ("  " ++ label.padRight(14)
        ++ "observe " ++ ((tObs / reps * 1e6).round(1).asString ++ " us").padLeft(12)
        ++ "   compute " ++ ((tComp / reps * 1e3).round(0.1).asString ++ " ms").padLeft(12)
        ++ "   cells " ++ op.cells.size.asString.padLeft(4)
        ++ "   entries " ++ op.counts.values.sum({ |r| r.size }).asString.padLeft(6)).postln;
    [tObs / reps, tComp / reps];
};

("  vocabulary " ++ cells.size ++ ", warmed with " ++ warm
    ++ " observations, then " ++ reps ++ " timed calls of each").postln;
"".postln;
plain = report.value(TransferOperator.new, "undecayed");
faded = report.value(TransferOperator.new(400), "halflife 400");
"".postln;

// THE BUDGET. One window is 11.7 s. The factory does one observe per window and
// one compute every third. Adding a second operator doubles both.
("  per window, the factory spends:").postln;
("    one observe  " ++ ((plain[0] + faded[0]) * 1e6).round(1) ++ " us   (both operators)").postln;
("    one compute  " ++ ((plain[1] + faded[1]) / 3 * 1e3).round(0.1)
    ++ " ms   (both, amortised over 3 windows)").postln;
("    as a fraction of an 11.7 s window: "
    ++ (((plain[0] + faded[0]) + ((plain[1] + faded[1]) / 3)) / 11.7 * 100).round(0.001)
    ++ " %").postln;
"".postln;
if (((plain[0] + faded[0]) + ((plain[1] + faded[1]) / 3)) < 0.5) {
    "  AFFORDABLE. Two operators cost a small fraction of one window.".postln;
    "  Whatever took 60 GB, it was not the arithmetic.".postln;
} {
    "  TOO EXPENSIVE at this vocabulary size. Do not wire it in.".postln;
};
0.exit;
)
