// Does sclang actually NOTICE when scsynth dies?
//
// WHY THIS EXISTS
// On 17 September 2026 scsynth segfaulted at 06:02 and the factory's window
// routine kept running until at least 09:14 -- three hours -- writing 1,951
// VSNAP and 477 REST lines for a single window into the measurement log while
// rendering nothing. The process was present, the log was growing, its mtime was
// current, and the factory log repeated "OK: Playing State" throughout.
//
// The intended fix is to test `server.serverRunning` once per window. But
// `serverRunning` is maintained by Server's alive thread, and whether that
// thread is running -- and how fast it reacts -- depends on how the server was
// reached. The factory constructs its own Server on a dedicated port and calls
// waitForBoot. Assuming the flag works is exactly the assumption that produced
// nine previous instances of a mechanism that was built and inert, so it is
// measured here against a real scsynth that is really killed.
//
// PASS means: serverRunning is true while the server lives, and becomes false
// within a bounded time after it is killed. If it never flips, the fix does not
// work and must not be wired in.
//
//   sclang tools/test_server_loss_detected.scd

(
var port = 57811, server, t0, flipped = nil, deadline = 30;

"=== server-loss detection test ===".postln;

server = Server(('losstest' ++ port).asSymbol, NetAddr("127.0.0.1", port));
server.options.numOutputBusChannels = 2;
server.options.numInputBusChannels = 0;
server.options.sampleRate = 44100;

server.waitForBoot({
    var alive;
    "  booted.".postln;
    0.5.wait;

    alive = server.serverRunning;
    ("  while alive, server.serverRunning = " ++ alive).postln;

    if (alive.not) {
        "  FAIL: serverRunning is already false on a LIVE server.".postln;
        "  The flag cannot be used as a liveness test in this configuration.".postln;
        1.exit;
    };

    // Kill the server the way it died: abruptly, from outside, with no
    // opportunity to send /quit or unregister.
    "  killing scsynth with SIGKILL (as a segfault would)...".postln;
    ("kill -9 " ++ ("pgrep -x scsynth".unixCmdGetStdOut.split($\n)
        .select({ |s| s.size > 0 }).last ? "")).unixCmd;

    t0 = Main.elapsedTime;
    while({ flipped.isNil and: { (Main.elapsedTime - t0) < deadline } }, {
        0.25.wait;
        if (server.serverRunning.not) { flipped = Main.elapsedTime - t0 };
    });

    if (flipped.notNil) {
        ("  serverRunning went false after " ++ flipped.round(0.01) ++ " s").postln;
        ("  PASS: a dead server is detectable. A per-window check will see it "
            ++ "within " ++ (flipped / 11.7).roundUp(1) ++ " window(s).").postln;
    } {
        ("  FAIL: serverRunning stayed TRUE for " ++ deadline
            ++ " s after scsynth was killed.").postln;
        "  Do not wire this check in; it would be a tenth inert instrument.".postln;
    };
    0.5.wait;
    0.exit;
});
)
