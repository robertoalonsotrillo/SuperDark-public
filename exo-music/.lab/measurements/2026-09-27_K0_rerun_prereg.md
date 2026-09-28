# Rule 1 re-run at K = 0 on the corrected allocation: pre-registration

**27 September 2026, written before the run.** Amends
`2026-09-22_layer_coupling_prereg.md` for this run only.

- Code: the K = 0 fix of 27 Sept (`2026-09-27_why_K0_kept_the_coupling.md`).
- Arms: A (K = −1), C1 (K = 0), A (K = −1), 1,600 windows each, 12 settle
  windows after each reload, through `run_n_arms.sh` (closes on A).
  About 14.5 h.
- Held: knobs_to_factory 0, voices_follow as is (inert), rung 2 inert.
- Rule 1, unchanged: in C1, macro-mid and macro-micro max |r| inside their
  null bars (p > 0.05) while both A arms keep them negative with p < 0.05.
- If C1 is null on both macro pairs: the allocation is the mechanism, K is
  live across [−1, 0], and C2 (K = +0.5) is re-run on this code next.
- If C1 stays negative and significant: a second path couples the layers;
  the next candidate is the section's fixed voice count (a shared total),
  tested with `voice_fill` set so each layer holds one slot.
- Integrity: a CLOCKJUMP voids its arm. Rule 5 (the ear) stands.
