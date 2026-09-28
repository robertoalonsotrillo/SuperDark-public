// BOTH ARMS OF MachineWriter, END TO END, INTO REAL FILES.
//
// test_grammar checks the grammar in isolation. This checks what MachineWriter
// actually WRITES: it drives a real TransferOperator until it has a gap, calls
// propose in each arm, then loads the emitted .scd files exactly the way the
// factory loads them and pulls events out of the resulting patterns.
//
// The arms differ by arguments and nothing else:
//   control   grammar nil                -- the template, unchanged since August
//   grammar   grammar set, table nil     -- the factory chooses the shape
//   shared    grammar set, table set     -- rates drawn from one table
//
// Files go to a scratch directory. NOTHING is written into the factory's mutable
// directory, because the live factory scans it and would load whatever it finds.
//
//   sclang workdir_music/tools/test_writer_arms.scd

(
var op, mw, gram, specs, dir, cells, arms, nEv = 60, bad = 0, progPath, say;

progPath = "/tmp/gramtest/arms.txt";
say = { |s|
	var f = File(progPath, "a");
	if (f.isOpen) { f.write(s ++ "\n"); f.close };
	s.postln;
};
File.delete(progPath);

dir = "/tmp/gramtest/written";
File.mkdir(dir);

// A transfer operator with enough history that findGap has something to find.
// Deliberately lopsided: some transitions common, some never taken, which is
// the shape of a real run and the condition the gap finder exists for.
op = TransferOperator.new(400);
cells = [\aa, \bb, \cc, \dd, \ee];
600.do { |i|
	op.observe(cells[ (i % 7).min(4) ]);
	if (i % 5 == 0) { op.compute };
};
op.compute;
say.value("  operator has " ++ op.cells.size ++ " cells");

// weights.json's shape: measured median event duration per machine, plus the
// body and centre the grammar arm reads.
specs = Dictionary.new;
cells.do { |c, i|
	specs[c.asString] = Dictionary[
		"dur" -> (0.04 + (i * 0.09)).asString,
		"body" -> (0.12 + (i * 0.03)).asString,
		"centre" -> (600 + (i * 700)).asString ];
};

gram = PatternGrammar.new(3);
arms = [
	["control", nil,  nil],
	["grammar", gram, nil],
	["shared",  gram, [1.0, 1.2, 1.5, 1.8]]
];

arms.do { |arm|
	var label = arm[0], g = arm[1], tbl = arm[2], ok = 0, tried = 0;
	// a fresh writer per arm: `bridged` retires pairs, so a shared writer would
	// starve the later arms of gaps and the comparison would be of nothing
	mw = MachineWriter.new(dir, 0.25);
	12.do { |k|
		var res, path, src, fn, pat, st, ev, fine = true, why = "";
		res = mw.propose(op, specs, dir, "gap", g, tbl, 0.8 + 0.5.rand);
		if (res.notNil) {
			tried = tried + 1;
			path = dir ++ "/" ++ res[0] ++ ".scd";
			// loaded the way the factory loads it: compile the file, call the
			// function with a buffer list and the args dictionary
			src = File.readAllString(path);
			fn = nil;
			try { fn = src.compile } { |e| fine = false; why = "compile" };
			if (fn.isNil) { fine = false; if (why == "") { why = "compile-nil" } };
			if (fine) {
				try {
					pat = fn.value.value([0, 1, 2, 3],
						IdentityDictionary[\density -> 0.5, \avgrms -> 0.2,
							\avgcent -> 2400, \percpitch -> 0.6]);
				} { |e| fine = false; why = "value: " ++ e.errorString };
			};
			if (fine and: { pat.isNil }) { fine = false; why = "nil pattern" };
			if (fine) {
				st = pat.asStream;
				nEv.do {
					if (fine) {
						ev = st.next(Event.new);
						if (ev.isNil) { fine = false; why = "stream ended" } {
							var d = ev[\dur], r = ev[\rate], a = ev[\amp];
							if (d.isNil or: { d.isNaN } or: { d <= 0 } or: { d.abs >= 1e12 })
								{ fine = false; why = "dur " ++ d };
							if (fine and: { r.isNil or: { r.isNaN } or: { r <= 0 } or: { r > 8 } })
								{ fine = false; why = "rate " ++ r };
							if (fine and: { a.isNil or: { a.isNaN } or: { a > 1 } })
								{ fine = false; why = "amp " ++ a };
						};
					};
				};
			};
			if (fine) { ok = ok + 1 } {
				bad = bad + 1;
				say.value("    FAIL " ++ label ++ " " ++ res[0] ++ " : " ++ why);
			};
		};
	};
	say.value("  " ++ label.padRight(8) ++ " wrote " ++ tried ++ ", "
		++ ok ++ " produced " ++ nEv ++ " safe events");
};

say.value("");
if (bad == 0) {
	say.value("  PASS. All three arms emit machines that load and run.");
	say.value("  The control arm is still the August template; the difference");
	say.value("  between arms is the argument list and nothing else.");
} {
	say.value("  DO NOT WIRE THIS IN. " ++ bad ++ " machines failed.");
};
say.value("");
0.exit;
)
