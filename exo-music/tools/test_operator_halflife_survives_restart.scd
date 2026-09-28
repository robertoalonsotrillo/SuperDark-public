// Does a decayed TransferOperator survive a restart?
//
// WHY THIS EXISTS
// 18 Sept 2026. #45 "wire the forgetting operator" was marked done, and the
// factory had never passed a half-life. Reading the persistence code showed why
// it would not have worked if it had: wNow was never saved, and loadDict cast
// every count with asInteger. So a decayed operator reloaded its old counts at
// whatever weight they were recorded (up to 1e150) against a fresh wNow of 1.0,
// and then truncated to integers whatever renorm had scaled below 1.
//
// The fix saves EFFECTIVE counts (divided by wNow) and loads floats. This test
// simulates a restart -- save, construct a fresh operator, load -- and checks
// three things:
//
//   1. No half-life: save/load round-trips EXACTLY. Nothing existing changes.
//   2. With a half-life, across a restart, an observation k steps old is worth
//      decay^k relative to a new one -- the same as if there had been no
//      restart. That is the whole property, and the one that was broken.
//   3. Fractional counts survive the round-trip (asFloat, not asInteger).
//
//   sclang -l workdir_music/tools/live_conf.yaml tools/test_operator_halflife_survives_restart.scd

(
var fail = 0, ok = { |c, msg| if (c) { ("  ok   " ++ msg).postln } { fail = fail + 1; ("  FAIL " ++ msg).postln } };
var saveLoad = { |o, hl|
    // exactly what live_factory does: write op.effective(v), then loadDict
    var d = IdentityDictionary.new, o2;
    o.counts.keysValuesDo { |a, row|
        var r = IdentityDictionary.new;
        row.keysValuesDo { |b, v| r[b] = o.effective(v) };
        d[a] = r;
    };
    o2 = TransferOperator.new(hl);
    o2.loadDict(d);
    o2
};
var near = { |a, b, tol = 1e-9| (a - b).abs < tol };
var o, o2, rowA, rowB, expect, hl;

"=== TransferOperator half-life across a restart ===".postln;

// ---------------------------------------------------------- 1. no half-life
o = TransferOperator.new;
[\a, \b, \a, \c, \a, \b].do { |c| o.observe(c) };
o2 = saveLoad.value(o, nil);
ok.value(o2.counts[\a][\b] == 2 and: { o2.counts[\a][\c] == 1 } and: { o2.counts[\b][\a] == 1 },
    "no half-life: counts round-trip exactly (a->b 2, a->c 1, b->a 1)");
ok.value(o2.total == o.total, "no half-life: total unchanged " ++ o.total);

// ------------------------------------------------- 2. half-life, no restart
// Reference: the SAME sequence with no restart in it.
hl = 4;
o = TransferOperator.new(hl);
// old: a->b once, then 8 steps of noise elsewhere, then a->b once more
o.observe(\a); o.observe(\b);
8.do { o.observe(\x); o.observe(\y) };
o.observe(\a); o.observe(\b);
rowA = o.counts[\a][\b];
// the two a->b events were recorded at weights w0 and w1, with w1/w0 = decay^-k
// for k steps between them, so the LATER one dominates. Effective value:
expect = o.effective(rowA);

// ---------------------------------------------------- 3. half-life, restart
// Same sequence, but save/load in the middle of the noise.
o = TransferOperator.new(hl);
o.observe(\a); o.observe(\b);
4.do { o.observe(\x); o.observe(\y) };
o2 = saveLoad.value(o, hl);                 // <-- the restart
// prev is not persisted, so the first observe after a boot records no
// transition -- exactly as the live factory does -- but it DOES advance wNow,
// like every observe. So the step count must match the reference exactly: the
// first version of this test added an extra observe(\y) "to re-establish
// position" and failed by one decay step (0.8781 vs 0.8721), which was the
// test being wrong about its own arithmetic, not the operator.
4.do { o2.observe(\x); o2.observe(\y) };
o2.observe(\a); o2.observe(\b);
ok.value(near.value(o2.effective(o2.counts[\a][\b]), expect, 1e-6),
    "half-life " ++ hl ++ ": a->b effective count matches the no-restart reference ("
        ++ expect.round(1e-6) ++ " vs " ++ o2.effective(o2.counts[\a][\b]).round(1e-6) ++ ")");

// ------------------------------------------- 4. fractional counts survive
o = TransferOperator.new(2);
o.observe(\p); o.observe(\q);
20.do { o.observe(\r); o.observe(\s) };     // p->q recorded long ago, now tiny
o2 = saveLoad.value(o, 2);
ok.value(o2.counts[\p].notNil and: { o2.counts[\p][\q] > 0 } and: { o2.counts[\p][\q] < 1 },
    "fractional count survives reload as a float: p->q = " ++ (o2.counts[\p] !? { |r| r[\q] }));

// --------------------------------------------- 5. setHalflife after the fact
o = TransferOperator.new;
ok.value(o.halflife.isNil and: { o.decay.isNil }, "constructed with nil: no decay");
o.setHalflife(100);
ok.value(o.halflife == 100 and: { near.value(o.decay, 2.0 ** (-1/100)) },
    "setHalflife(100) installs decay 2^(-1/100)");
o.setHalflife(0);
ok.value(o.halflife.isNil and: { o.decay.isNil }, "setHalflife(0) means none, matching policy '0'");

"".postln;
if (fail == 0) { "PASS: all checks".postln; 0.exit } { ("FAIL: " ++ fail ++ " check(s)").postln; 1.exit };
)
