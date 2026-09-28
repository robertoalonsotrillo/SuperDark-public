# Section selection ceded to the factory (B7 with A5), 28 Sept 2026

The macro form was set by four values I had chosen by hand:

| value | was | now a knob, architect's bounds | bound's reason |
|---|---|---|---|
| family_damping (how hard a section damps machines outside its family) | 0.85, hard-coded | [0.5, 0.97] | a section keeps a character |
| section_return (chance a new section returns to a remembered one) | 0.35, default | [0.1, 0.6] | memory recurs |
| section_mutate (chance a recalled section swaps a member) | 0.0, default | [0.0, 0.3] | a recalled section stays recognisable |
| section_windows_max (longest section) | 18 | [10, 30] windows | about 1 to 5 minutes |

Drawn by the existing knob walk at section boundaries (KNOB lines), like the other knobs since 20 Sept. Compiles (compileFile). Live from boot 28 Sept 21:2x.

Class 3 check: what the architect keeps is the bounds and their reasons; the values inside them are the factory's. Still the architect's in selection: the bias/coefficient inheritance rule of B7 (mechanical) and layer_coupling K (the A5 experiment variable, held at -1 until the K=0 rerun).

Not done yet (A5 nesting): the three timescales still choose independently; nesting (macro choice constraining mid and micro) is the next design step.

Also 28 Sept 21:18: a boot crashed at load (sclang SIGSEGV after two "grey count error" GC messages, report sclang-2026-09-28-211844.ips). The same code booted at 12:38 and again at 21:21; a SuperCollider 3.12.2 GC fault under the large state files, not a code change. Watch for recurrence.
