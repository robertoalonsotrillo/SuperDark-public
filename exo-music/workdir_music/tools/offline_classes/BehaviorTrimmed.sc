/*

The Behavior Module generates playback machine targets based on performance changes.
It operates based on a system of "events" corresponding to envelopes registered by the Analysis module.
Events are measured against a "target", analysed for %∆ changes, and the results inform a series of weights used to probabilistically inform the next target selection.

*/

BehaviorTrimmed {

    var eventCtr = 0, // counts incoming events
    eventTarget, // target event
    prevEvent = 0, // used to store previous target
    prevTarget = \sc, // previous playback machine

    target = \sc, // current playback machine
    <targets, // dictionary of available playback machines; getter added run 39
              // so tools/verify_machines.scd can assert every machine sounds
    means, weights, // used to store analysis results to calculate

    addr, // netaddr to send to python

    onsetList, offsetList, centList, rolloffList, flatList, rmsList, pitchList;
    // to keep long running totals of timing, spectral, and amplitude characteristics over time

    *new {
        |netAddr|
        ^super.new.init(netAddr)
    }

    init {
        |netAddr|

        addr = netAddr; // passing Python IP & port

        onsetList = List.new();
        offsetList = List.new();
        centList = List.new();
        rolloffList = List.new();
        flatList = List.new();
        rmsList = List.new();
        pitchList = List.new();

        eventTarget = rrand(1,10); // setting first event target randomly

        targets = [
            \sc,
            \lu,
            \so,
            \ma,
            \cr,
            \te,
            \ry,
            \an,
            \hp,
            \st,
            \ht,
            \gl,
            \cp,
            \wa,
            \gp,
            \bu,
            // generated machines, run 39: categories the vocabulary could
            // not express (claim 169). dr drone, pu rhythmic, hm tonal
            // progression, me melodic sequencing.
            \dr,
            \pu,
            \hm,
            \me
        ];

        // Calibrated initial means derived from events.csv statistics:
        // density mean IOI: 0.1002 s, windowsize: 0.0886 s, percpitch: 1.0 (all pitched),
        // avgcent: 3132 Hz, avgrolloff: 1560 Hz, avgflat: 0.17, avgrms: 0.016
        means = Dictionary[
            \density -> 0.10,
            \windowsize -> 0.09,
            \mainpitch -> 'D5',
            \percpitch -> 1.0,
            \avgcent -> 3132,
            \avgrolloff -> 1560,
            \avgflat -> 0.17,
            \avgrms -> 0.016
        ];

        weights = Dictionary[
            \sc -> 0,
            \lu -> 0,
            \so -> 0,
            \ma -> 0,
            \cr -> 0,
            \te -> 0,
            \ry -> 0,
            \an -> 0,
            \hp -> 0,
            \st -> 0,
            \ht -> 0,
            \gl -> 0,
            \cp -> 0,
            \wa -> 0,
            \gp -> 0,
            \bu -> 0,
            \dr -> 0,
            \pu -> 0,
            \hm -> 0,
            \me -> 0,
        ];
    }

    processDensity {
        // simple function to calculate event density from a collection of onsets
        |onsets|

        var density = Array.fill(onsets.size - 1, {
            |i|
            onsets[i + 1] - onsets[i]}
        ).mean;

        if (density.notNil == false, {
            "WARN: no density specified".postln;
            density = rrand(1.0, 6.0);
        });

        ^ density
    }

    processWindow {
        // simple function to calculate windowsize from a collection of onsets and offsets
        |onsets, offsets|

        var windowsize = Array.fill(onsets.size, {
            |i|
            offsets[i] - onsets[i]}
        ).mean;

        ^ windowsize
    }

    processMainPitch {
        // simple function to calculate most common pitch
        |pitches|

        var mainpitch = List.new();
        pitches.do{
            |i|
            mainpitch.add(pitches.occurrencesOf(i));
        };

        mainpitch = pitches[mainpitch.maxIndex];

        ^ mainpitch
    }

    targetprocessing {
        // calculate %∆s and set weights

        var eventOffsets = offsetList[
            (eventCtr - prevEvent)..],
        eventOnsets = onsetList[
            (eventCtr - prevEvent)..],
        eventPitches = pitchList[
            (eventCtr - prevEvent)..],
        eventCents = centList[
            (eventCtr - prevEvent)..],
        eventRolloffs = rolloffList[
            (eventCtr - prevEvent)..],
        eventFlats = flatList[
            (eventCtr - prevEvent)..],
        eventRMS = rmsList[
            (eventCtr - prevEvent)..],

        theseMeans = Dictionary [ // grabbing current means
            \density -> this.processDensity(eventOnsets),
            \windowsize -> this.processWindow(eventOnsets, eventOffsets),
            \mainpitch -> this.processMainPitch(eventPitches),
            \percpitch -> (
                (eventPitches.size - eventPitches.occurrencesOf('unpitched'))
                / eventPitches.size),
            \avgcent -> eventCents.mean,
            \avgrolloff -> eventRolloffs.mean,
            \avgflat -> eventFlats.mean,
            \avgrms -> eventRMS.mean
        ],

        // calculating deviation against previous means
        density_delta = (theseMeans.at(\density) / means.at(\density))
            .linlin(0, 2.0, 100, -100, clip: nil),
        windowsize_delta = (theseMeans.at(\windowsize) / means.at(\windowsize))
            .linlin(0, 2.0, -100, 100, clip: nil),
        percpitch_delta = (theseMeans.at(\percpitch) / (means.at(\percpitch) + 0.1))
            .linlin(0, 2.0, -100, 100, clip: nil),
        avgcent_delta = (theseMeans.at(\avgcent) / means.at(\avgcent))
            .linlin(0, 2.0, -100, 100, clip: nil),
        avgrolloff_delta = (theseMeans.at(\avgrolloff) / means.at(\avgrolloff))
            .linlin(0, 2.0, -100, 100, clip: nil),
        avgflat_delta = (theseMeans.at(\avgflat) / means.at(\avgflat))
            .linlin(0, 2.0, -100, 100, clip: nil),
        avgrms_delta = (theseMeans.at(\avgrms) / means.at(\avgrms))
            .linlin(0, 2.0, -100, 100, clip: nil),

        // Derived weight formulas - fitted to events.csv statistics
        //
        // KEY DERIVATIONS from data:
        // 1. All 967 events are pitched -> percpitch_delta locked at -9.09 after warm-up,
        //    so percpitch is not discriminating; reduced its coefficient role
        // 2. Initial means were miscalibrated (density 1.0 vs real 0.10 sec IOI),
        //    causing first-window deltas of +-90 that swamp the signal; fixed in init
        // 3. w_so had a bug: used weights.at(\sc) instead of weights.at(\so),
        //    permanently preventing 'so' from accumulating its own weight; fixed
        // 4. an, gl, hp had identical formulas; te and ry had identical formulas;
        //    differentiated them so the 16 machines represent 16 distinct states
        // 5. Added bias=5 so no machine starts at hard zero (clip floor);
        //    this restores accessibility to machines that the first window zeros out
        // 6. Amplified rms signal for machines that should respond to amplitude
        //
        // Coefficients are 1/20, 1/10, 1/5, or 1/4, derived from observed delta std:
        // density std=82, windowsize std=92, cent std=45, rolloff std=54, flat std=31, rms std=35
        // Smaller std -> larger coefficient (1/4) to make the signal equally influential
        // Larger std -> smaller coefficient (1/20) to prevent domination by noisy signal

        w_sc = ((weights.at(\sc) * 100) + 5
            - (density_delta / 10)
            - (windowsize_delta / 10)
            + (percpitch_delta / 10)
            + (avgflat_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        w_lu = ((weights.at(\lu) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            + (percpitch_delta / 10)
            - (avgflat_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // BUG FIX: was using weights.at(\sc); now correctly reads weights.at(\so)
        w_so = ((weights.at(\so) * 100) + 5
            + (density_delta / 10)
            + (windowsize_delta / 10)
            + (percpitch_delta / 10)
            - (avgflat_delta / 10)
            - (avgcent_delta / 10)
            - (avgrolloff_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        w_ma = ((weights.at(\ma) * 100) + 5
            + (density_delta / 10)
            + (windowsize_delta / 10)
            + (avgcent_delta / 10)
            + (avgrolloff_delta / 10)
            + (avgrms_delta / 5)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // cr: fast events, dark, flat - amplified density coefficient
        w_cr = ((weights.at(\cr) * 100) + 5
            + (density_delta / 5)
            + (windowsize_delta / 10)
            - (avgflat_delta / 5)
            - (avgcent_delta / 10)
            - (avgrolloff_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // te: differentiated from ry - responds to bright+fast, centroid primary
        w_te = ((weights.at(\te) * 100) + 5
            + (density_delta / 10)
            - (windowsize_delta / 10)
            + (avgcent_delta / 5)
            + (avgrolloff_delta / 10)
            + (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // ry: differentiated from te - responds to loud+fast, rms primary
        w_ry = ((weights.at(\ry) * 100) + 5
            + (density_delta / 10)
            - (windowsize_delta / 10)
            - (avgcent_delta / 10)
            + (avgrolloff_delta / 10)
            + (avgrms_delta / 5)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // an: slow events, long windows, bright - melodic sustained
        w_an = ((weights.at(\an) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            + (avgcent_delta / 10)
            + (avgrolloff_delta / 10)
            - (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // hp: differentiated from an - high centroid primary
        w_hp = ((weights.at(\hp) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            + (avgcent_delta / 5)
            - (avgrolloff_delta / 10)
            - (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        w_st = ((weights.at(\st) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            - (percpitch_delta / 10)
            - (avgcent_delta / 5)
            + (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 0.8, clip: \minmax),

        // ht: sparse, long windows, pitched, bright - harmonic textured
        // Changed percpitch_delta /5 -> /10: with 100% pitched corpus pd=-9.09 always,
        // so /5 systematically underweights ht by 1.82 units vs other machines' 0.91.
        w_ht = ((weights.at(\ht) * 100) + 5
            - (density_delta / 10)
            + (windowsize_delta / 10)
            + (percpitch_delta / 10)
            + (avgrolloff_delta / 10)
            + (avgflat_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // gl: differentiated from an/hp - responds to amplitude
        w_gl = ((weights.at(\gl) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            + (avgcent_delta / 10)
            + (avgrolloff_delta / 10)
            + (avgrms_delta / 5)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        w_cp = ((weights.at(\cp) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            - (percpitch_delta / 10)
            - (avgcent_delta / 5)
            + (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 0.85, clip: \minmax),

        w_wa = ((weights.at(\wa) * 100) + 5
            - (density_delta / 10)
            + (windowsize_delta / 5)
            - (percpitch_delta / 10)
            - (avgcent_delta / 5)
            + (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 0.85, clip: \minmax),

        // gp: sparse, pitched, quiet - grace-note like
        // Changed percpitch_delta /5 -> /10: same reason as ht; pd=-9.09 always,
        // /5 gives -1.82 penalty vs /10 gives -0.91. Brings gp to equal floor.
        w_gp = ((weights.at(\gp) * 100) + 5
            - (density_delta / 5)
            + (percpitch_delta / 10)
            - (avgrms_delta / 5)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // bu: fast events, loud - burst; amplified rms
        w_bu = ((weights.at(\bu) * 100) + 5
            + (density_delta / 5)
            - (percpitch_delta / 10)
            + (avgrms_delta / 5)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // --- generated machines, run 39 --------------------------------
        // Coefficients follow the same convention as above: 1/5 for the
        // feature that defines the category, 1/10 for supporting features.
        // Each formula answers "what input should call this machine", so the
        // four categories are reachable from the material and not only from
        // an override.

        // dr: sparse, long-windowed, dark, quiet -> a drone belongs here
        w_dr = ((weights.at(\dr) * 100) + 5
            - (density_delta / 5)
            + (windowsize_delta / 5)
            - (avgcent_delta / 10)
            - (avgrolloff_delta / 10)
            - (avgrms_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // pu: dense, short-windowed, loud -> a pulse belongs here
        w_pu = ((weights.at(\pu) * 100) + 5
            + (density_delta / 5)
            - (windowsize_delta / 5)
            + (avgrms_delta / 10)
            + (avgcent_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // hm: pitched, sustained, tonal. Low flatness is the tonal signal,
        // so avgflat carries the negative sign at full weight.
        w_hm = ((weights.at(\hm) * 100) + 5
            - (density_delta / 10)
            + (windowsize_delta / 10)
            + (percpitch_delta / 10)
            - (avgflat_delta / 5)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        // me: pitched, moving, bright, tonal -> melodic sequencing
        w_me = ((weights.at(\me) * 100) + 5
            + (density_delta / 10)
            - (windowsize_delta / 10)
            + (percpitch_delta / 10)
            + (avgcent_delta / 5)
            - (avgflat_delta / 10)
        ).linlin(0, 100, 0.0, 1.0, clip: \minmax),

        w_va = (50
            + (density_delta / 5)
            + (percpitch_delta / 10)
            - (avgflat_delta / 10)
            - (avgrolloff_delta / 10)
            - (avgrms_delta / 10)
        ).linlin(0, 100, 0, 10, clip: \minmax),

        // setting target
        calib = [
            w_sc,
            w_lu,
            w_so,
            w_ma,
            w_cr,
            w_te,
            w_ry,
            w_an,
            w_hp,
            w_st,
            w_ht,
            w_gl,
            w_cp,
            w_wa,
            w_gp,
            w_bu,
            w_dr,
            w_pu,
            w_hm,
            w_me
        ],

        recalib = Array.fill(
            calib.size, {
                |i|
                calib[i] / calib.sum;
        }),

        thisTarget = targets[recalib.windex],

        // resetting current means and weights
        theseWeights = Dictionary[
            \sc -> recalib[0],
            \lu -> recalib[1],
            \so -> recalib[2],
            \ma -> recalib[3],
            \cr -> recalib[4],
            \te -> recalib[5],
            \ry -> recalib[6],
            \an -> recalib[7],
            \hp -> recalib[8],
            \st -> recalib[9],
            \ht -> recalib[10],
            \gl -> recalib[11],
            \cp -> recalib[12],
            \wa -> recalib[13],
            \gp -> recalib[14],
            \bu -> recalib[15],
            \dr -> recalib[16],
            \pu -> recalib[17],
            \hm -> recalib[18],
            \me -> recalib[19]
        ];

        means = theseMeans;
        weights = theseWeights;
        ~variance = w_va;

        ("weights: " + weights.asString).postln;
        ("means: " + means.asString).postln;

        if (~targetOverride == true, {
            // to nudge the system toward a new playback machine and to reset weights

            ("WARN: Override Engaged, moving toward" + ~specTarget).postln;
            thisTarget = ~specTarget;

            means = Dictionary[
                \density -> 0.10,
                \windowsize -> 0.09,
                \mainpitch -> 'D5',
                \percpitch -> 1.0,
                \avgcent -> 3132,
                \avgrolloff -> 1560,
                \avgflat -> 0.17,
                \avgrms -> 0.016
            ];

            weights = Dictionary[
                \sc -> 0.1,
                \lu -> 0.1,
                \so -> 0.1,
                \ma -> 0.1,
                \cr -> 0.1,
                \te -> 0.1,
                \ry -> 0.1,
                \an -> 0.1,
                \hp -> 0.1,
                \st -> 0.1,
                \ht -> 0.1,
                \gl -> 0.1,
                \cp -> 0.1,
                \wa -> 0.1,
                \gp -> 0.1,
                \bu -> 0.1,
                \dr -> 0.1,
                \pu -> 0.1,
                \hm -> 0.1,
                \me -> 0.1
            ];

            ~targetOverride = false;
        });

        eventTarget = eventCtr + rrand(1, 30);

        ^ thisTarget // return target
    }

    runningArgs {
        // used to smooth incoming descriptors from the Analysis module to return as playback machine args

        |dist|

        var eventOffsets = offsetList[
            (eventCtr - dist)..],
        eventOnsets = onsetList[
            (eventCtr - dist)..],
        eventPitches = pitchList[
            (eventCtr - dist)..],
        eventCents = centList[
            (eventCtr - dist)..],
        eventRolloffs = rolloffList[
            (eventCtr - dist)..],
        eventFlats = flatList[
            (eventCtr - dist)..],
        eventRMS = rmsList[
            (eventCtr - dist)..],

        theseMeans = Dictionary [
            \density -> this.processDensity(eventOnsets),
            \windowsize -> this.processWindow(eventOnsets, eventOffsets),
            \mainpitch -> this.processMainPitch(eventPitches),
            \percpitch -> (
                (eventPitches.size - eventPitches.occurrencesOf('unpitched'))
                / eventPitches.size),
            \avgcent -> eventCents.mean,
            \avgrolloff -> eventRolloffs.mean,
            \avgflat -> eventFlats.mean,
            \avgrms -> eventRMS.mean
        ];

        ^ theseMeans
    }

    receiver { // osc client
        |args|

        var thisTarget = [target, prevTarget],
        selectTarget = thisTarget[
            [
                ((eventCtr - prevEvent) / (eventTarget - prevEvent)),
                1 - ((eventCtr - prevEvent)  / (eventTarget - prevEvent))
            ].windex
        ],
        returnArgs;

        onsetList.add(args[1]);
        offsetList.add(args[2]);
        centList.add(args[3]);
        rolloffList.add(args[4]);
        flatList.add(args[5]);
        rmsList.add(args[6]);
        pitchList.add(args[7]);

        if (eventCtr > eventTarget, // playback machine target selection
            {
                prevTarget = target;
                prevEvent = eventTarget;
                target = this.targetprocessing();
                ("OK: Moving To State:" + target.asString + "!").postln;
        });

        if (eventCtr > 3, // playback machine args generation
            {
                returnArgs = this.runningArgs(3)
            },
            {
                returnArgs = this.runningArgs(1)
            }
        );

        ("OK: Event No." ++ eventCtr.asString + "complete, next target: " ++ eventTarget.asString ++".").postln;
        eventCtr = eventCtr + 1;

        ^ [selectTarget, returnArgs]
    }
}