# The clock-jump guard was inert, and the gate could not say so

**18 September 2026, 10:2x.** Found by the three-window smoke test of
`run_n_arms.sh`, an hour before the fourteen-hour sequence it was meant to
clear.

## What was wrong

The machine rebooted at **09:12**. `/tmp` was cleared with it. Nothing in the
repository starts `tools/run_integrity.py --watch`, so the integrity monitor had
not been running since the reboot and `/tmp/superdark_integrity.jsonl` did not
exist.

Three things followed, and each of them was silent.

**One. The CLOCK JUMP abort was dead.** `run_n_arms.sh` lists six refusals at the
top of the file, and the third is *"run on through a clock jump (the machine
slept; the arm is not one series)"*. It is implemented by `jumps()`, which counts
`CLOCK_JUMP` lines in the journal:

```sh
jumps() {
  if [ -f /tmp/superdark_integrity.jsonl ]; then
    ...
  else echo 0; fi        # <- a missing journal reads as zero, forever
}
```

No journal means no lines means zero jumps, at every poll, for as long as the run
lasts. The guard would have reported a clean continuous series through any number
of sleeps. It is the same shape as the scsynth probe that had never matched
anything: built, wired, and answering a question it cannot see.

**Two. Nothing would have been recorded.** Sleeps, clock steps, FIFO saturation
and fill stalls all reach the harness through that journal and through no other
path. Fourteen unsupervised hours would have produced window logs with no way to
tell afterwards whether the windows were continuous.

**Three. The gate blocked every pair and said nothing was wrong.** Each of the
five smoke pairs came back:

```
FAIL  run_not_contaminated     0 fault(s) inside the arms
VERDICT  BLOCKED
```

Zero faults, and a failure. The cause is in `inv_run_not_contaminated`. On
16 September the fault **count** was scoped to the arms' own wall clock, which
was correct and necessary, because the unscoped count had blocked a gate over
sixteen faults that all fell outside both arms. The **verdict** kept `rc == 0`
alongside it, and `rc` is the whole journal's exit status. It is 1 when faults
exist anywhere in history, and it is 1 when there is no journal at all. So the
scoping worked and an unscoped condition overrode it.

## What changed

| | |
|---|---|
| `run_integrity.py --watch` | started; four probes up, report clean |
| `run_n_arms.sh` preflight | refuses to start when the monitor is not running, and prints the command to start it |
| `run_n_arms.sh` `wait_for` | checks the monitor at every poll; if it dies mid-run the arm returns 3 and the sequence ends `VOID ... the run was unwatched` |
| `eval_invariants.py` | `rc` dropped from the verdict; a missing journal returns `NOT CHECKED` and names the absence; an unreadable report returns its `rc` |

`monitor_dead()` treats a missing journal and a missing process as the same
answer, because for this purpose they are: neither can tell you whether the
machine slept.

The invariant was re-sealed. Every `run_not_contaminated` result taken before
`1d7fd40eb12309dd` used the old text.

## Two smaller defects in the same pass

**The scorer took a concurrent run's bundles.** `score_n_arms.sh` identified its
own output by modification time. A first invocation survived a client-side read
timeout, a second was started on top of it, and the second reported *"compare
produced no bundle"* for a comparison the first had already written. There is now
a lock directory, and the compare step finds its bundle by reading
`comparison.json` and matching both run names, which is identity and not
ordering. The same weakness produced the 18 September failure where a scorer took
the previous day's bundle after `eval_rig` rejected a flag.

**A failed pair reported success.** The pair loop ran as `echo "$PAIRS" | while
read`, so `exit 1` inside it left the pipeline's subshell and the script carried
on to exit 0. It now reads from a file.

## What is not claimed

That the monitor has ever caught a fault during a comparison. It has not been
asked to: this is the first run whose preflight requires it. What is established
is that between 09:12 and 10:19 on 18 September the factory ran unwatched, that
the runner could not have told anyone, and that the gate's report of that
condition was misleading in the direction of looking clean.

## Reproduce

```sh
pkill -f "run_integrity.py --watch"
sh tools/run_n_arms.sh --dry-run --windows 3 --cand voices_max=5
# preflight FAILs and names the monitor
```
