# The versioning readout, first result: the judges inflate it and the direct cells do not

> **CORRECTION, 8 Sept 2026.** The age control was built the next day and run on
> this same sequence. **|λ₂| is still moving**: it shifts 0.0558 across the curve
> and 0.0370 across the last four points, so it has not converged. The figure
> below — *two versions, 1.8 minutes* — is therefore **not quotable**. It is still
> a function of how much history the operator has eaten, which is the m7 mistake
> in a new place, and the control exists precisely to catch that.
>
> The transition matrix also turns out to be almost empty for most of the run:
> only **4 of 16 cell-pairs** had ever been observed at window 1,579, reaching 16
> only in the final quarter. That is the sparsity the design note predicted,
> appearing in real data.
>
> What survives unchanged is the **comparison** between the arms. The judge arm
> fails its Markov check and the direct arm passes it, and that is a relative
> statement which does not depend on either λ₂ having converged. Everything below
> about the judges inflating the answer stands. The absolute number does not.

7 September 2026. Run `live_260904_013018`, 2,707 windows, 7.9 hours — the longest
on disk. Both arms computed from the same log.

## The two arms

| | judge-score cells | metric-value cells |
|---|---|---|
| construction | P432, literally | peak, clip, live, gap — no learner |
| K chosen | 5 | 4 |
| spectrum | 1.000 0.999 0.995 0.977 0.916 | 1.000 0.895 0.854 0.752 |
| θ from block null | 0.9556 | 0.8633 |
| **versions m** | **4** | **2** |
| drop after m | 0.0614 | 0.0404 |
| dwell `−1/ln\|λ₂\|` | **1341 windows, 250 min** | **9.0 windows, 1.7 min** |
| empirical dwell | **93 windows, 17.4 min** | **9.7 windows, 1.8 min** |
| **the two dwells** | **disagree 14×** | **agree to 8%** |
| 1 − \|λ₂\| | 0.0007 | 0.1055 |

## The judge arm fails its own Markov check

The readout prints its own condition: *"if the two disagree badly the chain is not
Markov at this cell size."* On the judge arm they disagree by a factor of
fourteen. λ₂ = 0.999 says a version should persist four hours; the label sequence
changes 29 times in eight, which is one every seventeen minutes.

The cause is in `judges.py` and was already documented there for a different
reason. Judge scores are computed over **sliding histories** — the file's own null
discussion notes criteria over 20- and 15-window windows — so consecutive
profiles overlap *by construction*. That manufactures short-range persistence in
the cell sequence, which pushes λ₂ toward 1 and inflates the dwell. It is the
same reason the file needed a block shuffle rather than a plain one.

So the four versions lasting four hours are an artefact of the feature
construction, not a property of the factory. **A readout that had only the judge
arm would have reported them as the result.**

## The metric arm passes, and says something modest

Theoretical and empirical dwell agree to 8%, so λ₂ can be trusted at this cell
size. The answer:

**Two nearly-invariant regions in the evaluative profile, each held for about
1.8 minutes.**

That is close to the section rate — 229 sections in 28,572 s on this same run is
one every 125 s, or 2.1 minutes. So the regions the operator finds are, to within
the resolution available, **sections seen through the metrics**. The evaluative
profile turns over when the section turns over, and not on any slower clock.

## What this licenses, and what it does not

It licenses saying the readout exists, runs on real wake, passes a consistency
check, and returns a number. It does **not** license calling the factory
well-versioned. Two regions at 1.8 minutes is, in P432's own vocabulary, much
closer to *"provisional or transitional"* than to *"durable and well defined"*.

It is also the third independent result pointing the same way — the HMM scoring
worse than a unigram, the judges beating chance by an uncomfortable margin, and
now a dwell at the section timescale. The wake may simply not carry structure
above the section. That was pre-registered as an acceptable outcome and it should
be stated plainly if the drafting chat wants to lean on versioning.

## And it is direct evidence for a design argument made earlier from theory alone

`VERSION_READOUT_DESIGN.md` argued on 6 September that the judges should be kept
out of the cell definition, because they are the component shown not to work and
because ¶484/¶486 already named operator cells the wrong state space *for that
reason*. That was an argument from principle. This is the same conclusion from
data: on the same run, the judge arm fails the Markov check and the direct arm
passes it, and the judge arm's answer is fourteen times more flattering.

Keep both arms. Report both. The disagreement is the finding.

## Reproduce

```
python3 tools/judges.py --log <log> --cells /tmp/cells_j.npy --cell-source judges
python3 tools/judges.py --log <log> --cells /tmp/cells_m.npy --cell-source metrics
python3 tools/version_operator.py --cells /tmp/cells_j.npy
python3 tools/version_operator.py --cells /tmp/cells_m.npy
```

`tools/test_version_readout.py` verifies the readout points the right way against
three chains with known answers before either of these is believed.
