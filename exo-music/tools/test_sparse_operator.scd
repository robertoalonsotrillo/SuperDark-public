// IS computeSparse THE SAME OPERATOR, AND IS IT FASTER?
//
// compute builds a dense n x n matrix and runs 90 nested n x n loops through it
// in the interpreter. Measured 5 Sept: 0.75 s at n=184, 7.94 s at n=600,
// 11.44 s at n=736 -- and it runs every three windows. That cost is the reason
// the operator watches only the micro slot: widening its alphabet to see macro
// and mid puts n near 600 and spends a third of the factory's wall clock inside
// an uninterruptible loop.
//
// computeSparse claims to compute the same thing in O(nnz + n). This checks the
// claim on the operator's REAL accumulated memory rather than on a synthetic
// matrix, because the sparsity of the real thing is the whole question.
//
// AGREEMENT IS CHECKED BEFORE SPEED. A faster function that returns a different
// stationary distribution is not an optimisation, it is a different operator
// wearing the name of this one -- and every charter bound derived from the gap
// would silently start measuring something else. That failure has a precedent
// here: the 0.9 drift threshold turned out not to be commensurable with the
// runs it was quoted against.
//
// The second eigenvector is NOT compared. It starts from a random vector in
// both, so the two runs differ by construction; only lambda2, which both
// converge to, is meaningful.
//
//     sclang -l /tmp/harness_conf.yaml tools/test_sparse_operator.scd
(
var say, out = "/tmp/sparseop.txt", root, mem, opa, opb,
    tDense, tSparse, sa, sb, maxDiff = 0, nnz = 0, cellCount;

root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music";
("rm -f " ++ out).systemCmd;
say = { |t| var g = File(out, "a"); if (g.isOpen) { g.write(t ++ "\n"); g.close } };

mem = (root ++ "/mutable/memory.json").parseYAMLFile;
if (mem.isNil or: { mem["operator"].isNil }) {
    say.value("  no operator memory to test against");
    0.exit;
};

opa = TransferOperator.new;  opa.loadDict(mem["operator"]);
opb = TransferOperator.new;  opb.loadDict(mem["operator"]);

tDense  = Main.elapsedTime; opa.compute;       tDense  = Main.elapsedTime - tDense;
tSparse = Main.elapsedTime; opb.computeSparse; tSparse = Main.elapsedTime - tSparse;

cellCount = opa.cells.size;
mem["operator"].keysValuesDo { |a, row|
    if (row.isKindOf(Dictionary) or: { row.isKindOf(Event) }) { nnz = nnz + row.size };
};

sa = opa.stationary; sb = opb.stationary;
if (sa.notNil and: { sb.notNil } and: { sa.size == sb.size }) {
    sa.size.do { |i| maxDiff = max(maxDiff, (sa[i] - sb[i]).abs) };
} { maxDiff = -1 };

say.value("");
say.value("  operator memory: " ++ cellCount ++ " cells, " ++ nnz ++ " observed transitions");
say.value("  density: " ++ (100 * nnz / max(1, cellCount * cellCount)).round(0.01) ++ "% of the matrix");
say.value("");
say.value("  AGREEMENT");
say.value("    max |stationary difference| : " ++ maxDiff);
say.value("    spectral gap  dense  " ++ opa.gap.round(0.000001));
say.value("    spectral gap  sparse " ++ opb.gap.round(0.000001));
say.value("    gap difference             : " ++ (opa.gap - opb.gap).abs.round(0.000001));
say.value("");
say.value("  SPEED");
say.value("    dense  " ++ tDense.round(0.001) ++ " s");
say.value("    sparse " ++ tSparse.round(0.001) ++ " s");
say.value("    speedup x" ++ (tDense / max(1e-9, tSparse)).round(0.1));
say.value("");
if (maxDiff >= 0 and: { maxDiff < 1e-6 } and: { (opa.gap - opb.gap).abs < 1e-4 }) {
    say.value("  AGREES. Same stationary distribution to 1e-6 and the same gap, so");
    say.value("  every bound derived from the dense version still means what it meant.");
} {
    say.value("  DISAGREES -- do not use it. A faster function returning a different");
    say.value("  answer is a different operator, and the charter bounds would silently");
    say.value("  start measuring something else.");
};
0.exit;
)
