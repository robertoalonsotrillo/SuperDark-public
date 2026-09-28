# Factory 1 showed no metrics because one route was missing

**18 September 2026, 09:5x.** Roberto: the page gives no metrics for Factory 1
though the replica is running. It was.

## What was wrong

The relay's Caddyfile routes every path with an explicit `handle` and ends with
a catch-all returning `superdark - the stream is at /superdark.mp3`. Two blocks
were needed for the replica; **one had been added**:

| path | route | what the page got |
|---|---|---|
| `/replica.mp3` | present | 200 `audio/mpeg` — audio played |
| `/state-replica.json` | **missing** | 200 `text/plain`, 43 bytes — the placeholder |

So Factory 1 played correctly and reported nothing. `pollState` parses the body
as JSON, throws on the placeholder, `draw()` is never called, and the panel
stays hidden — which is the behaviour built on 17 Sept so a factory's audio can
never appear under another factory's numbers. It worked as designed and looked
like a dead factory.

## The replica was healthy throughout

Read off the relay before changing anything:

```
state-replica.json   24,845 bytes, written 5 s earlier
windows 4,486   voices 3   machines 35   charter metrics 10
```

This also confirms the replica pulled the `factory_status.py` path fix and
restarted: before that it published `"run": {}` with zero metrics.

## The fix

One `handle /state-replica.json` block with CORS and `no-store`, inserted before
the catch-all, `caddy validate`, `systemctl reload caddy`. Backup taken.

Verified on the live page at `?factory=1`: 4,490 windows, 4 voices,
`35 ever invented · 17 of them bridges`, ten metric rows, charter **satisfied**,
7/10 held, no departures.

## Worth naming

The diagnosis cost minutes because the failure was **specific and visible**: a
43-byte `text/plain` body where JSON belonged. Nothing had to be inferred. The
panel-hiding change made the day before is what kept it honest — without it the
page would have shown Factory 2's charter under Factory 1's audio, and the
report would have been "the numbers look wrong" instead of "there are no
numbers".
