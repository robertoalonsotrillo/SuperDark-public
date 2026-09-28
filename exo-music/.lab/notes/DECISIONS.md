# Decisions

## 2026-08-19 · Scope of the first agent run

**Decided.** The agent may modify **the behaviour model only** — rungs r₀ to r₂ of the ladder in `docs/05-archon.md` §7: the 87 coefficients, the form of the weight update, and the set of machines. The evaluator is fixed and outside its reach.

**Why.** With the evaluator fixed, any drift in the output is attributable to the policy. If both move, nothing is attributable and the run produces a story instead of a measurement.

**Decided.** **Exo from the start**, rather than a script loop. It is installed, credentialled and answering (run 01). It supplies the append-only event log and the single self-modification path, which cover two further items in `docs/00-brief.md`, and it puts claim 2 under test instead of leaving it on the vendor's word.

---

## PARKED — return to these deliberately

Roberto asked to be reminded to work through both. Neither is abandoned; both are sequenced after a fixed-evaluator baseline exists.

### P1 · Let the agent modify the evaluator as well as the behaviour model

The Superdark condition proper: a system that rewrites both what it does and what counts as doing well. Theoretically the most interesting configuration available, and the one the formalism is actually about.

**Precondition.** A baseline with a fixed evaluator, so there is something for the moving-evaluator condition to differ from.

**The measurement it enables.** How fast the evaluator drifts from the human verdict once the system controls it, against how fast it drifts when only the policy moves. That difference is the decorrelation of information from utility with a rate attached.

### P2 · Let the agent modify its own perception (rung r₃)

The descriptor set in `Analysis`: `peak`, `rms`, `freq`, `hasFreq`, `centroid`, `flatness`, `rolloff`. Seven numbers, and everything the system knows about its own output passes through them.

Letting the agent edit that list means letting it change what it can see. `docs/04-generator.md` §5 argues this is the sharpest manipulation the project has, because it is a dose-response design on the information channel itself: widen or narrow the channel and measure whether the drift rate changes.

**Precondition.** P1's baseline, plus a stable descriptor pipeline. Run 06 built the pipeline; it is one class-extension away from being editable.

**Why it is worth the wait.** If the agent can rewrite its own perception, the question stops being "does the proxy decay" and becomes "does a system choose to see less of what it is failing at". Nobody has asked that empirically.

### P3 · Real-time interaction

Roberto's note, 2026-08-19: the long-term aim is to morph this into something that supports real-time interaction. Parked deliberately, not abandoned.

Everything built so far is offline by design, and `07-run-architecture.md` §2 gives the reason: a live loop through two processes and a socket is not reproducible, and `03-sandbox.md` requires every run to start from a fixed state. Offline bought determinism, faster-than-real-time runs, and the seeded comparisons that made runs 10 and 13 possible.

**What already points back toward real time.** Archon *is* a real-time system; we removed the liveness rather than working around its absence. Run 02 showed scsynth runs at real-time rate inside Docker via JACK's dummy backend, and the only thing missing there is an audio device. `03-sandbox.md` narrows the remaining question to audible output on real hardware, which is task #13.

**What would have to change.** The evaluator is the hard part, not the audio. E0 and E1 both score a completed twenty-second render; a live system needs a score that runs on a sliding window and returns before the next decision. That is a different object, and it is worth designing only once the offline decay curves exist to calibrate it against.

**Remind Roberto when:** the agent-in-the-loop work is finished and the evidence pack is assembled.
