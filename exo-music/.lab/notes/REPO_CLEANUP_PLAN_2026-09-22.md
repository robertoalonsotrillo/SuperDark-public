# Repository cleanup plan, 22 September 2026

Read-only survey of `exo-music/` on branch `main` of `robertoalonsotrillo/SuperDark`. Nothing was moved, deleted, committed or pushed. This file is the only thing written.

## 0. One thing to know before any `git mv`

The git root is `/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK`, one level above `exo-music/`. `exo-music/` is a subtree of that repository (1,253 of its 1,436 tracked files), and the only `.gitignore` that git consults for it is the root one, whose patterns carry the `exo-music/` prefix. `exo-music/.gitignore` also exists (three lines, the `grains_play_*` symlinks) and is honoured for paths beneath it. Every command below is written to be run from `exo-music/`; git accepts paths relative to the current directory, so `git mv docs/records .lab/records` works from there. `.gitignore` additions go in the root file with the prefix.

The root holds the August phase of the project: `README.md` (20 Aug, "a recursively self-improving agent harness, pointed at sound", the Exo-agent-edits-Archon experiment), `CLAIMS.md`, `EVIDENCE.md`, `REFERENCES.md`, `docs/00..15-*.md` (17 design docs of that phase), `notes/` (116 files: run findings, `RESUME-HERE.md`, `PLAN.md`, a session summary), `REPLICA_KIT/`, `deploy/`, `SOURCES-MD/`, `figures/`, `spectrogram.png`, `listening-test.html`, the `exo` submodule and an empty file named `0.99` (a stray shell redirect, 16 Sept). That layer is outside the brief. Two things about it bear on this plan: the root README is what GitHub shows first, and it describes the August system, so the new `exo-music/README.md` drafted in section 5 will sit one click below a stale page unless the root README is also replaced or reduced to a pointer; and `notes/` at the root is the same kind of working record as `exo-music/docs/measurements/`, so the same hidden-folder treatment applies there if he wants one public face for the whole repository. `exo-music/` is treated below as the unit of work.

Working tree at survey time: 8 modified tracked files (`lib/MachineWriter.sc`, `lib/PatternGrammar.sc`, `mutable/bridged.json`, `mutable/memory.json`, `mutable/written_machines.json`, `tools/live_classes/MachineWriter.sc`, `tools/live_classes/TransferOperator.sc`, `tools/live_factory.scd`) and 17 untracked paths (`harness/n_arms_260919_141544.json`, `harness/superseded_260920_coverage_veto/` with 63 files, `tools/extract_fragments.py`, `workdir_music/mutable/factory_knobs.json`, `workdir_music/mutable/fragments.json`, new machines under `mutable/machines/`, six at the start of the survey and twelve by its end). The factory was running (`memory.json` and `factory_knobs.json` modified at 10:42). Do the moves with the factory stopped; see section 4.

## 1. Inventory

### 1.1 Tracked files by top-level directory (`git ls-files`, sizes on disk)

| path | files | bytes | what |
|---|---|---|---|
| `workdir_music/` | 773 | 13,849,109 | the factory: classes, source, mutable layer, stream, plus backups, shadows and logs |
| `harness/` | 200 | 23,335,684 | evaluation harness state; 187 of the 200 files and 23.0 MB are two run-bundle directories |
| `tools/` | 154 | 1,315,368 | Python and shell tooling, 12 SuperCollider tests |
| `docs/` | 87 | 5,649,043 | 26 top-level notes, 54 measurement files, 7 day records; 5.1 MB is two PNGs |
| `workdir/` | 15 | 520,768 | phase-1 offline Archon rig (August), incl. a 391 KB `_tmp.osc` |
| `variants/` | 9 | 156,886 | phase-1 hand-written `BehaviorTrimmed` variants |
| `frozen/` | 6 | 335,797 | sealed scorers, manifest, seal log, MERT reference |
| `prompts/` | 1 | 3,483 | `me.md`, the charter prompt given to the August agent |
| root files | 8 | 28,821 | `README.md`, `DECISIONS.md`, four Dockerfiles, `drun.sh`, `.gitignore` |
| total | 1,253 | 45,195,000 | |

Inside `workdir_music/` (773 files):

| path | files | bytes |
|---|---|---|
| `mutable/` | 203 | 5,360,414 |
| `mutable.before_ck_260915_165834_champion-rq25-fullstack/` | 198 | 2,177,380 |
| `mutable_shadow/` | 210 | 811,688 |
| `tools/` | 99 | 1,324,528 |
| `stream/` | 16 | 1,325,559 |
| `lib/` | 9 | 137,170 |
| `behaviour/` | 3 | 52,671 |
| `pilot_*/` (4 dirs) | 9 | 11,857 |
| `mnull_2500.json` | 1 | 2,561,504 |
| `events.csv`, `temporal_regimes.json` | 2 | 61,330 |
| 20 `*.log` files at the top of `workdir_music/` | 20 | 20,000 |
| `grains_lic_ev`, `grains_lic_mid`, `grains_lic_macro` | 3 | symlinks to `/Volumes/FMA/superdark/corpora/` |

Inside `harness/`: 13 top-level files (`measures.json`, `release_policy.v1.json`, `sealed_scorers.txt`, `partition_260919.json`, `harness_journal.jsonl`, eight `two_arms_*`/`n_arms_*` summaries), `superseded_260919_sliced_wrong/` (124 files, 23.0 MB, 19 of them `arm_windows.log` at about 1.2 MB each) and `smoke_debris_260918/` (63 files, 263 KB).

### 1.2 Largest tracked files

| bytes | path |
|---|---|
| 2,564,230 | `docs/measurements/hour_260903_1741.png` |
| 2,561,504 | `workdir_music/mnull_2500.json` |
| 2,560,313 | `docs/measurements/hour_260904_0149.png` |
| 1,662,270 | `workdir_music/mutable/memory.json` |
| 1,341,506 | `workdir_music/mutable/memory.json.bak_prune_260918_085207` |
| 1,211,391 and 18 more between 0.55 and 1.21 MB | `harness/superseded_260919_sliced_wrong/run_*/arm_windows.log` |
| 1,186,439 | `workdir_music/mutable/memory.json.before_trace_migration_260915_211005` |
| 1,186,038 | `workdir_music/mutable.before_ck_260915_165834_champion-rq25-fullstack/memory.json` |
| 1,086,265 | `workdir_music/stream/compare_R2.png` |
| 390,940 | `workdir/renders/_tmp.osc` |
| 299,745 | `frozen/mert_reference.npz` |
| 298,799 | `workdir_music/tools/live_factory.scd` |
| 226,927 x3 | `memory_old_corpus_260827.json` in `mutable/`, `mutable_shadow/` and the `before_ck` copy |
| 152,388 | `workdir_music/mutable_shadow/memory.json` |
| 132,385 | `workdir_music/tools/live_factory_instrumented.scd` |
| 131,947 | `workdir_music/mutable/kernel_journal.jsonl` |
| 125,894 | `workdir_music/tools/live_factory_slots.scd` |
| 98,419 | `workdir_music/tools/live_factory.scd.bak_110833` |

`memory.json` is rewritten by the factory every window and is tracked, so every commit made while it runs carries a fresh 1.6 MB blob; `.git` is 62 MB after 352 commits. That is a policy question (the mutable layer is the record, per the current README), noted here and left to him. `tools/checkpoint.py` exists for deliberate snapshots and `harness/checkpoints/` is already ignored.

### 1.3 Tracked material that should not be

No `.DS_Store`, no audio, no credentials and no `__pycache__` are tracked; the root `.gitignore` covers them and `tools/secret_scan.py` exists. The three `.DS_Store` files on disk (`.`, `workdir_music/`, `workdir_music/stream/`) are ignored. What is tracked and should not be, in groups:

