(
// Log the machine-selection sequence WITHOUT rendering audio.
//
// Runs the real BehaviorTrimmed class over the real events.csv and prints one
// line per transition. An NRT render takes minutes; this takes seconds, because
// machine selection never touches the audio server. Every variety figure in this
// project so far has come either from a full render or from the agent's Python
// re-implementation of the selection rule. This measures the actual class.
//
// Substitutions: WORKDIR, SEEDVAL.
var b, lines, transitions, last, r;

thisThread.randSeed = SEEDVAL;

b = BehaviorTrimmed.new(NetAddr("127.0.0.1", 5005));
lines = File.readAllString(WORKDIR ++ "/events.csv").split($\n).reject({ |l| l.isEmpty });

transitions = List.new();
last = nil;

lines.do { |l|
    var p = l.split($,), pitch;
    pitch = if (p[6] == "unpitched", { \unpitched }, { p[6].asSymbol });
    r = b.receiver([ \a, p[0].asFloat, p[1].asFloat, p[2].asFloat, p[3].asFloat,
                     p[4].asFloat, p[5].asFloat, pitch ]);
    if (r[0] != last) { transitions.add(r[0]); last = r[0] };
};

("EVENTS " ++ lines.size).postln;
("TRANSITIONS " ++ transitions.size).postln;
transitions.do { |t| ("STATE " ++ t.asString).postln };
0.exit;
)
