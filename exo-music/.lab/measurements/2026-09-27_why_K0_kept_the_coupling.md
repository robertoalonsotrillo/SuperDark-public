# Why K = 0 kept the coupling, and voices_follow is inert

**27 September 2026.** From the code and the 26–27 Sept baseline log.

## voices_follow is inert while sections run

`nVoices` returns `section[\voices]` whenever a section exists
(live_factory.scd, "how many voices this window"), and a section exists
from the first window of every boot (`section.isNil` only before the
first pick). Each section draws its count once, `rrand(voices_min,
voices_max)`. The `voices_follow inverse_density` branch is never
reached. It was part 1's named suspect; it cannot be the mechanism.
Eighteenth built-and-inert instance.

## The mechanism: the fill cycle hands a resting layer's spare slots on

Voices are assigned by slot: one per layer first, then the spare slots by
the fill string ("macro mid macro micro"). At K = 0 the target was reduced
by one voice per resting layer, and a slot drawn for a resting layer was
swapped to an active one. A resting macro owns up to three slots (its
first voice and two of every four spares); only one was withheld, and the
spares went to mid and micro. So a macro rest still raised mid and micro,
which is the anticoupling the prereg's K = 0 was meant to remove.

Measured on windows 19–3218 (K = −1): layer counts correlate macro-mid
−0.276, macro-micro −0.226; a random split of the same totals with the
same layer shares gives −0.10 / −0.08; with the total held fixed, macro-mid
is −0.78. The anticoupling is the allocation, most of it beyond what a
shared total alone produces.

## The fix (source only; deploys at the next boot)

At K > −1 the slot plan is built the way the loop assigns slots, every
slot of a resting layer is counted (`restSlots`), the target is
`nVoices − restSlots × (1 + min(K, 0))`, and each voice goes to the next
slot the plan owes. K = −1 is byte-for-byte as before (factor 0).
COUPLE lines gain a sixth field, restSlots. Compiles (sclang compileFile).

## Consequence

Part 1's C1 did not test the prereg's K = 0; it tested a partial refill.
Rule 1 is re-run on the corrected code: `2026-09-27_K0_rerun_prereg.md`.
