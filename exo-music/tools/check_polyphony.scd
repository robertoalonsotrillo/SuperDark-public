// Apply the writer's polyphony bound to the machines already written.
// 26 Sept 2026. The bound (MachineWriter.polyphonyOf: layers x mean(atk+rel)
// / mean(dur) over 60 events) exists from today; every machine written
// before it was never measured. This measures them all, moves any over the
// cap into mutable/quarantine/ with the number beside it, forgets its spec,
// and rewrites the \instrument of a machine that carries res/dly/blur keys
// from \playback(HP) to \playback(HP)FX, since the dry defs no longer carry
// the stages. Prints a census. Run with the factory STOPPED.
//
//   sclang -l /tmp/sctest.yaml tools/check_polyphony.scd
(
var root = "/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/workdir_music",
    dir = root ++ "/mutable/machines", qdir = root ++ "/mutable/quarantine",
    mw = MachineWriter.new(root ++ "/mutable"), files, n = 0, over = List.new, nil_ = 0,
    polys = List.new, fxed = 0, cap;
cap = mw.maxPolyphony;
~sampleSize = 1.0; ~numPairs = 1; ~fr = 20;
~dryBus = [0]; ~reverbShortBus = [4]; ~reverbMidBus = [6]; ~reverbLongBus = [8];
("mkdir -p " ++ qdir.quote).systemCmd;
files = (dir ++ "/*.scd").pathMatch.sort;
files.do { |path|
    var name = PathName(path).fileNameWithoutExtension, txt = File.readAllString(path), p, f, changed = false;
    n = n + 1;
    // FX instrument for machines that set their own stages
    if ((txt.contains("\\res,") or: { txt.contains("\\dly,") } or: { txt.contains("\\blur,") })
        and: { txt.contains("\\instrument, \\playback,") or: { txt.contains("\\instrument, \\playbackHP,") } }) {
        txt = txt.replace("\\instrument, \\playbackHP,", "\\instrument, \\playbackHPFX,")
                 .replace("\\instrument, \\playback,", "\\instrument, \\playbackFX,");
        changed = true; fxed = fxed + 1;
    };
    p = mw.polyphonyOf(txt);
    if (p.isNil) { nil_ = nil_ + 1 } { polys.add([name, p]) };
    if (p.notNil and: { p > cap }) {
        ("mv -f " ++ path.quote ++ " " ++ (qdir ++ "/" ++ name ++ ".scd").quote).systemCmd;
        f = File(qdir ++ "/" ++ name ++ ".why", "w");
        f.write("polyphony " ++ p.round(0.1) ++ " voices above " ++ cap ++ " (layers x (atk+rel) / dur); quarantined 26 Sept 2026\n"); f.close;
        mw.forgetSpec(name);
        over.add([name, p]);
    } {
        if (changed) { f = File(path, "w"); f.write(txt); f.close };
    };
};
("machines " ++ n ++ "  measured " ++ polys.size ++ "  unmeasurable " ++ nil_
    ++ "  rewritten to FX " ++ fxed ++ "  quarantined " ++ over.size ++ " (cap " ++ cap ++ ")").postln;
polys = polys.sort({ |a, b| a[1] > b[1] });
"  highest twelve:".postln;
polys.keep(12).do { |x| ("    " ++ x[0] ++ "  " ++ x[1].round(0.1)).postln };
"  quarantined:".postln;
over.do { |x| ("    " ++ x[0] ++ "  " ++ x[1].round(0.1)).postln };
0.exit;
)
