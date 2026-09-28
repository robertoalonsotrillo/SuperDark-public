// WHAT IS SOUNDING TOGETHER, AND WHAT THAT MEANS.
//
// Nothing in this factory can express "these two, now". Every voice draws its
// rate independently; no voice knows another exists. The measurement of 2 Sept
// showed the target walk is isotropic -- pitch is coordinate 5 and is moved by
// the same rule as coordinate 3 -- so there is no latent tonal behaviour being
// missed for want of a measurement. Harmony as a vertical relation is absent
// because there is no term anywhere that could hold one.
//
// THE TRAP THIS CLASS IS BUILT TO AVOID. Four self-generated criteria here have
// become convergence engines: E3, the audibility score, the transfer operator,
// and the coverage proposer. Each was installed at full strength and measured
// afterwards. A score over simultaneous intervals would be the fifth and the
// worst, because interval consonance is a smooth scalar the selector could climb
// all the way to a drone.
//
// So this class is split in two halves and only the first is on by default.
//
//   OBSERVATION  what intervals the factory is ALREADY producing, logged,
//                scored by nothing. This half is free: it cannot steer, and it
//                answers a question nobody has data for.
//
//   OFFER        a shared table of ratios that machines MAY read when they are
//                written. This is SHARED STATE, not mutual awareness: no voice
//                queries another, they draw from one table, and relatedness is
//                a side effect of a common source. It is much weaker than a
//                controller and much harder to climb, which is the point.
//                simultaneity_weight defaults to 0.0 so a run LOGS the
//                intervals without the table influencing anything -- the
//                control arm exists before the treatment does.
//
// WHERE THE TABLE COMES FROM, which is the whole argument.
//   \corpus   the pitch coordinates actually present in the material, so the
//             table is a property of what the factory has to play. DEFAULT.
//   \just     small-integer ratios. This is me importing a harmonic system and
//             it is labelled as such; useful as a contrast arm, dishonest if
//             reported as something the factory found.
//   \history  ratios the factory has already produced, reinforced. REFUSED and
//             left unimplemented: that is a convergence engine with extra steps,
//             and the reinforcement would manufacture the evidence for itself.
Simultaneity {
	var <hist, <offered, <>mode, <>maxVoices, <observed, <seen,
	    vEnd, vRatio, vAt, <nowLive;

	*new { |mode = \corpus| ^super.new.init(mode) }

	init { |m|
		mode = m; maxVoices = 24; observed = 0; seen = 0; vAt = 0; nowLive = 0;
		// Fixed arrays, allocated once. Two parallel Float arrays rather than an
		// array of pairs, so nothing is boxed and nothing is allocated in fire().
		vEnd = Array.fill(maxVoices, 0.0);
		vRatio = Array.fill(maxVoices, 0.0);
		hist = Array.fill(24, 0);     // semitone-class histogram, 0..23
		offered = [1.0];
		^this
	}

	// A voice has started. `ratio` is its playback rate, which is the only
	// pitch-affecting quantity a voice has: \playback reads the buffer at this
	// speed, so two voices on similar material at rates r1 and r2 sound a pitch
	// interval of r2/r1 whatever the material's own pitch is. That is why the
	// ratio, and not the corpus pitch coordinate, is the right thing to observe:
	// it is the part the factory controls.
	// THIS RUNS ON THE LANGUAGE THREAD, ONCE PER EVENT, INSIDE A PLAYING PATTERN.
	//
	// The first version called `voices.select` and `voices.copy` on every event,
	// allocating two Lists each time, and appended to an `intervals` List it then
	// trimmed from the front. A machine in the micro layer emits at up to 76
	// events per second, and several sound at once. This project has already had
	// a factory starved by exactly this shape of mistake -- the distance loop
	// doing dictionary lookups per grain per dimension inside the OSC callback,
	// which "blocks sclang for seconds and starves the factory".
	//
	// So: no allocation, no per-event growth, and a SAMPLE rather than a census.
	// Every 4th event is enough to characterise a distribution built from
	// thousands of them, and the expiry sweep is in-place over a fixed array.
	// Measurement must not change the thing measured, and an observer that
	// competes with the scheduler for the language thread does exactly that.
	fire { |ratio, dur, machine, now|
		var r, semis, n, k;
		if (ratio.isNil or: { ratio <= 0 } or: { ratio.isNaN }) { ^this };
		seen = seen + 1;
		// slot the voice in without allocating: overwrite the oldest cell
		vEnd[vAt] = now + (dur ? 1.0);
		vRatio[vAt] = ratio;
		vAt = (vAt + 1) % maxVoices;
		if (seen % 4 != 0) { ^this };                  // sample, do not census
		n = 0;
		maxVoices.do { |i|
			if (vEnd[i] > now and: { vRatio[i] > 0 }) {
				r = ratio / vRatio[i];
				if (r < 1) { r = r.reciprocal };       // fold to an upward interval
				if (r > 1.0001 and: { r < 64 } and: { r.isNaN.not }) {
					semis = (12 * log2(r)).round.asInteger;
					if (semis >= 0 and: { semis < 24 }) {
						hist[semis] = hist[semis] + 1;
						observed = observed + 1;
					};
				};
				n = n + 1;
			};
		};
		nowLive = n;
	}

	// How many voices are sounding at once, right now. m6 measures this from the
	// log; this is the same quantity available to the factory as it runs.
	concurrent { |now|
		var n = 0;
		maxVoices.do { |i| if (vEnd[i] > now) { n = n + 1 } };
		^n
	}

	// ---- observation, the half that is always on ---------------------------
	// The histogram, as a line for the window log. Deliberately raw counts: a
	// normalised "consonance" figure would be one step from a score, and the
	// thing that must not exist yet is a number that goes up.
	report {
		var top = 0, ti = 0;
		hist.do { |c, i| if (c > top) { top = c; ti = i } };
		^"SIMUL " ++ observed ++ "," ++ nowLive ++ "," ++ ti ++ ","
		++ hist.join("|")
	}

	// Is the distribution of intervals distinguishable from what independent
	// rate draws would give? Reported, not acted on. A flat histogram means the
	// verticals are accidental, which is the expected answer before any table is
	// switched on and is the baseline the treatment must beat.
	flatness {
		var n = hist.sum, p, h = 0;
		if (n < 30) { ^nil };
		hist.do { |c| p = c / n; if (p > 0) { h = h - (p * log2(p)) } };
		^(h / log2(24))               // 1.0 = uniform, lower = concentrated
	}

	// ---- the offer, the half that defaults to off --------------------------
	// `pitches` must be FREQUENCIES IN Hz, not descriptor coordinates.
	//
	// The first shadow run passed the corpus's normalised pitch COLUMN, and the
	// ratio between two normalised coordinates is not an interval -- it is the
	// quotient of two numbers that have been standardised and PCA-adjacent, and
	// it means nothing musically. It also came back degenerate, which hid the
	// conceptual error behind a mechanical one: the table was [1.0], every
	// machine got a constant rate, and the intervals appearing in the SIMUL
	// histogram were coming from the pre-existing vocabulary rather than from
	// anything this class did. Two faults, one of them invisible while the
	// other was present.
	//
	// Hz is the only input for which ps[i]/ps[0] is an interval.
	buildTable { |pitches, n = 4|
		var ps, rs;
		^switch (mode)
		{ \just } {
			// LABELLED IMPORT. Not discovered here, not derived from anything the
			// factory did. A contrast arm.
			offered = [1.0, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8].keep(n.clip(1, 7));
			offered
		}
		{ \history } {
			// REFUSED. See the header.
			offered = [1.0];
			offered
		}
		{
			// \corpus, the default.
			// audible fundamentals only: a 3 Hz "pitch" is an analysis artefact
			// and would produce an interval of several octaves
			ps = (pitches ? []).select { |x|
				x.notNil and: { x.isNumber } and: { x.isNaN.not }
					and: { x > 30 } and: { x < 5000 } };
			if (ps.size < 2) { offered = [1.0]; ^offered };
			ps = ps.asArray.sort;
			// Quantiles, so the table spans the pitch actually present instead
			// of clustering where the material happens to be dense. Every ratio
			// is folded into one octave: the table is an INTERVAL SET, and an
			// octave-and-a-fifth is the same interval class as a fifth for this
			// purpose, while a raw quotient across the corpus range would be
			// three octaves and simply transpose the machine out of the band.
			rs = Array.fill(n, { |i|
				var idx = ((ps.size - 1) * i / max(1, n - 1)).round.asInteger
					.clip(0, ps.size - 1),
				    r = ps[idx] / max(1e-6, ps[0]);
				while { r >= 2.0 } { r = r / 2 };
				while { r < 1.0 } { r = r * 2 };
				r });
			// DEDUPED, because quantiles of a real pitch distribution collapse.
			// The play corpus at n=4 gave [1.0, 1.9366, 1.5625, 1.5625]: the top
			// two quantiles fold to the same interval, so a quarter of the table
			// was a duplicate and the machine drawing from it had three
			// behaviours where it was asked for four. Rounded to a cent before
			// comparison, since two ratios differing in the fifth decimal are
			// the same interval to any ear.
			offered = rs.asArray.collect { |r| r.clip(0.25, 4.0).round(0.0006) }
				.asSet.asArray.sort;
			// THESE ARE NOT EQUAL TEMPERAMENT AND SHOULD NOT BE DESCRIBED AS A
			// TUNING. They are quantiles of the corpus's own fundamentals folded
			// into one octave -- 7.73 semitones, not 7.00. That is the point:
			// the table is a property of the material, and calling the result
			// harmony would be importing a system the factory never had.
			offered
		}
	}

	// What a machine being written should be handed. nil when the weight is
	// zero, which makes the control arm a missing argument and not a flag the
	// writer has to remember to honour.
	tableFor { |weight|
		if ((weight ? 0) <= 0) { ^nil };
		^offered
	}
}
