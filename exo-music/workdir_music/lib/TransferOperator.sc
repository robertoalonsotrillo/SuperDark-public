// The transfer operator, from SuperDark Factory P222-224.
//
//   "partition the factory's observable behavior into cells... count how often
//    behavior in one cell leads to behavior in another. The table of those
//    counted tendencies is the operator... the operator's eigenstates are the
//    special maps that fade without changing shape: patterns of more or less
//    reliable behavior. The operator's spectral gap is the distance between
//    those few slow-fading patterns and everything beneath them, giving us a
//    readout of whether versioning is happening at all."
//
// A CLASS rather than part of live_factory.scd, because that file is a single
// 1400-line parenthesised block and SuperCollider compiles it as one function.
// Adding this to it made sclang execute NOTHING -- no log, no boot, no error of
// any kind. Classes are compiled separately and have no such limit.
//
// WHAT EACH PART IS, MUSICALLY
//
//   stationary      the leading eigenvector. For a stochastic matrix lambda1 = 1 and
//             this is the stationary distribution: the near-invariant region
//             the factory currently occupies. THE DOMINANT BEHAVIOUR. Blending
//             selection toward it makes behaviour persist across windows
//             instead of being drawn fresh each one, which is the absence that
//             keeps returning as "random concatenation".
//
//   second    the second eigenvector: the mode that fades at |lambda2| WITHOUT
//             CHANGING SHAPE. Its positive and negative lobes are two
//             sub-populations, and rotating a phase across them makes each take
//             its turn against the dominant -- UNDERPINNING BEHAVIOURS MOVING
//             IN AND OUT OF SYNC, at a rate the operator sets rather than a
//             clock.
//
//   gap       1 - |lambda2|. Wide: one durable, cleanly separated version.
//             Narrow: versions bleeding into each other, or a version that is
//             provisional. P227 stable failure is a gap frozen wide in a bad
//             region; P229 learning death is a single cell with no variety;
//             P230 thrash is a gap that never settles. So the gap is the
//             coherence readout AND the pathology detector, in one number.
//
// A cell here is a MACHINE: the coarsest useful partition of observable
// behaviour, and dense enough to estimate from a few hundred windows. Counts
// accumulate across runs, so the operator describes the factory's whole history
// rather than one performance.
TransferOperator {
	var <counts,        // cell -> (cell -> n)
	    <cells,         // the cells actually observed, sorted
	    <stationary,            // leading eigenvector: the dominant behaviour
	    <second,        // second eigenvector: the phasing sub-populations
	    <lambda2 = 0,   // its decay rate
	    <gap = 0,       // 1 - lambda2
	    <phase = 0,     // rotates the second mode's lobes
	    <decay,         // per-observation multiplier, or nil for none
	    <halflife,      // observations after which a count is worth half
	    <wNow = 1.0,    // the weight the NEXT observation is recorded with
	    prev;

	// halflife nil (the default, and what every existing caller passes)
	// reproduces the original operator EXACTLY: no decay, no pruning, integral
	// counts. That matters because the accumulating operator STEERS selection at
	// operator_weight 0.35, so any change to it changes the factory. The decayed
	// variant is instrumentation and steers nothing.
	*new { |halflife| ^super.new.init(halflife) }

	init { |hl|
		counts = IdentityDictionary.new;
		cells = [];
		wNow = 1.0;
		this.setHalflife(hl);
		^this
	}

	// Set or change the half-life after construction. The factory builds `op`
	// before policy.json is loaded, so the value cannot be passed to *new. A
	// half-life only weights observations recorded AFTER it is set -- wNow keeps
	// growing from wherever it is -- so setting it late is exact, not approximate.
	setHalflife { |hl|
		halflife = if (hl.notNil and: { hl > 0 }) { hl } { nil };
		decay = halflife !? { 2.0 ** (-1.0 / halflife) };
		^this
	}

	// A stored count in units of "one observation at today's weight".
	//
	// 18 Sept 2026. wNow was never persisted, and loadDict cast every value with
	// asInteger. So a decayed operator did not survive a restart: counts recorded
	// at weight up to 1e150 were reloaded as-is against a fresh wNow of 1.0, and
	// every observation after the boot was worth nothing beside them. Then the
	// integer cast threw away everything renorm had scaled below 1. The forgetting
	// mechanism had only ever run with halflife nil, so none of this was reached.
	//
	// Saving EFFECTIVE counts fixes both. Divided by wNow they are already in
	// today's units, wNow = 1.0 on reload is then correct by construction, and
	// nothing needs to be persisted beyond the counts themselves.
	effective { |v| ^if (decay.notNil) { v / wNow } { v } }

	// Rescale to wNow = 1 and drop what has faded. O(entries), and it runs about
	// once every 400,000 observations -- two months at one window per 11.7 s --
	// so it never appears in the per-window budget.
	prRenorm {
		var s = wNow;
		counts.keys.asArray.do { |a|
			var r = counts[a], dead;
			if (r.notNil) {
				r.keys.asArray.do { |b| r[b] = r[b] / s };
				dead = r.keys.asArray.select { |b| r[b] < 0.01 };
				dead.do { |b| r.removeAt(b) };
				if (r.size == 0) { counts.removeAt(a) };
			};
		};
		wNow = 1.0;
	}

	// one transition per window: which behaviour followed which
	observe { |cell|
		var row;
		if (cell.notNil) {
			if (prev.notNil) {
				row = counts[prev];
				if (row.isNil) { row = IdentityDictionary.new; counts[prev] = row };
				// FORGETTING IN CONSTANT TIME.
				// The obvious implementation multiplies every count in every row
				// by the decay on every observation. It is correct and it is
				// unaffordable: hundreds of transient collections per window,
				// growing with the vocabulary.
				//
				// Instead of shrinking the past, GROW THE PRESENT. Recording
				// each observation with a geometrically rising weight makes an
				// event k steps old worth decay^k relative to now -- the same
				// exponential window, reached with one addition.
				//
				// It is EXACT, not an approximation, because compute() makes
				// every row stochastic: a factor common to all counts divides
				// out of every row sum, so the transition matrix, its
				// eigenvalues and lambda2 are identical to what the sweep would
				// have produced.
				row[cell] = (row[cell] ? 0) + wNow;
			};
			prev = cell;
			if (decay.notNil) {
				wNow = wNow / decay;
				// Float64 tops out near 1e308. Rescaling here is also where
				// behaviours the factory has abandoned leave the vocabulary.
				if (wNow > 1e150) { this.prRenorm };
			};
		};
	}

	// Effective transitions counted, for the log. Dividing by wNow converts the
	// weighted sum back to a count in units of "observations at today's weight",
	// so a decayed operator reports its EFFECTIVE memory and converges on the
	// geometric limit 1/(1-decay) instead of climbing for ever.
	total {
		var n = 0;
		counts.do { |row| row.do { |v| n = n + v } };
		^if (decay.notNil) { n / wNow } { n }
	}

	compute {
		var set, n, mat, v, w;

		set = Set.new;
		counts.keysValuesDo { |a, row| set.add(a); row.keysDo { |b| set.add(b) } };
		cells = set.asArray.sort { |a, b| a.asString < b.asString };
		n = cells.size;
		if (n < 3) { gap = 0; stationary = nil; second = nil; ^this };

		// row-stochastic. An UNOBSERVED row is uniform rather than zero, so the
		// chain stays irreducible and the stationary distribution is defined.
		mat = Array.fill(n, { |i|
			var row = counts[cells[i]],
			    r = Array.fill(n, { |j| ((row !? { row[cells[j]] }) ? 0).asFloat }),
			    tot = r.sum;
			if (tot > 0) { r / tot } { Array.fill(n, { 1.0 / n }) };
		});

		// LEADING EIGENVECTOR by power iteration on the left: v <- vP.
		v = Array.fill(n, { 1.0 / n });
		60.do {
			var nv = Array.fill(n, 0);
			n.do { |i| n.do { |j| nv[j] = nv[j] + (v[i] * mat[i][j]) } };
			v = nv / max(1e-12, nv.sum);
		};
		stationary = v;

		// SECOND EIGENVECTOR. Starting in the zero-sum subspace excludes the
		// lambda1 component, so iteration converges to the second mode and the
		// per-step contraction ratio IS |lambda2|.
		w = Array.fill(n, { 1.0.rand2 });
		w = w - (w.sum / n);
		lambda2 = 0;
		30.do {
			var nw = Array.fill(n, 0), a, b;
			n.do { |i| n.do { |j| nw[j] = nw[j] + (w[i] * mat[i][j]) } };
			nw = nw - (nw.sum / n);
			a = (w.squared.sum).sqrt;
			b = (nw.squared.sum).sqrt;
			if (a > 1e-9) { lambda2 = b / a };
			w = if (b > 1e-9) { nw / b } { nw };
		};
		second = w;
		gap = (1.0 - lambda2).clip(0, 1);
		^this
	}


	// ---- THE SAME OPERATOR, WITHOUT THE DENSE MATRIX -------------------------
	//
	// compute above is O(n^2): it builds a dense n x n matrix and runs 90 nested
	// n x n loops through it, in the interpreter. Measured 5 Sept:
	//
	//       n     seconds
	//     184      0.75      <- today, every 3 windows
	//     600      7.94
	//     736     11.44
	//
	// That is what stops the operator from watching more than one layer. Widening
	// its alphabet to see macro and mid would put n near 600-736 and spend a
	// third of the factory's wall clock inside an uninterruptible loop.
	//
	// But the matrix is nearly all zeros. 184 cells with 25,884 observations
	// cannot have filled 33,856 entries; most transitions never happened. So the
	// cost is an artefact of the REPRESENTATION and not of the mathematics.
	//
	// THE ONE TRICK THAT MAKES IT WORK. An unobserved row is uniform, not zero --
	// deliberately, so the chain stays irreducible and the stationary
	// distribution is defined. Uniform rows are DENSE by nature: each contributes
	// v[i]/n to every j, which would be O(n) per row and would put the n^2 back.
	// Instead their total mass is accumulated as a single scalar and spread once
	// per iteration. Sparse rows cost O(nnz); the uniform ones cost O(1) to
	// gather and O(n) to apply, once.
	//
	// Per iteration this is O(nnz + n) against O(n^2). It computes the same
	// quantity by the same method and is checked against compute rather than
	// trusted: tools/test_sparse_operator.scd runs both on the live memory and
	// compares the stationary vector and the spectral gap.
	computeSparse {
		var set, n, idx, rows, tots, uniform, v, w, lam = 0;

		set = Set.new;
		counts.keysValuesDo { |a, row| set.add(a); row.keysDo { |b| set.add(b) } };
		cells = set.asArray.sort { |a, b| a.asString < b.asString };
		n = cells.size;
		if (n < 3) { gap = 0; stationary = nil; second = nil; ^this };

		// cell -> index, so the inner loops never search
		idx = IdentityDictionary.new;
		cells.do { |c, i| idx[c] = i };

		// rows[i] is [[j, p], ...] for observed transitions; nil means uniform
		rows = Array.newClear(n);
		tots = Array.fill(n, 0);
		uniform = Array.fill(n, true);
		n.do { |i|
			var row = counts[cells[i]], pairs, tot = 0;
			if (row.notNil) {
				pairs = List.new;
				row.keysValuesDo { |b, c|
					var j = idx[b];
					if (j.notNil and: { c > 0 }) { pairs.add([j, c.asFloat]); tot = tot + c };
				};
				if (tot > 0) {
					rows[i] = pairs.asArray.collect({ |pr| [pr[0], pr[1] / tot] });
					uniform[i] = false;
				};
			};
		};

		v = Array.fill(n, { 1.0 / n });
		60.do {
			var nv = Array.fill(n, 0), umass = 0, sum;
			n.do { |i|
				if (uniform[i]) { umass = umass + v[i] } {
					rows[i].do { |pr| nv[pr[0]] = nv[pr[0]] + (v[i] * pr[1]) };
				};
			};
			if (umass > 0) { umass = umass / n; n.do { |j| nv[j] = nv[j] + umass } };
			sum = nv.sum;
			v = nv / max(1e-12, sum);
		};
		stationary = v;

		w = Array.fill(n, { 1.0.rand2 });
		w = w - (w.sum / n);
		30.do {
			var nw = Array.fill(n, 0), umass = 0, a, b;
			n.do { |i|
				if (uniform[i]) { umass = umass + w[i] } {
					rows[i].do { |pr| nw[pr[0]] = nw[pr[0]] + (w[i] * pr[1]) };
				};
			};
			if (umass != 0) { umass = umass / n; n.do { |j| nw[j] = nw[j] + umass } };
			nw = nw - (nw.sum / n);
			a = (w.squared.sum).sqrt;
			b = (nw.squared.sum).sqrt;
			if (a > 1e-9) { lam = b / a };
			w = if (b > 1e-9) { nw / b } { nw };
		};
		second = w;
		lambda2 = lam;
		gap = (1.0 - lam).clip(0, 1);
		^this
	}

	// THE CELL IS "sc@slow". THE MACHINE IS "sc". THEY NEVER MATCHED.
	//
	// Since operator_sees_macro (15 Sept) every observed state carries a
	// "@bucket" suffix, so cells read sc@slow, ry@slow, ... while `avail`
	// carries bare names. cells.indexOf(m) found nothing, the vector summed to
	// zero, dominantOver returned nil, and the caller's `if (dom.isNil) {
	// brk.value }` skipped the mix. THE OPERATOR STEERED NOTHING FOR FIVE DAYS,
	// through the 18 Sept repair (gap 0 -> 0.61, of a chain no one consulted)
	// and through operator_weight 0.35 -> 0.0 in the ten-arm run, which is why
	// that arm moved nothing: there was nothing to switch off. Found 20 Sept.
	//
	// Matching by bare name sums a machine's mass across every bucket it has
	// been seen in, which is the right reading of "how much does the operator
	// want m" whether the bucket is the constant it is today or varies later.
	bareOf { |cell|
		var s = cell.asString, i = s.indexOf($@);
		^if (i.isNil) { s } { s.copyRange(0, i - 1) }
	}
	indicesOf { |m|
		var bare = this.bareOf(m);
		^cells.selectIndices { |c| this.bareOf(c) == bare }
	}

	// the dominant distribution over a given set of machines, normalised
	dominantOver { |machines|
		var vec;
		if (stationary.isNil) { ^nil };
		vec = machines.collect { |m|
			var ix = this.indicesOf(m);
			if (ix.isEmpty) { 0 } { ix.collect { |i| stationary[i] }.sum }
		};
		if (vec.sum <= 0) { ^nil };
		^vec.normalizeSum
	}

	// the second mode over those machines, with its lobes rotated by phase.
	// The rotation rate is 1 - gap: a narrow gap means the modes are close in
	// decay rate, so they trade places faster.
	secondOver { |machines|
		var lobe;
		if (second.isNil) { ^nil };
		phase = phase + (1 - gap).max(0.02);
		lobe = (phase * 2pi).sin;
		^machines.collect { |m|
			var ix = this.indicesOf(m);
			if (ix.isEmpty) { 0 } { ix.collect { |i| second[i] }.sum * lobe }
		}
	}

	// what the operator currently says, in one line
	report {
		^if (stationary.isNil) { "operator: too few cells" } {
			"operator: cells " ++ cells.size
				++ "  gap " ++ gap.round(0.001)
				++ "  lambda2 " ++ lambda2.round(0.001)
				++ "  dominant " ++ cells[stationary.maxIndex]
				++ " (" ++ stationary.maxItem.round(0.001) ++ ")"
				++ "  transitions " ++ this.total
		}
	}

	// persistence, so the operator is a property of the factory's whole history
	asDict {
		var out = IdentityDictionary.new;
		counts.keysValuesDo { |a, row|
			var r = IdentityDictionary.new;
			row.keysValuesDo { |b, v| r[b] = v };
			out[a] = r;
		};
		^out
	}

	loadDict { |d|
		if (d.notNil) {
			d.keysValuesDo { |a, row|
				var r = IdentityDictionary.new;
				// asFloat, not asInteger. Saved counts are effective (see
				// `effective`) and may be fractional once a half-life has
				// applied; truncating them to integers discarded every count
				// renorm had scaled below 1 and rounded the rest. With no
				// half-life the values are whole numbers and this is identical.
				row.keysValuesDo { |b, v| r[b.asSymbol] = v.asFloat };
				counts[a.asSymbol] = r;
			};
		};
		^this
	}
}
