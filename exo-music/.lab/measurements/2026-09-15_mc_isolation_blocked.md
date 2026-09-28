# M-C: the lever now exists and the single-layer boot crashes. Not yet a bisection.

15 September 2026, 17:00–17:10. Status record, written while it is still true.

## What was built

`layers_active` in `policy.json`, read at boot in `live_factory.scd`. Before it,
isolating a layer was impossible from policy, and three separate things made it
impossible together:

1. the fill loop gives "one each first" (`vi < layerNames.size`), so the first
   three voices are one per layer whatever `voice_fill` says
2. the empty-slot fallback was `slotMach[\micro] ? currentState`, written
   literally, so micro was resurrected for any layer without a machine
   **including a resting one** — resting a layer never silenced it
3. `voice_fill` only ever governed the spare voices, and its string can name
   layers outside the active set

All three are fixed. `layerNames` is read from the file, the fallback stays
inside the active set, and `voice_fill` is filtered to it.

**Read at boot, deliberately not hot-reloaded.** Changing the layer set mid-run
would leave voices sounding from a layer that no longer exists, slot state keyed
to it, and a window log whose halves describe different instruments. That is the
unmarked seam again.

## The first version of the fix silently did nothing

It was written `policy !? { policy["layers_active"] }`. `policy` is assigned at
line ~524, inside the reload function, which has not run at that point in the
boot. So the guard fell through to the default, the factory came up with all
three layers, and **nothing in the log said the setting had been ignored**.

Caught in two minutes, only because `VOICES` was checked before the run was
believed. A policy read that silently defaults has the same shape as a panel
showing green because its source is gone, and this project has now met that
shape four times. The fix reads the file directly through `loadJSON` and the
factory prints `LAYERS_ACTIVE <set>` at boot, so the setting is visible in the
record instead of inferred.

## The blocker

With `layers_active = "macro"` the boot dies:

    LAYERS_ACTIVE macro
    ERROR: Message 'asFloat' not understood.
    RECEIVER: Dictionary[ (s -> [0.588, 0.491, ...]), (m -> ry), (r -> 76) ]
    ... Collection:collectAs, arg class = Array, res = [0.0, 0.0, 76.0]
    ... Interpreter:executeFile

Fatal at file level, immediately after the layer set is printed, before scsynth
comes up. The receiver is a **trace entry** from `memory.json`, being collected
to Array with `asFloat`, and the enclosing array is a mangled parse:
`[cp, r, 76, Dictionary[...], s, 0.588]` where six floats belong.

Python reads the same `memory.json` cleanly: 8,000 trace entries, 1,930
sections, zero malformed. So the JSON is well formed and SuperCollider's
`parseYAML` is producing something else from it. `collectAs` does not appear in
`live_factory.scd`, so the call is inside a class under `live_classes/`.

## What is NOT established

One boot with `"macro"` crashed. One boot with `"macro mid micro"` did not. That
is **n = 1 per arm**, and it was called a bisection in the moment, which it is
not. Two other things differed between those boots, because the working boot
also carried a corpus reassembly and a fresh `memory.json` written by the run in
between.

Candidate causes, none eliminated:

- a single-element `layerNames` taking a different path in a class file
- a `parseYAML` failure on `memory.json` that is intermittent or size-dependent
- something in the reassembled corpus of the 17:07 boot

## What to do next, and not on the live factory

`workdir_music/mutable_shadow/` exists for exactly this. Reproduce offline:

1. copy the current `mutable/` into `mutable_shadow/`, set
   `layers_active = "macro"` there
2. boot against the shadow with no stream attached, three times
3. boot the shadow with `"macro mid micro"` three times
4. if the crash follows the layer set, find the `collectAs` in `live_classes/`
   and fix it. If it does not, the suspect is `parseYAML` on `memory.json` and
   the test is to trim the trace and retry

Three boots per arm, because a single-run trigger has already scrapped a healthy
factory three times in one day in this project's history, and the kernel's
two-run rule exists for that reason.

## State at the time of writing

Service is restored and the change is inert at its default. `layers_active` is
`"macro mid micro"`, the factory is running `live_260915_170702` with zero
`FILL_STALL` and zero `UNTRACKED`, all three watchers are up, and the public
panel is fresh at 19 s.

Checkpoint `ck_260915_165834_champion-rq25-fullstack` holds the pre-M-C state.
The restore point `pre-harness-20260915` is older and unaffected.