Hand-made backups (13 files, 3.1 MB):
`workdir_music/mutable/policy.json.bak_pregate`, `.bak_pre_mc`, `.bak_pre_aw015`, `.bak_pre_aw03`, `.bak_two_arms`; `mutable/kernel_edition1.json.bak`; `mutable/memory.json.bak_prune_260918_085207`; `mutable/memory.json.before_trace_migration_260915_211005`; `mutable/memory_old_corpus_260827.json` (and its two copies); `workdir_music/tools/live_factory.scd.bak_110833`; `workdir_music/behaviour/BehaviorTrimmed.sc.baseline`, `.v1`; `mutable/weights_before_mid.json` (no reader in the codebase).

A whole pre-checkpoint copy of the mutable layer (198 files, 2.2 MB): `workdir_music/mutable.before_ck_260915_165834_champion-rq25-fullstack/`. Made by hand on 15 Sept before the first checkpoint; `tools/checkpoint.py` now does this job into the ignored `harness/checkpoints/`.

The shadow instance's state (210 files, 0.8 MB): `workdir_music/mutable_shadow/`. Per `run_live.sh` and the README, each instance owns its mutable layer; the shadow's is scratch.

Generated class directories (20 files, 288 KB): `workdir_music/tools/live_classes/` is deleted and rebuilt from `lib/` and `behaviour/` at every boot (`run_live.sh:79-88`, `rm -rf "$LIVE"; mkdir -p; cp`), with three files patched by `sed`; `workdir_music/tools/shadow_classes/` is the same for the shadow instance. Both show as modified whenever the factory boots. `offline_classes/` (6 files) differs: nothing regenerates it, `offline_conf.yaml` points at it, and two of its files differ from `lib/`; it is the phase-1 offline class path and stays as system.

Logs (23 files): the 20 `workdir_music/*.log` (already matched by the ignore pattern `exo-music/workdir_music/*.log`, tracked anyway because ignore patterns do not untrack), `workdir_music/tools/live_run.log`, `workdir_music/pilot_overnight_0901_0220/snapshots.log`, plus `docs/measurements/2026-09-06_fill_stall_excerpt.log` (an excerpt cited by a record; moves with the record).

Renders and caches: `workdir/renders/_tmp.osc` (391 KB; `*.osc` is ignored, still tracked), `workdir_music/stream/compare_R2.png` (1.1 MB, a spectrogram comparison with no reference from any file).

Harness debris: `harness/smoke_debris_260918/` (63 files; nothing references it). `harness/superseded_260919_sliced_wrong/` is different: `tools/test_coverage_metric.py:39` and `tools/test_early_warning.py:54-58` read two of its `arm_windows.log` files as fixtures and `tools/dwell_frozen_partition.py:71,133` documents it. It is 23 MB of test fixture. Keep it tracked, or move the two logs the tests need into `tools/fixtures/` and untrack the rest; either way the plan below leaves it alone and stops the pattern from recurring.

Pilot outputs (9 files): `workdir_music/pilot_20260831_2036/`, `pilot_20260901_0210/`, `pilot_20260901_0215/`, `pilot_overnight_0901_0220/`. Their `factory.log` and `ingest.log` are already ignored; the alignment and snapshot files are the same class.

Null data with no reader: `workdir_music/mnull_2500.json` (2.5 MB; no script reads or writes that name).

"grains_play_* 2" directories: `workdir_music/grains_play_ev 2/` (52 entries), `grains_play_mid 2/`, `grains_play_macro 2/`. Untracked and already ignored by `exo-music/workdir_music/grains_*/`. They are iCloud conflict copies from 10 Sept, the night `start_loop.sh` replaced the directories with symlinks. Delete by hand; git is not involved.

### 1.4 What `.gitignore` already excludes

Root `.gitignore` (56 lines): `.DS_Store`, `node_modules/`, `.env*`, `*.wav`/`*.aiff`/`*.aif` (with `!notes/runs/**/*.wav`), `__pycache__/`, `.venv/`, `SOURCES/*.pdf` and `*.docx`, `renders/**` audio, `exo-music/.e2venv/`, `exo-music/workdir_music/renders` (both spellings), `exo-music/workdir_music/grains_*/`, `exo-music/workdir_music/*.log`, `grains_*_raw/`, `grains_*_toremove/`, `stream/.stream_secrets`, `stream/icecast.xml`, `stream/logs/`, `stream/bisect*/`, `*.osc`, `pilot_*/factory.log`, `pilot_*/ingest.log`, `exo-music/harness/runs/`, `exo-music/harness/checkpoints/`, `restore/`. `exo-music/.gitignore` adds the three `grains_play_*` symlinks.

The two credential files are ignored and are not tracked; confirmed by `git ls-files`. The `grains_lic_*` entries are tracked as symlinks to an absolute path on the SSD, which is harmless on this machine and dangling on any other; `start_loop.sh` reads `$W/grains_lic_$L` and does not create them.

Untracked and not ignored (will enter the next `git add -A`): `harness/n_arms_260919_141544.json`, `harness/superseded_260920_coverage_veto/` (63 files, its two `arm_audio.wav` ignored), `tools/extract_fragments.py`, `workdir_music/mutable/factory_knobs.json`, `workdir_music/mutable/fragments.json`, the new `mutable/machines/*.scd`. The first and second are the same class as the debris above; the rest are the 20 to 22 Sept work and belong in.

## 2. Classification

### 2.1 Top-level paths

| path | class | note |
|---|---|---|
| `README.md` | (a) system | stale since 3 Sept; replaced by section 5 |
| `DECISIONS.md` | (b) working record | 19 Aug decisions and three parked items, "Roberto asked to be reminded" |
| `Dockerfile`, `Dockerfile.agent`, `Dockerfile.agent-e3`, `Dockerfile.agent-e3.nocheck`, `drun.sh` | (a) system, phase 1 | the sandbox images for the August offline rig; `drun.sh` mounts `workdir_music` and the SSD |
| `.gitignore` | (a) system | three lines; the root file does the work |
| `prompts/me.md` | (b) working record | the charter prompt handed to the August agent |
| `frozen/` | (a) system | `MANIFEST.json`, `SEAL_LOG.jsonl`, `sealed_scorers` copies, `mert_reference.npz` |
| `harness/` | (a) system, with (c) debris | `measures.json`, `release_policy.v1.json`, `sealed_scorers.txt`, `partition_260919.json`, `harness_journal.jsonl`, the `two_arms_*`/`n_arms_*` summaries are system; `smoke_debris_260918/` is debris; `superseded_260919_sliced_wrong/` is a test fixture |
| `tools/` | (a) system | 154 files; every one is tooling, tests or a measurement script cited by a record |
| `variants/` | (a) system, phase 1 | nine `BehaviorTrimmed` variants from the August ladder |
| `workdir/` | (a) system, phase 1 | offline Archon rig; `_tmp.osc` is (c) |
| `workdir_music/lib/` | (a) system | the nine classes |
| `workdir_music/behaviour/` | (a) system | `BehaviorTrimmed.sc`; the `.baseline` and `.v1` copies are (c) |
| `workdir_music/tools/` | (a) system, with (c) | the factory source and its runner, tests, render and probe scripts; `live_classes/`, `shadow_classes/`, `live_factory.scd.bak_110833`, `live_run.log` are (c). `live_factory_instrumented.scd`, `_slots.scd`, `_operator_WIP.scd` are three earlier bodies of the factory kept beside the live one; one measurement record cites the first two, so they stay as system history |
| `workdir_music/mutable/` | (a) system | the ceded layer and the append-only records; the `.bak*`, `.before_*`, `memory_old_corpus_*` files inside it are (c) |
| `workdir_music/mutable_shadow/` | (c) | scratch state of the shadow instance |
| `workdir_music/mutable.before_ck_*/` | (c) | hand-made pre-checkpoint copy |
| `workdir_music/stream/` | (a) system | splitter, encoder, publisher, `player.html`, `panel.js`, `panel.css`, the WordPress block and its two dated copies; `compare_R2.png` is (c) |
| `workdir_music/pilot_*/` | (c) | pilot outputs |
| `workdir_music/*.log`, `mnull_2500.json` | (c) | |
| `workdir_music/events.csv`, `temporal_regimes.json` | (a) system | inputs to `states.scd` and `derive_machines.py` |
| `docs/` | mixed | see 2.2 |

