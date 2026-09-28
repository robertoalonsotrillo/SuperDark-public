# Ten of the 115 policy keys cannot change the sound, and they are inert in three different ways

**19 September 2026.** All 115 non-underscore keys in
`workdir_music/mutable/policy.json` were classified against the shipped factory.
Ten cannot affect the output at the current policy. They fail in three ways that
a reader picking a knob for an experiment would not distinguish, and which this
record therefore separates:

| category | keys | what a reader would wrongly conclude |
|---|---|---|
| **read, acoustically inert** | `audibility_floor`, `max_live_voices`, `collapse_after`, `novelty_threshold` | that turning it does something |
| **shadowed fallback** | `continuity`, `voice_span` | that the live-looking value is the live value |
| **never read at all** | `section_operator_weight`, `self_ingest_weight`, `dwell_max`, `dwell_min`, `tonic_drift_oct` | that a zero is a decision |

The shadowed pair are the dangerous ones. `continuity = 0.5` and
`voice_span = 20.0` read as ordinary settings; the factory has never once
consulted either.

Two of the claims this verification was given turned out to carry wrong numbers.
Both are corrected below and neither changes a verdict.

**Not claimed:** that any of these should be removed, or that any is a bug. Four
of the ten are inert by an argument written in the comment above them. The claim
is only that the file does not say which is which, and that
`tools/audit_inert_mechanisms.sh` said the opposite about two of them.

---

## A. Read in code, acoustically inert

### `audibility_floor` = 0.05 — CONFIRMED, high confidence

Read once, `live_factory.scd:2927`, inside the per-machine weight loop:

```
v = v * (1 + ((policy["audibility_influence"] ? "1.0").asFloat
    * ((audib[m] ? 0.5).max((policy["audibility_floor"] ? "0.05").asFloat) - 1)));
```

`audibility_influence` is `0.0` in policy.json. The bracket the floor lives in is
multiplied by it, so the whole expression is `v * (1 + 0) = v` for every machine,
at every window, whatever the floor is set to. This is arithmetic on one line and
there is no second read site. The floor is not merely inert — so is the learned
audibility score `audib[m]` it clamps, which is the larger finding at this site:
the audibility learner runs, writes `mutable/audibility.json`, and is multiplied
out of selection.

*Overturned by:* `audibility_influence` becoming non-zero. Then the floor acts
immediately and nothing else need change.

### `max_live_voices` = 14 — CONFIRMED, medium-high confidence; **the reasoning given was wrong**

The ceiling is at `live_factory.scd:4295-4296`, at the top of `voiceKeeper`,
which loops every 0.25 s:

```
ceiling = (policy !? { policy["max_live_voices"] } ? "6").asInteger;
while { live.size > ceiling } { { live[0][0].stop }.try; live.removeAt(0) };
```

The claim as given was that `live.size` is bounded above by
`nVoices = clip(voices_min, voices_max) = [1,8]`. **That is not true**, and the
correct bound has to be derived, because the fill loop is not the only thing that
adds to `live`:

- `live.add` occurs at exactly two sites, 4239 and 4267, both inside `fireVoice`.
- `fireVoice` is called from two places in the keeper tick, in this order:
  the **slot loop** (4335 ff.), which fires into any layer with `held < 1`, and
  the **top-up loop** (4461), `while { live.size < nVoices }`.
- The slot loop runs *before* the top-up loop, so slot voices genuinely push
  `live.size` above `nVoices`.

The bound comes from three facts. `e[3]` is always `layerOf(m)`, which returns
`weights[m]["layer"]` or `"micro"`; every layer value in `weights.json`
(11 micro / 5 mid / 4 macro) and `written_machines.json` (148 macro / 12 mid /
9 micro) is one of the three, so the per-layer counts partition `live.size` and at
most one slot voice per layer can be outstanding at a time — three. The top-up
loop leaves `live.size` at `nVoices ≤ voices_max = 8`. And each `fireVoice` adds
exactly one entry: runtime machines add one `Pbindf(...).play` (4239), and the
class path (4267) iterates whatever `h.stateMachine` returns, but every branch of
`stateMachine` in `lib/Handler_Local.sc` ends in a single `.play`.

So `live.size ≤ 8 + 3 = 11 < 14`, and `while { live.size > 14 }` never executes.

