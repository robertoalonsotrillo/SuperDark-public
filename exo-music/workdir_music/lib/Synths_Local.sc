HDVerb {

	* ar {

		|in,
		decay = 3.5,
		mix = 0.08,
		lpf1 = 2000,
		lpf2 = 6000,
		predelay = 0.025,
		mul = 1,
		add = 0|

		var dry, wet, sig;

		dry = in;
		wet = in;
		wet = DelayN.ar(
			wet,
			0.5,
			predelay.clip(0.0001, 0.5));

		wet = 16.collect{
			var temp;
			temp = CombL.ar(
				wet,
				0.1,
				LFNoise1.kr(
					{
						ExpRand(0.02, 0.04)
				}!2).exprange(0.02, 0.099),
				decay
			);
			temp = LPF.ar(temp, lpf1);
		}.sum * 0.25;

		8.do {
			wet = AllpassL.ar(
				wet,
				0.1,
				LFNoise1.kr(
					{
						ExpRand(0.02,0.04)
				}!2).exprange(0.02, 0.099),
				decay
			);
		};

		wet = LeakDC.ar(wet);
		wet = LPF.ar(wet, lpf2, 0.5);

		sig = dry.blend(wet, mix);
		^sig * mul + add;

	}

}

FreezeVerb {

	* ar {
		|in,
		predelay = 1,
		decay = 10,
		lpf = 4500,
		mix = 0.5,
		amp = 1,
		mul = 1,
		add = 0|
		var dry, wet, temp, sig;

		dry = in;
		temp = in;
		wet = 0;
		temp = DelayN.ar(
			temp,
			0.2,
			predelay.clip(0.0001, 0.2));

		// THREE FAULTS, ALL FOUND 16 SEPT WHILE HUNTING SOMETHING ELSE.
		// Dormant the whole time: live_factory.scd:2456 sets every reverb bus to
		// [0], so nothing has ever instantiated this. It was a landmine waiting
		// for the day reverb got wired up, and that day would have looked like a
		// new bug rather than an old one.
		//
		// 1. `temp - LPF.ar(temp, lpf);` COMPUTED AND DISCARDED ITS RESULT.
		//    The lpf parameter was accepted, documented in the signature, and
		//    did nothing, so there was no damping anywhere in the chain. Almost
		//    certainly meant as a highpass: subtracting a lowpass from the
		//    signal leaves the band above it. Written as an assignment now.
		//
		// 2. `wet = wet + temp` SUMMED 16 UNITY-MAGNITUDE STAGES UNNORMALISED.
		//    AllpassN has unity magnitude response, so sixteen correlated copies
		//    add to as much as 16x. HDVerb, thirty lines above, does `.sum *
		//    0.25` over its own sixteen. The 1/16 here is the same correction.
		//
		// 3. NO LeakDC. HDVerb has one at line 49. Sixteen feedback stages at
		//    decay = 10 with no DC removal accumulate offset indefinitely, which
		//    is the slow road to exactly the kind of numerical excursion that
		//    cost 16 Sept to find at the master bus.
		//
		// predelay is clipped for the same reason HDVerb clips its own: the
		// DelayN above has a 0.2 s maximum and the declared default is 1.
		16.do {
			temp = AllpassN.ar(
				temp,
				0.05,
				{Rand(0.001, 0.05)}!2,
				decay);
			temp = temp - LPF.ar(temp, lpf);
			wet = wet + temp;
		};
		wet = LeakDC.ar(wet * (1 / 16));

		sig = XFade2.ar(
			dry,
			wet,
			mix * 2 - 1,
			amp);

		^ sig * mul + add;

	}

}