### 2.2 `docs/`, file by file

Top level (26). "Keep" means it stays under `docs/` as canonical documentation; "move" means working record.

| file | verdict | what it is |
|---|---|---|
| `HARNESS.md` | keep | the harness: checkpoint, seal, measure registry, release policy, what the rig caught; cites Exo and states the non-revisability settlement |
| `WORLD_CHANNEL_DESIGN.md` | keep | the world channel: transport, source, consumption rule; the one input the factory did not produce |
| `PROGRAMME_AMENDMENT_2026-09-15.md` | keep | amends the Class 3 programme of 22 Aug (Target 5, the ear's standing veto); the programme itself lives outside the repo in `GRF_2027_28/31_Class3_Roadmap.md` |
| `PATH_TO_A_FULLY_ONLINE_FACTORY.md` | keep | what "online" means on three axes and what would close each; the roadmap for the online question |
| `VERSION_READOUT_DESIGN.md` | move | design and pre-registration of the spectral readout for the versioning strand; cited as `prereg` in `harness/measures.json` |
| `THE_REWARD_CHANNEL.md` | move | design note, decision 6 of the metrics review: three weak signals admitted |
| `HARMONY_AS_A_HARNESS_MEASURE.md` | move | design note, decision 5 of the metrics review |
| `LAMBDA_NOVELTY_AS_CURRENCY.md` | move | design note: novelty as the unit of account |
| `NESTING_THE_THREE_TIMESCALES.md` | move | design note written while the five-knob sequence ran; four coupling mechanisms weighed |
| `SECTION_SPREAD.md` | move | the section-spread mechanism, built in answer to the recurrence result |
| `METRICS_REVIEW_2026-09-18.md` | move | the metrics reviewed against the paper, for a discussion; lists decisions to be made |
| `BISECTION.md` | move | the bisection ladder that found shellac crackle in the corpus, 30-31 Aug; cited by six tools |
| `COVERAGE_PROPOSALS_REFUSED.md` | move | why the 89 coverage proposals were refused, with a same-day correction; cited by all 89 lines of `charter_decisions.jsonl` |
| `M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md` | move | finding: m7 measures the operator's age; cited as `evidence` in `charter.json` |
| `THE_KERNEL_IS_BROAD_BUT_NOT_DEEP.md` | move | finding from the kernel rehearsal; first person throughout |
| `PITCH_IS_A_COORDINATE_NOT_A_FACULTY.md` | move | finding: the target walk is isotropic |
| `THE_SHARED_TABLE_HAS_NO_SOURCE.md` | move | finding from two shadow runs of the simultaneity work |
| `EXP_WEIGHT_M1_M7.md` | move | pre-registration, 1 Sept, self_ingest_weight against m1 and m7 |
| `EXP_WEIGHT_SWEEP.md` | move | pre-registration, 2 Sept, the weight sweep |
| `FRAGMENTATION_LEVERS.md` | move | 2 Sept: the drift into fragmentation and two wrong explanations, first person |
| `OVERNIGHT_2026-09-17.md` | move | overnight note written at 02:15 while the work ran |
| `RESUME_2026-09-16.md` | move | resume point at the end of 16 Sept |
| `RUNBOOK_attention_and_mdprime.md` | move | step-by-step runbook for one comparison, with absolute paths on this machine |
| `DIAGRAM_UPDATE_BRIEF.md` | move | a brief to paste to an agent, with absolute paths |
| `diagram_prompts.md` | move | two Claude Design prompts for the GRF 2027/28 figures |
| `diagram_prompt_3_mechanisms.md` | move | a third Claude Design prompt, the mechanism chain |

The six design notes (`VERSION_READOUT_DESIGN`, `THE_REWARD_CHANNEL`, `HARMONY_AS_A_HARNESS_MEASURE`, `LAMBDA_NOVELTY_AS_CURRENCY`, `NESTING_THE_THREE_TIMESCALES`, `SECTION_SPREAD`) are the borderline. They are design reasoning a stranger could use, and they are also dated notes written mid-run in the first person. The brief classes design notes as working record, so they move; if he wants the reasoning public, keep them in `docs/` and drop the corresponding six lines from the move list and the four edits that touch them (section 4.2, entries for `measures.json:46`, `HARMONY:3`, `THE_REWARD_CHANNEL:3`, `SECTION_SPREAD:8`).

`docs/measurements/` (54 files, all move). Pre-registrations, results and incident records, each dated, each written before or after one run:

| file | what it is |
|---|---|
| `2026-09-03_1741_hour.md` + `hour_260903_1741.png` | the hour of 3 Sept, five changes measured; the PNG is its figure |
| `hour_260904_0149.png` | figure for the following night's hour (no `.md` beside it) |
| `2026-09-05_just_mode_prereg.md`, `_result.md` | just-intonation table as a contrast arm |
| `2026-09-06_fill_stall_excerpt.log` | log excerpt for the fill-stall incident |
| `2026-09-06_recurrence_prereg.md`, `_result.md` | the recurrence measure against a loop and 140 FMA artists |
| `2026-09-06_spread_first_run.md`, `2026-09-08_spread_two_hours.md` | section spread, first run and two hours |
| `2026-09-07_version_readout_first_result.md` | first spectral readout |
| `2026-09-10_full_vector_result.md` | the full descriptor vector; the day three changes went live together |
| `2026-09-15_attention_prereg.md`, `2026-09-16_attention_03_prereg.md`, `_attention_arms.md`, `_attention_result.md` | the attention comparison |
| `2026-09-15_fill_stall_at_slow.md` | FILL_STALL at slow dwell |
| `2026-09-15_macro_calibration.json`, `_macro_measure_prereg.md`, `_macro_measure_result.md` | M-A and M-B, the macro measures |
| `2026-09-15_mc_isolation_blocked.md` | the isolation run that fed its own channels |
| `2026-09-15_md_calibration.json`, `_partial_hold_prereg.md`, `_partial_hold_result.md`, `2026-09-16_partial_hold_prime_prereg.md` | M-D, partial hold |
| `2026-09-16_numerical_blowups.md` | the blow-ups, before the root cause |
| `2026-09-16_reward_channel_prereg.md` | reward channel pre-registration |
| `2026-09-17_clicking_verdict_reexamined.md` | the clicking verdict revisited |
| `2026-09-17_m1_driving_not_vacuous.md`, `_m7_reads_the_wrong_column.md`, `_why_lambda2_is_one.md` | three metric findings |
| `2026-09-17_null_prereg.md`, `2026-09-18_null_result.md` | the null arm |
| `2026-09-17_scsynth_died_and_nothing_noticed.md` | incident; cites a `docs/wip/*.patch` that is not tracked |
| `2026-09-17_threshold_provenance_audit.md` | where every threshold came from |
| `2026-09-18_charter_edition_7_proposal.md` | the edition 7 proposal; cited by `charter.json` and `SEAL_LOG.jsonl` |
| `2026-09-18_coverage_metric_prereg.md` | the one coverage metric; cited by `coverage_metric.py` |
| `2026-09-18_early_warning_veto_prereg.md`, `2026-09-19_early_warning_saturation.json` | early warning as a veto |
| `2026-09-18_factory_one_had_no_route.md`, `_the_run_was_unwatched.md` | two incidents of 18 Sept |
| `2026-09-18_the_operator_carries_a_dead_state_space.md` | finding; cited by `prune_dead_operator_cells.py` |
| `2026-09-18_three_knobs_prereg.md`, `2026-09-19_three_knobs_result.md` | three knobs |
| `2026-09-19_five_knobs_prereg.md`, `2026-09-20_five_knobs_result.md`, `2026-09-19_four_results.md` | five knobs, ten arms |
| `2026-09-19_read_but_inert_policy_keys.md` | the inert-key audit |
| `2026-09-20_factory_consumes_factory_prereg.md`, `_knobs_to_factory_prereg.md`, `_four_steps.md`, `_the_attractor.md` | the 20 Sept work; the scheduled task reads two of these |
| `evidence/2026-09-18_1028_factory_log_grey_count_error.txt`, `evidence/2026-09-18_1028_start_log.txt` | raw evidence for the 18 Sept incidents |

`docs/records/` (7 files, all move): the seven records of 16 Sept, `blowup_named`, `blowup_root_cause`, `drone_gain_refuted`, `harness_first_real_use`, `request_channel`, `the_day`, `voice_probe_live`. Day logs, first person ("both mine", "I should have run").

## 3. Reference check

Method: `git grep` over every tracked file under `exo-music/` for each path proposed to move, plus the scheduled task file. No script opens, stats or writes any `docs/` path; every hit is a string in a comment, a docstring, a JSON note field, a markdown link or a `prereg`/`source`/`evidence` field that `measure_registry.py`, `seal_rig.py` and `review_proposals.py` print and never resolve. Nothing breaks at runtime if a string goes stale. The edits below are for the record's sake.

Hits that must NOT be edited, and why:

Append-only records: `workdir_music/mutable/charter_decisions.jsonl` (89 lines, all pointing at `docs/COVERAGE_PROPOSALS_REFUSED.md`) and `frozen/SEAL_LOG.jsonl:29` (`docs/measurements/2026-09-18_charter_edition_7_proposal.md`). Rewriting history to follow a rename is the thing these files exist to refuse. The old path is recorded in `.lab/README.md` instead.

Sealed scorers: `tools/sonic_variety.py:60,247`, `tools/macro_variety.py:2,199`, `tools/partial_hold.py:4,258,315,342`, `tools/reward_channel.py:94`. Each is in `frozen/MANIFEST.json`; changing one byte of a docstring changes its sha256 and `eval_rig.sh` refuses to run until `seal_rig.py adopt` records the change. A rename is not a reason to spend an adoption. Leave the nine strings; the `.lab/README.md` mapping covers them. (If he wants them clean, one `adopt` per file with reason "path rename, docs/ to .lab/, no logic change".)

Archived charter editions: `workdir_music/mutable/charter_edition_3.json:105`, `_4.json:107`, `_5.json:109` (`docs/M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md`). Prior editions are kept as they were.

Copies that will be untracked in section 4.4, so nothing to edit: the same strings inside `mutable.before_ck_*/`, `mutable_shadow/policy.json`, and the five `policy.json.bak_*`.

Root-level references to `exo-music/` paths (outside the brief, listed so nothing is missed): `README.md:103` and `.gitattributes:4-5` point at `exo-music/workdir/lib/` and `behaviour/` (not moving); `notes/runs/2026-08-19-14-score-calibration/findings.md:9,36` and `notes/runs/2026-08-20-20-agent-optimisation/findings.md:53` mention `exo-music/DECISIONS.md` and `exo-music/prompts/me.md` in prose. Those are the root working record; leave them.

References to the root `docs/0x-*.md` (`Dockerfile:11,41`, `tools/build_grains.py:18`, `tools/build_grains_onset.py:6`, `tools/score.py:6`, `tools/survival.py:24`, `workdir_music/tools/render_ladder.sh:5`, `DECISIONS.md:5,9,29` and the two `score.py` copies) point at `SUPERDARK/docs/`, which is not moving. Not affected.

### 3.1 The edit list (71 lines)

Format: `file:line  string found  ->  replacement`. Mapping is mechanical: `docs/measurements/` -> `.lab/measurements/`, `docs/records/` -> `.lab/records/`, the 22 top-level notes -> `.lab/notes/<same name>` except the three prompt files -> `.lab/prompts/<same name>`, `docs/DECISIONS.md` (a path that never existed; the file is `DECISIONS.md`) -> `.lab/notes/DECISIONS.md`.

Code comments and docstrings, unsealed (25):

```
tools/build_grains_onset.py:67        docs/BISECTION.md
tools/build_grains_onset.py:360       docs/BISECTION.md
tools/calibrate_ingest_weight.sh:28   docs/BISECTION.md
tools/coverage_metric.py:4            docs/measurements/2026-09-18_coverage_metric_prereg.md
tools/coverage_metric.py:25           docs/COVERAGE_PROPOSALS_REFUSED.md
tools/coverage_metric.py:291          docs/measurements/2026-09-18_coverage_metric_prereg.md   (a "prereg" value written into its JSON output)
tools/dwell_frozen_partition.py:6     docs/measurements/2026-09-19_three_knobs_result.md
tools/dwell_frozen_partition.py:100   docs/measurements/   (prefix only)
tools/early_warning.py:4              docs/measurements/2026-09-18_early_warning_veto_prereg.md
tools/prune_dead_operator_cells.py:143  docs/measurements/2026-09-18_the_operator_carries_a_dead_state_space.md   (written into kernel_journal as a note)
tools/read_weight_experiment.py:4     docs/EXP_WEIGHT_M1_M7.md
tools/read_weight_sweep.py:2          docs/EXP_WEIGHT_SWEEP.md
tools/score.py:19                     docs/DECISIONS.md
tools/suspend_m7.py:19                docs/M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md
tools/suspend_m7.py:65                docs/M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md   (an "evidence" value it writes into charter.json)
tools/test_coverage_metric.py:5       docs/measurements/2026-09-18_coverage_metric_prereg.md
tools/the_attractor.py:14             docs/measurements/2026-09-20_the_attractor.md
tools/transient_median_null.py:14     docs/BISECTION.md
tools/transient_median_null.py:368    docs/BISECTION.md
tools/transient_null.py:13            docs/BISECTION.md
tools/transient_null.py:45            docs/BISECTION.md
tools/transient_null.py:197           docs/BISECTION.md
tools/transient_null.py:237           docs/BISECTION.md
tools/transient_null.py:359           docs/BISECTION.md
tools/transient_null.py:504           docs/BISECTION.md
```

Phase-1 copies of the same comment (2): `workdir/tools/score.py:19` and `workdir_music/tools/score.py:19`, `docs/DECISIONS.md`.

The factory source (3), comments only; takes effect at the next boot, and `checkpoint.py diff` will report the file's hash changed:

```
workdir_music/tools/live_factory.scd:1399   docs/measurements/2026-09-06_recurrence_result.md
workdir_music/tools/live_factory.scd:3269   docs/measurements/2026-09-15_fill_stall_at_slow.md
workdir_music/tools/live_factory.scd:4594   docs/measurements/2026-09-03_1741_hour.md
```

Live configuration read by the factory and the scorer (6). `policy.json` is hot-reloaded every ten windows and `charter.json` is read by `score_charter.py`; these are `_`-prefixed note fields, no parameter changes, but edit them with the factory stopped:

```
workdir_music/mutable/charter.json:86    docs/measurements/2026-09-18_charter_edition_7_proposal.md
workdir_music/mutable/charter.json:135   docs/M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md
workdir_music/mutable/charter.json:241   docs/measurements/2026-09-18_charter_edition_7_proposal.md
workdir_music/mutable/policy.json:21     docs/measurements/2026-09-03_1741_hour.md
workdir_music/mutable/policy.json:23     docs/measurements/2026-09-15_macro_measure_prereg.md
workdir_music/mutable/policy.json:189    docs/measurements/2026-09-20_knobs_to_factory_prereg.md
```

Harness registry (13), `prereg`, `was` and `source` fields in `harness/measures.json`, printed by `measure_registry.py status`, never opened:

```
harness/measures.json:15    docs/measurements/2026-09-06_recurrence_prereg.md
harness/measures.json:32    docs/measurements/2026-09-06_recurrence_prereg.md
harness/measures.json:46    docs/VERSION_READOUT_DESIGN.md
harness/measures.json:77    docs/THE_KERNEL_IS_BROAD_BUT_NOT_DEEP.md
harness/measures.json:107   docs/measurements/2026-09-03_1741_hour.md
harness/measures.json:122   docs/measurements/2026-09-18_early_warning_veto_prereg.md
harness/measures.json:146   docs/measurements/2026-09-15_attention_prereg.md
harness/measures.json:157   docs/measurements/2026-09-18_coverage_metric_prereg.md
harness/measures.json:201   docs/measurements/2026-09-10_full_vector_result.md
harness/measures.json:211   docs/measurements/2026-09-15_macro_measure_result.md
harness/measures.json:216   docs/measurements/2026-09-15_partial_hold_prereg.md
harness/measures.json:221   docs/measurements/2026-09-15_partial_hold_result.md
harness/measures.json:231   docs/measurements/2026-09-16_reward_channel_prereg.md
```

Cross-references inside the moved files themselves and inside the two `docs/` files that stay (19). These move with their files; the strings are updated so a reader of `.lab/` is not sent to a path that no longer exists:

```
docs/HARNESS.md:270                                   docs/measurements/2026-09-10_full_vector_result.md   (HARNESS.md stays)
docs/HARNESS.md:271                                   docs/THE_KERNEL_IS_BROAD_BUT_NOT_DEEP.md             (HARNESS.md stays)
docs/DIAGRAM_UPDATE_BRIEF.md:10                       docs/diagram_prompts.md
docs/DIAGRAM_UPDATE_BRIEF.md:11                       docs/diagram_prompt_3_mechanisms.md
docs/HARMONY_AS_A_HARNESS_MEASURE.md:3                docs/METRICS_REVIEW_2026-09-18.md
docs/RESUME_2026-09-16.md:112                         docs/records/2026-09-16_the_day.md
docs/RUNBOOK_attention_and_mdprime.md:8               docs/measurements/2026-09-15_attention_prereg.md
docs/RUNBOOK_attention_and_mdprime.md:9               docs/measurements/2026-09-16_partial_hold_prime_prereg.md
docs/SECTION_SPREAD.md:8                              docs/measurements/2026-09-06_recurrence_result.md
docs/THE_REWARD_CHANNEL.md:3                          docs/METRICS_REVIEW_2026-09-18.md
docs/measurements/2026-09-15_macro_calibration.json:45      docs/measurements/2026-09-15_macro_measure_prereg.md
docs/measurements/2026-09-15_macro_measure_result.md:4      docs/measurements/2026-09-15_macro_measure_prereg.md
docs/measurements/2026-09-15_md_calibration.json:63         docs/measurements/2026-09-15_partial_hold_prereg.md
docs/measurements/2026-09-15_partial_hold_result.md:4       docs/measurements/2026-09-15_partial_hold_prereg.md
docs/measurements/2026-09-18_charter_edition_7_proposal.md:4    docs/METRICS_REVIEW_2026-09-18.md
docs/measurements/2026-09-18_charter_edition_7_proposal.md:105  docs/measurements/2026-09-18_charter_edition_7_proposal.md
docs/measurements/2026-09-18_coverage_metric_prereg.md:3    docs/METRICS_REVIEW_2026-09-18.md
docs/measurements/2026-09-18_coverage_metric_prereg.md:20   docs/COVERAGE_PROPOSALS_REFUSED.md
docs/measurements/2026-09-18_early_warning_veto_prereg.md:3 docs/METRICS_REVIEW_2026-09-18.md
```

The scheduled task, `/Users/robertoalonsotrillo/Documents/Claude/Scheduled/superdark-knob-walk-24h/SKILL.md` (3). It is outside the repository and is not sealed:

```
"Read first: docs/measurements/2026-09-20_knobs_to_factory_prereg.md and docs/measurements/2026-09-20_four_steps.md."
    -> .lab/measurements/2026-09-20_knobs_to_factory_prereg.md and .lab/measurements/2026-09-20_four_steps.md
"Write the findings as docs/measurements/2026-09-22_knob_walk_result.md"
    -> .lab/measurements/2026-09-22_knob_walk_result.md
```

If the task fires before the move (it was written 21 Sept for a 24 h check on the 21 Sept 19:01 run, so it may already have run), its result file lands in `docs/measurements/` and needs one more `git mv`.

`README.md:35` and `:81` describe `docs/` as "findings, including the ones that went against us"; the README is replaced whole.

Counts: 71 edits (68 in the repository, 3 in the scheduled task); 9 sealed-scorer strings and 3 archived-edition strings deliberately left; 90 append-only lines deliberately left.

## 4. Move plan

### 4.1 The hidden folder

Proposed name: `.lab/`. Short, a dot-directory so GitHub's tree view and most editors hide it, and the word says what it is: the bench, not the instrument. Layout mirrors `docs/` so every path edit is a prefix swap:

```
.lab/
  README.md          new, five lines, see 4.5
  measurements/      54 files, from docs/measurements/ (keeps evidence/ and the two PNGs)
  records/            7 files, from docs/records/
  notes/             20 files: 19 from docs/, plus DECISIONS.md
  prompts/            4 files: prompts/me.md, docs/diagram_prompts.md, docs/diagram_prompt_3_mechanisms.md, docs/DIAGRAM_UPDATE_BRIEF.md
```

That is 85 files moved: 54 + 7 + 20 + 4. `notes/` takes 19 of the 22 top-level docs (the three diagram files go to `prompts/`) plus `DECISIONS.md`.

### 4.2 Ordered commands

Stop the factory first (`sh tools/stop_factory.sh`), because `policy.json` and `charter.json` are edited in step 4 and `live_classes/` is deleted from the index in step 6 while `run_live.sh` rewrites it at boot. Run from `exo-music/`.

Step 1, create the folder and move the subtrees (git creates parents on `mv`):

```sh
mkdir -p .lab/notes .lab/prompts
git mv docs/measurements .lab/measurements
git mv docs/records      .lab/records
```

Step 2, the 19 notes:

```sh
for f in BISECTION.md COVERAGE_PROPOSALS_REFUSED.md EXP_WEIGHT_M1_M7.md EXP_WEIGHT_SWEEP.md \
         FRAGMENTATION_LEVERS.md HARMONY_AS_A_HARNESS_MEASURE.md LAMBDA_NOVELTY_AS_CURRENCY.md \
         M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY.md METRICS_REVIEW_2026-09-18.md \
         NESTING_THE_THREE_TIMESCALES.md OVERNIGHT_2026-09-17.md \
         PITCH_IS_A_COORDINATE_NOT_A_FACULTY.md RESUME_2026-09-16.md \
         RUNBOOK_attention_and_mdprime.md SECTION_SPREAD.md THE_KERNEL_IS_BROAD_BUT_NOT_DEEP.md \
         THE_REWARD_CHANNEL.md THE_SHARED_TABLE_HAS_NO_SOURCE.md VERSION_READOUT_DESIGN.md; do
  git mv "docs/$f" ".lab/notes/$f"
done
git mv DECISIONS.md .lab/notes/DECISIONS.md
```

Step 3, the prompts:

```sh
git mv prompts/me.md                        .lab/prompts/me.md
git mv docs/diagram_prompts.md              .lab/prompts/diagram_prompts.md
git mv docs/diagram_prompt_3_mechanisms.md  .lab/prompts/diagram_prompt_3_mechanisms.md
git mv docs/DIAGRAM_UPDATE_BRIEF.md         .lab/prompts/DIAGRAM_UPDATE_BRIEF.md
```

After step 3, `docs/` holds `HARNESS.md`, `WORLD_CHANNEL_DESIGN.md`, `PROGRAMME_AMENDMENT_2026-09-15.md`, `PATH_TO_A_FULLY_ONLINE_FACTORY.md` and this plan; `prompts/` is empty and git drops it.

Step 4, the string edits. One `sed` per file over the 68 in-repo lines of section 3.1, applied only to the files listed there (never to `charter_decisions.jsonl`, `SEAL_LOG.jsonl`, the sealed scorers or the archived editions). BSD `sed` needs `-i ''` and `-E` for the alternation (the expression was checked on a copy of `suspend_m7.py`):

```sh
EDIT='s#docs/measurements/#.lab/measurements/#g;
      s#docs/records/#.lab/records/#g;
      s#docs/diagram_prompts\.md#.lab/prompts/diagram_prompts.md#g;
      s#docs/diagram_prompt_3_mechanisms\.md#.lab/prompts/diagram_prompt_3_mechanisms.md#g;
      s#docs/DIAGRAM_UPDATE_BRIEF\.md#.lab/prompts/DIAGRAM_UPDATE_BRIEF.md#g;
      s#docs/DECISIONS\.md#.lab/notes/DECISIONS.md#g;
      s#docs/(BISECTION|COVERAGE_PROPOSALS_REFUSED|EXP_WEIGHT_M1_M7|EXP_WEIGHT_SWEEP|FRAGMENTATION_LEVERS|HARMONY_AS_A_HARNESS_MEASURE|LAMBDA_NOVELTY_AS_CURRENCY|M7_IS_NOT_A_PROPERTY_OF_THE_FACTORY|METRICS_REVIEW_2026-09-18|NESTING_THE_THREE_TIMESCALES|OVERNIGHT_2026-09-17|PITCH_IS_A_COORDINATE_NOT_A_FACULTY|RESUME_2026-09-16|RUNBOOK_attention_and_mdprime|SECTION_SPREAD|THE_KERNEL_IS_BROAD_BUT_NOT_DEEP|THE_REWARD_CHANNEL|THE_SHARED_TABLE_HAS_NO_SOURCE|VERSION_READOUT_DESIGN)\.md#.lab/notes/\1.md#g'
for f in tools/build_grains_onset.py tools/calibrate_ingest_weight.sh tools/coverage_metric.py \
         tools/dwell_frozen_partition.py tools/early_warning.py tools/prune_dead_operator_cells.py \
         tools/read_weight_experiment.py tools/read_weight_sweep.py tools/score.py tools/suspend_m7.py \
         tools/test_coverage_metric.py tools/the_attractor.py tools/transient_median_null.py \
         tools/transient_null.py workdir/tools/score.py workdir_music/tools/score.py \
         workdir_music/tools/live_factory.scd workdir_music/mutable/charter.json \
         workdir_music/mutable/policy.json harness/measures.json docs/HARNESS.md \
         .lab/prompts/DIAGRAM_UPDATE_BRIEF.md .lab/notes/HARMONY_AS_A_HARNESS_MEASURE.md \
         .lab/notes/RESUME_2026-09-16.md .lab/notes/RUNBOOK_attention_and_mdprime.md \
         .lab/notes/SECTION_SPREAD.md .lab/notes/THE_REWARD_CHANNEL.md \
         .lab/measurements/2026-09-15_macro_calibration.json \
         .lab/measurements/2026-09-15_macro_measure_result.md \
         .lab/measurements/2026-09-15_md_calibration.json \
         .lab/measurements/2026-09-15_partial_hold_result.md \
         .lab/measurements/2026-09-18_charter_edition_7_proposal.md \
         .lab/measurements/2026-09-18_coverage_metric_prereg.md \
         .lab/measurements/2026-09-18_early_warning_veto_prereg.md; do
  sed -i '' -E -e "$EDIT" "$f"
done
python3 -c "import json;json.load(open('workdir_music/mutable/policy.json'));json.load(open('workdir_music/mutable/charter.json'));json.load(open('harness/measures.json'))"
git grep -n 'docs/' -- . ':!.lab' ':!workdir_music/mutable/charter_decisions.jsonl' ':!frozen/SEAL_LOG.jsonl' | grep -v -E 'docs/(0[0-9]|1[0-9]|HARNESS|WORLD_CHANNEL|PROGRAMME_AMENDMENT|PATH_TO_A_FULLY|REPO_CLEANUP)'
```

The last line should print only the nine sealed-scorer lines and the three archived-edition lines. Then edit the three strings in the scheduled task's `SKILL.md` by hand (section 3.1), and run `python3 tools/seal_rig.py verify` to confirm no sealed file was touched.

Step 5, `.gitignore` additions, appended to the root `.gitignore`:

```gitignore
# ---- 22 Sept 2026: generated, backup and debris under exo-music ------------
# hand-made backups beside the live file; checkpoint.py is the tool for this
exo-music/workdir_music/mutable/*.bak*
exo-music/workdir_music/mutable/*.before_*
exo-music/workdir_music/mutable/memory_old_corpus_*.json
exo-music/workdir_music/mutable.before_ck_*/
exo-music/workdir_music/tools/*.bak_*
exo-music/workdir_music/behaviour/*.baseline
exo-music/workdir_music/behaviour/*.v1
# the shadow instance owns its state and it is scratch
exo-music/workdir_music/mutable_shadow/
# class directories rebuilt from lib/ and behaviour/ at every boot (run_live.sh)
exo-music/workdir_music/tools/live_classes/
exo-music/workdir_music/tools/shadow_classes/
# run logs and pilot output
exo-music/workdir_music/tools/live_run.log
exo-music/workdir_music/pilot_*/
# harness debris and superseded bundles; the 19 Sept set is a test fixture
exo-music/harness/smoke_debris_*/
exo-music/harness/superseded_*/
!exo-music/harness/superseded_260919_sliced_wrong/
# large derived data with no reader
exo-music/workdir_music/mnull_*.json
exo-music/workdir_music/stream/compare_*.png
```

Step 6, untrack without deleting from disk (`--cached` leaves the working copy; `-r` for directories):

```sh
git rm -r --cached workdir_music/mutable.before_ck_260915_165834_champion-rq25-fullstack
git rm -r --cached workdir_music/mutable_shadow
git rm -r --cached workdir_music/tools/live_classes workdir_music/tools/shadow_classes
git rm -r --cached harness/smoke_debris_260918
git rm -r --cached workdir_music/pilot_20260831_2036 workdir_music/pilot_20260901_0210 \
                   workdir_music/pilot_20260901_0215 workdir_music/pilot_overnight_0901_0220
git rm --cached workdir_music/mutable/policy.json.bak_pregate workdir_music/mutable/policy.json.bak_pre_mc \
                workdir_music/mutable/policy.json.bak_pre_aw015 workdir_music/mutable/policy.json.bak_pre_aw03 \
                workdir_music/mutable/policy.json.bak_two_arms workdir_music/mutable/kernel_edition1.json.bak \
                workdir_music/mutable/memory.json.bak_prune_260918_085207 \
                workdir_music/mutable/memory.json.before_trace_migration_260915_211005 \
                workdir_music/mutable/memory_old_corpus_260827.json
git rm --cached workdir_music/tools/live_factory.scd.bak_110833 workdir_music/tools/live_run.log
git rm --cached workdir_music/behaviour/BehaviorTrimmed.sc.baseline workdir_music/behaviour/BehaviorTrimmed.sc.v1
git rm --cached workdir_music/mnull_2500.json workdir_music/stream/compare_R2.png workdir/renders/_tmp.osc
git rm --cached workdir_music/census.log workdir_music/census44.log workdir_music/census44b.log \
                workdir_music/d44.log workdir_music/dump.log workdir_music/dump2.log workdir_music/envfix90.log \
                workdir_music/gain.log workdir_music/grains.log workdir_music/ncensus.log workdir_music/pg2.log \
                workdir_music/playgran.log workdir_music/probe.log workdir_music/render_ctl.log \
                workdir_music/render_new.log workdir_music/replicates.log workdir_music/repro.log \
                workdir_music/run44.log workdir_music/run46.log workdir_music/verify.log
git status --short | grep -c '^D '     # expect 536: 198 + 210 + 20 + 63 + 9 + 9 + 2 + 2 + 3 + 20
```

That removes 536 index entries (198 + 210 + 20 + 63 + 9 + 9 + 2 + 2 + 3 + 20) and about 10.7 MB of tracked bytes; the files stay on disk and history keeps them. `weights_before_mid.json` is left tracked because nothing says whether the factory or a person made it.

Step 7, do not stage the untracked debris: add `harness/n_arms_260919_141544.json` if it is a wanted summary, and confirm `harness/superseded_260920_coverage_veto/` is now ignored (`git status` should no longer list it). Stage `tools/extract_fragments.py`, `mutable/factory_knobs.json`, `mutable/fragments.json` and the new machines; they are the 20 to 22 Sept work.

Step 8, replace `README.md` with section 5, write `.lab/README.md` (4.5), commit as one change with a message naming the rename and the untracking, and push. Then boot with `sh tools/start_loop.sh`; the first boot recreates `live_classes/` (ignored now) and `checkpoint.py diff` against the last checkpoint will show `live_factory.scd` changed by three comment lines.

### 4.3 What stays in `docs/` and why

`HARNESS.md`: the evaluation harness's own document, cited from `tools/eval_rig.sh`'s reasoning and the README; it is the reference a stranger needs to read the bundles. `WORLD_CHANNEL_DESIGN.md`: the design of the only non-self input, cited by `tools/world_sim.py:11`. `PROGRAMME_AMENDMENT_2026-09-15.md`: the standing amendment to the Class 3 programme; it is the closest thing in this subtree to the roadmap, and it is what makes the ear's veto a rule. `PATH_TO_A_FULLY_ONLINE_FACTORY.md`: the three-axis definition of online that the README's architecture section leans on. All four are dated and carry the author's voice in places; they are kept because a reader of the system needs them, and because two of them are cited from code. This plan file stays beside them until the cleanup is done, then belongs in `.lab/notes/`.

### 4.4 What is deliberately not moved

`tools/`, `harness/` top-level files, `frozen/`, `workdir_music/lib`, `behaviour`, `stream`, `mutable/` (minus the backups): the system. `workdir/`, `variants/`, `Dockerfile*`, `drun.sh`, `frozen/score_e1_frozen.py`, `frozen/score_e3_frozen.py`: the August offline rig, still runnable, referenced by `Dockerfile.agent` (`COPY workdir`) and `Dockerfile.agent-e3`; the README names it as phase 1 in one sentence. `workdir_music/tools/live_factory_instrumented.scd`, `_slots.scd`, `_operator_WIP.scd`: three superseded bodies of the factory, 335 KB, cited by one measurement record; they could go to `.lab/superseded_factory_bodies/` in a second pass, with `2026-09-19_read_but_inert_policy_keys.md:220,276` edited to match. `harness/superseded_260919_sliced_wrong/`: test fixture, see 1.3.

### 4.5 `.lab/README.md`, proposed text

```
# .lab

The working record of SuperDark, kept out of the way of the system. Everything
here is first person and unedited: pre-registrations written before a run,
results written after, incident records, design notes, resume points, runbooks
and the prompts used to make figures. Dates are in the filenames.

Until 22 September 2026 this material lived under docs/. Paths of the form
docs/measurements/..., docs/records/... and docs/<NOTE>.md in the append-only
files (mutable/charter_decisions.jsonl, frozen/SEAL_LOG.jsonl, the archived
charter editions) and in the sealed scorers refer to .lab/measurements/...,
.lab/records/... and .lab/notes/<NOTE>.md here. Those files were left as they
were, on purpose.
```

## 5. README draft

Sources read for this: the current `README.md` (3 Sept), `docs/HARNESS.md`, `docs/PROGRAMME_AMENDMENT_2026-09-15.md`, `docs/PATH_TO_A_FULLY_ONLINE_FACTORY.md`, `docs/WORLD_CHANNEL_DESIGN.md`, `tools/start_loop.sh`, `tools/stop_factory.sh`, `workdir_music/stream/run_fifo.sh`, `run_stream.sh`, `publish_state.sh`, `player.html`, `tools/factory_status.py`, `tools/eval_rig.sh`, `tools/overnight_watch.sh`, `lib/MachineWriter.sc`, `lib/PatternGrammar.sc`, `lib/TransferOperator.sc`, `lib/Simultaneity.sc`, `tools/extract_fragments.py`, `mutable/charter.json` (edition 7), `mutable/kernel.json` (edition 2, armed), `frozen/README.md`, the root `README.md` licence line and `DECISIONS.md`. Numbers are as of 22 September 2026. There is no LICENSE file anywhere in the repository; the root README states MIT, and the draft repeats that.

```markdown
# SuperDark

A generative music factory that has been running continuously since the end of
August 2026. It assembles sound from recorded grains, listens to its own output,
writes new playback machines into itself while it plays, and is judged by a
charter it may propose changes to and cannot enact. A kernel it cannot edit can
stop it, and has, twice. The stream and the public evaluation panel are at
https://stream.robertoalonsotrillo.com.

It is the working prototype for *The Superdark Factory* (Marek Poliks and
Roberto Alonso Trillo), built to find out what a system converges on when its
objective cannot be written down. Music has no score function, so every measure
here is a proxy, and the project's record is mostly an account of proxies that
saturated, inverted or steered the wrong way, and of what was done about each.
The architecture that follows is the shape those failures produced.

## Architecture

Four layers, each with its own author and its own rate of change.

The factory is SuperCollider. `workdir_music/tools/live_factory.scd` is the
single file that runs: three timescales (micro, mid, macro), one voice slot per
timescale with its own dwell, a six-dimensional target (five cepstral components
and pitch) that walks through a corpus of 44.1 kHz grains, a transfer operator
over machine identities that reads where behaviour is thin, and a window log
written every 11.7 seconds. The nine classes in `workdir_music/lib/` supply the
operator, the machine writer, the pattern grammar, the simultaneity observer
and Archon's original handler. `run_live.sh` copies the classes into a live
class path at boot, patches three of them for continuous operation, and starts
sclang under caffeinate. There is no DSP chain beyond a buffer read, one
filter, pan and a limiter; the FFT on the listener bus is analysis.

The mutable layer is `workdir_music/mutable/`, the only directory the factory
may write. `policy.json` holds the parameters the architect can change while it
runs, read every ten windows. `memory.json`, `weights.json`,
`written_machines.json`, `factory_knobs.json`, `fragments.json` and
`machines/*.scd` are the factory's own: its transition history, the machines it
has authored, the five knobs it now moves itself at each section boundary.
`charter.json` (edition 7: four norms, nine bounded metrics, two descriptors
without bounds, and `m3_no_clipping` never tolerated) and `kernel.json`
(edition 2, armed, `factory_may_write: false`) sit beside them for now; the
split between substrate and policy is a filesystem line still owed.
`charter_proposals.jsonl`, `charter_decisions.jsonl` and `kernel_journal.jsonl`
are append-only. The factory has proposed 93 changes to its charter; one was
adopted and 92 refused, each with a reason written against it.

The harness is `harness/`, `frozen/` and the `eval_*`, `checkpoint`,
`seal_rig` and `measure_registry` tools. It exists so that the numbers can be
trusted, and it protects them from the architect, since the factory cannot
write files. `docs/HARNESS.md` is its document.

The stream is a pipe. scsynth writes raw float32 audio into a FIFO on the
internal disk; `workdir_music/stream/fifo_splitter.py` reads it once and feeds
two consumers, an ffmpeg encoder that publishes 128 kbps MP3 through an
outbound ssh tunnel to an Icecast relay on Hetzner, and a writer of ten-minute
WAV segments on the SSD that the self-ingestion daemon eats. Nothing is stored
on the way to the listener. `publish_state.sh` pushes a JSON snapshot from
`tools/factory_status.py` to the relay every ten seconds, and `player.html`
with `panel.js` is the page that plays the mount and draws the snapshot,
failing metrics included. The panel has never been allowed to show only the
passing ones.

## Running it

Requirements: macOS with SuperCollider, a silent two-channel loopback output
(VB-Cable or BlackHole 2ch), ffmpeg, a Homebrew Python 3 with numpy and scipy,
an SSD mounted at `/Volumes/FMA/superdark` (override with `SD_ROOT`) holding the
archive, the self-ingest pools and the segment ring, and
`workdir_music/stream/.stream_secrets` with the Icecast source password and the
relay host. That file is ignored and never committed.

Boot, from `exo-music/`:

    sh tools/start_loop.sh

It refuses to start on a wedged scsynth holding the port, assembles the play
corpus from the archive and the self-ingest pool at `self_ingest_weight`,
verifies that every grain's descriptor row matches its audio, starts the tunnel
and the FIFO splitter before the factory so the pipe has a reader, boots the
factory and waits for it to report its buffers, starts one ingest daemon,
starts the state publisher, and checks that the public panel is fresh. Every
path and port is an environment variable, so a second instance can run beside
the first: `MUTABLE=mutable_shadow SCPORT=57130 NO_STREAM=1 sh tools/start_loop.sh`
plays locally, learns into its own state, and publishes nothing. `WEIGHT`
overrides the ingest weight for one boot. Newly admitted grains sound only after
the next boot, which is the generation boundary.

Stop:

    sh tools/stop_factory.sh          # caffeinate, sclang, scsynth, then verify the port is free
    sh tools/stop_factory.sh --all    # also the ingest daemon

It stops and verifies. It touches nothing in `mutable/`. Stop the factory before
restarting the splitter; the splitter holds the read end of the FIFO and
dropping it sends SIGPIPE to scsynth.

Stream, from `workdir_music/stream/`:

    sh run_fifo.sh start | stop | status     # the splitter, the encoder and the segment writer
    sh run_stream.sh tunnel                  # the outbound tunnel to the relay
    sh publish_state.sh start | status | once

The encoder probes Icecast for its own mount and respawns when it is gone.

Status, from `exo-music/`:

    python3 tools/factory_status.py             # one snapshot, what the panel shows
    sh tools/overnight_watch.sh --report        # was the long run trustworthy: clock jumps, FIFO full, server loss
    python3 tools/run_integrity.py              # the out-of-band watcher; repairs nothing
    python3 tools/kernel_guard.py               # dry run of the kernel; --arm to let it stop the factory
    python3 tools/score_charter.py <window log> # the charter verdict
    sh tools/eval_rig.sh validate               # the harness is sane, seals intact

Read the watch report before judging a run. An eight-hour run in August lost 85%
of itself to a clock jump and was scored before anyone noticed.

## How the factory writes its own machines

The transfer operator (`lib/TransferOperator.sc`) partitions the factory's
behaviour into cells, one per machine, counts transitions between them every
window, and reads its stationary distribution, second eigenvector and spectral
gap. A transition that has never happened is a hole in the factory's own
dynamics. The machine writer (`lib/MachineWriter.sc`) takes a turn at whichever
timescale is starved, finds a hole there, and writes a bridge: a machine whose
parameters sit between the two endpoints. The pattern grammar
(`lib/PatternGrammar.sc`) decides the shape of each slot, expanding a typed
grammar over eight SuperCollider combinators to a bounded depth, so a machine's
expression can be one the architect never wrote; every slot is clamped at
emission. Since 22 September the writer can also fill a slot with a fragment
taken mechanically from one of Archon's twenty original machines
(`tools/extract_fragments.py` into `mutable/fragments.json`), at a probability
the policy sets. A deviation gate refuses any candidate whose durations and
shape fall within a set distance of a machine that already exists, and logs the
refusal with its reason; acquisition rates under that gate are what the current
measurements are about. An accepted machine is written to `mutable/machines/`
and loaded while the server runs, so nothing stops. The factory chooses where a
machine is needed and what it contains; the template, the combinators, the
guards and the slots are the architect's, and the project has been careful not
to claim otherwise.

## The evaluation harness

Nothing in the factory can edit a scorer, so the harness guards against the
architect. Every scorer whose number can reach a claim is sealed: its sha256 is
in `frozen/MANIFEST.json`, `eval_rig.sh` checks the seal before computing
anything, and a change is allowed only through `seal_rig.py adopt`, which
records old hash, new hash and reason in `frozen/SEAL_LOG.jsonl`. A checkpoint
(`tools/checkpoint.py`) carries the policy layer, the operator, the corpus
hashes and the git head, so two states can be diffed and one change at a time
can be enforced instead of hoped for; restore refuses while the factory runs.
`harness/measures.json` gives every measure a promotion budget of three
adjudications on seen data, after which it keeps its veto and loses its vote;
saturation retires it at once. `harness/release_policy.v1.json` was written
before any candidate existed, with nine hard invariants (two added the day they
were needed), and its margins are unset on purpose, so the gate runs in shadow:
it computes, writes the bundle, and promotes nothing. Changes ship on judgement
and on the ear, and an ear win is recorded as an ear win. The rig is good at
numbers and blind to mechanisms that are wired and never run; four of those
have been found by reading the code, which is why the release policy asks for
the consumer of a knob to be grepped before the knob is turned.

## The working record

`.lab/` holds the working record: pre-registrations, results, incident reports,
design notes, resume points, runbooks and figure prompts, dated in their
filenames. It is written in the first person, mostly by the agent that did the
work, and it is unedited. `docs/` keeps four documents a reader of the system
needs: the harness, the world channel design, the programme amendment and the
path to a fully online factory. The August phase of the project, an Exo agent
editing Archon's behaviour model offline, is still here as `workdir/`,
`variants/`, the Dockerfiles and `frozen/score_e1_frozen.py`, and its own
record is in the repository root.

## Licence

MIT, as stated in the repository root. Archon's class library under
`workdir/lib/` and `workdir_music/lib/` (Handler, Behavior, Synths, Methods,
Pkill) is Alonso Trillo and Poliks's, vendored so the factory can compile it.
```

## 6. Summary for the hand-back

Plan file: `/Users/robertoalonsotrillo/Desktop/COWORK_OS/SUPERDARK/exo-music/docs/REPO_CLEANUP_PLAN_2026-09-22.md`. Hidden folder: `.lab/` with `measurements/`, `records/`, `notes/`, `prompts/`. Files to move: 85 (54 measurements, 7 records, 20 notes including `DECISIONS.md`, 4 prompts including `prompts/me.md`). References to edit: 71 (68 in the repository, 3 in the scheduled task), with 9 sealed-scorer strings, 3 archived charter editions and 90 append-only lines deliberately left alone. Clearly tracked and should not be: the 536 index entries listed in step 6 (the pre-checkpoint copy of `mutable/`, `mutable_shadow/`, the two boot-generated class directories, `smoke_debris_260918/`, four pilot directories, nine `.bak`/`.before_` files in `mutable/`, the `live_factory.scd.bak_110833`, two `BehaviorTrimmed` copies, 22 top-level logs plus `live_run.log`, `mnull_2500.json`, `compare_R2.png`, `_tmp.osc`), and two things to decide: whether `memory.json` (1.6 MB, rewritten every window) should keep entering every commit, and whether the 23 MB `harness/superseded_260919_sliced_wrong/` fixture should be trimmed to the two logs the tests read. The git root being `SUPERDARK/`, not `exo-music/`, is the one fact that changes how the commands are written.
