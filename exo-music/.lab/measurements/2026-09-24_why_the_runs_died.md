# Why the runs died: the factory was a child of the Claude app

**24 September 2026, 22:40.** Closes #116 ("scsynth died, clean exit,
no crash report") and voids nothing that was not already void.

## The two deaths

| run | boot | death | log signature |
|---|---|---|---|
| live_260923_194659 | 23 Sept 19:47 | 23:35 | `Server exited with exit code 0`, SERVER_LOST, no crash report |
| live_260924_101737 | 24 Sept 10:17 | 17:24 | same, at window 2387 (arm A2, 747 of 800 windows) |

Both were read at the time as an unexplained scsynth exit. On 24 Sept the
whole stack went at once: scsynth, then sclang (which wrote SERVER_LOST
and stopped itself, as designed), the FIFO splitter, the autossh tunnel,
and the integrity watcher, whose journal ends at its own start line.

## The cause

`ps -o pgid` on the shells this assistant runs: process group 36630, which
is the PID of `/Applications/Claude.app/Contents/MacOS/Claude`, started
17:24:02, the same second the run died. Every service had been launched
from such a shell with `nohup ... &`, so every one sat in the app's process
group. When the app restarts it terminates its group. scsynth handles the
termination as a clean quit, hence exit code 0 and no crash report, which
is what #116 recorded on 23 Sept as an AppKit oddity. `nohup` ignores
SIGHUP and nothing else.

No sleep, no clock jump, no CoreAudio fault: uptime 6 days at the time of
the second death. The lid and the battery were never the cause of these
two; the wedged CoreAudio of the morning of 24 Sept was a separate fault
and was cleared by restarting coreaudiod.

## The fix

`tools/detach.sh` starts a command in its own session
(`start_new_session=True`, parent launchd). `start_loop.sh` and
`run_n_arms.sh` now check the leader of their own process group and, when
it is an application, re-launch themselves through `detach.sh` and exit,
so the old invocation cannot recreate the fault. Verified 22:29: sclang,
scsynth and the splitter in group 44754, the runner and the watcher in
their own, all with parent 1.

What this does not cover: a machine sleep or reboot still ends a run (and
should, as a clock jump). The watcher cannot see this class of death
because it dies with the rest; that is a reason to move it, and the
splitter and tunnel, to launchd agents, which is user-level configuration
and is left for Roberto to decide.

## Consequence for the coupling run

From live_260924_101737: A1 (windows 29–823, the first five at K=0 from a
reload lag), C1 (828–1627) and A2 (1628–2374, 747 windows) are scored by
the 22:30 task. C2 was never run there. A new sequence A C2(+0.5) A at 800
windows started 22:29 on live_260924_222853 (detached), done around
03:15; it runs on commit 11ba674, which carries rung 2 inert
(`synth_slot_weight` absent, so 0). Comparison of C2 against its own
bracketing arms is within one boot; comparison against C1 crosses a boot
and is reported as such.
