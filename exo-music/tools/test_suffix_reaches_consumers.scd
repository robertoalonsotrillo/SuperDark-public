// Do the operator and the writer see through the @bucket suffix?
//
// WHY THIS EXISTS
// 20 Sept 2026. Since operator_sees_macro (15 Sept) every observed state is
// suffixed "@bucket" and the bucket is the constant "slow". Two consumers looked
// those cells up by bare machine name and found nothing:
//   TransferOperator.dominantOver(avail) -> nil -> the mix was skipped.
//     The operator steered nothing for five days, through its own repair.
//   MachineWriter.propose -> "endpoint not in specs: x@slow/y@slow" -> nil.
//     1,107 times in the ten-arm run, 0 ACQUIRED. Last ACQUIRED anywhere:
//     5 Sept 18:20. The supply was frozen for fifteen days.
// This test builds an operator whose cells are suffixed, asks it about bare
// names, and checks the writer's ledger key normalises both forms.
//
//   sclang -l workdir_music/tools/live_classes tools/test_suffix_reaches_consumers.scd
(
var op, avail, dom, sec, mw, k1, k2, k3, op2, specs, g, pass = true;
var say = { |ok, what| (if (ok) { "  ok    " } { "  FAIL  " } ++ what).postln; if (ok.not) { pass = false } };

"=== suffix reaches consumers ===".postln;

// an operator that has only ever seen suffixed states
op = TransferOperator.new;
20.do { op.observe('sc@slow'); op.observe('ry@slow'); op.observe('fma2@slow'); };
10.do { op.observe('ry@slow'); op.observe('sc@slow'); };
op.compute;
say.(op.cells.every { |c| c.asString.contains("@") }, "every cell is suffixed: " ++ op.cells);

// 1. dominantOver with BARE names must return a distribution, not nil
avail = [\sc, \ry, \fma2, \ht];
dom = op.dominantOver(avail);
say.(dom.notNil, "dominantOver(bare avail) is not nil");
say.(dom.notNil and: { dom.size == avail.size }, "one entry per avail machine");
say.(dom.notNil and: { (dom.sum - 1.0).abs < 1e-6 }, "normalised");
say.(dom.notNil and: { dom[3] == 0 }, "a machine the operator never saw (ht) gets 0");
say.(dom.notNil and: { dom[0] > 0 and: { dom[1] > 0 } }, "seen machines get mass: " ++ dom.round(0.001));

// 2. secondOver likewise
sec = op.secondOver(avail);
say.(sec.notNil and: { sec.size == avail.size }, "secondOver(bare avail) returns a vector");

// 3. a suffixed query still works (nothing breaks for callers that pass cells)
say.(op.dominantOver(['sc@slow', 'ry@slow']).notNil, "dominantOver(suffixed) still works");

// 4. the writer's ledger key normalises both forms to one
mw = MachineWriter.new(nil);
k1 = mw.key('sc@slow', 'ry@slow');
k2 = mw.key(\sc, \ry);
k3 = mw.key("sc@slow", "ry");
say.(k1 == k2, "key(sc@slow, ry@slow) == key(sc, ry): " ++ k1);
say.(k1 == k3, "mixed forms agree: " ++ k3);
say.(mw.bare("fma2@slow") == "fma2", "bare() strips: " ++ mw.bare("fma2@slow"));
say.(mw.bare("fma2") == "fma2", "bare() leaves bare alone");

// 5. the gap search must not choose a pair it cannot resolve. Build an
// operator whose most-dwelt cell (fma4, no spec anywhere) dominates, and
// hand findGap a specs dict that lacks it. The second lock found 20 Sept:
// findGapInLayer looked specs up with the suffixed name, found nothing,
// fell through to the layer-blind findGap, which never checked specs, and
// proposed fma4/te every eight windows.
op2 = TransferOperator.new;
30.do { op2.observe('fma4@slow'); op2.observe('te@slow'); op2.observe('sc@slow'); op2.observe('ry@slow'); };
30.do { op2.observe('fma4@slow'); op2.observe('fma4@slow'); op2.observe('te@slow'); };
op2.compute;
specs = Dictionary.new;
specs["te"] = Dictionary.new.put("dur", "0.5").put("layer", "mid");
specs["sc"] = Dictionary.new.put("dur", "0.05").put("layer", "micro");
specs["ry"] = Dictionary.new.put("dur", "0.08").put("layer", "micro");
g = mw.findGap(op2, 5, specs);
say.(g.notNil, "findGap(specs) finds a pair: " ++ g);
say.(g.notNil and: { g.every { |x| mw.bare(x) != "fma4" } }, "and it never touches the spec-less fma4");
say.(g.notNil and: { g.every { |x| mw.specOf(specs, x).notNil } }, "both endpoints resolve through specOf");
g = mw.findGapInLayer(op2, specs, "micro", 5);
say.(g.notNil and: { g.every { |x| mw.specOf(specs, x).notNil } }, "findGapInLayer(micro) resolves both endpoints: " ++ g);
say.(mw.specOf(specs, 'te@slow').notNil, "specOf strips the suffix");
say.(mw.specOf(specs, 'fma4@slow').isNil, "specOf is nil for a machine with no spec");

// 6. the shape metric counts. Third lock, 20 Sept: the set Jaccard passed
// 0 of 2,905 logged candidates; weighted Jaccard at the same threshold
// passes 364. These values are the ones the Python simulation used.
say.(mw.shapeDistance("Pseg1Pseq4Pwhite4Pn2", "Pseg1Pseq4Pwhite4Pn2") == 0.0, "identical -> 0");
say.((mw.shapeDistance("Pseg1Pseq4Pwhite4Pn2", "Pgeom1Pseg1Pseq3Pwhite2Pn5") - (1 - (8/15))).abs < 1e-9,
	"template vs Pgeom1Pseg1Pseq3Pwhite2Pn5 = 1-8/15: " ++ mw.shapeDistance("Pseg1Pseq4Pwhite4Pn2", "Pgeom1Pseg1Pseq3Pwhite2Pn5").round(0.001));
say.((mw.shapeDistance("Pseq1Pwhite1Pn1", "Pseq8Pwhite8Pn8") - (1 - (3/24))).abs < 1e-9, "Pseq1 is not Pseq8: " ++ mw.shapeDistance("Pseq1Pwhite1Pn1", "Pseq8Pwhite8Pn8").round(0.001));
say.(mw.shapeDistance("Pseq1", "") == 1.0, "vs empty -> 1");
say.(mw.shapeDistance("", "") == 0.0, "empty vs empty -> 0");
say.(mw.countIn("Pseg1Pseq12Pwhite4Pn2", "Pseq") == 12, "countIn reads two digits");
say.(mw.countIn("Pseg1Pseq12Pwhite4Pn2", "Pwrand") == 0, "countIn absent -> 0");

"".postln;
(if (pass) { "ALL PASS" } { "SOME FAILED" }).postln;
0.exit;
)
