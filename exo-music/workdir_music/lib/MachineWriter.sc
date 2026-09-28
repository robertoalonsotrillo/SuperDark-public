// THE FACTORY WRITES A MACHINE INTO ITSELF, WHILE PLAYING.
//
// Until now the mutable directory has been a channel with only one writer: me.
// Twenty of the twenty-two machines are inherited whole from Archon, four are
// mine, the two runtime ones are mine, and the five FMA-derived ones were
// emitted by a script I wrote and ran by hand. The system has never acquired a
// behaviour it was not given. That is the gap the whole project exists to close.
//
// WHAT DECIDES WHAT TO WRITE
//
// The transfer operator already knows where the factory's behaviour is THIN.
// Its stationary distribution says which cells are rarely occupied, and its
// count table says which transitions have never happened at all. A missing
// transition A -> B is a hole in the factory's own dynamics: two behaviours it
// has never found a way to move between.
//
// So the factory writes a BRIDGE. A machine whose parameters interpolate
// between the two endpoints of a missing or rare transition, placed exactly
// where its own dynamics have a gap.
//
// This matters because of what happened to every other criterion here. The
// audibility score narrowed the vocabulary from nine machines to four by
// weighting up whatever already worked; E3 narrowed it toward the investigator's
// taste. Both pulled the factory toward what it already did. THIS ONE TARGETS
// WHAT IT DOES NOT DO -- it is anti-convergent by construction, and it uses the
// operator as a GENERATOR rather than only as a diagnostic, which is a stronger
// reading of P222-224 than measuring the gap and stopping there.
//
// HONEST LIMITS, so nobody overclaims from this later:
//   * I wrote this class, and the template it emits. The factory chooses WHERE
//     a machine is needed and WHAT its parameters are; it does not invent the
//     form. Derivations still terminate in my inputs (P113).
//   * A bridge is an interpolation, not an invention. It cannot produce a
//     behaviour outside the convex hull of what already exists.
//
// AND THE LIMIT NOBODY HAD WRITTEN DOWN, found 3 Sept by listening.
// Every machine this class had ever written -- 147 of 147 -- emitted
// \playback, which is PlayBuf into one BPF into Pan2. Four operations: no
// delay, no feedback, no resonance, no modulation, no spectral processing.
// So the entire authored vocabulary differed only in WHEN grains fire, one
// filter centre, four semitones of rate, amplitude and pan. Roberto: "that
// sounds like cheap concatenative synthesis", and the code agreed with him.
//
// The interpolation limit above was the one this class confessed to. The real
// ceiling was narrower and unstated: the factory could vary rhythm and nothing
// else, while \playgran -- GrainBuf on an Impulse train, grain position
// modulated, filter envelope swept, stereo spread -- sat in the same file
// being used by three of the originals and never by anything written here.
// The writer now chooses its instrument, and the deviation gate counts timbre
// rather than event duration alone, because duration was the one axis that
// could not fix a sameness living in timbre.
// What is new is that nothing but the factory decides that a machine should
// exist, or what it should be, or when it arrives -- and it arrives WITHOUT THE
// FACTORY STOPPING. That is r > 0 in P75's sense, made concrete.
MachineWriter {
	var <written, <lastGap, <bridged, <stamp, <ledgerPath, <specPath, <minDeviation;
	// HOW STRUCTURALLY UNLIKE its duration-neighbours a machine must be to enter
	// on shape alone. 0.5 on a Jaccard distance over combinator sets means it
	// must differ in at least half the combinators it and its neighbour use
	// between them -- one extra Pwhite is not a new behaviour, Pwrand over Prand
	// where the neighbour has a flat Pseq is. A STIPULATION, and the honest test
	// is whether an hour of the resulting machines sounds like more kinds of
	// thing or like noise.
	var <minShapeDeviation;
	// WHY THE LAST propose() DECLINED. It has thirteen separate nil exits and
	// they mean entirely different things -- "the operator is too young",
	// "every pair has been bridged already", "the endpoints are not in specs",
	// "the duration is too close to an existing machine". From outside they were
	// indistinguishable, so "the factory wrote two machines today" was a fact
	// with no diagnosis attached, and on 5 Sept it took six attempts to find out
	// which door was shut. Read it after any nil return.
	var <lastReason = "none";
	// ---- COMPOSITION FROM FRAGMENTS OF THE ORIGINALS, 22 Sept 2026 -------
	// fragmentWeight: per slot, the probability that the slot is a fragment
	// from an original rather than a grammar term. Set by the factory from
	// policy fragment_weight every window. 0 is the pre-22-Sept writer.
	var <>fragmentWeight = 0.0, <fragments, fragPath, fragMtime = 0;
	// dspWeight: per machine, the probability that it sets its own processing
	// stages (B8 rung 1). Set by the factory from policy dsp_slot_weight.
	var <>dspWeight = 0.0;
	// synthWeight: per machine, the probability that it AUTHORS ITS OWN
	// SynthDef through a SynthGrammar (B8 rung 2, 24 Sept 2026) instead of
	// naming one of the three the architect wrote. Set by the factory from
	// policy synth_slot_weight; nothing happens unless synthGrammar is set.
	// A rung 2 machine is written to <dir>/../pending, not to <dir>: the
	// factory renders it offline (tools/check_machine.sh) and moves it into
	// machines/ only on a pass. propose returns the pending path as a 7th
	// element for those, nil for the others.
	var <>synthWeight = 0.0, <>synthGrammar;
	// the most concurrent voices one machine may ask for; see polyphonyOf
	var <>maxPolyphony = 48;
	// THE STARVED-LAYER LOCK, 28 Sept 2026. starvedLayer sends every attempt
	// to the layer with the fewest machines. On 27 Sept that was micro, whose
	// bridges all land below 0.09 s on playbackHP, a region already full: 302
	// of 312 attempts refused as near-copies, 1 machine in 7.5 h, and rung 2
	// (which needs >= 0.09 s) never drawn. A refusal adds nothing to the
	// layer, so it stays starved and is chosen again, for ever. A layer that
	// has refused stallLimit attempts in a row now stops counting as starved
	// until another layer admits a machine or every layer has stalled.
	// stallLimit is a factory knob (acquire_stall_limit), not a constant.
	var <>stallLimit = 12, <layerStall, <lastLayer;
	// THE REFUSED-PAIR LOCK, 28 Sept 2026 (the deeper cause). A refusal does
	// not retire the pair, on purpose (it may bridge later), so the strongest
	// gap stays strongest and is tried again every attempt: 302 refusals of
	// one short-grain region in one boot. A pair refused stallLimit times now
	// rests until any machine is admitted (the vocabulary moved, the same
	// bridge may land somewhere new).
	var <refusedPairs, <lastPair;
	// REACH, 28 Sept 2026. The bridge's duration was interpolated strictly
	// between its endpoints (mix 0.35..0.65), so the writer could never leave
	// the convex hull of what already plays (named on 3 Sept, never fixed).
	// With the played vocabulary dense below 0.09 s every candidate landed on
	// a near-copy. reach > 0 lets the mix run from -reach to 1 + reach in log
	// duration: the pair still says WHICH relation to bridge, the factory
	// says how far past it to go. Knob acquire_reach, the factory's.
	var <>reach = 0.0;
	// what the last written machine was made of, for the header and the log
	var <lastComposition = "";

	*new { |dir = nil, minDev = 0.25, minShape = 0.5|
		^super.new.init(dir, minDev, minShape) }

	// THE NAME COUNTER RESTARTED EVERY RUN, AND THE FACTORY ATE ITS OWN WORK.
	//
	// Names were "br" ++ a ++ b ++ written, where `written` starts at 0 in a
	// fresh writer. So run N and run N+1 both produce brpugp1, brbudr12, and so
	// on. Measured on the 7.4 h run of 3 Sept: ALL SIXTEEN machines written
	// that night overwrote a file of the same name that had been loaded at boot
	// from an earlier run. The log showed brbudr12 sounding at window 114 and
	// being "written" at window 180 -- the older machine of that name playing
	// before the new one replaced it.
	//
	// Three consequences, and the third is the worst. The vocabulary cannot
	// accumulate across runs, because each run destroys as much as it makes.
	// The `bridged` ledger lived only in memory, so a pair retired last night
	// was eligible again tonight and got written over the top. And provenance
	// is gone: a file named brbudr12 does not say which run made it, so the
	// count of files on disk understates what has been written by an unknown
	// amount.
	//
	// A run stamp fixes the collision. A ledger on disk fixes the re-bridging.
	init { |dir, minDev, minShape = 0.5|
		written = 0;
		minDeviation = minDev;
		minShapeDeviation = minShape;
		// yy MM dd HH mm -- unique per run at minute resolution, sorts
		// chronologically, and short enough to keep names readable
		stamp = Date.getDate.format("%y%m%d%H%M");
		bridged = IdentityDictionary.new;
		if (dir.notNil) {
			ledgerPath = dir ++ "/bridged.json";
			specPath = dir ++ "/written_machines.json";
			fragPath = dir ++ "/fragments.json";
			this.loadLedger;
		};
		^this
	}

	// ---- THE FRAGMENT LIBRARY ---------------------------------------------
	//
	// mutable/fragments.json, written by tools/extract_fragments.py from
	// Handler_Local.sc: for each of the twenty originals, its var prelude
	// (locals renamed <machine>_<name>) and its \dur \rate \cutoff \pan \amp
	// \atk \rel \out expressions. Reloaded when the file changes. Nothing here
	// is curated: it is the originals, taken apart.
	loadFragments {
		var txt, raw, out, mt;
		if (fragPath.isNil or: { File.exists(fragPath).not }) { fragments = nil; ^this };
		mt = File.mtime(fragPath);
		if (mt == fragMtime and: { fragments.notNil }) { ^this };
		txt = File.readAllString(fragPath);
		raw = txt.parseYAML;
		if (raw.isKindOf(Dictionary).not or: { raw["machines"].isNil }) { fragments = nil; ^this };
		out = Dictionary.new;
		raw["machines"].keysValuesDo { |k, v|
			var e = Dictionary.new, pre = (v["prelude"] ? "").asString, dropped = List.new;
			e["instrument"] = (v["instrument"] ? "playback").asString;
			e["prelude"] = pre;
			e["slots"] = Dictionary.new;
			(v["slots"] ? Dictionary.new).keysValuesDo { |s, x|
				// A FRAGMENT MUST STAND ON ITS OWN. harmonyPlayer and
				// dronePlayer build their Pbind inside a loop, so their
				// \rate and \out reference loop variables the prelude does
				// not declare. Compiled once here, with the prelude, exactly
				// as the writer will emit it; what does not compile is not
				// a fragment. Mechanical, so an edit to Handler_Local.sc
				// cannot smuggle a broken expression into a live machine.
				var src = "{ |buf, args| " ++ (if (pre.isEmpty) { "" } { "var " ++ pre ++ "; " })
					++ "var x = " ++ x.asString ++ "; x }";
				if (src.compile.notNil) { e["slots"][s.asString] = x.asString } { dropped.add(s.asString) };
			};
			if (dropped.notEmpty) {
				("MachineWriter: fragments of " ++ k ++ " dropped (do not stand alone): "
					++ dropped.join(" ")).postln };
			out[k.asString] = e;
		};
		fragments = out; fragMtime = mt;
		^this
	}

	// The originals a fragment may come from for this machine: same
	// instrument as the machine being written (a playgran \dur is seconds
	// between clouds, a playback \dur is between grains; they do not mix),
	// preferring the bridge's own endpoints when those are originals, so a
	// bridge between sc and ry tends to be made of sc and ry.
	fragSources { |inst, a, b|
		var pool, ends;
		if (fragments.isNil) { ^[] };
		pool = fragments.keys.asArray.select { |k| fragments[k]["instrument"] == inst.asString };
		if (pool.isEmpty) { ^[] };
		ends = [this.bare(a), this.bare(b)].select { |k| pool.includes(k) };
		^if (ends.notEmpty and: { 0.7.coin }) { ends } { pool }
	}

	// One slot: a fragment from `src`, guarded the way the grammar guards its
	// own terms. The guards are the whole reason a fragment written for one
	// machine can sit in another: whatever the expression does, dur stays
	// positive and bounded, rate keeps its sign and its magnitude in range,
	// amp and cutoff stay inside what \playback survives. Finite patterns
	// (Pseq([...], 2)) are wrapped in Pn(..., inf) so a fragment cannot end
	// the machine after a handful of events.
	// A FRAGMENT CAN BE EMPTY FOR SOME ARGS. Pwhite(a, b, n) with n computed
	// from a live feature can be Pwhite(a, b, 0), which yields nothing, and
	// Pn(nothing, inf) is a loop that never yields: the whole language thread
	// stops. Found by the composer test on the first run (240 s, no output).
	// So each cycle is Pseq([fragment, fallback], 1): the fallback is one
	// literal value the writer already knows for that slot, and a cycle
	// always yields at least once. When the fragment yields, its values come
	// first and dominate.
	fragSlot { |src, slot, fb = nil|
		var x = fragments[src]["slots"][slot], cyc;
		if (x.isNil) { ^nil };
		x = x.replace("\t", " ").replace("\n", " ");
		// Pflatten(1, ...) on every slot: the originals write `bus ! n` and
		// `rate ! reps` inside their Pseqs, which an Event multichannel-
		// expands into n synths per event. Flattened, it means what it
		// reads as: hold this value for n events.
		cyc = { |fallback| "Pflatten(1, Pn(Pseq([" ++ x ++ ", " ++ fallback ++ "], 1), inf))" };
		^switch (slot)
		{ "dur" }    { cyc.(fb ? "0.1") ++ ".max(0.01).min(6.0)" }
		{ "rate" }   { cyc.(fb ? "1.0") ++ ".collect({ |r| var v = r.asArray.first ? 1.0, m = v.abs.clip(0.25, 4.0); if (v < 0) { m.neg } { m } })" }
		{ "cutoff" } { cyc.(fb ? "1200") ++ ".max(80).min(9000)" }
		{ "amp" }    { cyc.(fb ? "0.1") ++ ".max(0.0005).min(0.5)" }
		{ "pan" }    { cyc.(fb ? "0.0") ++ ".clip(-1.0, 1.0)" }
		{ "atk" }    { "(" ++ x ++ ").clip(0.003, 4.0)" }
		{ "rel" }    { "(" ++ x ++ ").clip(0.01, 8.0)" }
		{ "out" }    { cyc.("0") ++ ".collect({ |o| o.asArray.first ? 0 })" }
		{ nil }
	}

	// WHAT THE FACTORY KNOWS ABOUT THE MACHINES IT WROTE: nothing, until now.
	//
	// weights.json holds the 20 machines the architect authored. A machine the
	// factory writes never enters it, and layerOf falls back to "micro" for any
	// machine it cannot find there. So EVERY ONE of the 147 written machines was
	// treated as micro whatever its actual event rate -- and all sixteen written
	// on 3 Sept were logged by the writer itself as MACRO, with event durations
	// up to 7.9 s.
	//
	// Harmless while every layer behaved identically. Not harmless now: dwell and
	// voice span are per layer, so the factory's own long-form machines would be
	// held for one window and cut at 12 s, and the long-form work would reach
	// every machine except the ones the factory authored.
	//
	// Written to a SEPARATE file, merged at load. weights.json is the architect's
	// and stays that way; this is the factory's record of its own work, and the
	// separation is the same one the charter and policy already keep. Only
	// descriptive fields -- dur, layer, inst -- are recorded. No bias or coef, so
	// SELECTION weighting is unchanged: this teaches the factory what its
	// machines ARE, not that it should prefer them.
	// NINE MACHINES WRITTEN, ONE RECORDED. Measured 3 Sept: bridged.json holds
	// nine entries across five run stamps and written_machines.json holds the
	// FIRST one only, its mtime frozen at the moment the file stopped being
	// empty. Every later write appended to the ledger and left no spec.
	//
	// The record was nested -- a map of maps -- so every call after the first
	// had to read back a structure it had itself written and index one level
	// down. Whatever parseYAML hands back for an inline flow mapping, the
	// factory then indexes it, and one wrong type there is a silent
	// DoesNotUnderstand: the ledger line above it had already been saved, the
	// .scd was already on disk, and the only casualty was the record of what
	// the machine WAS. This is the isInf failure again, one layer down.
	//
	// So the file is now FLAT: one key per field, "name|dur", never nested.
	// parseYAML returns string -> string and nothing is indexed twice. And the
	// call site guards the whole thing, because losing a spec must never be
	// able to cost a machine.
	loadSpecs {
		var txt, raw, out, i, nm, fld;
		if (specPath.isNil or: { File.exists(specPath).not }) { ^Dictionary.new };
		txt = File.readAllString(specPath);
		raw = txt.parseYAML;
		out = Dictionary.new;
		if (raw.isKindOf(Dictionary).not) { ^out };
		raw.keysValuesDo { |k, v|
			var ks = k.asString;
			// find, not indexOf($|): the pipe is sclang's argument delimiter and
			// a bare Char literal for it is one more thing to get wrong in a file
			// that cannot be tested without restarting the factory
			i = ks.find("|");
			if (i.notNil) {
				// flat form, "name|field"
				nm = ks.copyRange(0, i - 1);
				fld = ks.copyRange(i + 1, ks.size - 1);
				if (out[nm].isNil) { out[nm] = Dictionary.new };
				out[nm][fld] = v.asString;
			} {
				// legacy nested form, tolerated on read so the one entry
				// already on disk is not thrown away
				if (v.isKindOf(Dictionary)) {
					if (out[ks].isNil) { out[ks] = Dictionary.new };
					v.keysValuesDo { |k2, v2| out[ks][k2.asString] = v2.asString };
				};
			};
		};
		^out
	}

	// `shape` is a structural signature of the emitted pattern -- the multiset of
	// combinators it uses, as a sorted string like "Pn2Prand1Pwhite3Pwrand1".
	// THE SAME FOR EVERY TEMPLATE MACHINE, which is what the gate needs. I first
	// wrote that templates record the EMPTY string; they do not. Measured on the
	// live run of 5 Sept they all record "Pseg1Pseq4Pwhite4Pn2", because shapeOf
	// counts the whole emitted file and the template carries its own Pseg and
	// Pseq. The effect is identical -- one constant signature for the stock form,
	// so template machines collide with each other in the gate as they should --
	// but the reason stated here was wrong, and a wrong comment in this file is
	// how two hours went on nearestAround.

	// THE STRUCTURAL SIGNATURE OF AN EMITTED PATTERN.
	//
	// The multiset of combinators the pattern actually uses, sorted and
	// concatenated: "Pn2Prand1Pwhite3Pwrand1". Two machines with the same
	// signature are built the same way however their constants differ; two with
	// different signatures are different KINDS of behaviour even if they happen
	// to fire at the same rate.
	//
	// Counted from the emitted source rather than from the grammar's own tree,
	// because the source is what the factory will actually play and the tree is
	// a claim about it. Cheap -- this runs once per written machine.
	// THE NAMES A SIGNATURE COUNTS. Eight combinators since 5 Sept; from
	// 22 Sept also the four buses (does the machine route, and where), Ppar
	// (does it layer), and the twenty originals' fragment prefixes (what it
	// is made of). Without these the gate could not see that a machine that
	// rings on the long return and stacks two layers of sc's rate palette is
	// a different kind of thing from a dry single Pbind with the same
	// combinator counts -- and would refuse it as a duplicate.
	shapeNames {
		^["Pwrand", "Pgeom", "Pstutter", "Prand", "Pseg", "Pseq", "Pwhite", "Pn",
		  "dryBus", "reverbShortBus", "reverbMidBus", "reverbLongBus", "Ppar",
		  "resfz", "dlyfb", "blurhz",   // one per processing stage (B8 rung 1)
		  // rung 2: the source and the stages of a machine's own SynthDef
		  "Warp1", "PitchShift", "DynKlank", "BufRd", "GrainBuf", "HPF.ar", "LPF.ar",
		  "Ringz", "CombL", "FreqShift", "tanh",
		  "sc_", "lu_", "so_", "ma_", "cr_", "te_", "ry_", "an_", "hp_", "st_",
		  "ht_", "gl_", "cp_", "wa_", "gp_", "bu_", "dr_", "pu_", "hm_", "me_"]
	}

	shapeOf { |txt|
		var names = this.shapeNames, out = "";
		if (txt.isNil) { ^"" };
		names.do { |nm|
			var c = 0, i = 0, hit;
			while {
				hit = txt.find(nm, false, i);
				hit.notNil
			} { c = c + 1; i = hit + nm.size };
			if (c > 0) { out = out ++ nm ++ c };
		};
		^out
	}

	// HOW FAR APART TWO SIGNATURES ARE, 0 for identical and 1 for disjoint.
	//
	// WEIGHTED Jaccard over the combinator COUNTS: 1 - sum(min)/sum(max).
	// Until 20 Sept this was a set Jaccard over the eight names, ignoring
	// counts, on the argument that "whether it uses Pwrand twice or three
	// times is detail". Measured over every refusal logged 5-20 Sept (2,905
	// candidates, 1,232 distinct grammar shapes): 0 passed. Pseq, Pwhite and
	// Pn are in nearly every machine, so the set metric had at most five
	// names to differ on and every candidate was within 0.5 of whatever sat
	// nearest to it in duration. The duration route was closed too: the
	// widest hole among 174 playback machines is 0.454 in log10, and the
	// gate needs 0.5. The acquisition channel had been shut since 5 Sept by
	// its own measure, with the threshold never touched.
	// With counts, the same 2,905 candidates at the SAME threshold 0.5:
	// 364 pass (12.5%), about one acquisition per 64 windows. The norm is
	// unchanged; the metric can now see that Pseq8 is not Pseq1.
	shapeDistance { |a, b|
		var names = this.shapeNames, ca, cb, mn = 0, mx = 0;
		a = (a ? "").asString; b = (b ? "").asString;
		// TWO IDENTICAL SIGNATURES ARE AT DISTANCE 0, WHICH IS THE POINT.
		// I first wrote that template machines record the EMPTY signature. They
		// do not: measured 5 Sept, every template machine records
		// "Pseg1Pseq4Pwhite4Pn2", because shapeOf counts the whole emitted file
		// and the template has its own Pseg and Pseq in it. The BEHAVIOUR is the
		// same either way -- identical sets give a Jaccard distance of 0, so no
		// template can rescue another -- but the stated reason was wrong, and a
		// wrong comment is how this project loses hours.
		// The empty-vs-empty case is kept because a machine emitted with no
		// recognised combinator at all should still not count as maximally
		// novel; returning 1 there would open the gate to unlimited duplicates,
		// which is the 26 Aug failure with a new coat on.
		if (a.isEmpty and: { b.isEmpty }) { ^0.0 };
		names.do { |nm|
			ca = this.countIn(a, nm); cb = this.countIn(b, nm);
			mn = mn + min(ca, cb);
			mx = mx + max(ca, cb);
		};
		if (mx < 1) { ^0.0 };
		^(1.0 - (mn / mx))
	}

	// the integer that follows `nm` in a signature like "Pseg1Pseq4", 0 if absent.
	// "Pn" must not match inside "Pwhite"... it cannot: signatures are built
	// by shapeOf from this same name list, each name followed by its digits.
	countIn { |sig, nm|
		var i = sig.find(nm), j, n = 0;
		if (i.isNil) { ^0 };
		j = i + nm.size;
		while { j < sig.size and: { sig[j].isDecDigit } } {
			n = (n * 10) + sig[j].digit; j = j + 1 };
		^n
	}

	// THE WEIGHTS A WRITTEN MACHINE INHERITS, 22 Sept 2026 (B7).
	//
	// weights.json gives each original a bias, per-feature coefficients and
	// a range, and selection moves an original's weight with the live
	// features through them. A written machine had none: "selectable but
	// never preferred", a flat 5 with no response to anything. So selection
	// favoured the originals by construction, whatever the writer did.
	// Now a bridge inherits the mean of its endpoints' coefficients, bias and
	// range, mechanically, and an endpoint that is itself a bridge passes on
	// what it inherited. Nothing here is tuned by hand; the numbers are the
	// originals' own, diluted by the path that led to this machine. Stored
	// flat as name|bias, name|coef_<feature>, name|range_lo, name|range_hi.
	weightsOf { |spec|
		var w = Dictionary.new, coef = Dictionary.new;
		if (spec.isNil) { ^nil };
		w["bias"] = (spec["bias"] ? "5.0").asString.asFloat;
		if (spec["coef"].isKindOf(Dictionary)) {
			spec["coef"].keysValuesDo { |k, v| coef[k.asString] = v.asString.asFloat } };
		spec.keysValuesDo { |k, v|
			var ks = k.asString;
			if (ks.beginsWith("coef_")) { coef[ks.copyRange(5, ks.size - 1)] = v.asString.asFloat } };
		w["coef"] = coef;
		w["lo"] = if (spec["range"].isKindOf(Array)) { spec["range"][2].asString.asFloat }
		          { (spec["range_lo"] ? "0.0").asString.asFloat };
		w["hi"] = if (spec["range"].isKindOf(Array)) { spec["range"][3].asString.asFloat }
		          { (spec["range_hi"] ? "1.0").asString.asFloat };
		if (coef.isEmpty and: { spec["bias"].isNil }) { ^nil };   // no weights to inherit
		^w
	}
	inheritWeights { |sa, sb|
		var wa = this.weightsOf(sa), wb = this.weightsOf(sb), out = Dictionary.new, coef = Dictionary.new, keys;
		if (wa.isNil and: { wb.isNil }) { ^nil };
		if (wa.isNil) { ^wb }; if (wb.isNil) { ^wa };
		out["bias"] = (wa["bias"] + wb["bias"]) / 2;
		keys = (wa["coef"].keys ++ wb["coef"].keys).asSet;
		keys.do { |k| coef[k] = ((wa["coef"][k] ? 0) + (wb["coef"][k] ? 0)) / 2 };
		out["coef"] = coef;
		out["lo"] = min(wa["lo"], wb["lo"]); out["hi"] = max(wa["hi"], wb["hi"]);
		^out
	}

	recordSpec { |name, dur, layer, inst, shape = "", weights = nil|
		var d, f, parts, rec;
		if (specPath.isNil) { ^this };
		d = this.loadSpecs;
		rec = Dictionary[
			"dur" -> dur.round(0.0001).asString,
			"layer" -> layer.asString,
			"inst" -> inst.asString,
			"shape" -> shape.asString,
			"by" -> stamp.asString ];
		if (weights.notNil) {
			rec["bias"] = weights["bias"].round(0.0001).asString;
			rec["range_lo"] = weights["lo"].round(0.0001).asString;
			rec["range_hi"] = weights["hi"].round(0.0001).asString;
			weights["coef"].keysValuesDo { |k, v| rec["coef_" ++ k] = v.round(0.0001).asString };
		};
		d[name.asString] = rec;
		parts = [];
		d.keysValuesDo { |k, v|
			var g = { |fld, dflt| ((v.isKindOf(Dictionary)).if({ v[fld] }, { nil }) ? dflt).asString };
			parts = parts
				.add("  \"" ++ k ++ "|dur\": \""   ++ g.value("dur", "0") ++ "\"")
				.add("  \"" ++ k ++ "|layer\": \"" ++ g.value("layer", "micro") ++ "\"")
				.add("  \"" ++ k ++ "|inst\": \""  ++ g.value("inst", "playback") ++ "\"")
				.add("  \"" ++ k ++ "|shape\": \"" ++ g.value("shape", "") ++ "\"")
				.add("  \"" ++ k ++ "|by\": \""    ++ g.value("by", "?") ++ "\"");
			// the inherited weights, only for machines that have them
			if (v.isKindOf(Dictionary)) {
				v.keysValuesDo { |fld, val|
					if (fld == "bias" or: { fld == "range_lo" } or: { fld == "range_hi" }
						or: { fld.asString.beginsWith("coef_") }) {
						parts = parts.add("  \"" ++ k ++ "|" ++ fld ++ "\": \"" ++ val.asString ++ "\"") } } } };
		f = File(specPath, "w");
		if (f.isOpen) { f.write("{\n" ++ parts.join(",\n") ++ "\n}\n"); f.close };
		^this
	}

	// Concurrent voices a machine file asks for: layers x mean(atk + rel) /
	// mean(dur) over its first 60 events, with representative args. nil when
	// the file does not compile or stream (those are caught elsewhere).
	polyphonyOf { |txt|
		var fn, pat, st, ev, durs = List.new, lives = List.new, layers = 1, i = 0;
		fn = txt.compile;
		if (fn.isNil) { ^nil };
		layers = 1 + txt.findAll("Pbindf(main").size;
		try {
			pat = fn.value.value([0, 1, 2, 3], Dictionary[\windowsize -> 0.4, \percpitch -> 0.3,
				\avgflat -> 0.09, \density -> 1.5, \avgcent -> 2400.0, \avgrms -> 0.2,
				\mainpitch -> 220.0, \avgrolloff -> 4300.0]);
			// the layers are a Ppar of the same stream; measure one and multiply
			if (pat.isKindOf(Ppar)) { pat = pat.list.first };
			st = pat.asStream;
			while { i < 60 } {
				ev = st.next(Event.default);
				if (ev.isNil) { i = 60 } {
					if (ev[\dur].isNumber) { durs.add(ev[\dur].max(0.001)) };
					if (ev[\atk].isNumber and: { ev[\rel].isNumber }) { lives.add(ev[\atk] + ev[\rel]) };
				};
				i = i + 1;
			};
		} { |e| ^nil };
		if (durs.isEmpty or: { lives.isEmpty }) { ^nil };
		^layers * (lives.sum / lives.size) / (durs.sum / durs.size)
	}

	// A rung 2 machine that fails its offline render is refused after its
	// spec was recorded; the factory calls this so selection never sees a
	// name that has no file.
	forgetSpec { |name|
		var d, f, parts;
		if (specPath.isNil) { ^this };
		d = this.loadSpecs;
		if (d[name.asString].isNil) { ^this };
		d.removeAt(name.asString);
		parts = [];
		d.keysValuesDo { |k, v|
			if (v.isKindOf(Dictionary)) {
				v.keysValuesDo { |fld, val|
					parts = parts.add("  \"" ++ k ++ "|" ++ fld ++ "\": \"" ++ val.asString ++ "\"") } } };
		f = File(specPath, "w");
		if (f.isOpen) { f.write("{\n" ++ parts.join(",\n") ++ "\n}\n"); f.close };
		^this
	}

	// EVERY PAIR THIS FACTORY HAS EVER BRIDGED, ACROSS ALL RUNS.
	// Without this the retirement rule is per-run, which is not retirement at
	// all: the pair carrying the most negative residual wins again on the next
	// boot, and the 26 Aug pattern -- 154 bridges across 7 transitions -- comes
	// back one run at a time instead of all at once.
	loadLedger {
		var f, txt, d;
		if (ledgerPath.isNil or: { File.exists(ledgerPath).not }) { ^this };
		txt = File.readAllString(ledgerPath);
		d = txt.parseYAML;
		if (d.isKindOf(Dictionary)) {
			d.keysValuesDo { |k, v| bridged[k.asSymbol] = v };
		};
		^this
	}

	saveLedger {
		var f, parts;
		if (ledgerPath.isNil) { ^this };
		parts = [];
		bridged.keysValuesDo { |k, v|
			parts = parts.add("  \"" ++ k ++ "\": \"" ++ v ++ "\"") };
		f = File(ledgerPath, "w");
		if (f.isOpen) { f.write("{\n" ++ parts.join(",\n") ++ "\n}\n"); f.close };
		^this
	}

	// SUBSTANTIAL DEVIATION, OR DO NOT WRITE AT ALL.
	//
	// A bridge is an interpolation and this class's own header admits it
	// "cannot produce a behaviour outside the convex hull of what already
	// exists". Measured on the 3 Sept run: 16 machines written, 2 new
	// BEHAVIOURS. The other fourteen landed on bridges that already existed.
	//
	// So a candidate must differ from everything already in the vocabulary by
	// more than `minDeviation` in log event-duration -- the axis the layer
	// split is defined on, and the one a listener hears as the difference
	// between a grain, a gesture and a phrase. 0.25 in log10 is about a factor
	// of 1.8: a machine must be nearly twice as fast or slow as its nearest
	// neighbour to earn a file.
	//
	// Refusing to write is a legitimate outcome. A factory that writes nothing
	// because it has nothing distinct to add is telling the truth; one that
	// writes sixteen near-copies is not.
	// NOVELTY IS DISJUNCTIVE ACROSS DIMENSIONS, 5 Sept.
	//
	// This asked ONE question -- is the median event duration a factor of 1.78
	// from every existing machine on the same instrument -- and that was a fair
	// proxy while a machine was only a rhythm. In August the whole vocabulary
	// was 147 machines emitting \playback, differing in when grains fire, one
	// filter centre, four semitones of rate. Duration was nearly all there was.
	//
	// It stopped being true when the grammar was wired. A grammar machine can
	// differ in the SHAPE of its slot expressions -- Pwrand over Prand over
	// Pwhite against a flat Pseq -- and land on the same median duration, so the
	// gate rejected exactly the machines the grammar exists to produce, for
	// being rhythmically similar to things they are nothing like.
	//
	// MEASURED 5 Sept, and this is why it had to change rather than be tuned:
	//     playback    170 machines over 2.94 decades -> 12 slots, 11 taken
	//     playbackHP    2 machines                   ->  2 slots,  2 taken
	//     playgran      7 machines over 1.65 decades ->  7 slots,  4 taken
	// 179 machines competing for ~21 distinguishable positions, with ONE free
	// playback slot in the entire space. The factory was three machines from
	// never being able to acquire again, for ever, however long it ran.
	//
	// So a candidate now passes if it is far enough in duration OR far enough in
	// shape. Disjunctive on purpose: adding a dimension can then only ever OPEN
	// the gate, never close it, so this cannot silently tighten anything that
	// was already passing.
	//
	// WHY THIS DOES NOT REOPEN 26 AUGUST. That failure was 154 bridges across
	// seven transitions -- near-copies. A near-copy has the same duration AND
	// the same shape, so it still fails both tests and is still refused. Two
	// template machines record the SAME signature as each other --
	// "Pseg1Pseq4Pwhite4Pn2", measured on the live run of 5 Sept, NOT the empty
	// string as I first wrote here -- and an identical pair is at Jaccard
	// distance 0, which is what keeps the stock form from duplicating itself.
	//
	// CONFIRMED IN THE LOG, not just argued. Two playback candidates at 0.1925 s
	// and 0.1495 s were refused with "duration ... AND shape Pseg1Pseq4Pwhite4Pn2
	// within minShapeDeviation", and a playgran candidate at 0.2116 s carrying a
	// rich grammar signature was refused against an existing playgran. The gate
	// discriminates in both dimensions on real traffic.
	deviates { |dur, specs, inst = nil, shape = ""|
		var best = inf, d, same, all, shapeBest = inf, sd;
		if (dur <= 0) { ^true };
		// the architect's machines AND the factory's own, so the gate stops
		// passing playgran indefinitely once playgran machines exist
		all = Dictionary.new;
		if (specs.notNil) { specs.keysValuesDo { |k, v| all[k] = v } };
		this.loadSpecs.keysValuesDo { |k, v| all[k] = v };
		specs = all;
		specs.keysValuesDo { |k, v|
			d = (v["dur"] ? "0").asFloat;
			// Compare only against machines on the SAME instrument. A granular
			// cloud and a discrete grain at the same event rate are not near
			// each other, and treating them as neighbours would block exactly
			// the writes that add timbral variety. weights.json records the
			// instrument for machines written since 3 Sept; older entries have
			// none and are treated as playback, which is what they all were.
			same = inst.isNil or: { (v["inst"] ? "playback").asString == inst.asString };
			if (d > 0 and: { same }) {
				best = min(best, absdif(log10(dur), log10(d)));
				// The nearest NEIGHBOUR IN DURATION is what the shape has to
				// differ from. Comparing shape against every machine in the
				// corpus would let one distant oddity anywhere in the space
				// veto a candidate that is genuinely new next to its actual
				// neighbours.
				sd = this.shapeDistance(shape, v["shape"] ? "");
				if (absdif(log10(dur), log10(d)) < minDeviation) {
					shapeBest = min(shapeBest, sd);
				};
			};
		};
		// far in duration, OR structurally unlike everything it is close to
		^((best >= minDeviation) or: { shapeBest >= minShapeDeviation })
	}

	// THE MECHANISM HAD NO MEMORY OF WHAT IT HAD ALREADY DONE.
	//
	// Writing a bridge does not change the transition counts, so whichever pair
	// carries the most negative residual keeps carrying it, and keeps winning.
	// Measured over the six-hour run of 26 Aug: 154 bridges written across SEVEN
	// distinct transitions, a 95% duplicate rate, with `sc -> bu` written 77
	// times and `pu -> hm` 51 times. Five pairs accounted for 98% of all writing.
	//
	// This is why that run appeared to trebple its vocabulary. The count of
	// distinct machine NAMES rose from 27 to 147; the count of distinct
	// BEHAVIOURS did not, because 147 of those names were near-copies of seven
	// things differing only in a random interpolation constant. Twenty-minute
	// runs hid it -- the bridge control saw 4 of 21 bridges hit `bu` and the
	// six-hour run reverted to 77 of 154.
	//
	// A pair is retired once bridged. If the factory later actually MAKES that
	// transition the hole is filled and there is nothing to do; if it still does
	// not, a second identical bridge will not help either, and the evidence is
	// that it will write seventy-six more.
	// The ledger key is by BARE machine name on both sides. findGap looks pairs
	// up with the operator's suffixed cell names (sc@slow) and the successful
	// write records them stripped; without normalising here the two would
	// never match and the same pair would be proposed every eight windows
	// forever. Entries written before 15 Sept were bare already, so they still
	// match. 20 Sept.
	bare { |x|
		var s = x.asString, i = s.indexOf($@);
		^if (i.isNil) { s } { s.copyRange(0, i - 1) }
	}
	key { |a, b| ^(this.bare(a) ++ ">" ++ this.bare(b)).asSymbol }

	// A HOLE, MEASURED AGAINST WHAT THE ENDPOINTS' OWN RATES PREDICT.
	//
	// The first version of this minimised the RAW count n(a,b). That does not
	// find a hole in the dynamics; it finds whichever machines are rarest.
	// `bu` carries the lowest audibility prior in the vocabulary, 0.05, so it is
	// selected least often, so every transition touching it has the smallest
	// count, so it won every time. In the 24 Aug ablation TWELVE OF SIXTEEN
	// bridges targeted `bu` and exactly one bridge in sixteen ever sounded.
	//
	// The error is a base-rate error, not a silence problem. A transition that
	// is rare only because both its endpoints are rare is not a hole. A
	// transition that is rare RELATIVE TO how often its endpoints occur is. So
	// score the standardised residual against independence,
	//
	//     e(a,b) = row(a) * col(b) / N        z = (n - e) / sqrt(e + 1)
	//
	// and take the most negative z among endpoints observed often enough for
	// the expectation to mean anything. A machine the factory barely visits can
	// no longer dominate, because its expectation is small too.
	tallies { |op|
		var cells = op.cells, counts = op.counts, n,
		    row = IdentityDictionary.new, col = IdentityDictionary.new, tot = 0;
		cells.do { |a|
			cells.do { |b|
				n = (counts[a] !? { counts[a][b] }) ? 0;
				row[a] = (row[a] ? 0) + n;
				col[b] = (col[b] ? 0) + n;
				tot = tot + n;
			};
		};
		^[row, col, tot]
	}

	// A cell's spec, looked up by BARE name. Cells carry "@bucket" since
	// 15 Sept; specs never did. Returns nil when the machine has no spec at
	// all (fma0-4, grind, sift: on disk as .scd, in no spec file), and the
	// gap searches below treat that as ineligible, so a pair the writer cannot
	// resolve is never chosen and re-proposed every eight windows. 20 Sept.
	specOf { |specs, x|
		var b;
		if (specs.isNil) { ^nil };
		b = this.bare(x);
		^(specs[b] ?? { specs[b.asSymbol] } ?? { specs[x.asString] } ?? { specs[x] })
	}

	findGap { |op, minObs = 5, specs = nil|
		var cells, counts, t, row, col, tot, n, e, z, best = nil, bestZ = inf;
		cells = op.cells;
		if (cells.isNil or: { cells.size < 3 }) { ^nil };
		counts = op.counts;
		t = this.tallies(op); row = t[0]; col = t[1]; tot = t[2];
		if (tot < 1) { ^nil };
		cells.do { |a|
			cells.do { |b|
				if (a != b and: { (row[a] ? 0) >= minObs } and: { (col[b] ? 0) >= minObs }
					and: { bridged[this.key(a, b)].isNil } and: { this.resting(a, b).not }
					and: { specs.isNil or: { this.specOf(specs, a).notNil and: { this.specOf(specs, b).notNil } } }) {
					n = (counts[a] !? { counts[a][b] }) ? 0;
					e = (row[a] * col[b]) / tot;
					z = (n - e) / (e + 1).sqrt;
					if (z < bestZ) { bestZ = z; best = [a, b] };
				};
			};
		};
		// Every eligible pair already bridged is a legitimate terminal state: the
		// factory has acted on every hole it can see. Returning nil stops it
		// writing, which is correct. It is NOT a fallback to repeat.
		if (best.isNil) { ^nil };
		lastGap = best;
		^best
	}

	// WHICH LAYER IS STARVED, AND THE GAP INSIDE IT.
	//
	// findGap above is layer-blind, and that is not a neutral choice: it looks
	// for holes in the observed dynamics, the holes sit between the machines the
	// factory rarely visits, and those are the slow ones. Eleven of the twenty
	// class machines are micro and they are chosen constantly, so micro->micro
	// is densely observed and never reads as a hole. The result, measured across
	// all 156 written machines on 3 Sept: every one macro, none faster than
	// 0.46 s. The factory could not author a grain even in principle.
	//
	// Roberto's requirement is explicit -- "some will engage micro behaviour,
	// some gestures, and some long-term behaviours" -- and the three slots now
	// PLAY all three, so a vocabulary that only grows at one timescale starves
	// two of the three slots of anything new to select.
	//
	// So the writer takes a turn at each layer, starting with whichever has the
	// fewest machines of its own, and searches for the strongest hole whose
	// bridge would LAND there. This does not weaken the gap criterion; it
	// applies it three times over three subsets instead of once over the union,
	// which is the same move the three slots made on selection.
	starvedLayer {
		var have = Dictionary["micro" -> 0, "mid" -> 0, "macro" -> 0], best, bestN = inf, open;
		layerStall = layerStall ?? { Dictionary["micro" -> 0, "mid" -> 0, "macro" -> 0] };
		this.loadSpecs.keysValuesDo { |k, v|
			var l = (v.isKindOf(Dictionary)).if({ (v["layer"] ? "micro").asString }, { "micro" });
			if (have[l].notNil) { have[l] = have[l] + 1 };
		};
		open = have.keys.asArray.sort.reject({ |k| (layerStall[k] ? 0) >= stallLimit });
		if (open.isEmpty) {
			layerStall.keys.asArray.do { |k| layerStall[k] = 0 };
			open = have.keys.asArray.sort };
		open.do { |k| if (have[k] < bestN) { bestN = have[k]; best = k } };
		^best
	}

	// every attempt ends here: a refusal counts against the layer it tried,
	// an admission clears every layer's count (the vocabulary moved)
	resting { |a, b|
		^refusedPairs.notNil and: { (refusedPairs[this.key(a, b)] ? 0) >= stallLimit }
	}

	noteStall { |ok|
		refusedPairs = refusedPairs ?? { IdentityDictionary.new };
		if (ok) { refusedPairs = IdentityDictionary.new } {
			if (lastPair.notNil) { refusedPairs[lastPair] = (refusedPairs[lastPair] ? 0) + 1 } };
		layerStall = layerStall ?? { Dictionary["micro" -> 0, "mid" -> 0, "macro" -> 0] };
		if (ok) { layerStall.keys.asArray.do { |k| layerStall[k] = 0 } } {
			if (lastLayer.notNil) {
				layerStall[lastLayer] = (layerStall[lastLayer] ? 0) + 1;
				lastReason = lastReason ++ " [layer " ++ lastLayer ++ ", stall "
					++ layerStall[lastLayer] ++ "/" ++ stallLimit ++ "]" } };
	}

	layerOfDur { |d|
		^if (d < 0.155) { "micro" } { if (d < 0.894) { "mid" } { "macro" } }
	}

	findGapInLayer { |op, specs, want, minObs = 5|
		var cells, counts, t, row, col, tot, n, e, z, best = nil, bestZ = inf, da, db, mid;
		if (want.isNil or: { specs.isNil }) { ^this.findGap(op, minObs, specs) };
		cells = op.cells;
		if (cells.isNil or: { cells.size < 3 }) { ^nil };
		counts = op.counts;
		t = this.tallies(op); row = t[0]; col = t[1]; tot = t[2];
		if (tot < 1) { ^nil };
		cells.do { |a|
			// specOf strips "@bucket". Before 20 Sept this was specs[a.asString]
			// with a suffixed, so da was 0 for every cell, no pair ever
			// qualified, and every call fell through to the layer-blind
			// findGap below -- which did not check specs at all.
			var sa = this.specOf(specs, a);
			da = (sa.isKindOf(Dictionary)).if({ (sa["dur"] ? "0").asFloat }, { 0 });
			if (da > 0) {
				cells.do { |b|
					var sb = this.specOf(specs, b);
					db = (sb.isKindOf(Dictionary)).if({ (sb["dur"] ? "0").asFloat }, { 0 });
					if (db > 0 and: { a != b }
						and: { (row[a] ? 0) >= minObs } and: { (col[b] ? 0) >= minObs }
						and: { bridged[this.key(a, b)].isNil } and: { this.resting(a, b).not }) {
						// the midpoint the writer would actually produce, at the
						// centre of its mix range, in the metric it now uses
						mid = exp((log(da) + log(db)) * 0.5);
						if (this.layerOfDur(mid) == want) {
							n = (counts[a] !? { counts[a][b] }) ? 0;
							e = (row[a] * col[b]) / tot;
							z = (n - e) / (e + 1).sqrt;
							if (z < bestZ) { bestZ = z; best = [a, b] };
						};
					};
				};
			};
		};
		// No hole that lands in this layer is a real answer, not a failure: it
		// means every pair whose bridge would sit there is already bridged or
		// already well observed. Fall back to the layer-blind gap rather than
		// write nothing, so a starved layer cannot stall the writer entirely.
		if (best.isNil) { ^this.findGap(op, minObs, specs) };
		lastGap = best;
		^best
	}

	// ARM B of the 25 Aug control. Two adequately-observed cells, chosen
	// UNIFORMLY, ignoring the operator's structure entirely. The `acquire`
	// condition scored the highest audibility in the ablation while wasting
	// three quarters of its bridges on `bu`, which raises the possibility that
	// the value lies in PERTURBATION -- new machines arriving into a narrowing
	// vocabulary -- and not in targeting at all. If this arm matches findGap,
	// the operator-as-generator claim does not survive.
	findRandom { |op, minObs = 5|
		var cells, t, row, col, ok, a, b, cand, gap;
		cells = op.cells;
		if (cells.isNil or: { cells.size < 3 }) { ^nil };
		t = this.tallies(op); row = t[0]; col = t[1];
		if (t[2] < 1) { ^nil };
		ok = cells.select { |c| ((row[c] ? 0) >= minObs) or: { (col[c] ? 0) >= minObs } };
		if (ok.size < 2) { ^nil };
		// same retirement rule as findGap, so the two arms of the control differ
		// ONLY in how they choose and not in whether they repeat themselves
		cand = List.new;
		ok.do { |x| ok.do { |y|
			if (x != y and: { bridged[this.key(x, y)].isNil } and: { this.resting(x, y).not }) { cand.add([x, y]) } } };
		if (cand.size < 1) { ^nil };
		gap = cand.choose;
		a = gap[0]; b = gap[1];
		lastGap = [a, b];
		^[a, b]
	}

	// Interpolate between the two endpoints. `specs` is weights.json's machines
	// dictionary, which carries each machine's MEASURED median event duration
	// and its grain layer.
	// `mode` is "gap" (default) or "random", read from policy.json so the two
	// arms of the control differ by ONE string and nothing else.
	// `grammar` is a PatternGrammar or nil, `simTable` a shared ratio array or
	// nil, `ratio` the pitch ratio the machine is born at.
	//
	// THREE ARMS, DIFFERING BY WHAT IS PASSED IN AND NOTHING ELSE, which is the
	// same discipline the gap/random control already uses:
	//   grammar nil                 the hand-written template. The control.
	//   grammar set, simTable nil   the factory chooses the SHAPE; rate is
	//                               anchored on measured pitch but unshared.
	//   grammar set, simTable set   machines additionally draw their rates from
	//                               one table, so verticals relate.
	// A missing argument is the off switch, so a run cannot accidentally get the
	// treatment by forgetting a flag.
	propose { |op, specs, dir, mode = "gap", grammar = nil, simTable = nil, ratio = 1.0|
		var r;
		lastLayer = nil; lastPair = nil;
		r = this.proposeInner(op, specs, dir, mode, grammar, simTable, ratio);
		this.noteStall(r.notNil);
		^r
	}

	proposeInner { |op, specs, dir, mode = "gap", grammar = nil, simTable = nil, ratio = 1.0|
		var gap, a, b, sa, sb, dur, layer, name, path, f, txt, mix, m, body, centre, inst, ioiEmit, want,
		    needsShape = false, shapeSig = "",
		    slots, layerSpec = [], preludeTxt = "", mainTxt, pbindTxt, dspSpec = nil, dspTxt = "",
		    sg = nil, sgDef = nil, sgName = nil, sustained = false, fragInst, outPath, poly;

		// "random" is arm B of the 25 Aug control and stays layer-blind, or the
		// two arms would differ in two ways at once and the comparison would
		// say nothing.
		want = if (mode == "random") { nil } { this.starvedLayer };
		lastLayer = want;
		gap = if (mode == "random") { this.findRandom(op) } {
			this.findGapInLayer(op, specs, want) };
		if (gap.isNil) { lastReason = "no candidate pair (operator young, or every pair bridged)"; ^nil };
		// THE GAP COMES FROM THE OPERATOR'S CELLS, WHICH ARE SUFFIXED "@bucket"
		// since 15 Sept. specs is keyed by bare machine names. So every lookup
		// below failed with "endpoint not in specs: fma2@slow/grind@slow" --
		// 1,107 times in the ten-arm run of 19-20 Sept, 0 ACQUIRED. Across all
		// 211 logs the last machine the factory ever wrote is
		// brmapu2609051820x1 on 5 Sept 18:20. The supply had been frozen for
		// fifteen days and the whole vocabulary measured this week is that
		// frozen set. Strip the suffix here; the bridge is between machines,
		// not between tempo-bucketed states of them. Found 20 Sept.
		lastPair = this.key(gap[0], gap[1]);
		a = gap[0].asString; b = gap[1].asString;
		if (a.indexOf($@).notNil) { a = a.copyRange(0, a.indexOf($@) - 1) };
		if (b.indexOf($@).notNil) { b = b.copyRange(0, b.indexOf($@) - 1) };
		// look up by String AND Symbol. weights.json arrives from parseYAML as a
		// Dictionary keyed by Strings, but an IdentityDictionary keyed by Strings
		// compares by identity and silently misses -- the same failure class as
		// the String/Symbol dispatch bug that made 19 of 22 machines inaudible.
		sa = this.specOf(specs, a);
		sb = this.specOf(specs, b);
		if (sa.isNil or: { sb.isNil }) {
			lastReason = "endpoint not in specs: " ++ a ++ "/" ++ b; ^nil };

		mix = if (reach > 0) { rrand(reach.neg, 1 + reach) } { 0.35 + 0.3.rand };   // where between (or past) the two
		// GEOMETRIC, NOT ARITHMETIC. Event rates in this vocabulary span
		// 0.013 s to 11.4 s -- three orders of magnitude -- and a linear
		// average of two of them is dominated by the slower one. Halfway
		// between ry (0.082) and hm (1.143) is 0.61 s arithmetically and
		// 0.31 s geometrically, and only the second is halfway in the sense
		// a listener means: an octave of tempo, not a count of seconds.
		// Everywhere else in this system rate is compared in log10 --
		// `deviates` uses absdif(log10, log10) -- so the interpolation was
		// the one place using a different metric from the gate that judges it.
		dur = exp((log((sa["dur"] ? "0.1").asFloat.max(1e-4)) * (1 - mix))
		        + (log((sb["dur"] ? "0.1").asFloat.max(1e-4)) * mix));
		// THREE LAYERS, BECAUSE THE FACTORY PLAYS THREE.
		//
		// This was `if (dur < 0.15) { "micro" } { "macro" }` -- binary, with no
		// mid at all, so the gesture layer could never receive a machine the
		// factory wrote. Measured 3 Sept across all 156 written machines: EVERY
		// ONE was classified macro, minimum event 0.4607 s, nothing below it.
		// The factory has never authored a grain or a gesture.
		//
		// Two causes, and the binary split is only the second. The first is
		// that findGap looks for HOLES, the holes are between the machines the
		// factory rarely visits, and those are the slow ones -- eight of the
		// nine bridges written on 3 Sept had a macro machine at one or both
		// ends. So the writer was structurally confined to long-form, and then
		// labelled the result with a rule that had nowhere else to put it.
		//
		// Boundaries are the geometric means of the three layer scales the
		// policy already names -- 60 ms, 400 ms, 2 s -- so a machine is called
		// what it is nearest to in the metric everything else uses.
		layer = if (dur < 0.155) { "micro" } { if (dur < 0.894) { "mid" } { "macro" } };

		// THE DEVIATION GATE, BEFORE ANY FILE IS NAMED.
		// Refusing here rather than after writing means the pair is NOT retired
		// and NOT counted: the factory may bridge it later, once the vocabulary
		// has moved and the same interpolation would land somewhere new.
		// WHICH INSTRUMENT. Until now this was always \playback -- 147 of 147
		// written machines -- and \playback is PlayBuf into one BPF into Pan2.
		// Four operations, no delay, no feedback, no modulation. So every
		// machine the factory had ever authored was the same sound at a
		// different speed, which is what Roberto heard as "cheap concatenative
		// synthesis" and what the code says it is.
		//
		// \playgran was there the whole time and the writer never emitted it:
		// GrainBuf driven by Impulse.kr(freq), grain position modulated by
		// LFNoise2, a SWEPT filter envelope, stereo spread. It is what the three
		// distinctive originals use. Granular clouds against discrete grains are
		// two different sounds rather than two rhythms.
		//
		// Very short events stay on playbackHP, because a cloud whose grains are
		// 30 ms apart is not a cloud. Above that the choice is the factory's.
		inst = if (dur < 0.09) { "playbackHP" } {
			if (0.5.coin) { "playgran" } { "playback" } };
		// B8 RUNG 2, 24 Sept 2026: with probability synthWeight the machine
		// AUTHORS ITS OWN SynthDef through the SynthGrammar, on one of six
		// sources. Its instrument, for the gate and the spec, is "sg_<source>",
		// so two machines on different sources are different by construction
		// and two on the same source still separate in duration and shape.
		// Not below 0.09 s: a held source at grain rate is not held.
		if (grammar.notNil and: { synthGrammar.notNil } and: { dur >= 0.09 } and: { synthWeight.coin }) {
			sg = synthGrammar.pickSource;
			inst = "sg_" ++ sg;
			sustained = synthGrammar.sustained(sg);
		};
		// which pool of the originals' fragments fits: a held source takes the
		// cloud player's (seconds), a grain source takes the grain player's
		fragInst = if (sg.isNil) { inst } { if (sustained) { "playgran" } { "playback" } };

		// The gate now counts TIMBRE, not only rhythm. Two machines on
		// different instruments are different by construction whatever their
		// event rate; two on the same instrument must still separate in
		// duration. Measuring deviation on duration alone was measuring the one
		// axis that could not fix the problem.
		// THE DURATION TEST DEFERS INSTEAD OF REJECTING, 5 Sept.
		//
		// The shape signature can only be read off the emitted source, and the
		// source does not exist yet -- grammar.machine runs at line ~742 and
		// needs ioiEmit, which is computed below this point. Rather than hoist
		// half the emitter above the gate, a candidate that is too close in
		// DURATION is now merely marked, and gets a second test on SHAPE just
		// before the file is written, where its real structure is known.
		//
		// Fast path is unchanged: a machine far enough in duration passes here
		// and never computes a signature.
		lastReason = "ok";
		needsShape = this.deviates(dur, specs, inst).not;

		// ONE PLACE, BOTH ARMS. The control arm reads the emitted `var ioi` and
		// the grammar arm bakes numbers in from its own ioi, so scaling in only
		// one of them would give the two arms different densities and make the
		// comparison between them meaningless.
		ioiEmit = if (inst == "playgran" or: { sustained }) { (dur * 8).clip(0.6, 6.0) } { dur };

		written = written + 1;
		// RUN-STAMPED. Two runs can no longer collide, so the vocabulary
		// accumulates instead of each run overwriting the last.
		name = "br" ++ a ++ b ++ stamp ++ "x" ++ written;
		path = dir ++ "/" ++ name ++ ".scd";
		// a rung 2 machine is written to <dir>/../pending and admitted by the
		// factory only after tools/check_machine.sh has rendered it
		if (sg.notNil) {
			outPath = dir ++ "/../pending";
			("mkdir -p " ++ outPath.quote).systemCmd;
			path = outPath ++ "/" ++ name ++ ".scd";
			sgName = "sg_" ++ name;
		};

		// ---- THE COMPOSITION, decided before any text exists -------------
		//
		// 22 Sept 2026. With a grammar, every slot is drawn: a fragment from
		// an original (probability fragmentWeight, same instrument, endpoints
		// preferred) or a grammar term. Routing, envelope and layer count are
		// slots like the others. The originals' idiom -- which events ring,
		// how an event is articulated, how many voices of itself a machine
		// stacks -- is now material the factory composes with, and the record
		// of what came from where is written into the machine's own header.
		// Without a grammar nothing here runs and the template is unchanged.
		if (grammar.notNil) {
			var srcs, pickSrc, comp = List.new, preludes = Dictionary.new, s, e, fbs;
			this.loadFragments;
			srcs = this.fragSources(fragInst, a, b);
			pickSrc = { if (srcs.notEmpty and: { fragmentWeight.coin }) { srcs.choose } { nil } };
			body = ((sa["body"] ? "0.2").asFloat + (sb["body"] ? "0.2").asFloat) / 2;
			centre = ((sa["centre"] ? "1200").asFloat + (sb["centre"] ? "1200").asFloat) / 2;
			m = grammar.machine(
				(ioi: ioiEmit, body: body.clip(0.02, 0.4), centre: centre.clip(120, 6000), ratio: ratio),
				simTable);
			slots = Dictionary.new;
			// the fallback each fragment cycle carries: the writer's own
			// measured value for the slot (see fragSlot)
			fbs = Dictionary[
				"dur" -> ioiEmit.round(0.0001).asString,
				"rate" -> ratio.clip(0.25, 4.0).round(0.0001).asString,
				"cutoff" -> centre.clip(120, 6000).round(0.1).asString,
				"amp" -> body.clip(0.02, 0.4).round(0.0001).asString,
				"pan" -> "0.0", "out" -> "0"];
			["dur", "rate", "cutoff", "pan", "amp", "out"].do { |k|
				s = pickSrc.value;
				e = s !? { this.fragSlot(s, k, fbs[k]) };
				if (e.notNil) {
					slots[k] = e; preludes[s] = fragments[s]["prelude"]; comp.add(k ++ "<-" ++ s);
				} {
					slots[k] = m[k.asSymbol]; comp.add(k ++ "<-grammar");
				};
			};
			// envelope: atk and rel together, from one source or one profile
			s = pickSrc.value;
			if (s.notNil and: { this.fragSlot(s, "atk").notNil } and: { this.fragSlot(s, "rel").notNil }) {
				slots["atk"] = this.fragSlot(s, "atk"); slots["rel"] = this.fragSlot(s, "rel");
				preludes[s] = fragments[s]["prelude"]; comp.add("env<-" ++ s);
			} {
				slots["atk"] = m[\env][\atk]; slots["rel"] = m[\env][\rel];
				comp.add("env<-grammar(" ++ m[\env][\profile] ++ ")");
			};
			layerSpec = m[\layers];
			comp.add("layers=" ++ (layerSpec.size + 1));
			// the processing stages (B8 rung 1): the machine's own, or dry
			if (sg.notNil) {
				sgDef = synthGrammar.def(sgName, sg, (ioi: ioiEmit, centre: centre.clip(120, 6000)));
				if (sgDef.isNil) { lastReason = "SynthGrammar refused (UGen cap) for " ++ sg; written = written - 1; ^nil };
				comp.add(sgDef[\signature]);
			};
			dspSpec = if (sg.isNil) { grammar.dsp(centre.clip(120, 6000), dspWeight) } { nil };
			if (dspSpec.notNil) {
				dspTxt = [\res, \resfz, \resrt, \dly, \dlyt, \dlyfb, \blur, \blurhz]
					.select({ |k| dspSpec[k].notNil })
					.collect({ |k| "        \\" ++ k ++ ", " ++ dspSpec[k] ++ ",\n" }).join;
				comp.add("dsp=" ++ dspSpec[\tree]);
			} { if (sg.isNil) { comp.add("dsp=dry") } };
			preludeTxt = preludes.keys.asArray.sort.collect({ |k|
				var p = preludes[k];
				if (p.isEmpty) { "" } { "    var " ++ p.replace("\t", " ") ++ ";\n" } }).join;
			// ';'-joined, no spaces: it rides on the ACQUIRED log line, and
			// the log parsers split fields on commas and lines on whitespace
			lastComposition = comp.join(";");
		};

		txt = "// " ++ name ++ " -- WRITTEN BY THE FACTORY, WHILE PLAYING.\n"
		++ "//\n"
		++ "// Not by me. The transfer operator found a hole in the factory's own\n"
		++ "// dynamics: the transition " ++ a ++ " -> " ++ b ++ " had been observed\n"
		++ "// " ++ ((op.counts[a] !? { op.counts[a][b] }) ? 0) ++ " times across its whole history.\n"
		++ "// This machine is a BRIDGE between those two behaviours, placed where\n"
		++ "// the factory has never found a way to move.\n"
		++ "//\n"
		++ "// Interpolated at " ++ mix.round(0.01) ++ " between them:\n"
		++ "//   " ++ a ++ " median event " ++ (sa["dur"] ? "?") ++ " s\n"
		++ "//   " ++ b ++ " median event " ++ (sb["dur"] ? "?") ++ " s\n"
		++ "//   this   " ++ dur.round(0.0001) ++ " s -> " ++ layer ++ " layer\n"
		++ "//\n"
		++ "// Anti-convergent by construction: it targets what the factory does\n"
		++ "// NOT do, unlike the audibility score, which weighted up whatever\n"
		++ "// already worked and took the vocabulary from nine machines to four.\n"
		++ if (grammar.isNil) { "" } {
			"// SHAPE CHOSEN BY THE FACTORY, not filled into a template I wrote.\n"
			++ "// Each slot below is a term expanded from PatternGrammar to depth "
			++ grammar.maxDepth ++ ".\n"
			++ "// Rate is anchored on the pitch ratio measured when this machine was\n"
			++ "// written (" ++ ratio.round(0.001) ++ ")"
			++ (if (simTable.isNil) { ", drawn alone.\n" }
			   { ", drawn from the shared table "
			     ++ simTable.collect({ |x| x.round(0.001) }) ++ ".\n" })
			++ "// COMPOSED: " ++ lastComposition ++ "\n"
			++ "//   <-xx is a fragment of original xx (Handler_Local.sc, via\n"
			++ "//   mutable/fragments.json); <-grammar is a term the grammar drew.\n"
			++ "//\n"
		}
		++ (if (sgDef.isNil) { "" } {
			"// THE INSTRUMENT IS THE FACTORY'S TOO (B8 rung 2): the SynthDef below\n"
			++ "// was drawn by SynthGrammar for this machine alone -- " ++ sgDef[\signature] ++ "\n"
			++ sgDef[\text] ++ "\n" })
		++ "{ |buf, args|\n"
		++ "    var ioi   = " ++ ioiEmit.round(0.0001) ++ ",\n"
		++ "        scale = args.at(\\density).linlin(0.0, 1.2, 1.5, 0.7, clip: \\minmax),\n"
		++ "        body  = args.at(\\avgrms).linlin(0.0, 1.0, 0.10, 0.32, clip: \\minmax),\n"
		++ "        centre = args.at(\\avgcent).linlin(1200, 6000, 300, 2400, clip: \\minmax);\n"
		++ "    var main;\n"
		++ preludeTxt
		++ "\n"
		++ "    main = Pbind(\n"
		// the FX def only when the machine draws stages (26 Sept): a dry
		// voice on \playback allocates no delay line
		++ "        \\instrument, \\" ++ (sgName ?? { if (dspTxt.isEmpty) { inst } { inst ++ "FX" } }) ++ ",\n"
		++ (if (inst == "playgran") {
			// GRAIN DENSITY IS THE PARAMETER THAT MAKES playgran A CLOUD.
			// GrainBuf is driven by Impulse.kr(freq), so freq is grains per
			// second and it, not \dur, sets the texture. Derived from the
			// bridge's own event rate so a fast bridge clouds densely and a
			// slow one sparsely -- the same quantity the layer split uses,
			// read through the other instrument.
			"        \\freq, " ++ (1.0 / dur.clip(0.02, 4.0)).clip(1.5, 40).round(0.01) ++ ",\n"
		} { "" })
		++ "        \\buf, Pshuf(buf, inf),\n"
		++ (if (grammar.isNil) {
			// THE CONTROL ARM: the template exactly as it has always been, so a
			// run without a grammar is byte-for-byte the machine the factory has
			// been writing since August and the comparison is clean.
			"        \\dur, Pseq([\n"
			++ "            Pn(Pwhite(ioi * 0.7, ioi) * scale, " ++ (2 + 3.rand) ++ "),\n"
			++ "            Pn(Pwhite(ioi, ioi * 1.6) * scale, " ++ (2 + 3.rand) ++ ")\n"
			++ "        ], inf),\n"
			++ "        \\cutoff, Pseg(Pseq([centre, centre * 1.7, centre * 0.8], inf),\n"
			++ "                       Pseq([ioi * 9, ioi * 14], inf), \\sin),\n"
			++ "        \\rate, Pseq([1.0, " ++ (0.85 + 0.4.rand).round(0.01) ++ ", 1.0], inf),\n"
			++ "        \\pan, Pwhite(-0.7, 0.7),\n"
			++ "        \\amp, Pwhite(body * 0.6, body),\n"
		} {
			// THE GRAMMAR ARM, now the COMPOSED arm: the slots were decided
			// above, each a fragment of an original or a grammar term, and
			// the machine was computed against the same measured quantities
			// the template's locals come from (ioiEmit already carries the
			// playgran cloud scaling; see ioiEmit above).
			"        \\dur, "    ++ slots["dur"]    ++ ",\n"
			++ "        \\cutoff, " ++ slots["cutoff"] ++ ",\n"
			++ "        \\rate, "   ++ slots["rate"]   ++ ",\n"
			++ "        \\pan, "    ++ slots["pan"]    ++ ",\n"
			++ "        \\amp, "    ++ slots["amp"]    ++ ",\n"
			++ dspTxt
		})
		// THE ENVELOPE IS PER-INSTRUMENT, and getting this wrong would waste the
		// whole change. playback's envelope brackets ONE grain, so atk and rel
		// are fractions of the event. playgran's brackets a CLOUD that
		// GrainBuf keeps refilling underneath it, so a release of dur*0.7 would
		// cut the cloud off after a few grains and produce another click. The
		// originals give it seconds; so does this. A composed playback machine
		// takes its articulation from the composition (a fragment's atk/rel
		// or a grammar profile); playgran keeps the cloud envelope.
		++ (if (inst == "playgran" or: { sustained }) {
			"        \\atk, " ++ (dur * 4).clip(0.15, 2.5).round(0.001) ++ ",\n"
			++ "        \\rel, " ++ (dur * 12).clip(1.0, 8.0).round(0.001) ++ ",\n"
		} {
			if (grammar.isNil) {
				"        \\atk, " ++ (dur * 0.15).round(0.0001) ++ ",\n"
				++ "        \\rel, " ++ (dur * 0.7).round(0.0001) ++ ",\n"
			} {
				"        \\atk, " ++ slots["atk"] ++ ",\n"
				++ "        \\rel, " ++ slots["rel"] ++ ",\n"
			}
		})
		// ROUTING. The template wrote \out, 0 for every machine the factory
		// ever made: dry, all of them, while every original decides per event
		// which bus it rings on. A composed machine routes.
		++ (if (grammar.isNil) { "        \\out, 0\n" } { "        \\out, " ++ slots["out"] ++ "\n" })
		++ "    );\n"
		// LAYERS. Zero or more copies of the machine at rate intervals from
		// the shared table, quieter and offset: dronePlayer's three fixed
		// layers, with the count and the intervals drawn by the factory.
		++ (if (layerSpec.isEmpty) { "    main\n" } {
			"    Ppar([main" ++ layerSpec.collect({ |ly|
				",\n        Pbindf(main, \\rate, (Pkey(\\rate) * " ++ ly[\ratio] ++ ").clip(-4.0, 4.0),"
				++ " \\amp, Pkey(\\amp) * " ++ ly[\amp] ++ ","
				++ " \\pan, (Pkey(\\pan) + " ++ ly[\pan] ++ ").clip(-1.0, 1.0))" }).join
			++ "])\n"
		})
		++ "}\n";

		// ---- THE POLYPHONY BOUND (26 Sept 2026) -------------------------------
		// A machine's concurrent voices are layers x (atk + rel) / dur. On
		// 25 Sept a written machine paired micro events (0.05 s) with
		// dronePlayer's 3-9 s release: ~180 voices on \playback, each holding
		// a 128 KB delay line, and the server's real-time pool was gone in
		// eight minutes. The originals sit under 20. The estimate runs the
		// emitted stream for 60 events with representative args, the way
		// tools/test_composer.scd does; a machine over the cap is refused
		// before the file exists, and the reason is logged.
		poly = this.polyphonyOf(txt);
		if (poly.notNil and: { poly > maxPolyphony }) {
			lastReason = "polyphony " ++ poly.round(0.1) ++ " voices above " ++ maxPolyphony
				++ " (layers x (atk+rel) / dur)";
			written = written - 1;
			^nil };

		// ---- THE SHAPE RESCUE ------------------------------------------------
		// Everything above built a candidate. If it was too close in duration to
		// something on its own instrument, it may still enter on being a
		// different KIND of pattern -- which is the whole reason the grammar
		// exists, and the thing the duration-only gate could never see.
		shapeSig = this.shapeOf(txt);
		if (needsShape and: { this.deviates(dur, specs, inst, shapeSig).not }) {
			lastReason = "duration " ++ dur.round(0.0001) ++ " s within minDeviation "
				++ minDeviation ++ " AND shape " ++ (if (shapeSig.isEmpty) { "<template>" } { shapeSig })
				++ " within minShapeDeviation " ++ minShapeDeviation
				++ " of an existing " ++ (inst ? "playback") ++ " machine";
			// the counter was advanced at line ~659 on the assumption this would
			// be written; give it back, or names drift for every refusal
			written = written - 1;
			^nil };
		f = File(path, "w");
		if (f.isOpen) {
			f.write(txt); f.close;
			// retire the pair ONLY on a successful write, so a failed write does
			// not silently remove a hole the factory never actually addressed.
			// Recorded against the run stamp and persisted, so the retirement
			// survives a restart -- without that the rule is per-run and the
			// same pair is bridged again on every boot.
			bridged[this.key(a, b)] = stamp ++ "x" ++ written;
			this.saveLedger;
			// and tell the factory what it just made, so layerOf stops calling
			// every machine the factory wrote a micro one.
			// GUARDED: the spec is a convenience, the machine is the work. When
			// this threw silently between 12:43 and 12:57 on 3 Sept it cost
			// eight records; unguarded and one line further up it would have
			// cost eight machines.
			try { this.recordSpec(name, dur, layer, inst, shapeSig, this.inheritWeights(sa, sb)) } { |e|
				("MachineWriter: spec not recorded for " ++ name ++ " -- "
					++ e.errorString).postln };
			^[name.asSymbol, a, b, dur, layer, inst, if (sg.notNil) { path } { nil }]
		};
		^nil
	}
}
