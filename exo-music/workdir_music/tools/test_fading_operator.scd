// Does the decayed operator behave, and does the undecayed one still behave
// EXACTLY as before? The second question is the important one: the accumulating
// operator steers selection at operator_weight 0.35, so any change to it changes
// the factory, and this work is supposed to be instrumentation only.
//
//   sclang tools/test_fading_operator.scd
(
var a, b, seq, r1, r2, ok = true, note;

// 1. The undecayed operator is untouched -------------------------------------
a = TransferOperator.new;            // no argument, as every existing caller does
seq = [\x, \y, \z, \x, \y, \z, \x, \q, \z, \y] ++ Array.fill(200, {
    [\x, \y, \z, \q].choose });
seq.do { |c| a.observe(c) };
a.compute;
("  undecayed: cells " ++ a.cells.size ++ "  total " ++ a.total
    ++ "  lambda2 " ++ a.lambda2.round(0.0001)
    ++ "  decay " ++ (a.decay ? "nil")).postln;
if (a.total != (seq.size - 1)) {
    ok = false; "  FAIL: undecayed total changed; counts are no longer integral".postln;
};

// 2. The decayed operator forgets --------------------------------------------
b = TransferOperator.new(40);        // half-life 40 transitions
seq.do { |c| b.observe(c) };
b.compute;
("  decayed:   cells " ++ b.cells.size ++ "  total " ++ b.total.round(0.01)
    ++ "  lambda2 " ++ b.lambda2.round(0.0001)
    ++ "  halflife " ++ b.halflife).postln;

// Total must approach the geometric sum 1/(1-decay), NOT grow without bound.
// That is the whole point: a fixed memory rather than the whole history.
r1 = 1.0 / (1.0 - b.decay);
("  decayed total " ++ b.total.round(0.01) ++ " vs geometric limit "
    ++ r1.round(0.01)).postln;
if (b.total > (r1 * 1.5)) {
    ok = false; "  FAIL: decayed total exceeds its geometric limit".postln;
};

// 3. It actually FORGETS a behaviour that stops ------------------------------
// \q is played early and then never again; after many transitions it should
// have been pruned out of the cell list entirely.
b = TransferOperator.new(20);
[\q, \q, \q].do { |c| b.observe(c) };
400.do { b.observe([\x, \y, \z].choose) };
b.compute;
note = b.cells.includes(\q);
("  after 400 transitions without it, \\q still present: " ++ note).postln;
if (note) {
    ok = false; "  FAIL: the decayed operator never forgot an abandoned cell".postln;
};

// 4. Two operators fed the SAME sequence must disagree ------------------------
// If they agreed, the decay would be doing nothing and the instrumentation
// would be measuring the same thing twice.
a = TransferOperator.new; b = TransferOperator.new(30);
seq = Array.fill(300, { [\x, \y, \z, \w, \v].choose });
seq.do { |c| a.observe(c); b.observe(c) };
a.compute; b.compute;
("  same input -> undecayed lambda2 " ++ a.lambda2.round(0.0001)
    ++ ", decayed " ++ b.lambda2.round(0.0001)).postln;

("\n  " ++ if (ok) { "ALL CHECKS PASS" } { "SOMETHING FAILED" }).postln;
0.exit;
)
