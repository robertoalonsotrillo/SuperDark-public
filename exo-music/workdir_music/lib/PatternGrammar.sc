// A GRAMMAR THE FACTORY COMPOSES, INSTEAD OF A TEMPLATE IT FILLS IN.
//
// MachineWriter's honest limit, written by me in its own header: "I wrote this
// class, and the template it emits. The factory chooses WHERE a machine is
// needed and WHAT its parameters are; it does not invent the form." Every
// machine the factory has ever written is the same Pbind with different numbers
// in it. The 154 bridges of 26 Aug were not 154 behaviours, and even after the
// duplicate-pair fix the survivors differ only in constants.
//
// This is the second axis. A term is built by expanding a TYPED grammar to a
// bounded depth, so the emitted pattern has a SHAPE the factory chose: how many
// regimes a stream alternates between, whether it is stochastic or cyclic,
// whether it stutters, whether one parameter sweeps while another jumps. The
// space of machines becomes larger than the space I wrote, which is the
// difference between a parameterisation and a generative grammar.
//
// WHAT IS STILL MINE, so this is not overclaimed the way the vocabulary count
// was overclaimed in August:
//   * The combinators. Pseq, Pwhite, Pn, Prand, Pseg, Pgeom, Pstutter and
//     multiplication are SuperCollider's, and the subset is my choice.
//   * The type discipline, the depth bound, and every guard rail.
//   * The slots. A machine still has dur, rate, cutoff, amp, pan and buf,
//     because \playback has those arguments.
// What is NOT mine any more is the structure of the expression in each slot.
// A machine can now be a shape I did not write down, and there are more such
// shapes than I could enumerate by hand.
//
// SAFETY IS NOT OPTIONAL HERE. This emits code into a factory that is playing.
// A generated `dur` that reaches zero is an infinite loop in a Routine; a
// negative or huge `rate` reads a buffer at nonsense speed; a NaN anywhere
// silently kills a voice. So every slot is clamped AT EMISSION by construction
// -- not by hoping the grammar stays in range -- and tools/test_grammar.scd
// generates hundreds of machines and runs their event streams before any of
// this is allowed near the live factory.
PatternGrammar {
	var <>maxDepth, <>seed, <lastTree;

	*new { |maxDepth = 3| ^super.new.init(maxDepth) }

	init { |d| maxDepth = d; lastTree = ""; ^this }

	// ---- helpers -----------------------------------------------------------
	// Everything numeric that reaches the emitted text goes through here, so a
	// NaN or an inf produced by any amount of arithmetic upstream cannot become
	// a literal in a file the factory is about to compile and play.
	// SuperCollider has no isInf on Float -- the first version of this guard
	// called one, sclang threw DoesNotUnderstand, dropped to the interpreter and
	// sat there producing no output at all, which reads exactly like a hang. The
	// magnitude test does the same job and exists.
	num { |v, lo, hi, places = 4|
		var x = v;
		if (x.isNil or: { x.isNumber.not } or: { x.isNaN } or: { x.abs >= 1e12 })
			{ x = (lo + hi) / 2 };
		^x.clip(lo, hi).round(10 ** places.neg)
	}

	f { |v, lo, hi| ^this.num(v, lo, hi).asString }

	pick { |list| ^list.choose }

	// ---- the grammar -------------------------------------------------------
	// A stream of positive numbers centred on `v`, spread by `spread` (a
	// multiplicative half-width), expanded to `depth`. Each production returns
	// SuperCollider source text; the tree is recorded alongside it so a machine
	// can say what shape it is rather than only how it sounds.
	//
	// The productions divide into three kinds and that division is the point:
	//   LEAF        a value or a distribution           -- no structure
	//   SEQUENCING  Pseq, Pn, Prand, Pwrand             -- structure in time
	//   SHAPING     Pseg, Pgeom, Pstutter, scaling      -- structure in value
	// A hand-written template is one fixed path through this. The factory now
	// picks a path.
	stream { |v, spread = 0.3, depth = 0, lo = 0.001, hi = 1e6, kinds|
		var opts, k, a, b, n, parts, txt, r;
		opts = kinds ?? { if (depth >= maxDepth) { [\lit, \white] }
		                  { [\lit, \white, \seq, \pn, \prand, \pwrand,
		                     \pseg, \pgeom, \pstutter, \scale] } };
		k = this.pick(opts);
		^switch (k)
		{ \lit } {
			this.f(v, lo, hi)
		}
		{ \white } {
			a = v * (1 - spread); b = v * (1 + spread);
			"Pwhite(" ++ this.f(a, lo, hi) ++ ", " ++ this.f(b, lo, hi) ++ ")"
		}
		{ \seq } {
			// two to four regimes, each its own subtree: this is where a machine
			// gets alternating behaviour instead of one stationary distribution
			n = 2 + 3.rand;
			parts = Array.fill(n, { |i|
				this.stream(v * (0.6 + 0.8.rand), spread, depth + 1, lo, hi) });
			"Pseq([" ++ parts.join(", ") ++ "], inf)"
		}
		{ \pn } {
			// repeat a subtree a fixed number of times -- periodicity, which the
			// old template had only as the fixed Pn(..., 2 + 3.rand)
			"Pn(" ++ this.stream(v, spread, depth + 1, lo, hi) ++ ", " ++ (2 + 5.rand) ++ ")"
		}
		{ \prand } {
			n = 2 + 2.rand;
			parts = Array.fill(n, { this.stream(v * (0.6 + 0.8.rand), spread, depth + 1, lo, hi) });
			"Prand([" ++ parts.join(", ") ++ "], inf)"
		}
		{ \pwrand } {
			// unequal weights: a machine that mostly does one thing and rarely
			// another, which is a shape the template could not express at all
			n = 2 + 2.rand;
			parts = Array.fill(n, { this.stream(v * (0.6 + 0.8.rand), spread, depth + 1, lo, hi) });
			r = Array.fill(n, { 0.1 + 0.9.rand });
			r = r / r.sum;
			"Pwrand([" ++ parts.join(", ") ++ "], "
			++ "[" ++ r.collect({ |x| x.round(0.001) }).join(", ") ++ "].normalizeSum, inf)"
		}
		{ \pseg } {
			// a swept value rather than a jumping one
			"Pseg(Pseq([" ++ this.f(v, lo, hi) ++ ", "
			++ this.f(v * (1 + spread), lo, hi) ++ ", "
			++ this.f(v * (1 - spread * 0.6), lo, hi) ++ "], inf), "
			++ "Pseq([" ++ this.f(1 + 8.0.rand, 0.05, 60) ++ ", "
			++ this.f(1 + 12.0.rand, 0.05, 60) ++ "], inf), "
			++ "\\" ++ this.pick(["sin", "lin", "exp"]) ++ ")"
		}
		{ \pgeom } {
			// a value that accelerates or decays across a run of events -- the
			// only production here that produces a DIRECTION
			n = 3 + 5.rand;
			r = 0.82 + 0.36.rand;                       // ratio per step
			"Pn(Pgeom(" ++ this.f(v, lo, hi) ++ ", " ++ r.round(0.001) ++ ", " ++ n ++ "), inf)"
		}
		{ \pstutter } {
			"Pstutter(Pwhite(1, " ++ (2 + 3.rand) ++ "), "
			++ this.stream(v, spread, depth + 1, lo, hi) ++ ")"
		}
		{ \scale } {
			"(" ++ this.stream(v, spread, depth + 1, lo, hi) ++ " * "
			++ (0.6 + 0.8.rand).round(0.001) ++ ")"
		}
		{ this.f(v, lo, hi) }
	}

	// A slot is a stream plus its guard. The guard is not advice, it is applied
	// to the emitted expression, so no path through the grammar can produce a
	// value outside the range \playback can survive.
	// EVERY SLOT IS WRAPPED IN Pn(..., inf), AND THAT IS NOT COSMETIC.
	//
	// Several productions are finite: Pn(X, k) yields k values and stops,
	// Pstutter and the scaling wrapper inherit that, and Pgeom is finite before
	// it is repeated. A Pbind ends when its SHORTEST stream ends, so one finite
	// slot silently kills the whole machine after a handful of events. The first
	// run of test_grammar caught exactly this: 33 of 400 machines ended early,
	// every one of them "stream ended" and not an unsafe value.
	//
	// It is the failure the hand-written template could not have, because I put
	// `inf` on everything by hand. A grammar has to make that structural, so a
	// finite subtree becomes a repeating cycle instead of an ending one --
	// which is also the musically sensible reading of a finite regime.
	slot { |v, spread, lo, hi|
		^"Pn(" ++ this.stream(v, spread, 0, lo, hi) ++ ", inf).max("
		++ lo ++ ").min(" ++ hi ++ ")"
	}

	// ---- routing, envelope, layers: the slots the originals had and the ----
	// ---- written machines did not, 22 Sept 2026 ---------------------------
	//
	// Every written machine before today had \out, 0 and an envelope that was
	// two fixed fractions of the event. The originals route each event to one
	// of four buses in a sequence that decides which events ring, and their
	// envelopes range from a click to a swell. These three productions put
	// those axes under the grammar. The bus variables are read with a `? [0]`
	// so a machine written today still compiles in a factory without returns.

	// A sequence over the four buses: 2-4 segments, each a bus repeated 1-6
	// times. Which buses, in what order, how long each holds: the factory's.
	out {
		var buses = ["~dryBus", "~reverbShortBus", "~reverbMidBus", "~reverbLongBus"],
		    n = 2 + 3.rand, parts;
		parts = Array.fill(n, {
			"((" ++ this.pick(buses) ++ " ? [0])[0] ! " ++ (1 + 6.rand) ++ ")" });
		// Pflatten: `bus ! n` is an array, and an Event would expand it into
		// n synths. Flattened it is one bus held for n events, which is what
		// the sequence means.
		^"Pflatten(1, Pseq([" ++ parts.join(", ") ++ "], inf))"
	}

	// atk and rel as fractions of the event, drawn together, so a machine has
	// ONE articulation. Three profiles the originals span: a click that decays,
	// a body that sustains, a swell that arrives late.
	env { |ioi|
		var p = this.pick([\percussive, \percussive, \sustained, \swell]), atk, rel;
		switch (p)
		{ \percussive } { atk = ioi * (0.04 + 0.1.rand);  rel = ioi * (0.5 + 0.5.rand) }
		{ \sustained }  { atk = ioi * (0.25 + 0.25.rand); rel = ioi * (1.2 + 1.4.rand) }
		{ \swell }      { atk = ioi * (0.6 + 0.5.rand);   rel = ioi * (0.3 + 0.3.rand) };
		^(atk: this.f(atk, 0.003, 4.0), rel: this.f(rel, 0.01, 8.0), profile: p)
	}

	// 1 to 3 simultaneous layers of the same machine, each at a rate interval
	// from the shared table (or a plain interval when there is none), quieter
	// and offset in the field. dronePlayer stacks three fixed layers; here the
	// count and the intervals are drawn.
	layers { |sim = nil|
		var n = this.pick([1, 1, 1, 2, 2, 3]), table;
		table = if (sim.notNil and: { sim.asArray.asSet.size > 1 })
			{ sim.asArray.reject({ |r| (r - 1.0).abs < 1e-6 }) } { [0.5, 0.75, 1.5, 2.0] };
		if (table.isEmpty) { table = [0.5, 0.75, 1.5, 2.0] };
		^Array.fill(n - 1, { |i|
			(ratio: this.num(this.pick(table), 0.25, 4.0),
			 amp:   (0.45 + 0.3.rand).round(0.01),
			 pan:   ((i.odd.if({ -1 }, { 1 })) * (0.3 + 0.5.rand)).round(0.01)) })
	}

	// ---- the processing stages, per machine (B8 rung 1, 22 Sept 2026) ------
	//
	// \playback, \playbackHP and \playgran carry res (Ringz body), dly (comb
	// with feedback) and blur (envelope lowpass), all dry by default. With
	// probability `weight` a machine sets its own: one or two stages, depths
	// bounded here below what the 4-6 Sept overlay measured as safe, the
	// resonance anchored on the machine's centre. Returns nil for a dry
	// machine, else an Event of slot -> text.
	dsp { |centre, weight = 0.5|
		var which, d = ();
		if (weight.coin.not) { ^nil };
		which = this.pick([[\res], [\dly], [\blur], [\res, \blur], [\dly, \blur], [\res, \dly]]);
		if (which.includes(\res)) {
			d[\res]   = this.f(0.15 + 0.35.rand, 0.0, 0.5);
			d[\resfz] = this.slot(centre * this.pick([0.5, 1.0, 1.5, 2.0]), 0.2, 60, 6000);
			d[\resrt] = this.f(0.1 + 1.4.rand, 0.02, 3.0);
		};
		if (which.includes(\dly)) {
			d[\dly]   = this.f(0.15 + 0.35.rand, 0.0, 0.5);
			d[\dlyt]  = this.f(this.pick([0.008, 0.02, 0.05, 0.12, 0.25, 0.4]) * (0.8 + 0.4.rand), 0.005, 0.45);
			d[\dlyfb] = this.f(0.2 + 0.55.rand, 0.0, 0.75);
		};
		if (which.includes(\blur)) {
			d[\blur]   = this.f(0.3 + 0.5.rand, 0.0, 0.8);
			d[\blurhz] = this.f(centre * this.pick([0.5, 1.0, 2.0]), 200, 12000);
		};
		d[\tree] = which.collect(_.asString).join("+");
		^d
	}

	// ---- the machine -------------------------------------------------------
	// `ctx` carries what the factory measured: ioi, body, centre, and the pitch
	// ratio the machine is born at. `sim` is an optional shared ratio table from
	// Simultaneity; when it is nil the rate slot is grammar-only, which is the
	// control arm.
	machine { |ctx, sim = nil, sd = nil|
		var ioi, body, centre, ratio, rateExpr, tree;
		if (sd.notNil) { thisThread.randSeed = sd; seed = sd };
		ioi    = (ctx[\ioi] ? 0.12).clip(0.01, 4.0);
		body   = (ctx[\body] ? 0.2).clip(0.02, 0.4);
		centre = (ctx[\centre] ? 1200).clip(120, 6000);
		ratio  = (ctx[\ratio] ? 1.0).clip(0.25, 4.0);

		// THE RATE SLOT IS WHERE PITCH ENTERS.
		// The old template wrote Pseq([1.0, 0.85 + 0.4.rand, 1.0], inf) -- one
		// constant drawn when the machine was born and never revised, unrelated
		// to anything the factory had measured. mainpitch was computed every
		// window and discarded. Here the machine's rate is anchored on the pitch
		// ratio it was written at, and when a shared table is supplied the
		// members of the table are what it moves between.
		// A DEGENERATE TABLE IS WORSE THAN NO TABLE, so it is refused here.
		// The first shadow run emitted \rate, Pn(Pseq([1.0], inf), inf): the
		// table had come back as [1.0], every machine got a constant rate, and
		// the result had LESS pitch movement than the August template's random
		// constant. A table needs at least two distinct members to relate
		// anything to anything; below that, fall through to the grammar.
		rateExpr = if (sim.notNil and: { sim.asArray.asSet.size > 1 }) {
			// The shared table, anchored on this machine's birth pitch. Same
			// infinite-and-guarded discipline as every other slot.
			"Pn(Pseq([" ++ sim.collect({ |r|
				(ratio * r).clip(0.25, 4.0).round(0.0001) }).join(", ")
			++ "], inf), inf).max(0.25).min(4.0)"
		} {
			this.slot(ratio, 0.18, 0.25, 4.0)
		};

		tree = "dur=" ++ maxDepth ++ " ratio=" ++ ratio.round(0.001)
		    ++ " shared=" ++ (sim.notNil);
		lastTree = tree;

		^(
			dur:    this.slot(ioi, 0.35, 0.01, 6.0),
			rate:   rateExpr,
			cutoff: this.slot(centre, 0.5, 80, 9000),
			amp:    this.slot(body, 0.4, 0.0005, 0.5),
			pan:    "Pwhite(-0.75, 0.75)",
			out:    this.out,
			env:    this.env(ioi),
			layers: this.layers(sim),
			tree:   tree
		)
	}
}
