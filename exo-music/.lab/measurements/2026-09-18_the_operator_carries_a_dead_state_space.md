# The operator is 61% dead history, and `@slow` is a constant

**18 September 2026, 01:3x.** Written while the null comparison runs. This
**corrects yesterday's account** of why λ₂ = 1, and with it the repair Roberto
chose on the strength of that account.

## What I said yesterday, and why it was wrong

Yesterday I reported that the transfer operator is reducible, split into two
closed classes by the `@slow` suffix, and I described those classes as **two
tempo regimes**. On that framing Roberto chose the right repair for the problem
as described: two operators, one per regime, compared against each other.

The framing was wrong. There are not two regimes. There is **one live regime and
one dead era**.

## What the data says

**The bucket is a constant.** `operator_sees_macro` has been `1` since 15
September. It computes a bucket from the macro slot's event duration —
`fast < 0.155 ≤ mid < 0.894 ≤ slow` — and appends it to the state. Across
**twelve runs** since then, every single one emits exactly one ALPHABET line:

```
ALPHABET 0,macro_bucket,slow
```

Never `rest`, never `unk`, never `fast`, never `mid`. The macro slot only ever
holds slow machines, because long duration is what puts a machine in the macro slot
at all. So the suffix appends the same five characters to every state the
operator has ever seen since 15 September, and discriminates nothing.

**The bare cells are dead.** Sampled the live operator over 2 m 47 s of the
running factory, comparing `memory.json` before and after it was rewritten:

| | |
|---|---|
| cells that gained counts | 8 |
| of those, `@slow` | **8** |
| of those, bare | **0** |

The 190 bare cells are history from before 15 September and will never be
visited again. The 27 `@slow` cells are the entire live state space.

**And that dead history is most of the operator:**

| | counts | share |
|---|---|---|
| live (`@slow`) | 18,143 | 39% |
| dead (bare) | 28,079 | **61%** |

## What this does to the gap

Computed directly from `memory.json`:

| chain | n | \|λ₂\| | gap |
|---|---|---|---|
| **whole operator, as m7 sees it today** | 217 | 1.0000 | **0.0000** |
| **live only** (`@slow`, drop dead history) | 27 | 0.3876 | **0.6124** |
| dead only (bare, pre-15-Sept) | 190 | 0.6735 | 0.3265 |

λ₂ = 1 is caused by **dead history sitting in the matrix as a second closed
class**, not by any live partition. Each component is irreducible on its own.
Drop the dead cells and the gap becomes measurable immediately.

## An unexpected confirmation of provenance

m7's derivation reads *"6h run: gap ran 0.295–0.422 at p10–p90"*, and its bound
is `[0.02, 0.45]`.

The **dead** chain's gap is **0.3265** — squarely inside that quoted range.

So m7's bound was derived on the pre-15-September state space, which is exactly
the component that is now dead. The live chain's gap is **0.6124**, above the
bound's upper limit of 0.45.

**m7 would therefore FAIL, not pass, the moment the operator is repaired** — and
failing would be wrong, because the bound describes a different chain. The bound
has to be re-derived on the live state space, not merely un-suspended.

## What I now recommend, replacing yesterday's answer

**Two operators per tempo regime is not the fix.** It would produce one
populated chain and one empty one, because there is only one regime in the data.

1. **Drop or decay the dead bare cells.** 61% of the operator's mass describes a
   state space the factory left behind. The forgetting operator (#45) already
   exists and is the mechanism built for exactly this; whether to decay or to
   cut cleanly at the 15 September boundary is a judgement about how much of the
   old era should still influence selection.
2. **Decide what `operator_sees_macro` is for.** As written it appends a
   constant. Either remove it — in which case live states return to bare names
   and would collide with the dead era's keys, so the history must be cut in the
   same move — or make the bucket read something that varies.
3. **Re-derive m7's bound on the live chain afterwards.** The existing bound
   belongs to the dead one.

## What is not claimed

That the live 27-cell chain is the *right* state space. It is 27 cells for a
factory with 126 distinct machines in the macro slot alone, which is a large
collapse and may itself be a defect. This record establishes only where λ₂ = 1
comes from and what removing the dead component does to the gap.

That the ALPHABET evidence proves the duration mechanism. It proves the bucket's
**value** has been constant across twelve runs. The reconstruction of *why* —
that the macro slot admits only long machines — is consistent with the four
named macro machines carrying durations 11.394, 2.488, 1.864 and 1.143, all
above the 0.894 threshold, but the bred machines' live durations come from
`proposeSpecs` at runtime and were not read here.

## Reproduce

```sh
python3 - <<'PY'
import json, numpy as np
op = json.load(open("workdir_music/mutable/memory.json"))["operator"]
def spec(cells):
    cells = sorted(cells, key=str); i = {c: k for k, c in enumerate(cells)}
    n = len(cells); M = np.full((n, n), 1.0 / n)
    for c in cells:
        r = np.zeros(n); t = 0
        for b, v in op.get(c, {}).items():
            if b in i: r[i[b]] = v; t += v
        if t: M[i[c]] = r / t
    return np.sort(np.abs(np.linalg.eigvals(M.T)))[::-1][:2]
print("whole", spec(op.keys()))
print("live ", spec([c for c in op if str(c).endswith("@slow")]))
PY
```
