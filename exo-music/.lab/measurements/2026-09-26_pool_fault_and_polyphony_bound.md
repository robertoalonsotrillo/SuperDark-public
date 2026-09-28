# The pool fault of 25 Sept, and the polyphony bound

**26 September 2026, 03:20.** Run `live_260925_131822`, booted 13:18 for the
C2 sequence, stalled at window 38 (13:26) and was found at 01:16 still up
and doing nothing: `alloc failed, increase server's memory allocation` 8.6
million times in the server log, the runner PARTIAL at A1, the FMA volume
gone, three clock jumps from sleep after midnight. The run is void.

## What the log shows

Window 30 `wa`; window 35 the written machine
`brbrscbrpugl2609051356x12609201749x3te2609241017x1` (micro, 0.106 s median,
composed 24 Sept 10:17: dur from the grammar at 0.04–0.13 s, envelope from
`dr` so release = `dr_dur` = 3–9 s by window size, `res+dly` stages, one
layer); eighteen `Playing State: gl` lines, then the first `alloc failed`,
and the pool never came back.

## What is, and is not, established

That machine asks for the most concurrent voices of any machine written
this month that is still under the cap: 38 with the harness's representative
arguments, near 100 at a long window size. Each of its voices held a 0.5 s
CombL, 128 KB, on the dry `\playback` def. That is 5–13 MB against a 512 MB
pool, so **this machine alone does not account for the fault** and the
record does not claim it does. Two other explanations remain open: a
scheduler catch-up burst when sclang blocked on a log write to a volume that
was being detached (the volume is missing now and a `_FileWrite` failure is
in the log), and the fragmentation of the pool under a long run of
short-lived 128 KB allocations. The window log is on the missing volume;
what would settle it is the VOICES and SLOTS lines around window 35, read
when the drive is back.

## What was built (commit below)

1. `MachineWriter.polyphonyOf`: layers × mean(atk + rel) / mean(dur) over
   the emitted stream's first 60 events with representative arguments; a
   machine over `maxPolyphony` (48) is refused before its file exists,
   reason logged as `polyphony N voices above 48`. The originals sit under
   20 (`fma1` 13.1 is the highest).
2. `tools/check_polyphony.scd` applied the bound to the 202 machines already
   written: one over the cap, `brbrrysc2609031456x1te2609221232x7` at 50.1,
   moved to `mutable/quarantine/` with the number beside it and its spec
   forgotten; the next three are 40.3, 38.1 (the machine above) and 13.1.
3. `\playback` and `\playbackHP` are dry by construction: the res/dly/blur
   stages moved to `\playbackFX` and `\playbackHPFX`, same arguments, and
   the writer names the FX def only when a machine draws stages. A dry
   voice allocates nothing. The three written machines with stages were
   rewritten to the FX names by the check tool; the audition renderer
   carries the new defs.
4. The pool reset in `live_factory.scd`: on the server's first `/fail` with
   `alloc failed` in any 30 s, every live player is stopped so its voices
   end at their envelopes and the pool refills; `POOL_RESET win,count,
   machines` is logged with the machines that were sounding. The keeper's
   top-up rebuilds the texture. The two faults of 23 and 25 Sept each cost
   hours because nothing recovered; this is the net under the bound.

Not changed: `memSize` (512 MB); the 0.5 s line; the quarantine of the
38-voice machine, which is under the cap and stays.

## Consequence for the coupling run

C2 has now failed to run three times (app restart, an edited running
script, this). The sequence A C2 A starts again at the next boot with the
drive attached and the laptop awake on power; nothing in the arms changes.
