+ SimpleNumber {

	midipitch {
		var midi = this, pitch, oct,

		ref = [
			"A",
			"A#",
			"B",
			"C",
			"C#",
			"D",
			"D#",
			"E",
			"F",
			"F#",
			"G",
			"G#",
		];

		if (midi < 21, {
			pitch = "unpitched";
		},
		{
			pitch = ref[(midi - 21) % 12];
			oct = (((midi - 21) / 12).asInteger).asString;
			pitch = pitch ++ oct;
		});

		^pitch;

	}

	sec2Hz {
		var sec = this,
		hz = 1 / sec;

		^ hz;
	}

	hz2Sec {
		var hz = this,
		sec = 1 / hz;

		^ sec;
	}

}

+ String {

	pitchcps {

		var pitch = this, midi, freq = 0, oct,

		ref = [
			"A",
			"A#",
			"B",
			"C",
			"C#",
			"D",
			"D#",
			"E",
			"F",
			"F#",
			"G",
			"G#",
		];

		if (pitch == "unpitched",
			{
				freq = 0;
			},
			{
				// Octave is the TRAILING DIGITS, not the last character. Taking
				// only the last character made "D10" parse as "D1", which matches
				// no entry in ref, leaving freq unassigned and pitchcps returning
				// nil. Every caller then sent linlin to nil and died inside a bare
				// .try, which is how five machines failed silently since run 04.
				oct = "";
				while ({ (pitch.size > 1) and: { pitch[pitch.size - 1].isDecDigit } }, {
					oct = pitch[pitch.size - 1].asString ++ oct;
					pitch = pitch[0..(pitch.size - 2)];
				});
				if (oct == "", { oct = "4" });
				ref.size.do {
					|i|
					if (pitch == ref[i],
						{
							midi = (i + 21) + (12 * oct.asInteger);
							freq = midi.midicps;
					});
				};
		});

		^ freq;

	}

}

+ Array {

	archonJSON{

		var id = this[0],
		cent = this[1],
		flat = this[2],
		rolloff = this[3],
		rms = this[4],
		pitch = this[5],
		variance = this[6],

		str = ("{" ++
			'"' ++ id.asString ++ '"' ++
			':{' ++
			'"cent":' ++
			'"' ++ cent.asString ++ '"' ++
			',' ++
			'"flat":' ++
			'"' ++ flat.asString ++ '"' ++
			',' ++
			'"rolloff":' ++
			'"' ++ rolloff.asString ++ '"' ++
			',' ++
			'"rms":' ++
			'"' ++ rms.asString ++ '"' ++
			',' ++
			'"pitch":' ++
			'"' ++ pitch.asString ++ '"' ++
			',' ++
			'"variance":' ++
			'"' ++ variance.asString ++ '"' ++
			'}}').asString;

		^ str;
	}

}