Confidence is medium-high rather than high because the bound rests on
`h.stateMachine` returning one player on every branch — the `pl.isKindOf(Collection)`
handling at 4266 exists precisely because the author was not certain of that. Four
class machines (`hm`, `dr`, `gp`, `bu`) take that path. At two players per call the
bound becomes 15 and the ceiling would begin to fire.

Note what this does **not** say: the ceiling is not structurally dead, it is dead
at 14. The in-code default is `"6"`, and at 6 the ceiling would trim on most
ticks. This is a knob whose value, not whose wiring, disabled it.

*Overturned by:* an `UNTRACKED` or multi-player class machine raising the bound
past 14; by `voices_max` above 11; or by one `LIVE=` reading above 14 in a window
log. No window log was available in this checkout (`workdir_music/renders/` is not
present), so this verdict is static only.

### `collapse_after` = 600 — CONFIRMED, high confidence; **the threshold cited was wrong**

`live_factory.scd:2678-2679`, inside the `/desc` OSCdef:

```
if (amp < 0.00005) { silentWindows = silentWindows + 1 } { silentWindows = 0 };
if (silentWindows > (policy["collapse_after"] ? "600").asInteger) { ... running = false };
```

The claim said the threshold was 300. **It is 600**, and has been 600 in all five
`policy.json.bak_*` snapshots on disk. The correction makes the guard twice as
hard to trip, so it strengthens the verdict rather than weakening it.

Two further points the claim did not make. `silentWindows` does not count
windows: the OSCdef fires on `onset + Impulse.kr(4)` (line 2099), so the counter
is in **reports**, at four or more per second — 600 of them is under 150 s of
unbroken silence, not 600 windows. And the reset is total: one report at or above
0.00005 sets the counter to zero, so the guard requires 600 *consecutive* silent
reports with not one above the floor.

The 15.5 h measurement behind the claim (longest run of 3) could not be
reproduced here — the run logs are not in this checkout. The structural argument
stands without it: at four reports per second, a factory that is audible at any
point in a 150 s span cannot reach 600.

*Overturned by:* a `COLLAPSE` line in any window log, or a measured consecutive
silent-report run approaching 600.

### `novelty_threshold` = 0.34 — CONFIRMED as acoustically inert, high confidence; **"nothing downstream reads it" is too strong**

`live_factory.scd:1438`, at section close. Its two outputs are a `NOVEL` line in
the window log and one JSON object appended to
`mutable/charter_proposals.jsonl`. Nothing in the factory reads either: the
proposal is written, the block ends, and no later expression in `live_factory.scd`
touches `charter_proposals.jsonl` except the second, independent `VOICE_NOVEL`
writer thirty lines down.

But `charter_proposals.jsonl` **is** read, by `tools/review_proposals.py` and
`tools/triage_proposals.py`, and by `tools/factory_status.py` and
`tools/checkpoint.py`. Those are architect-run tools, not the factory, and that is
by design — the comment above the block says so: *"The factory proposes; the
architect commits."* So the correct verdict is that the threshold cannot change
the sound of the run that computes it, **not** that it feeds nothing. A record
that said "nothing downstream reads it" would be wrong in a way that matters,
because this is the one key of the ten whose inertness is a governance boundary
rather than an oversight.

*Overturned by:* any charter edition that adopted a proposal minted by this
threshold, which would make its calibration retroactively load-bearing.

---

## B. Shadowed fallbacks — a live-looking value that is never consulted

SuperCollider's `?` is left-associative, so
`policy["a"] ? policy["b"] ? "lit"` parses as `(policy["a"] ? policy["b"]) ? "lit"`
and reaches `b` only when `a` is absent from policy.json. Both keys below sit in
that second position with every first-position sibling present.

### `continuity` = 0.5 — CONFIRMED, high confidence

Three read sites, one per layer:

```
1585:  policy["micro_continuity"] ? policy["continuity"] ? "0.5"
2304:  policy["macro_continuity"] ? policy["continuity"] ? "0.5"
2341:  policy["mid_continuity"]   ? policy["continuity"] ? "0.6"
```

policy.json has `micro_continuity = 0.9`, `macro_continuity = 0.75`,
`mid_continuity = 0.6`. All three siblings present, so `continuity` is unreachable
at all three sites. There is no fourth site — `grep` across `lib/*.sc` and every
`.scd` finds none. The remaining mentions in the factory are prose.

