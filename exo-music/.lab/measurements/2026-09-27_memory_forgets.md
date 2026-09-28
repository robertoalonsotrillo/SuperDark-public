# Memory that forgets: a half-life on the transition table

**27 September 2026.** Step 3 of the agreed order (memory that updates in
performance). Boot `live_260927_115847`.

## What already existed

- memory.json is written at every section boundary (sections, transitions,
  operator, trace) and read at boot: it has updated during performance
  since August.
- `section_mutate` 0.5: a recalled section turns over one family slot,
  biased toward the factory's own machines. Of the 239 machines in
  remembered families, 200 are written ones, so the August freeze
  (41 written, 5 ever sounded) is answered.

## What was missing

Forgetting. 148 runs had built 5,178 sections and 6,942 transitions, and
nothing decayed: a path taken once in August weighed as much as one taken an
hour ago, and returns were steered by the whole archive equally. The same
defect was fixed in the machine operator on 18 Sept (operator_half_life);
the section graph never got it.

## What changed

- `memory_half_life` H (policy, in sections, about 125 s each): at each new
  section every transition count is multiplied by 0.5^(1/H); counts below
  0.05 are dropped. MEMDECAY win,H,entries,dropped in the log.
- The "no known successor" fallback draws only among sections some surviving
  path still reaches; the archive itself is never pruned.
- Counts load and save as fractions. H = 0 is the accumulating table exactly.
- Set to 200 (about 7 h). A path taken once fades out after about 30 h
  unless taken again. Backup of memory.json before the change:
  `/Volumes/FMA/superdark/memory_backup_260927_before_halflife.json`.
- Checked live: after the first new section all 6,942 counts read 0.9965.

## What to watch, not gate on

The number of surviving transitions (MEMDECAY) should fall toward a level set
by how often the factory revisits; returns should favour this week's paths.
If recall collapses to a handful of places, H is too short.

## Revised the same day, against Class 3 (Roberto: "we are steering here, aiming for a Class 3 factory, always take that into account")

The first version fixed H = 200 from outside: a means set by the architect,
and a uniform decay that fades the core with the frontier. Revised:

- `memory_half_life` is a sixth factory knob, range [50, 2000] sections,
  drawn log-uniformly by the factory at section boundaries like the other
  five. The architect keeps the bound; the rate is ceded.
- A path's effective half-life is H x (1 + log2 count): once-taken paths
  fade at H, paths the factory keeps returning to are retained up to about
  8x longer. Reinforcement decides what is kept (SDF: surplus generated at
  the frontier, retained at a core).
- Charter edition 8: norm n5_new_in_kind (from the rung 2 listening);
  constraint c5_memory_bounded; the edition note records this as a change
  to the memory physics, a new v0 in the book's terms. The rung 2 source
  weights are named there as the architect's reading of n5 and a soft cast,
  to be ceded at rung 3.

Class 3 check, from here on in every record: what is the architect's (norms,
constraints, bounds), what is ceded (means, values inside bounds), and what
is still set from outside and should be ceded next.
