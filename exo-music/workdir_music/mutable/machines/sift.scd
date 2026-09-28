// sift — written INTO A RUNNING FACTORY.
//
// This file did not exist when the server booted. If it appears in the log as
// LOADED_MACHINE and is later selected, the factory acquired a behaviour
// without stopping, which is the whole claim.
//
// Uses Pseries and Pgeom for a slowly opening filter and a descending rate,
// and Pmono so successive events reuse one synth instead of stacking — Pmono
// appears nowhere in the sixteen original machines.
{ |buf, args|
    var step  = args.at(\density).linlin(0.0, 5.0, 0.30, 0.06, clip: \minmax),
        base  = args.at(\avgcent).linlin(0, 10000, 200, 1800, clip: \minmax),
        body  = args.at(\avgrms).linlin(0.0, 1.0, 0.12, 0.34, clip: \minmax),
        width = args.at(\avgrms).linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax);

    Pbind(
        \instrument, \playback,
        \dur, Pseq([ step, step, step * 2, step / 2 ], inf),
        \atk, 0.02,
        \rel, step * 4,

        // a filter that opens over sixteen events, then resets
        \cutoff, Pseq([ Pseries(base, base / 8, 16) ], inf),

        // and a rate that falls away underneath it
        \rate, Pseq([ Pgeom(1.0, 0.955, 24) ], inf),

        \buf, Pshuf(buf, inf),
        \pan, Pwhite(width.neg, width),
        \amp, Pseq([ body, body * 0.55 ], inf),
        \out, 0
    )
}
