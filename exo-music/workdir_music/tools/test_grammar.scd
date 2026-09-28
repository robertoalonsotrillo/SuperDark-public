// DOES THE GRAMMAR EMIT MACHINES THAT ARE SAFE TO PLAY?
//
// This generates many machines from PatternGrammar, compiles each one, and pulls
// events out of it. It runs entirely in the language, touches no server, and
// writes nothing into the factory's mutable directory.
//
// The failure modes it exists to catch are not stylistic. A generated `dur` that
// reaches zero is an infinite loop inside a Routine and takes the factory down;
// a NaN rate reads a buffer at nonsense speed; an unbounded Pgeom runs to inf in
// a few dozen events. The old template could not do any of these because I fixed
// its shape. A grammar can, so it must be shown not to before it writes anything
// the factory will play.
//
//   sclang workdir_music/tools/test_grammar.scd

(
var g, nMach = 400, nEv = 120, fails = 0, parsed = 0, ran = 0, shapes = IdentityDictionary.new,
    durMin = inf, durMax = 0, rateMin = inf, rateMax = 0, ampMax = 0, cutMin = inf, cutMax = 0,
    ctxs, report, progPath = "/tmp/gramtest/progress.txt", say;

// PROGRESS GOES TO A FILE, OPENED AND CLOSED EACH TIME.
// sclang's stdout is block-buffered when it is not a terminal, so postln output
// from a long run appears only at exit -- and if the run throws, sclang drops to
// the interpreter and NOTHING is ever flushed. A silent process at 0% CPU then
// looks identical to a hang, which cost two wrong diagnoses here already. A file
// closed after every line is visible from outside while the run is still going,
// so "which machine did it stop on" is answerable.
say = { |s|
	var f = File(progPath, "a");
	if (f.isOpen) { f.write(s ++ "\n"); f.close };
	s.postln;
};
File.delete(progPath);

g = PatternGrammar.new(3);

// Contexts spanning what the factory actually measures: the micro layer at 30 ms
// and the macro layer at seconds, quiet and loud, dark and bright, and pitch
// ratios across the whole range \playback tolerates.
ctxs = Array.fill(nMach, { |i|
	(ioi:    0.02 + 2.0.rand,
	 body:   0.03 + 0.3.rand,
	 centre: 200 + 4000.rand,
	 ratio:  0.3 + 3.0.rand)
});

"".postln;
("  generating " ++ nMach ++ " machines, pulling " ++ nEv ++ " events from each").postln;
"".postln;

ctxs.do { |ctx, i|
	var m, src, fn, pat, st, ev, ok = true, why = "";
	// written BEFORE the work, so the file names the machine that stalls
	if (i % 20 == 0) { say.value("  .. at machine " ++ i) };
	// Half get a shared table, half do not: the control arm is exercised by the
	// test rather than assumed to work.
	m = g.machine(ctx, if (i.even) { nil } { [1.0, 1.2, 1.5, 1.8] }, 1000 + i);

	src = "Pbind("
	++ "\\dur, "    ++ m[\dur]    ++ ", "
	++ "\\rate, "   ++ m[\rate]   ++ ", "
	++ "\\cutoff, " ++ m[\cutoff] ++ ", "
	++ "\\amp, "    ++ m[\amp]    ++ ", "
	++ "\\pan, "    ++ m[\pan]    ++ ")";

	// 1. DOES IT COMPILE. A grammar that emits unbalanced parentheses or a
	//    misspelled class name would otherwise fail at the moment the factory
	//    loads it, which is while it is playing.
	fn = nil;
	try { fn = src.compile } { |e| ok = false; why = "compile" };
	if (fn.isNil) { ok = false; if (why == "") { why = "compile-nil" } };

	if (ok) {
		parsed = parsed + 1;
		try { pat = fn.value } { |e| ok = false; why = "value" };
	};

	// 2. DOES IT PRODUCE FINITE, IN-RANGE EVENTS. Pulling nEv events is the only
	//    way to see what a stochastic tree actually does; inspecting the source
	//    cannot tell you that a Pgeom inside a Pn diverges after forty steps.
	if (ok and: { pat.notNil }) {
		st = pat.asStream;
		nEv.do {
			if (ok) {
				ev = st.next(Event.new);
				if (ev.isNil) { ok = false; why = "stream ended" } {
					var d = ev[\dur], r = ev[\rate], c = ev[\cutoff], a = ev[\amp];
					// no isInf on Float in SC; magnitude does the same job
					if (d.isNil or: { d.isNumber.not } or: { d.isNaN }
						or: { d.abs >= 1e12 } or: { d <= 0 })
						{ ok = false; why = "dur " ++ d };
					if (ok and: { r.isNil or: { r.isNaN } or: { r <= 0 } or: { r > 8 } })
						{ ok = false; why = "rate " ++ r };
					if (ok and: { c.isNil or: { c.isNaN } or: { c <= 0 } or: { c > 20000 } })
						{ ok = false; why = "cutoff " ++ c };
					if (ok and: { a.isNil or: { a.isNaN } or: { a < 0 } or: { a > 1 } })
						{ ok = false; why = "amp " ++ a };
					if (ok) {
						durMin = min(durMin, d); durMax = max(durMax, d);
						rateMin = min(rateMin, r); rateMax = max(rateMax, r);
						cutMin = min(cutMin, c); cutMax = max(cutMax, c);
						ampMax = max(ampMax, a);
					};
				};
			};
		};
		if (ok) { ran = ran + 1 };
	};

	if (ok.not) {
		fails = fails + 1;
		if (fails <= 8) {
			("  FAIL " ++ i ++ " (" ++ why ++ ")").postln;
			("      dur  " ++ m[\dur]).postln;
			("      rate " ++ m[\rate]).postln;
		};
	};

	// How many DISTINCT SHAPES the grammar produced, counting the outermost
	// combinator of each slot. This is the number the whole exercise is for:
	// the old template has exactly one shape.
	shapes[(m[\dur].keep(9) ++ "/" ++ m[\rate].keep(9) ++ "/" ++ m[\cutoff].keep(9)).asSymbol]
		= (shapes[(m[\dur].keep(9) ++ "/" ++ m[\rate].keep(9) ++ "/" ++ m[\cutoff].keep(9)).asSymbol] ? 0) + 1;
};

"".postln;
("  compiled            " ++ parsed ++ " / " ++ nMach).postln;
("  produced " ++ nEv ++ " safe events  " ++ ran ++ " / " ++ nMach).postln;
("  failed              " ++ fails).postln;
"".postln;
("  dur     " ++ durMin.round(0.0001) ++ " .. " ++ durMax.round(0.0001) ++ " s").postln;
("  rate    " ++ rateMin.round(0.001) ++ " .. " ++ rateMax.round(0.001)).postln;
("  cutoff  " ++ cutMin.round(0.1) ++ " .. " ++ cutMax.round(0.1) ++ " Hz").postln;
("  amp     max " ++ ampMax.round(0.0001)).postln;
("  distinct slot shapes " ++ shapes.size ++ " across " ++ nMach ++ " machines "
 ++ "(the hand-written template has 1)").postln;
"".postln;
if (fails == 0) {
	"  PASS. Every machine compiled and produced only finite, in-range events.".postln;
	"  This does NOT say they sound like anything. It says none of them can".postln;
	"  hang a Routine, read a buffer backwards, or emit a NaN into the mix.".postln;
} {
	("  DO NOT WIRE THIS IN. " ++ fails ++ " machines failed.").postln;
};
"".postln;
0.exit;
)
