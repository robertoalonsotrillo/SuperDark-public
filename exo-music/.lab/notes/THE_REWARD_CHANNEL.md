# The reward channel: three weak signals, admitted as weak

**18 September 2026.** Decision 6 of `.lab/notes/METRICS_REVIEW_2026-09-18.md`.
Roberto admitted all three candidates. A design note; each channel needs its own
pre-registration before it carries a number.

## The hole

This is the largest one in the project, and the charter has said so since
27 August in its own words: every metric is a metric over the factory's own
output, because constraint c4 records that there is no world.

The paper's position, in three lines:

- L151: judges "measure outcomes (and only outcomes), answer to signals in the world"
- L256: "the signal that grades an evaluator must sit outside the loop that evaluator judges"
- L260: "A realized-consequence score requires true regressions and real failures"

And the consequence of not having one, L260 again: evaluator agents and
productive agents "would be easily incentivized to collaborate in the direction
of overfitting."

Everything built here stops short at the same place. The factory proposes
metrics and does not adopt them. The judges run and steer nothing. The early
warnings are computed and nothing acts on them. Each stop is deliberate, and
each is deliberate because the signal that would make the loop safe to close
does not exist.

## What counts as a world signal here

A factory whose only contact with anything outside itself is a stream mount and
whoever is listening to it. So the candidates are thin. The test is not whether
a signal is strong; it is whether the factory generated it.

| channel | what it is | why it is outside the loop | why it is weak |
|---|---|---|---|
| **listen duration** | how long a connected client stays before disconnecting | a person deciding to stay is a consequence the factory cannot author | few listeners; a tab left open is indistinguishable from attention; no control for what else the person is doing |
| **second-factory ingestion** | Factory 1 ingesting Factory 2's output, or the reverse | the ingesting factory's admission decisions were not made by the producing factory | both factories share a corpus, a codebase and an architect, so "outside" is doing a lot of work |
| **listener count** | concurrent connections on the mount | not authored by the factory | at current numbers (0 to a handful) this is dominated by whether Roberto has the page open |

All three are admitted. None is presented as sufficient.

## The check that comes first, before any figure is quoted

Pre-registered 16 September, in `measures.json` under
`reward_channel_audibility_check`:

> BEFORE quoting any skill figure: confirm `audibility.json` updates on a slower
> clock than the window. If `audib[]` is a lagged copy of recent audibility,
> skill would be autocorrelation wearing a forecast's clothes and the shuffled
> null alone would not catch it.

This applies to all three channels and generalises: for each, confirm the signal
is not a transform of something the factory already produced. For listen
duration that means confirming the relay's session records are not derived from
the mount's own byte counters in a way that makes duration a function of
bitrate. For second-factory ingestion it means confirming the ingesting
factory's admission threshold is not reading a descriptor the producing factory
optimised.

A channel that fails this check is not weak. It is circular, and circular is
worse than absent, because it looks like the thing the paper asks for.

## Order of work

1. **Listen duration.** The relay already logs connections. The work is to
   extract sessions, confirm the non-circularity check, and characterise the
   distribution before proposing any statistic. Start here because the data
   exists and is accumulating whether or not anyone reads it.
2. **Listener count.** Trivial once listen duration's extraction exists, since
   it comes from the same records. Adopted as a covariate on listen duration
   first, and only as a channel of its own if it survives on its own.
3. **Second-factory ingestion.** The most interesting and the furthest off. It
   needs both factories running independently, which is what Factory 1 exists
   for, and it needs the shared-ancestry objection answered before it can claim
   to be outside anything.

## What a reward channel may and may not do here

**May:** report. Be published on the panel. Enter the registry as a measure with
veto power, once calibrated.

**May not, without a further decision by Roberto:** steer selection. The moment a
signal steers, the factory is optimising against it, and P238's warning applies:
"the only thing any engineer can institute a price regime against is yet another
metric, which cascades out into another regime of possible overfitting." A weak
signal that steers is worse than no signal, because it converts a thin proxy for
the world into the thing the factory maximises. Three evaluation layers here
have already been scalars to climb and all three narrowed the vocabulary.

So the default is: measure it, publish it, let it veto, do not let it steer.

## What is not claimed

That any of these is a realized-consequence metric in the paper's sense. L262 is
explicit that the events cannot be staged: "they have to be real and they have to
keep coming." A stream with no listeners generates no consequences. What these
three buy is the beginning of a channel and an honest record of how thin it is,
which is better than the current position of having none and knowing it.
