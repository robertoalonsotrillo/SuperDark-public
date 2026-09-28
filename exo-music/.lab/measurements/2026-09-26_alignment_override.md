# Alignment check overridden at the 26 Sept evening boot

**26 September 2026, about 20:55.** Decision: Roberto ("override").

## Why the factory was down

The 11:01 boot hung after the laptop slept and the FMA drive detached
(18:50): CLOCKJUMP 4,305 s at window 2536, the log handle died, no window
after 2537 (20:23). Stopped cleanly at 20:44; mutable/, corpora and logs
untouched.

## What refused the reboot

`verify_alignment.py`, step 2 of `start_loop.sh`: grains_play_macro min
rho 0.99723, 4 of 45 probes moved more than 2 ranks, tolerance
max(2, 45 // 15) = 3. ev and mid aligned (0 moved). Identical on a second
attempt: the assembly draw is seeded.

## Diagnosis

`why_misaligned.py --corpus workdir_music/grains_play_macro`: pc0-pc3 rho
at or above 0.99997; all displacement on pc4, the lowest-variance axis
(g126 and g396 by 4 ranks, g153 and g351 by 2), classed LOCAL: the corpus
order is sound. The pool itself (`self_corpus/grains_pool_macro`) shows 6
moved on pc4, same grains plus g117 and g369. The pool's descriptors.json
was last written at 18:29, when self_ingest admitted a macro grain into
slot 754 and projected it through the frozen basis. Same class as the
1 Sept case recorded in verify_alignment.py (two grains swapping on pc4,
fully accounted for by tie noise).

## What was changed

`start_loop.sh`: a failed alignment check still stops the boot unless
`ALIGN_OVERRIDE` is set to a person's reason, in which case the boot goes
on and the reason is printed in the start log. Default behaviour and the
check itself are unchanged.

## Open

Why an admission into slot 754 moves the pc4 ranks of other grains, and
whether the probe tolerance should scale with admissions since the basis
was frozen. Until that is answered, every boot after an admission can hit
this again.
