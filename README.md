# SuperDark

A generative music factory that has been running continuously since the end of
August 2026. It assembles sound from recorded grains, listens to its own output,
writes new playback machines into itself while it plays, and is judged by a
charter it may propose changes to and cannot enact. A kernel it cannot edit can
stop it, and has, twice. The stream and the public evaluation panel are at
https://stream.robertoalonsotrillo.com/superdark.

It is the working prototype for *The Superdark Factory* (Marek Poliks and
Roberto Alonso Trillo), built to find out what a system converges on when its
objective cannot be written down. Music has no score function, so every measure
here is a proxy, and the project's record is mostly an account of proxies that
saturated, inverted or steered the wrong way, and of what was done about each.
The architecture that follows is the shape those failures produced.

The live system is `exo-music/`. Every path below is relative to it.

## Architecture

Four layers, each with its own author and its own rate of change.

The factory is SuperCollider. `workdir_music/tools/live_factory.scd` is the
single file that runs: three timescales (micro, mid, macro), one voice slot per
timescale with its own dwell, a six-dimensional target (five cepstral components
and pitch) that walks through a corpus of 44.1 kHz grains, a transfer operator
over machine identities that reads where behaviour is thin, and a window log
written every 11.7 seconds. The nine classes in `workdir_music/lib/` supply the
operator, the machine writer, the pattern grammar, the simultaneity observer
and Archon's original handler with its twenty machines. `run_live.sh` copies the
classes into a live class path at boot, patches three of them for continuous
operation, and starts sclang under caffeinate. The signal path is a buffer
read, one filter, pan, three reverb returns the machines route events to, and a
limiter; the FFT on the listener bus is analysis.

The mutable layer is `workdir_music/mutable/`, the only directory the factory
may write. `policy.json` holds the parameters the architect can change while it
runs, read every window. `memory.json`, `weights.json`,
`written_machines.json`, `factory_knobs.json`, `fragments.json` and
`machines/*.scd` are the factory's own: its transition history, the machines it
has authored, the five knobs it moves itself at each section boundary.
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
passing ones. A second factory, the replica, runs the same code on another
machine from `REPLICA_KIT/` and publishes its own mount and panel.

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
event duration sits between the two endpoints. Each of its slots (duration,
rate, filter, pan, amplitude, the bus sequence that decides which events ring,
the envelope, and how many layers of itself it stacks) is either a term drawn
from a typed grammar over eight SuperCollider combinators
(`lib/PatternGrammar.sc`) or a fragment taken mechanically from one of Archon's
twenty original machines (`tools/extract_fragments.py` into
`mutable/fragments.json`), at a probability the policy sets. Every slot is
clamped at emission, and the composition is written into the machine's own
header. A deviation gate refuses any candidate whose duration and shape fall
within a set distance of a machine that already exists, and logs the refusal
with its reason. An accepted machine is written to `mutable/machines/` and
loaded while the server runs, so nothing stops. The factory chooses where a
machine is needed and what it is made of; the combinators, the guards, the
slots and the originals are the architect's, and the project has been careful
not to claim otherwise.

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
numbers and blind to mechanisms that are wired and never run; sixteen of those
have been found by reading the code, which is why the release policy asks for
the consumer of a knob to be grepped before the knob is turned.

## The working record

Two hidden folders hold the working record, each beside what it records.
`exo-music/.lab/` has this phase: pre-registrations written before a run,
results written after, incident records, design notes, resume points, runbooks
and figure prompts, dated in their filenames. `.lab/august/` at the root has
the August phase, an Exo agent editing Archon's behaviour model offline: its
design documents, claims, evidence, sources and run notes. Both are written in
the first person, mostly by the agent that did the work, and both are unedited.
`exo-music/docs/` keeps the four documents a reader of the system needs: the
harness, the world channel design, the programme amendment and the path to a
fully online factory. The August rig itself is still runnable as
`exo-music/workdir/`, `variants/`, the Dockerfiles and
`frozen/score_e1_frozen.py`.

## Licence

MIT; see `LICENSE`. Archon's class library under `workdir/lib/` and
`workdir_music/lib/` (Handler, Behavior, Synths, Methods, Pkill) is Alonso
Trillo and Poliks's, vendored so the factory can compile it.
