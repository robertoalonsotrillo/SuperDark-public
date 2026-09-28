# scsynth died at 06:02 and every instrument said the factory was fine

**17 September 2026.** The overnight two-arm comparison ended PARTIAL. The cause
is not musical, not numerical, and not in the factory's own code.

## What happened

scsynth segfaulted at **06:02:23**. Crash report
`~/Library/Logs/DiagnosticReports/scsynth-2026-09-17-060223.ips`:

```
EXC_BAD_ACCESS (SIGSEGV), KERN_INVALID_ADDRESS at 0x0000088000000020
faulting thread 0, com.apple.main-thread

  -[NSWorkspaceNotificationCenter _systemDidChangeAppearance:]
  -[NSSystemAppearanceProxy _menuBarAppearanceChanged:]
  +[NSAppearance appearanceNamed:]  ->  +[NSAppearance _aquaAppearance]
  -[NSBuiltinAppearance initWithBundleResourceName:publicName:catalystName:]
  NSCreateCoreUIRenderer  ->  CUIRenderer::Create
  +[CUIThemeFacet themeNamed:forBundleIdentifier:error:]
  +[NSBundle bundleWithIdentifier:]  ->  +[__NSBundleTables bundleTables]   <-- crash
```

The backtrace is entirely AppKit, CoreUI and Foundation. There is no factory code
in it, no DSP, no OSC. `otool -L` confirms **scsynth links AppKit** — a headless
audio server that receives GUI notifications. The machine has
`AppleInterfaceStyleSwitchesAutomatically = 1`.

### What is NOT claimed

**That the appearance switch is sufficient.** Three earlier runs crossed 06:00
and survived: `live_260904_013018` (01:30→09:27), `live_260910_002430`
(00:24→08:54), `live_260916_002600` (00:26→10:00). Only one scsynth crash report
exists on the machine. So this is a latent hazard that fired once, not a
demonstrated every-dawn failure, and the trigger is not established.

I also proposed and then **refuted my own second hypothesis** in the same hour: a
CoreAudio context leak, from seeing context IDs jump 3442 → 5459 in twenty
minutes. Across the whole week the IDs climb at a broadly steady rate on nights
that survived too. It is not a leak. Recorded because the refutation took four
minutes and the hypothesis would otherwise have looked plausible in the record.

## The part that matters more: nothing noticed

scsynth died at 06:02. sclang ran until at least **09:14 — three hours** — and in
that time wrote, for window 1422 alone:

| line type | count after the server died |
|---|---|
| VSNAP | 1,951 |
| REST | 477 |
| REST_HELD | 75 |

Every cheap liveness signal was false at the same time:

- the process was present in `ps`
- the window log was **growing**, and its mtime was current
- the factory log printed `OK: Playing State:  me .` repeatedly, with **no error
  line before or after the death**
- no BLOWUP, no VOICEBLOW, no FILL_STALL, errors 0

The only true signal was the window number, which stopped at 1422.

## Why the monitor built for exactly this did not say so

`tools/run_integrity.py` exists to catch failures that are invisible to the thing
being measured — its own header says so. It watches scsynth. It watched with:

```python
"scsynth": alive("scsynth -u 57700")
```

`start_loop.sh` boots the server on `SCPORT="${SCPORT:-57110}"`.

**The pattern had never matched a running process in its life.** Across 52
recorded events spanning many runs:

| subject | events |
|---|---|
| sclang | 23 |
| ssd | 3 |
| **scsynth** | **0** |
| splitter | 0 |

Verified against a real scsynth booted on 57110: `pgrep -f "scsynth -u 57700"`
does not match; `pgrep -x scsynth` does.

**Tenth instance of the built-and-inert pattern**, and the sharpest one yet,
because the defect is not the typo. It is that `watch()` emitted only on
TRANSITIONS, so a probe pinned False forever and a probe correctly reporting a
healthy process produce **identical output: nothing**. A mis-wired instrument and
a clean run were indistinguishable, and the charter, the panel and this monitor
all reported normally through a three-hour silence.

The splitter probe, by contrast, is correctly worded — `run_fifo.sh` uses the
identical string. Its zero is legitimate. That it *looks* the same as the broken
one is the whole point.

## Fixed, and tested

`tools/run_integrity.py`:

1. Probes are **declared**, not inlined, and scsynth is matched by process name
   with `pgrep -x` rather than by a command line containing a **port number**.
   The probe broke because it encoded configuration into a liveness check.
2. **The initial state is emitted.** A subject down when the monitor starts now
   says so on line one instead of waiting for a transition that cannot come.
3. **A probe that has never matched announces itself** — `PROBE_NEVER_MATCHED`,
   with its pattern and mode quoted, after a 300 s grace. This is the check that
   would have caught the port typo on the first run instead of on the night it
   cost a comparison.
4. `--report` now ranks a dead probe above everything else: *"until this is
   resolved, the absence of faults below is not evidence that there were none."*

Tests run: the old pattern misses a real running scsynth and the new one matches
it; the never-matched announcement fires **exactly once**, not every poll.

One test failed twice for reasons that were not the probe's — a shebang script
takes the interpreter's process name, and a copied system binary loses its
signature and is killed on launch. Both are noted in the test, because a test
that fails for the wrong reason misleads exactly as much as one that passes for
the wrong reason.

## Built but NOT shipped

A per-window `server.serverRunning` check for `live_factory.scd`, which on three
consecutive missed windows writes `SERVER_DEAD` and exits — exits rather than
setting `running = false`, because that flag gates only the analysis block, while
VSNAP and REST come from the voice keeper on its own clock, which is precisely
what kept writing for three hours.

The mechanism is **measured, not assumed**:
`tools/test_server_loss_detected.scd` boots a server, kills it with SIGKILL as a
segfault would, and times the flag. `serverRunning` went false after **0.26 s** —
inside a single 11.7 s window.

**The edit introduced a syntax error and has been reverted.** `live_factory.scd`
is byte-identical to HEAD and the factory is startable. The work is preserved at
`docs/wip/2026-09-17_server_loss_detection.patch` and must be fixed, parsed
against the baseline control, and tested against a real killed server before it
goes anywhere near a run. Filed as #117, still open.

## Open

- **#116** why scsynth died is named but not explained; three dawn crossings
  survived. Do not treat the AppKit trace as a solved cause.
- **#117** the server-loss check is written and reverted, not shipped.
- **#112** comparison 2 attempt 2 is PARTIAL: champion 808 scored windows,
  candidate ~519. The pre-registration's void condition (fewer than 200 scored
  windows in an arm) is **not** breached, so the candidate is short, not void.
  Whether to score matched at 519, score unequal, or re-run is Roberto's, because
  it changes what the comparison can claim.