The trap is sharp: the `_continuity` docstring in policy.json is the longest and
most emphatic in the file — *"This is the parameter that decides whether the
output is concatenative synthesis or shuffling"* — and it documents a key the
factory cannot see. A reader running an ablation on `continuity` would get a null
and a wrong explanation for it.

### `voice_span` = 20.0 — CONFIRMED, high confidence

One read site, `live_factory.scd:3698-3699`, inside `fireVoice`:

```
span = ((policy["voice_span_" ++ lay] ?? { policy["voice_span"] } ? "14.0").asFloat) * rrand(0.7, 1.4)
```

`lay` is `layerOf(m)`, which returns a layer string from `weights.json` or
`written_machines.json` and **defaults to `"micro"`** when neither has one. Every
layer value in both files is `macro`, `mid` or `micro`, and policy.json carries
`voice_span_micro = 12.0`, `voice_span_mid = 40.0`, `voice_span_macro = 90.0`. So
`policy["voice_span_" ++ lay]` is non-nil on every call, `??` short-circuits, and
`voice_span` is never evaluated.

Note the second trap: even if it were reached, the literal fallback is `"14.0"`,
not the 20.0 in the file. The two numbers disagree and neither is used.

*Both overturned by:* deleting a per-layer sibling from policy.json, or by
`layerOf` returning a layer string with no `voice_span_` sibling — which would
require a new layer name in `weights.json`.

---

## C. Never read at all — which is not the same thing

A key nothing reads and a key read-but-inert are different failures, and
conflating them was itself a finding here: `tools/audit_inert_mechanisms.sh`
reported both `section_operator_weight` and `self_ingest_weight` as **READ**.

### `section_operator_weight` = 0.0 — CONFIRMED comment-only, high confidence

Exactly one occurrence in `live_factory.scd`, **line 931**, and it is prose:

```
// ZERO INFLUENCE. It observes, computes and logs; it steers nothing.
// section_operator_weight exists in policy.json and defaults to 0.0.
```

Zero occurrences after comment stripping, and the same after stripping
`live_factory_instrumented.scd` and `live_factory_slots.scd`. So `secOp` (932) is
built and updated, and there is no expression anywhere that could consult a
weight for it. Setting this key to 1.0 would change nothing. The comment is
accurate; the audit read the comment as the wiring.

### `self_ingest_weight` = 0.75 — CONFIRMED comment-only in the factory, high confidence

One occurrence in `live_factory.scd`, **line 1735**, also prose — and also a line
naming it as unread: *"Same family as self_ingest_weight unread, PatternGrammar
unwired"*. It **is** read, by twelve files under `tools/` including
`self_ingest.py`, `assemble_play_corpus.py` and `calibrate_ingest_weight.sh`, so
it is a live knob for the corpus pipeline and a dead one for the factory. This is
the key `2026-09-19_four_results.md` §1 already identified as *"the knob the
running factory never reads"* — the dwell finding and this audit meet here.

### `dwell_max` = 1, `dwell_min` = 1 — CONFIRMED, high confidence, NEW

Absent from `live_factory.scd` entirely, and absent from every `.py`, `.sh`,
`.sc` and `.scd` in the repository outside `policy.json` itself. Dwell is read
per layer at 3066-3067:

```
lo = (policy["dwell_" ++ lay ++ "_min"] ? "1").asInteger;
hi = (policy["dwell_" ++ lay ++ "_max"] ? "1").asInteger;
```

with literal defaults, no `?` chain back to the unsuffixed pair. These are not
shadowed fallbacks — they are orphans left by the move to per-layer dwell, and
their values (1, 1) do not match any per-layer pair.

### `tonic_drift_oct` = 0.25 — CONFIRMED, high confidence, NEW

Absent from `live_factory.scd` and from the whole repository outside
`policy.json`. `tonic_centres`, `tonic_pull` and `tonic_windows` are all read in
code; this fourth member of the family is not.

*All four overturned by:* one grep. They are the cheapest claims in this record
and the least interesting, which is why they survived.

### Adjacent, and recorded rather than asserted

Two further keys are read in code and set to zero, so every branch behind them is
dead at this policy. Both say so in the comment above them, so neither is an
oversight, and neither is counted in the ten:

- **`world_pull` = 0.0** gates `if (wp > 0 and: { world.notNil } ...)` at 3469.
  The entire world-listening influence path is off. The comment: *"world_pull
  defaults to 0.0 so a run can LOG the world without being steered by it, which
  is the control arm the Day 1 acceptance test needs."*
