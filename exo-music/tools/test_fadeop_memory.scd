// Does the decayed operator leak? Run it hard, alone, and watch it grow.
//
// WHY THIS EXISTS. Wiring a halflife operator into the factory preceded
// SuperCollider taking 60 GB and bringing the machine down. The wiring is
// reverted. This reproduces the operator's work in isolation -- no server, no
// audio, no factory -- so the question "does this data structure grow without
// bound" can be answered without anything else running.
//
// RUN IT UNDER A MEMORY CAP. The shell wrapper sets ulimit -v, so if this is the
// leak the process dies instead of the machine:
//
//   ( ulimit -v 4000000; sclang -l tools/live_conf.yaml tools/test_fadeop_memory.scd )
//
// A test for a crash that must not be able to cause the crash again.
(
var op, cells, n = 12000, report, t0;

// A realistic vocabulary: about 150 behaviours, most of them bridges, drawn with
// the long tail the factory actually shows.
cells = Array.fill(27, { |i| ("m" ++ i).asSymbol })
     ++ Array.fill(123, { |i| ("br" ++ i).asSymbol });

op = TransferOperator.new(400);
t0 = Main.elapsedTime;

report = { |i|
    ("  " ++ i.asString.padLeft(6)
        ++ "  cells " ++ op.cells.size.asString.padLeft(4)
        ++ "  rows " ++ op.counts.size.asString.padLeft(4)
        ++ "  entries " ++ op.counts.values.sum({ |r| r.size }).asString.padLeft(6)
        ++ "  total " ++ op.total.round(0.1).asString.padLeft(9)
        ++ "  " ++ (Main.elapsedTime - t0).round(0.1).asString ++ "s").postln;
};

"  observations   cells   rows   entries      total    elapsed".postln;
n.do { |i|
    op.observe(cells.choose);
    if (i % 3 == 0) { op.compute };
    if (i % 1000 == 0) { report.value(i) };
};
report.value(n);

// The two things that would show a leak: entries should plateau at roughly
// cells^2 in the worst case and far below it in practice, and total should
// converge on the geometric limit 1/(1-decay), NOT keep climbing.
("\n  geometric limit for total: " ++ (1.0 / (1.0 - op.decay)).round(0.1)).postln;
("  observed total:            " ++ op.total.round(0.1)).postln;
("  entries:                   " ++ op.counts.values.sum({ |r| r.size })).postln;
("  cells:                     " ++ op.cells.size).postln;
0.exit;
)
