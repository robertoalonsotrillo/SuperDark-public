/*

The Handler is a sequencer that takes several inputs:
1. it takes buffer information from the Python query,
2. it takes playback machine information (state) from the Behavior module,
3. it takes live feature extraction information (args) from the Analysis module, smoothed by the Behavior module.

*/


Handler {

	var state = \sc, // playback machine
	args; // live features

	*new {

        ^super.new.init()
	}

	init {

		args = Dictionary[
			\windowsize -> 0.4, // duration of average event
			\percpitch -> 0.0, // % of an event that is pitched
			\avgflat -> 0.09, // spectral flatness
			\density -> 1.5, // average duration between events
			\avgcent -> 4906.16, // spectral centroid
			\avgrms -> 0.10, // rms amplitude
			\mainpitch -> 'unpitched', // main pitch of event
			\avgrolloff -> 4300 // spectral rolloff
		];


	}

	settings { // function for setting playback machine and playback args

		|msg|

		state = msg[0];
		args = msg[1];

	}


	sciarrinoPlayer { // short flurries of events

		|buf|

		var dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
		dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pseq([
				Pwhite(0.05, 0.2 * dur, (dur + 2).asInteger),
				Pwhite(0.01, 0.02 * dur, (dur + 2).asInteger),
				Pwhite(0.4, 1.2, (dur + 2).asInteger)
			], 2),

			\atk, atk,

			\rel, ~sampleSize - atk,

			\rate, Pseq(
				[1.0]++
				(2.0!(dense.asInteger))++
				(0.5!(noise.asInteger))++
				(-1.0!(dense.asInteger * 2))++
				(2.0!((dense/2).asInteger)),
				2),

			\buf, Pshuf(buf, inf),

			\cutoff, cent,

			\pan, Pwhite(-1 * width, width),

			\amp, Pwhite(0.02, 0.1),

			\out, Pseq([
				(~dryBus[rrand(0, 4) % ~numPairs]!(bright.asInteger)),
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!4),
				(~reverbLongBus[rrand(0, 4) % ~numPairs]!(resonant.asInteger)),
				(~dryBus[1 % ~numPairs]!1),
				(~reverbMidBus[0 % ~numPairs]!(resonant.asInteger))], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	lushPlayer { // short flurries of events

		|buf|

		var dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
		dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 13000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			// BUG FIX (run 39). The original was
			//     Pseq(Pwhite(0.01, 0.3, Pwhite(0, 10)),
			//          Pwhite(4.0, 10.4, 1),
			//          Pwhite(0, 10))
			// which passes three Pwhites into Pseq(list, repeats, offset).
			// The first argument must be a collection, so this raised
			//     "ListPattern (Pseq) requires a non-empty collection;
			//      received a Pwhite"
			// on every call. The error is unconditional and does not depend on
			// any feature value, so lushPlayer has NEVER produced a sound.
			//
			// INTERPRETATION, needs Marek's confirmation. The comment says
			// "short flurries of events", and the two duration ranges are a
			// burst (0.01-0.3 s, 0-10 of them) and a gap (4.0-10.4 s, one).
			// Read as a list, that is flurry-then-rest, repeating, which is
			// what the comment describes. The third Pwhite sat in the `offset`
			// slot, where it has no meaning, and is dropped.
			\dur, Pseq([
				Pwhite(0.01, 0.3, Pwhite(0, 10)),
				Pwhite(4.0, 10.4, 1)
			], inf),

			\atk, atk,

			\rel, ~sampleSize - atk,

			\rate, Pseq(
				[1.0]++
				(0.5!(noise.asInteger))++
				(-1.0!(dense.asInteger * 2))++
				(-0.5!((dense/2).asInteger)),
				2),

			\buf, Pshuf(buf, inf),

			\cutoff, cent,

			\pan, Pwhite(-1 * width, width),

			\amp, Pwhite(0.02, 0.1),

			\out, ~reverbLongBus[rrand(0, 4) % ~numPairs],

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	sonorousPlayer { // flurries of events with reverb

		|buf|

		var dur = args.at(\windowsize).linlin(0, 5, 1, 5, clip: \minmax),
		dense = args.at(\density).linlin(0, 5, 1, 5, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 0, 5, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 1, 4, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
		reps = rrand(dense, dense * 7),
		granreps = rrand(0, 1),
		choose = rrand(0, 2),
		freq = args.at(\mainpitch).asString.pitchcps,
		atk = rrand(0.01, 0.4);

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pseq([
				Pwhite(0.05, 0.2 * dur, 5),
				Pwhite(0.01, 0.02 * dur, 6),
				Pwhite(0.4, 2.2, (dur + 2).asInteger)
			], reps),

			\atk, atk,

			\rel, ~sampleSize - atk,

			\rate, Pseq(
				[1.0]++
				(0.5!(noise.asInteger))++
				(-1.0!(dense.asInteger * 2))++
				(1.0!((dense/2).asInteger)),
				inf),

			\buf, Pshuf(buf, inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent, cent * 2, cent / 2], [1.0, 6.0], \sin).discretize(33).asArray,
					inf),

			\amp, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([0.01, 0.1, 0.01], [1.0, 6.0], \sin).discretize(33).asArray,
					inf),

			\pan, Pwhite(-1 * width, width),

			\out, Pseq([
				(~reverbShortBus[0 % ~numPairs]!2),
				(~reverbMidBus[4 % ~numPairs]!3)], 6),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(160);
			}

		).play;

		if ((choose == 0), {

			if ((freq < 30), {
				freq = rrand(6, 60)
			});

			Pkill(

				\instrument, \playgran,

				\dur, dense,

				\env, 1,

				\buf, Pshuf(buf, inf),

				\atk, Pwhite(1.0, 10.0),

				\rel, Pwhite(1.0, 10.0),

				\freq, freq,

				\rate, Pwrand([-1.0, 1.0], [1, 1], reps),

				\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent, cent * 5, cent / 2], [1, 10], \sin).discretize(33).asArray,
					inf),

				\pan, Pwhite(-1 * width, width),

				\amp, Pwhite(0.001, 0.02),

				\out, Pseq([
					(~reverbMidBus[rrand(0, 4) % ~numPairs]),
					(~reverbLongBus[rrand(0, 4) % ~numPairs]),
				], inf),

				{ //empty
				}

			).play;
		});

	}

	machinePlayer { // semi-periodic assemblages of events

		|buf|

		var dur = args.at(\density).linlin(0.0, 5.0, 0.2, 1.0, clip: \minmax),
		variance = args.at(\windowsize).linlin(0.0, 3.0, 0.1, 0.3, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(1000, 12000, 1, 4, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
		cutoff = rrand(200 * velocity, 800 * velocity),
		reps = rrand(10, bright * 50),
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pwrand(
				[(dur / 16), (dur / 8), (dur / 16), (dur /32), (dur / 2)],
				[16, 1, 1, 2, 1].normalizeSum,
				inf),

			\rate, Pwrand(
				[0.5, 1, 2.0, -1],
				[2, 6, 1, 6].normalizeSum,
				reps * 2),

			\buf, Pshuf(buf, inf),

			\atk, atk,

			\rel, ~sampleSize - atk,

			\pan, Pwhite(
				rrand(-1, 1),
				(rrand(-1, 1) + 0.3)
					.linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),
				inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent, cent * 2, cent / 2], [rrand(2, 10), rrand(2, 40)], \sin).discretize(128).asArray,
					inf),

			\amp, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([0.01, 0.1, 0.01], [rrand(2, 10), rrand(2, 40)], \sin).discretize(128).asArray,
					inf),

			\out, Pseq([
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!((bright + 1).asInteger)),
				(~dryBus[rrand(0, 4) % ~numPairs]!(3))
				], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	crankPlayer { // semi-periodic assemblages of events

		|buf|

		var dur = args.at(\density).linlin(0.0, 5.0, 0.2, 1.0, clip: \minmax),
		variance = args.at(\windowsize).linlin(0.0, 3.0, 0.1, 0.3, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(1000, 12000, 1, 4, clip: \minmax),
		// run 45. cr was the machine Roberto identified as harsh, confirmed by ear
		// and by measurement: loudest in the vocabulary and the highest 2-5 kHz
		// fraction. Its filter sweeps [cent, cent*2, cent/2], and at the corpus
		// mean the old mapping put that at 5.2k -> 10.4k -> 2.6k. Topping the
		// sweep near 4 kHz cuts sharpness 5.159 -> 4.283 and the energy above
		// 8 kHz by a factor of eleven.
		cent = args.at(\avgcent).linlin(0, 10000, 150, 6000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
		cutoff = rrand(200 * velocity, 800 * velocity),
		reps = rrand(10, bright * 50),
		buffno = rrand(0, 10),
		atk = 0.1;

		Pkill(

			\instrument, \playbackHP,

			\env, 1,

			\dur, Pwrand(
				[(dur / 16), (dur / 64), (dur / 128), (dur /32), (dur / 8)],
				[16, 2, 1, 2, 1].normalizeSum,
				inf),

			\rate, 1.0,

			\buf, buffno,

			\atk, Pwhite(0.01, ~sampleSize / 2),

			\rel, Pwhite(0.01, ~sampleSize / 2),

			\pan, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([-1.0, 1.0, rrand(1.0, -1.0)], [rrand(2, 10), rrand(2, 20)], \sin).discretize(128).asArray,
					inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent, cent * 2, cent / 2], [rrand(2, 10), rrand(2, 40)], \sin).discretize(128).asArray,
					inf),

			// run 45 gain compensation. Darkening alone made cr 10 dB LOUDER, peak
			// 0.985 and close to clipping, because the filter now sits on top of the
			// material's own energy. 0.25 returns it to -31.5 dBFS, matching where
			// it was, at peak 0.384.
			// Chosen blind: preferred on "which would you keep" and "least harsh",
			// level on "loses the least of what the machine was doing".
			\amp, Pwhite(0.0, 0.25),

			\out, Pseq([
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!((bright + 1).asInteger)),
				(~reverbMidBus[rrand(0, 4) % ~numPairs]!((bright + 1).asInteger)),
				(~dryBus[rrand(0, 4) % ~numPairs]!(3))
				], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	techPlayer { // periodic sequences corresponding to input density

		|buf|

		var temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
		variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		cutoff = rrand(200 * velocity, 800 * velocity),
		reps = rrand(10, 35).asInteger,
		atk = rrand(0.01, variance + 0.1);

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, rrand(temp / 2, temp),

			\rate, Pwrand(
				[0.5, 1, 2.0, -1],
				[2, 6, 1, 6].normalizeSum,
				reps * 2),

			\atk, atk,

			\rel, ~sampleSize - atk,

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(
				rrand(-1, 1),
				(rrand(-1, 1) + 0.2)
					.linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),
				inf),

			\amp, // run 44 REPAIR. Was Env(...), which in an event slot resolves to a
				// CONSTANT equal to its first level (claim 202). This envelope starts
				// at 0, so amp was 0.0 on every event and the machine was silent.
				//
				// Pseg does NOT fix it: measured identical output, and it hung ma and
				// te. Pkill is not a Pbind and cannot give a time-based pattern the
				// delta it needs. discretize samples the SAME envelope into 128 steps
				// that Pseq advances once per event, which is all Pkill provides.
				// Trade-off: the envelope now cycles per 128 EVENTS, not per
				// {durs} SECONDS. The shape is preserved; the time base is not.
				Pseq(
					Env([0, 0.1, 0], [(reps / 2).asInteger, (reps / 2).asInteger], \sin).discretize(44).asArray,
					inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cutoff, cutoff * 6, cutoff / 2], [(reps / 2).asInteger, (reps / 2).asInteger], \sin).discretize(44).asArray,
					inf),

			\out, Pseq([
				(~dryBus[0 % ~numPairs]!3),
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!(noise.asInteger))
			], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	rytmPlayer { // periodic sequences corresponding to input density

		|buf|

		var temp = args.at(\density).linlin(0.0, 10.0, 0.1, 3.0, clip: \minmax),
		variance = args.at(\windowsize).linlin(0.0, 3.0, 0.01, 0.1, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 0.1, 0.01, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		cutoff = rrand(200 * velocity, 800 * velocity),
		reps = rrand(10, 35).asInteger,
		atk = rrand(0.01, variance);

		Pkill(

			\instrument, \playback,

			\env, 1,

			// BUG FIX (run 39). The original was
			//     Pseq([ temp, (rrand(0.01, 0.03)!velocity * 2) ])
			// with two faults. Pseq defaults to repeats = 1, so the duration
			// stream was exhausted after two values and Pkill's kill fired
			// almost immediately. And `!velocity` builds an ARRAY, because
			// velocity is a float in 1.0-4.0, so the second duration was a
			// collection where a number is required.
			//
			// `.sum` collapses the array to the total of the short values,
			// which preserves the intent (a long value follows a short one)
			// without inventing a number. `inf` matches every other machine.
			\dur, Pseq([
				temp,
				(rrand(0.01, 0.03) ! velocity.asInteger * 2).sum
			], inf),

			\rate, Pwrand(
				[1.0, 1.3, -1.0, -0.9, -0.8, 2.0],
				[6, 1, 6, 4, 2, 1].normalizeSum,
				reps * 2),

			\atk, rrand(atk, atk + 0.1),

			\rel, ~sampleSize - 0.2,

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(
				rrand(-1, 1),
				(rrand(-1, 1) + 0.2)
					.linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),
				inf),

			\amp, 0.08,

			\cutoff, cent,

			\out, Pseq([
				(~dryBus[0 % ~numPairs]!3),
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!(noise.asInteger))
			], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	angelPlayer { // high-pitched, warbling, long envelope

		|buf|

		var temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
		variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 200, 10000, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		cutoff = rrand(100 * velocity, 400 * velocity),
		rate = (rrand(1, 2) * 2),
		reps = rrand(16, 80).asInteger,
		atk = (0.5 * (~sampleSize / rate));

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pwhite(0.001, 0.1, inf),

			\rate, Pwrand(
				[rate, (-1 * rate)],
				[2, 2].normalizeSum,
				reps),

			\atk, atk,

			\rel, (~sampleSize - (atk + 0.1)),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(
				rrand(-1, 1),
				(rrand(-1, 1) + 0.2)
					.linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),
				reps),

			\amp, // run 44 REPAIR. Was Env(...), which in an event slot resolves to a
				// CONSTANT equal to its first level (claim 202). This envelope starts
				// at 0, so amp was 0.0 on every event and the machine was silent.
				//
				// Pseg does NOT fix it: measured identical output, and it hung ma and
				// te. Pkill is not a Pbind and cannot give a time-based pattern the
				// delta it needs. discretize samples the SAME envelope into 128 steps
				// that Pseq advances once per event, which is all Pkill provides.
				// Trade-off: the envelope now cycles per 128 EVENTS, not per
				// {durs} SECONDS. The shape is preserved; the time base is not.
				Pseq(
					Env([0, 0.1, 0], [rrand(4, 10), rrand(6, 14)], \sin).discretize(77).asArray,
					inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cutoff, cutoff * 4, cutoff / 2], [rrand(8, 12), rrand(8, 10)], \sin).discretize(77).asArray,
					inf),

			\out, Pseq([
				(~reverbLongBus[rrand(0, 4) % ~numPairs]),
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!4)
			], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(40);
			}

		).play
	}

	hissPlayer { // high-pitched, warbling, long envelope

		|buf|

		var temp = args.at(\density).linlin(0.0, 5.0, 0.1, 3.0, clip: \minmax),
		variance = args.at(\windowsize).linlin(0.0, 3.0, 0.0, 0.3, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 16000, 200, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 200, 10000, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 4.0, clip: \minmax),
		noise = args.at(\avgflat).linlin(0.0, 0.1, 1, 3, clip:\minmax),
		rate = (velocity.asInteger * 2),
		reps = rrand(temp * 30, temp * 80).asInteger,
		atk = (0.5 * (~sampleSize / rate));

		Pkill(

			\instrument, \playbackHP,

			\env, 1,

			\dur, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([velocity / 10, velocity, velocity / 10], [rrand(noise, noise * 3), rrand(noise * 2, noise * 4)], \sin).discretize(8).asArray,
				// N MEASURED, not derived. The entries-based estimate in run 47
				// gives this machine 38 and -60.4 dBFS; 8 gives -51.9 (claim 234).
					inf),

			\rate, Pwrand(
				[
					Pwhite(rate - 0.3, rate),
					Pwhite(
						(-1 * (rate - 0.3)),
						(-1 * rate))
				],
				[2, 2].normalizeSum,
				reps),

			\atk, atk,

			\rel, (~sampleSize - (atk + 0.05)),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(
				rrand(-1, 1),
				(rrand(-1, 1) + 0.2)
					.linlin(-1.0, 1.0, -1.0, 1.0, clip: \minmax),
				reps),

			\amp, // run 44 REPAIR. Was Env(...), which in an event slot resolves to a
				// CONSTANT equal to its first level (claim 202). This envelope starts
				// at 0, so amp was 0.0 on every event and the machine was silent.
				//
				// Pseg does NOT fix it: measured identical output, and it hung ma and
				// te. Pkill is not a Pbind and cannot give a time-based pattern the
				// delta it needs. discretize samples the SAME envelope into 128 steps
				// that Pseq advances once per event, which is all Pkill provides.
				// Trade-off: the envelope now cycles per 128 EVENTS, not per
				// {durs} SECONDS. The shape is preserved; the time base is not.
				Pseq(
					Env([0, 0.1, 0], [rrand(4, 10), rrand(6, 14)], \sin).discretize(8).asArray,
				// N MEASURED, not derived. The entries-based estimate in run 47
				// gives this machine 38 and -60.4 dBFS; 8 gives -51.9 (claim 234).
					inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([bright, bright * 2, bright], [rrand(8, 12), rrand(8, 10)], \sin).discretize(8).asArray,
				// N MEASURED, not derived. The entries-based estimate in run 47
				// gives this machine 38 and -60.4 dBFS; 8 gives -51.9 (claim 234).
					inf),

			\out, Pseq([
				(~reverbLongBus[rrand(0, 4) % ~numPairs]),
				(~reverbShortBus[rrand(0, 4) % ~numPairs]!4)
			], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(40);
			}

		).play
	}

	stretchPlayer { // slowed down audio corresponding to spectral rolloff

		|buf|

		var rates = [0.125, 0.25, 0.5],
		bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
		rate = rates[bright.asInteger],
		freq = args.at(\mainpitch)
			.asString
			.pitchcps
			.linlin(0, 10000, 1, 10, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 0.0, 0.7, clip: \minmax),
		choose = rrand(0, 4),
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\atk, atk,

			\rel, (~sampleSize * 2) - atk,

			\dur, Pwhite(0.01, 3.0),

			\rate, rate,

			\rel, 0.5 * (1 / rate),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([freq * 2000, freq * 1000, freq * 500], [rrand(0.1, 0.5), rrand(1, 9)], \sin).discretize(18).asArray,
					inf),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(-0.2, 0.2),

			\amp, Pwhite(0.01, 0.1),

			\out, Pseq([
				(~dryBus[rrand(0, 4) % ~numPairs]!2),
				(~reverbShortBus[4 % ~numPairs]!1),
				(~reverbMidBus[3 % ~numPairs]!(freq.asInteger)),
			], rrand(2, 5)),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(90);
			}

		).play;

		if (choose >= 2, {

			Pkill(

				\instrument, \playbackHP,

				\env, 1,

				\dur, Pwhite(0.01, 2.0),

				\atk, 0.2 * (1 / (rate * 2)),

				\rate, rate * 2,

				\rel, 0.5 * (1 / (rate * 2)),

				\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([rrand(2500, 6000), rrand(6000, 16000), rrand(2500, 6000)], [rrand(0.1, 0.5), rrand(1, 9)], \sin).discretize(18).asArray,
					inf),

				\buf, Pshuf(buf, inf),

				\pan, Pwhite(-1, 1),

				\amp, Pwhite(0.01, 0.2),

				\out, Pseq([
					(~dryBus[rrand(0, 4) % ~numPairs]!2),
					(~dryBus[4 % ~numPairs]!1),
					(~reverbMidBus[rrand(0, 4) % ~numPairs]!2),
				], rrand(1, 4)),

				{ // empty
				}

			).play;
		})
	}

	halftimePlayer { // stretched audio highly reactive to pitched information

		|buf|

		var freq = args.at(\mainpitch)
			.asString
			.pitchcps
			.linlin(0, 10000, 2, 0.01, clip: \mixmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
		reps = rrand(6, 35).asInteger,
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pwhite(0.01, 0.1),

			\atk, atk,

			\rel, (~sampleSize * 2) - atk,

			\rate, Pseq([
				(0.5!3),
				(-0.5!(bright.asInteger))
			], inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([bright * 1000, bright * 2000, bright * 500], [rrand(0.1, 3), rrand(4, 19)], \sin).discretize(68).asArray,
					inf),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(-1 * (freq / 2), freq / 2),

			\amp, Pwhite(0.01, 0.08),

			\out, Pseq([
				(~dryBus[3 % ~numPairs]!(resonant.asInteger)),
				(~reverbShortBus[2 % ~numPairs]!(resonant.asInteger)),
				(~reverbMidBus[rrand(0, 4) % ~numPairs]!2),
			], reps),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	glissPlayer { // rate envelope

		|buf|

		var freq = args.at(\mainpitch)
			.asString
			.pitchcps
			.linlin(0, 10000, 2, 0.01, clip: \mixmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 2, 7, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
		reps = rrand(resonant * 2, resonant * 10).asInteger,
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pwhite(0.01, 0.1),

			\atk, atk,

			\rel, (~sampleSize * 2) - atk,

			\rate, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([0.80, rrand(1.0, 1.1), rrand(0.8, 1.1)], [rrand(0.1, resonant), rrand(resonant, resonant * 3)], \sin).discretize(71).asArray,
					inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([bright * 1000, bright * 2000, bright * 500], [rrand(0.1, 3), rrand(4, 19)], \sin).discretize(71).asArray,
					inf),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(-1 * (freq / 2), freq / 2),

			\amp, Pwhite(0.01, 0.08),

			\out, Pseq([
				(~reverbShortBus[2 % ~numPairs]!(resonant.asInteger)),
				(~reverbMidBus[rrand(0, 4) % ~numPairs]!2),
			], reps),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	clusterPlayer { // pitch stacks

		|buf|

		var freq = args.at(\mainpitch)
			.asString
			.pitchcps
			.linlin(0, 10000, 2, 0.01, clip: \mixmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
		reps = rrand(6, 35).asInteger,
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pwhite(0.01, 0.1),

			\atk, atk,

			\rel, (~sampleSize * 2) - atk,

			\rate, Pseq([
				(0.6),
				(0.5),
				(-0.53),
				(0.52),
				(-0.51),
				(-0.5)
			], inf),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([bright * 1000, bright * 2000, bright * 500], [rrand(0.1, 10), rrand(4, 19)], \sin).discretize(69).asArray,
					inf),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(-1 * (freq / 2), freq / 2),

			\amp, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([0.01, 0.08, 0.03], [rrand(0.1, 10), rrand(4, 19)], \sin).discretize(69).asArray,
					inf),

			\out, Pseq([
				(~dryBus[bright.asInteger % ~numPairs]!(resonant.asInteger)),
				(~reverbShortBus[2 % ~numPairs]!(resonant.asInteger)),
				(~reverbMidBus[rrand(0, 4) % ~numPairs]!2),
			], reps),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	wallPlayer { // noise stacks

		|buf|

		var freq = args.at(\mainpitch)
			.asString
			.pitchcps
			.linlin(0, 10000, 2, 0.01, clip: \mixmax),
		resonant = args.at(\percpitch).linlin(0.0, 1.0, 7, 2, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 1, 5, clip: \minmax),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 3.0, clip: \minmax),
		reps = rrand(6, 35).asInteger,
		atk = 0.1;

		Pkill(

			\instrument, \playback,

			\env, 1,

			\dur, Pwhite(0.01, 0.1),

			\atk, atk,

			\rel, (~sampleSize / 2) - atk,

			\rate, Pwhite(0.5, 1.5),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([bright * 1000, bright * 2000, bright * 500], [rrand(0.1, 10), rrand(4, 19)], \sin).discretize(69).asArray,
					inf),

			\buf, Pshuf(buf, inf),

			\pan, Pwhite(-1 * (freq / 2), freq / 2),

			\amp, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([0.06, 0.08, 0.01], [rrand(0.01, 20), rrand(0.01, 20)], \sin).discretize(69).asArray,
					inf),

			\out, Pseq([
				(~reverbShortBus[2 % ~numPairs]!(resonant.asInteger)),
				(~reverbLongBus[rrand(0, 4) % ~numPairs]!2),
			], reps),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	granPlayer { // granular synthesis engine corresponding to input frequency


		|buf|

		var freq = args.at(\mainpitch).asString.pitchcps,
		choose = rrand(0, 4),
		dense = args.at(\density).linlin(0.0, 5.0, 5, 1, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
		reps = rrand(1, 5),
		rates = [0.125, 0.25, 0.5, 1.0],
		bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
		rate = rates[bright.asInteger],
		atk = 0.1;

		if ((freq < 30) || (choose < 2), {
			freq = rrand(2, 45)
		});

		Pkill(

			\instrument, \playgran,

			\dur, Pwhite(1, dense, inf),

			\env, 1,

			\buf, Pshuf(buf, inf),

			\atk, Pwhite(atk, atk * 13),

			\rel, (~sampleSize * 2) - atk,

			\freq, freq,

			\rate, Pseq([
				(0.5!(1)),
				(1.0!(1)),
				(-2.0!(1))
			], reps),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent, cent * 5, cent / 2], [(reps / 2).asInteger, (reps / 2).asInteger], \sin).discretize(17).asArray,
					inf),

			\pan, Pwhite(-1, 1),

			\amp, Pwhite(0.01, 0.08),

			\out, Pseq([
				(~reverbShortBus[rrand(0, 4) % ~numPairs]),
				(~reverbMidBus[rrand(0, 4) % ~numPairs]),
				(~reverbLongBus[rrand(0, 4) % ~numPairs]),
			], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(60);
			}

		).play;

		if (choose >= 3, {

			Pkill(

				\instrument, \playbackHP,

				\env, 1,

				\dur, Pwhite(0.01, 4.0),

				\atk, 0.2 * (1 / rate),

				\rate, rate,

				\rel, 0.5 * (1 / rate),

				\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent / 2, rrand(4000, 16000), cent / 2], [rrand(1, 3), rrand(1, 9)], \sin).discretize(17).asArray,
					inf),

				\buf, Pshuf(buf, inf),

				\pan, (dense / 5) * rrand(-1, 1),

				\amp, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([0.01, rrand(0.4, 1.0),  0.01], [rrand(1, 3), rrand(1, 9)], \sin).discretize(17).asArray,
					inf),

				\out, Pseq([
					(~dryBus[rrand(0, 4) % ~numPairs]!2),
					(~dryBus[4 % ~numPairs]!1),
					(~reverbLongBus[rrand(0, 4) % ~numPairs])
				], rrand(3, 5)),

				{ // empty
				}

			).play;
		});
	}


	bubblePlayer { // granular synthesis engine corresponding to input frequency


		|buf|

		var dense = args.at(\density).linlin(0.0, 10.0, 20, 1, clip: \minmax),
		cent = args.at(\avgcent).linlin(0, 10000, 200, 16000, clip: \minmax),
		reps = rrand(1, 5),
		velocity = args.at(\avgrms).linlin(0.0, 1.0, 1.0, 1.6, clip: \minmax),
		rates = [1.0, velocity],
		bright = args.at(\avgrolloff).linlin(500, 12000, 0, 2, clip: \minmax),
		freq = rrand(1, dense),
		altfreq = rrand(1, dense),
		atk = 0.1;

		Pkill(

			\instrument, \playgran,

			\freq, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([freq, altfreq, freq], [rrand(3, 20), rrand(3, 20)], \sin).discretize(16).asArray,
					inf),

			\dur, Pwhite(1, dense, inf),

			\env, 1,

			\buf, Pshuf(buf, inf),

			\atk, Pwhite(atk, atk * 13),

			\rel, (~sampleSize * 2) - atk,

			\freq, freq,

			\rate, Pseq([
				(rates[0]!reps),
				(rates[1]!reps),
			], rrand(3, 20)),

			\cutoff, // run 44: was Env(...), frozen at its first level in an event slot
				// (claim 202). Pseg does not fix it and hangs ma and te. discretize
				// samples the SAME envelope into 128 steps advanced once per event.
				// The shape is preserved; the envelope now cycles per 128 EVENTS
				// rather than over its written duration in seconds.
				Pseq(
					Env([cent, cent * 5, cent / 2], [rrand(3, 20), rrand(3, 20)], \sin).discretize(16).asArray,
					inf),

			\pan, Pwhite(-1, 1),

			\amp, Pwhite(0.01, 0.08),

			\out, Pseq([
				(~reverbShortBus[rrand(0, 4) % ~numPairs]),
			], inf),

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(60);
			}

		).play
	}

	/* ---------------------------------------------------------------------
	   GENERATED MACHINES (run 39)

	   Run 35 measured the vocabulary: sixteen machines, five pattern classes,
	   three of those in all sixteen. Ppar, Ptpar, Pfsm, Pseries, Pgeom,
	   Pstutter and Pclutch appeared zero times, and those seven name exactly
	   the four musical categories the system could not express.

	   Each machine below is built around a constructor that was absent, so
	   the categories are reachable by construction and not by reweighting
	   what already exists.

	     dr  low drone            Ppar + Pgeom      three sustained layers
	     pu  rhythmic             Pfsm              cells chained by a grammar
	     hm  tonal progression    Ppar + Pseries    triads through a cadence
	     me  melodic sequencing   Pstutter/Pclutch  a motif stated and varied

	   Pitch here is playback rate: a semitone is 2 ** (1/12). The corpus
	   grains are around 500 ms, so sustain is obtained by lowering the rate,
	   which stretches the grain, and not by lengthening the envelope.
	   --------------------------------------------------------------------- */

	dronePlayer { // three sustained low layers at fixed intervals

		|buf|

		var dur = args.at(\windowsize).linlin(0, 5, 3.0, 9.0, clip: \minmax),
		dark = args.at(\avgcent).linlin(0, 10000, 90, 700, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.4, 1.0, clip: \minmax),
		// GAIN (run 40). The census measured dr at -54.7 dBFS against cr -28.5 and
		// ht -41.5, so the machine was audible only in principle. Raised x3, which
		// is conservative because Ppar sounds three layers at once.
		body = args.at(\avgrms).linlin(0.0, 1.0, 0.12, 0.39, clip: \minmax),
		atk = 1.2,
		voice;

		// One layer. ratio offsets the whole layer in pitch; last carries the
		// buffer-freeing function, which must run exactly once across the Ppar.
		voice = {
			|ratio, bus, last|
			Pkill(
				\instrument, \playback,
				\env, 1,
				\dur, Pwhite(dur * 0.4, dur),
				\atk, atk,
				\rel, dur,
				// slow descending drift, bounded by construction, then reset
				\rate, Pseq([ Pgeom(0.25 * ratio, 0.972, 24) ], inf),
				\buf, Pshuf(buf, inf),
				\cutoff, Pseq([ Pseries(dark, dark / 24, 12),
					Pseries(dark * 1.5, dark / -24, 12) ], inf),
				\pan, Pwhite(-1 * width, width),
				\amp, Pwhite(body * 0.6, body),
				\out, bus,
				last
			)
		};

		Ppar([
			voice.value(1.0, ~dryBus[0 % ~numPairs], {}),
			voice.value(2.0, ~reverbLongBus[0 % ~numPairs], {}),
			voice.value(1.5, ~reverbMidBus[0 % ~numPairs],
				{ { buf.do { |b| b.free } }.defer(20) })
		], 1).play
	}

	pulsePlayer { // rhythmic cells chained by a finite state machine

		|buf|

		var grid = args.at(\density).linlin(0, 5, 0.45, 0.08, clip: \minmax),
		bright = args.at(\avgcent).linlin(0, 10000, 400, 6000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.2, 0.9, clip: \minmax),
		// GAIN (run 40): pu measured -59.5 dBFS. Single voice, so x5.
		body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.70, clip: \minmax),
		atk = 0.005;

		Pkill(
			\instrument, \playback,
			\env, 1,

			// Four rhythmic cells and the transitions permitted between them.
			// A grammar, so the pulse is stateful and does not merely shuffle.
			\dur, Pfsm([
				#[0, 1],
				Pseq([grid, grid, grid, grid], 1),                #[1, 2],
				Pseq([grid * 2, grid, grid], 1),                  #[0, 3],
				Pseq([grid / 2, grid / 2, grid, grid * 2], 1),    #[1, 3],
				Pseq([grid * 4], 1),                              #[0, 1, 2]
			], inf),

			\atk, atk,
			\rel, 0.35,
			\rate, Pwrand([1.0, 2.0, 0.5], [0.7, 0.2, 0.1], inf),
			\buf, Pshuf(buf, inf),
			\cutoff, bright,
			\pan, Pwhite(-1 * width, width),
			\amp, Pseq([body, body * 0.5, body * 0.7, body * 0.5], inf),
			\out, ~dryBus[0 % ~numPairs],

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	harmonyPlayer { // triads moving through a cadence, three parallel voices

		|buf|

		var dur = args.at(\windowsize).linlin(0, 5, 1.1, 3.5, clip: \minmax),
		bright = args.at(\avgrolloff).linlin(0, 12000, 500, 4000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
		// GAIN (run 40): hm measured -53.6 dBFS. Ppar x3 layers, so x3.
		body = args.at(\avgrms).linlin(0.0, 1.0, 0.12, 0.36, clip: \minmax),
		prog = [0, 9, 5, 7],   // I vi IV V, in semitones from the root
		voice;

		voice = {
			|degree, bus, last|
			Pkill(
				\instrument, \playback,
				\env, 1,
				\dur, dur,
				\atk, 0.05,
				\rel, dur * 0.9,
				// the chord tone, transposed through the progression
				\rate, Pseq(
					prog.collect({ |root| 2 ** ((root + degree - 12) / 12) }),
					inf),
				\buf, Pshuf(buf, inf),
				\cutoff, Pseq([ Pseries(bright, bright / 16, 8),
					Pseries(bright * 1.5, bright / -16, 8) ], inf),
				\pan, Pwhite(-1 * width, width),
				\amp, body,
				\out, bus,
				last
			)
		};

		Ppar([
			voice.value(0, ~dryBus[0 % ~numPairs], {}),          // root
			voice.value(4, ~reverbMidBus[0 % ~numPairs], {}),    // third
			voice.value(7, ~reverbLongBus[0 % ~numPairs],        // fifth
				{ { buf.do { |b| b.free } }.defer(20) })
		], 1).play
	}

	melodyPlayer { // a motif stated, repeated and varied

		|buf|

		var dur = args.at(\windowsize).linlin(0, 5, 0.18, 0.6, clip: \minmax),
		bright = args.at(\avgcent).linlin(0, 10000, 600, 5000, clip: \minmax),
		width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 0.9, clip: \minmax),
		// GAIN (run 40): me measured -56.7 dBFS. Single voice, so x5.
		body = args.at(\avgrms).linlin(0.0, 1.0, 0.25, 0.75, clip: \minmax),
		motif = [0, 2, 4, 2, 7, 5, 4, 0],   // scale degrees, semitones
		atk = 0.01;

		Pkill(
			\instrument, \playback,
			\env, 1,
			\dur, Pseq([dur, dur, dur * 2, dur], inf),
			\atk, atk,
			\rel, dur * 2,

			// Pstutter repeats each note 1-3 times, so the contour is stated
			// and then insisted on. This is the sequencing the system lacked.
			\rate, Pstutter(
				Pwrand([1, 2, 3], [0.6, 0.3, 0.1], inf),
				Pseq(motif.collect({ |d| 2 ** (d / 12) }), inf)),

			\buf, Pshuf(buf, inf),

			// Pclutch holds the filter across the repeats, so a stuttered note
			// keeps its colour instead of flickering.
			\cutoff, Pclutch(
				Pseq([ Pseries(bright, bright / 12, 6),
					Pseries(bright * 1.5, bright / -12, 6) ], inf),
				Pseq([true, false, false, true], inf)),

			\pan, Pwhite(-1 * width, width),
			\amp, Pseq([body, body * 0.6, body * 0.8, body * 0.6], inf),
			\out, ~dryBus[0 % ~numPairs],

			{
				{
					buf.do {
						|b|
						b.free;
					}
				}.defer(20);
			}

		).play
	}

	stateMachine { // function that relays handler buffer into playback machines

		|buf|

		//args.postln;

		//state = \hp;

		("OK: Playing State: " + state + ".").postln;

		switch(state,

			\sc, {
				this.sciarrinoPlayer(buf)
			},

			\lu, {
				this.lushPlayer(buf)
			},

			\so, {
				this.sonorousPlayer(buf)
			},

			\ma, {
				this.machinePlayer(buf)
			},

			\cr, {
				this.crankPlayer(buf)
			},

			\te, {
				this.techPlayer(buf)
			},

			\ry, {
				this.rytmPlayer(buf)
			},

			\an, {
				this.angelPlayer(buf)
			},

			\hp, {
				this.hissPlayer(buf)
			},

			\st, {
				this.stretchPlayer(buf)
			},

			\ht, {
				this.halftimePlayer(buf)
			},

			\gl, {
				this.glissPlayer(buf)
			},

			\cp, {
				this.clusterPlayer(buf)
			},

			\wa, {
				this.wallPlayer(buf)
			},

			\gp, {
				this.granPlayer(buf)
			},

			\bu, {
				this.bubblePlayer(buf)
			},

			// generated machines, run 39
			\dr, {
				this.dronePlayer(buf)
			},

			\pu, {
				this.pulsePlayer(buf)
			},

			\hm, {
				this.harmonyPlayer(buf)
			},

			\me, {
				this.melodyPlayer(buf)
			},

		);
	}

	msg_handler { // osc client

		|msg, server|

		var buf = List.new();

		//msg.postln;

		msg.size.do {

			|i|

			var b;


			if (i < (msg.size - 1), {
				b = Buffer.readChannel(server, msg[i], 0, -1, [0], action: {
					buf.add(b);
					})
				},
				{
				b = Buffer.readChannel(server, msg[i], 0, -1, [0], action: {
					buf.add(b);

					{
						this.stateMachine(buf)
					}.defer(1);
				});
			})
		};
	}

}