- **`dsp_dly` = 0.0** feeds `\dly, Pseg(Pseq([0.0, ddly * dall * 0.7], inf) ...)`
  at 4209. The macro delay stage is always 0.0.

Also recorded: `capture_rotate_s`, `grammar_depth`, `ingest_floor_db`,
`life_floor` and `machine_grammar` are absent from `live_factory.scd` but are read
elsewhere — `ingest_floor_db` by `self_ingest.py`, `capture_rotate_s` by
`calibrate_ingest_weight.sh`, and the other three only by
`live_factory_instrumented.scd`. `run_live.sh:186` substitutes
`"${FACTORY_SRC:-$ROOT/tools/live_factory.scd}"`, so the shipped factory is
`live_factory.scd` and the instrumented variant runs only when `FACTORY_SRC` is
set by hand. `life_floor`, `grammar_depth` and `machine_grammar` are therefore
instrument-only keys living in the live policy file.

---

## What the audit was doing wrong, and what it does now

`tools/audit_inert_mechanisms.sh` asked `grep -c "$K" live_factory.scd`.
`live_factory.scd` is roughly 40% prose — 4,848 lines, 1,790 non-blank after
comment stripping. Two of the three mechanisms the audit was written to
investigate appear in that file **only inside comments saying they steer
nothing**, and the audit reported both READ. It was returning a clean bill
sourced from the sentence admitting the fault.

A second bug, quieter: `N=$(grep -c "$K" "$FACTORY" || echo 0)`. `grep -c` prints
`0` **and** exits 1 on no match, so `N` became the two-line string `"0\n0"` and
`[ "$N" -gt 0 ]` raised `Illegal number` under `sh`. Every genuinely-unread key
reached its NOT READ line through an error path rather than a test.

Fixed by `tools/strip_sc_comments.py` (handles `//`, nesting `/* */`, string
literals and `$char` literals; preserves line numbers so `grep -n` on the output
still names the true source line) plus three changes to the audit:

1. comments stripped before searching;
2. concatenated keys resolved — `policy["rest_" ++ lay]` and
   `policy["voice_span_" ++ lay]` reach nineteen keys no literal search can see,
   and without this the fix would have traded false READs for false NOT-READs;
3. all 115 non-underscore keys checked, not a hand-written list of eight chosen
   from the three mechanisms already suspected.

A new section 6 asks the harder question — not "is the key in code" but "can the
value act" — by flagging keys read in the same expression as a zero-valued key,
and keys read in code whose own value is zero. It is a lead generator, not a
proof: of its four expression-adjacency hits, one is real (`audibility_floor`) and
three are adjacent `var` declarations. It prints the line so the reader can tell.

### Status changes

| key | before | after |
|---|---|---|
| `section_operator_weight` | READ (1 reference) | **COMMENT ONLY** |
| `self_ingest_weight` | READ (1 reference) | **COMMENT ONLY** |
| `judge_weight`, `score_charter` | NOT READ (via `Illegal number` error) | not policy keys; dropped from the key scan |
| `judges`, `charter`, `attention_weight`, `operator_weight` | READ | unchanged in substance; `attention_weight` and `operator_weight` now CODE, `judges`/`charter` are substrings of no policy key |
| 19 `dwell_*` / `rest_*` / `voice_span_*` keys | never asked | **CONCAT** — would have been false NOT-READ under a naive comment fix |
| `continuity`, `voice_span` | never asked | **SHADOWED** |
| `dwell_max`, `dwell_min`, `tonic_drift_oct` | never asked | **NEVER MENTIONED** |
| `capture_rotate_s`, `grammar_depth`, `ingest_floor_db`, `life_floor`, `machine_grammar` | never asked | **NEVER MENTIONED** in the factory; four read elsewhere |

Final counts over 115 keys: 84 CODE, 19 CONCAT, 2 SHADOWED, 2 COMMENT ONLY,
8 NEVER MENTIONED.

---

## The shape

The project has now met "built and inert" about a dozen times, and this pass adds
a variant it had not named: **inert because a sibling key exists**. `continuity`
and `voice_span` are not switched off, not multiplied by zero, and not unwired.
They are shadowed by per-layer keys added later, and the only evidence of it is
one `?` in a line that reads like a default. The measure that missed them missed
them for the same reason the four measures in `2026-09-19_four_results.md` were
wrong: it never asked what it reports when nothing is there.
