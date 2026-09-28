// A GRAMMAR OVER THE SOURCE, NOT ONLY OVER WHAT HAPPENS AFTER ONE.
//
// B8 rung 2, 24 Sept 2026. Roberto's verdict of 22 Sept on the composed
// writer's first auditions: arrangement and processing are colour, the source
// is kind. Every machine the factory had authored ended in one of three
// SynthDefs the architect wrote (\playback, \playbackHP, \playgran), so the
// factory could rearrange and could not make a new kind of sound.
//
// This class emits a SynthDef SOURCE per machine. The machine file carries it
// at the top (`SynthDef(\sg_<name>, {..}).add;`) ahead of the machine function,
// so `path.load` in the live factory registers the def on the running server
// the same way every machine is loaded, and the machine's \instrument names it.
//
// SIX SOURCES, each a different relation to the grain, and that relation is
// what "kind" has meant for the whole project:
//   playbuf     the grain played (today's grain player)
//   grainbuf    a cloud of it (today's playgran, mono, its own grain rate)
//   warp1       the grain time-stretched: a held, smeared version of the material
//   pitchshift  the grain looped and pitch-shifted to the machine's rate: held
//   klank       the grain's onset exciting a resonator bank: the grain as impulse
//   wavetable   a slice of the grain read as a period: the grain as a waveform
// After the source: zero to two stages from a fixed set, the machine's BPF at
// its cutoff slot, the shared envelope, Pan2, Out.
//
// WHAT IS THE ARCHITECT'S: the six sources, the stage set, every bound below,
// the dry-mix floor, the Limiter, the UGen cap. WHAT IS THE FACTORY'S: which
// source, at what parameters, with which stages, in which machine. Rung 3 is
// where the list itself becomes proposable.
//
// GUARDS, because this emits a UGen graph into a factory that is playing:
//   * every parameter is clipped at emission (num) and again at the UGen;
//   * each stage is mixed against dry with a wet share of at most 0.7, so no
//     graph is silent;
//   * a Limiter at 0.9 inside the def, before the envelope, so a resonator or
//     a comb cannot deliver more than a grain would;
//   * the arg list is \playback's, so a composed Pbind (rung 1 keys included)
//     drives it unchanged and unknown keys are simply not sent;
//   * a UGen-count cap, checked on the emitted text (ugenCount);
//   * memory: only CombL (0.5 s line) and PitchShift (window <= 0.25 s)
//     allocate from the server's real-time pool, at most one of each per def.
//     23 Sept's pool exhaustion came from a 2 s CombL on every voice.
//   * and tools/check_machine.sh renders the machine offline and measures
//     peak and RMS before the live factory admits it (MachineWriter writes
//     rung 2 machines to mutable/pending/, the factory moves them on a pass).
SynthGrammar {
	var <lastSignature, <lastSource, <>maxUGens = 48, ringMax;
	// 27 Sept 2026: the architect's weight per source, from Roberto's
	// listening of the twelve test renders (klank and wavetable new in kind;
	// warp1 heard as the originals). Empty or all-zero: uniform, as before.
	var <>sourceWeights;
	// B8 rung 3, second half (27 Sept 2026). The CATALOGUE is the architect's:
	// bounded source idioms the factory may TRIAL offline (tools/trial_sources.scd)
	// and propose adding. A catalogue source is never drawn live unless it has
	// been adopted into `extraSources` (policy synth_sources_adopted) by the
	// architect. `forceSource` exists for the trial only.
	var <>extraSources, <>forceSource;

	*new { ^super.new.init }
	init { lastSignature = ""; lastSource = nil; ^this }

	sources { ^[\playbuf, \grainbuf, \warp1, \pitchshift, \klank, \wavetable] ++ (extraSources ? []) }
	catalogue { ^[\pluck, \formant, \fm, \freeze] }

	pickSource {
		var srcs = this.sources, w;
		if (forceSource.notNil) { ^forceSource.asSymbol };
		if (sourceWeights.isNil) { ^srcs.choose };
		w = srcs.collect({ |s| (sourceWeights[s] ? 0).asFloat.max(0) });
		if (w.sum <= 0) { ^srcs.choose };
		^srcs.wchoose(w.normalizeSum)
	}

	// a source whose event is a held thing rather than one grain: the machine
	// takes the cloud envelope (seconds) and the playgran fragment pool
	// klank is not in this list: its exciter is the grain's onset, and a long
	// attack would hide it (the first test renders of klank were silent for
	// that reason); its def floors the release at its longest ring instead
	sustained { |src| ^[\grainbuf, \warp1, \wavetable, \fm, \freeze].includes(src.asSymbol) }
	// excited by the grain's onset and ringing after it, like klank: short
	// attack, release floored at the ring
	rings { |src| ^[\klank, \pluck, \formant].includes(src.asSymbol) }

	num { |v, lo, hi, places = 4|
		var x = v;
		if (x.isNil or: { x.isNumber.not } or: { x.isNaN } or: { x.abs >= 1e12 }) { x = (lo + hi) / 2 };
		^x.clip(lo, hi).round(10 ** places.neg)
	}
	f { |v, lo, hi, places = 4| ^this.num(v, lo, hi, places).asString }

	// the number of UGens the emitted text instantiates, by construction
	ugenCount { |txt|
		var n = 0, i = 0, j;
		[".ar(", ".kr(", ".ir("].do { |tok|
			i = 0;
			while { j = txt.find(tok, false, i); j.notNil } { n = n + 1; i = j + 1 };
		};
		^n
	}

	// ---- the source ------------------------------------------------------------
	// Each returns text that assigns `sig` (mono) from `buf`, `rate`, `atk`,
	// `rel`; `ctx` carries ioi and centre. Constants are drawn here, once, at
	// birth: they are the machine's, like a grammar term.
	sourceText { |src, ctx|
		var ioi = (ctx[\ioi] ? 0.12).clip(0.01, 6.0), centre = (ctx[\centre] ? 1200).clip(120, 6000);
		^switch (src.asSymbol)
		{ \playbuf } {
			"        life = atk.max(0.03) + rel;\n"
			++ "        bdur = BufDur.ir(buf) / rate.abs.max(0.01);\n"
			++ "        lp = life > (bdur * 1.5);\n"
			++ "        rt = BufRateScale.ir(buf) * rate;\n"
			++ "        sig = PlayBuf.ar(1, buf, rt, loop: lp, startPos: (rt < 0) * (BufFrames.ir(buf) - 1), doneAction: 0);\n"
		}
		{ \grainbuf } {
			// grains per second from the event rate the machine was born at,
			// grain length and the drift of the read position drawn
			"        sig = GrainBuf.ar(1, Impulse.kr(" ++ this.f((1.0 / ioi).clip(3, 40) * (0.6 + 0.8.rand), 3, 40, 2)
			++ "), " ++ this.f(0.04 + 0.3.rand, 0.03, 0.35)
			++ ", buf, rate.clip(0.25, 4.0), LFNoise2.kr(" ++ this.f(0.05 + 0.45.rand, 0.03, 0.5)
			++ ").range(0, 1), 4, 0, -1) * 1.6;\n"
		}
		{ \warp1 } {
			// the pointer crosses the buffer once per (BufDur * stretch) seconds
			"        sig = Warp1.ar(1, buf, LFSaw.kr(1 / (BufDur.ir(buf).max(0.01) * "
			++ this.f(3 + 17.0.rand, 2, 24, 2) ++ "), 1).range(0, 1), rate.clip(0.25, 4.0), "
			++ this.f(0.1 + 0.25.rand, 0.08, 0.35) ++ ", -1, " ++ (4 + 4.rand)
			++ ", " ++ this.f(0.05 + 0.25.rand, 0.0, 0.3) ++ ", 2) * 0.8;\n"
		}
		{ \pitchshift } {
			// the grain looped at its own speed, shifted to the machine's rate
			"        sig = PitchShift.ar(PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 1), "
			++ this.f(0.08 + 0.17.rand, 0.06, 0.25) ++ ", rate.clip(0.25, 4.0), "
			++ this.f(0.02.rand, 0.0, 0.02) ++ ", " ++ this.f(0.08.rand, 0.0, 0.08) ++ ") * 2.0;\n"
		}
		{ \klank } {
			// the grain, cut to an onset, into a bank of 3-6 resonators whose
			// centre is the machine's; harmonic or stretched, the factory's
			var n = 3 + 4.rand, harmonic = 0.5.coin, ratios, amps, rings;
			ratios = Array.fill(n, { |i| if (harmonic) { i + 1 } { (1 + i) ** (1.05 + 0.4.rand) } });
			amps = ratios.collect({ |r| (1.0 / r).clip(0.05, 1.0) });
			rings = Array.fill(n, { 0.2 + 2.3.rand });
			ringMax = rings.maxItem.clip(0.2, 2.5).round(0.01);
			"        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 0, doneAction: 0)\n"
			++ "            * EnvGen.ar(Env.perc(0.001, " ++ this.f(0.01 + 0.07.rand, 0.005, 0.08) ++ "), 1);\n"
			++ "        sig = DynKlank.ar(`[[" ++ ratios.collect({ |r| this.f(centre * r / (2 + 2.rand), 40, 6000, 1) }).join(", ")
			++ "] * rate.clip(0.25, 4.0), [" ++ amps.collect({ |a| this.f(a, 0.05, 1.0, 3) }).join(", ")
			++ "], [" ++ rings.collect({ |r| this.f(r, 0.2, 2.5, 2) }).join(", ") ++ "]], exc) * 0.12;\n"
		}
		{ \wavetable } {
			// one period's worth of the grain, read as a loop at a pitch below
			// the machine's centre; the start of the slice drifts so the tone
			// changes colour as it is held
			var f0 = (centre / [4, 6, 8, 12].choose).clip(40, 800);
			"        per = SampleRate.ir / (" ++ this.f(f0, 40, 800, 2) ++ " * rate.clip(0.25, 4.0)).clip(30, 2000);\n"
			++ "        st = (BufFrames.ir(buf) * (" ++ this.f(0.5.rand, 0.0, 0.5, 3)
			++ " + LFNoise2.kr(" ++ this.f(0.02 + 0.3.rand, 0.01, 0.4) ++ ").range(0, " ++ this.f(0.3.rand, 0.0, 0.3, 3)
			++ "))).clip(0, (BufFrames.ir(buf) - 2000).max(0));\n"
			++ "        sig = LeakDC.ar(BufRd.ar(1, buf, Phasor.ar(0, 1, 0, per) + st, 1, 4)) * 1.5;\n"
		}
		// ---- THE CATALOGUE (architect's, 27 Sept 2026) ------------------------------
		// Memory: pluck's delay line is 0.05 s (2,205 samples); freeze's FFT is a
		// LocalBuf of 1,024; nothing else allocates. No catalogue source may add
		// more than one allocating UGen.
		{ \pluck } {
			// the grain as the pluck of a tuned string (Karplus-Strong): the
			// grain's onset excites a delay line at a pitch below the centre
			var f0 = (centre / [2, 3, 4, 6].choose).clip(40, 1500), dec = 0.4 + 3.1.rand;
			ringMax = dec.clip(0.3, 3.5).round(0.01);
			"        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 0, doneAction: 0)\n"
			++ "            * EnvGen.ar(Env.perc(0.001, " ++ this.f(0.005 + 0.04.rand, 0.003, 0.05) ++ "), 1);\n"
			++ "        sig = Pluck.ar(exc, Impulse.kr(0), 0.05, (1 / (" ++ this.f(f0, 40, 1500, 2)
			++ " * rate.clip(0.25, 4.0))).clip(0.00067, 0.05), " ++ this.f(dec, 0.3, 3.5, 2) ++ ", "
			++ this.f(0.05 + 0.5.rand, 0.0, 0.6, 3) ++ ") * 1.2;\n"
		}
		{ \formant } {
			// the grain's onset through 3-5 formant resonators (a vowel-like
			// body), placed from the machine's centre
			var n = 3 + 3.rand, fs, dec = 0.05 + 0.6.rand;
			fs = Array.fill(n, { |i| (centre * [0.35, 0.8, 1.6, 2.4, 3.3][i] * (0.85 + 0.3.rand)).clip(150, 5000) });
			ringMax = (dec * 3).clip(0.2, 2.0).round(0.01);
			"        exc = PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 1, doneAction: 0);\n"
			++ "        sig = Mix.new([" ++ fs.collect({ |f| "Formlet.ar(exc, " ++ this.f(f, 150, 5000, 1)
			++ " * rate.clip(0.5, 2.0), 0.005, " ++ this.f(dec, 0.03, 0.7, 3) ++ ")" }).join(", ")
			++ "]) * " ++ this.f(0.15 / n.sqrt, 0.05, 0.15, 3) ++ ";\n"
		}
		{ \fm } {
			// a sine carrier whose phase the grain modulates: the grain heard as
			// the timbre of a pitch
			var fc = (centre / [1, 2, 3, 4].choose).clip(60, 2000);
			"        sig = SinOsc.ar(" ++ this.f(fc, 60, 2000, 2) ++ " * rate.clip(0.25, 4.0), "
			++ "PlayBuf.ar(1, buf, BufRateScale.ir(buf), loop: 1) * " ++ this.f(0.5 + 5.5.rand, 0.3, 6.0, 2)
			++ ") * 0.25;\n"
		}
		{ \freeze } {
			// the grain's spectrum held after a short read, then left to sound:
			// the grain as a sustained chord of its own partials
			"        sig = IFFT(PV_MagFreeze(FFT(LocalBuf(1024), PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate.clip(0.25, 4.0), loop: 1)), "
			++ "EnvGen.kr(Env.step([0, 1], [" ++ this.f(0.05 + 0.3.rand, 0.03, 0.4, 3) ++ ", 1])))) * 0.6;\n"
		}
		{ nil }
	}

	// ---- the stages ------------------------------------------------------------
	// Each is mixed against dry at a wet share w in [0.3, 0.7], so at least 0.3
	// of the source always passes.
	stageText { |stage, centre|
		var w = this.f(0.3 + 0.4.rand, 0.3, 0.7, 2), wet;
		wet = switch (stage.asSymbol)
		{ \hpf }       { "HPF.ar(sig, " ++ this.f(200 + 2300.rand, 200, 2500, 1) ++ ")" }
		{ \lpf }       { "LPF.ar(sig, " ++ this.f(400 + 5600.rand, 400, 6000, 1) ++ ")" }
		{ \ringz }     { "Ringz.ar(sig, " ++ this.f(centre * [0.5, 1.0, 1.5, 2.0].choose, 60, 6000, 1)
		                 ++ ", " ++ this.f(0.1 + 1.4.rand, 0.05, 1.5, 3) ++ ") * 0.08" }
		{ \combl }     { var dt = this.num([0.008, 0.02, 0.05, 0.12, 0.25, 0.4].choose * (0.8 + 0.4.rand), 0.005, 0.45);
		                 "CombL.ar(sig, 0.5, " ++ dt ++ ", " ++ this.f(dt * 8 * (0.2 + 0.55.rand), 0.01, 3.0, 3) ++ ")" }
		{ \freqshift } { "FreqShift.ar(sig, " ++ this.f([1, -1].choose * (5 + 395.rand), -400, 400, 1) ++ ")" }
		{ \softclip }  { var g = this.num(2 + 4.rand, 2, 6, 2); "(sig * " ++ g ++ ").tanh * " ++ this.f(1 / g.sqrt, 0.3, 0.8, 3) }
		{ "sig" };
		^"        sig = (sig * " ++ (1 - w.asFloat).round(0.01) ++ ") + (" ++ wet ++ " * " ++ w ++ ");\n"
	}

	// ---- the def ---------------------------------------------------------------
	// Returns (text:, signature:, sustained:, source:) or nil when the text
	// exceeds the UGen cap (which by construction it should not; the cap is
	// the guard against this class being edited carelessly).
	def { |name, src, ctx|
		var centre = (ctx[\centre] ? 1200).clip(120, 6000), stages, nSt, txt, body, sig;
		src = src.asSymbol;
		nSt = [0, 1, 1, 2].choose;
		stages = [\hpf, \lpf, \ringz, \combl, \freqshift, \softclip].scramble.keep(nSt);
		body = this.sourceText(src, ctx);
		if (body.isNil) { ^nil };
		txt = "SynthDef(\\" ++ name ++ ", { |rate=1, atk=0.1, rel=0.4, cutoff=500, pan=0, buf, rq=4.0, amp=1.0, out=0,\n"
		++ "                    res=0, resfz=440, resrt=0.6, dly=0, dlyt=0.12, dlyfb=0.4, blur=0, blurhz=4000|\n"
		++ "    // SOURCE " ++ src ++ "; STAGES " ++ (if (stages.isEmpty) { "none" } { stages.join("+") })
		++ " -- drawn by SynthGrammar (B8 rung 2)\n"
		++ "    var sig, env, life, bdur, lp, rt, exc, per, st;\n"
		++ (if (this.rings(src)) {
			// the bank rings after the onset: a short attack and a release no
			// shorter than the longest ring, whatever the composition drew
			"    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03).min(0.05), rel.max(" ++ (ringMax ? 1.0) ++ ")], [1, -1]), doneAction: 2);\n"
		} {
			"    env = EnvGen.kr(Env.new([0, 1, 0], [atk.max(0.03), rel.max(0.01)], [1, -1]), doneAction: 2);\n"
		})
		++ body
		++ stages.collect({ |s| this.stageText(s, centre) }).join
		++ "        sig = BPF.ar(sig, cutoff.clip(20, 18000), rq.clip(0.5, 2.5).min(20000 / cutoff.clip(20, 18000)));\n"
		++ "        sig = Limiter.ar(LeakDC.ar(sig), 0.9, 0.01);\n"
		++ "        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1), amp.clip(0, 0.7)));\n"
		++ "}).add;\n";
		if (this.ugenCount(txt) > maxUGens) { ^nil };
		sig = "src=" ++ src ++ ";stages=" ++ (if (stages.isEmpty) { "none" } { stages.join("+") });
		lastSignature = sig; lastSource = src;
		^(text: txt, signature: sig, sustained: this.sustained(src), source: src, stages: stages)
	}
}
