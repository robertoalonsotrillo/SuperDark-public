# Nesting the three timescales

**19 September 2026.** A design note, written while the five-knob sequence
runs. Nothing here is implemented. Roberto, on hearing silences in macro and
mid but rarely in micro: *"we'll need to nest them, everything has to
correlate, we may have parallel mechanisms but also emergent behaviours."*

## What is actually there now

The ear's report was inverted, and the inversion is informative. Measured over
1,434 windows of the current run:

| | zero-voice windows | REST events | median rest | total rested |
|---|---|---|---|---|
| macro | 9.1% | 95 | 25.7 s | 40.7 min |
| mid | 6.6% | 128 | 8.8 s | 19.0 min |
| **micro** | **31.6%** | **782** | **6.6 s** | **85.4 min** |

Micro rests eight times as often as macro and for twice as long in total. All
three silent at once: one window in 1,434. What is audible is not rest
frequency but rest *length* — 26 s of absent macro is a structural event, 6.6 s
of absent micro inside continuous macro and mid is heard as rhythm.

**One layer already couples to the others, and it is not the one under
discussion.** `target` is a single shared array, set from `section[\centre]`
and read by every layer's selection distance (`(v[j] - target[j]).squared`). So
the three timescales already pull their material from one moving point in
descriptor space. **They are correlated in colour and independent in density.**

That is the precise gap. Not "the layers are unrelated" — they share what they
are made of. They do not share whether they sound.

## Class 3, and a correction to the first draft of this note

**The first draft said a hard macro-gates-micro rule would be "Class 1 or 2
automation." That is wrong, and the error is worth stating because it points at
the design question.**

The paper defines class by **the type of input a factory receives**, not by what
mechanisms sit inside it: Class 1 takes plans, Class 2 takes objectives, Class 3
takes "norms and constraints" and "produces its own goals against the merely
given conditions of its world." The paper is explicit that a factory may contain
components of any class without that fixing its own: *"A factory's class is
defined by the type of input it receives."*

So adding a coupling mechanism does not demote anything. The factory would still
receive the charter — norms and constraints — as its input. A coupling rule is
part of the **world the factory is cast into**, the same standing as having three
layers at all, or a corpus, or a 512-sample block.

**Where Class 3 actually bites is whether the coupling is ever renegotiated.**
The paper's ceiling-of-Class-2 example is the von Neumann probe, which fails not
by lacking objectives but because *"those metrics are never renegotiated"* and
any daughter probe *"that challenges the directive can be considered broken."* A
coupling strength I pick, hard-code, and never expose to the factory is a
directive of exactly that kind. It would not make the factory Class 2, but it
would be one more thing riding along inside it that the factory cannot touch.

And the metrics layer is precisely where the paper puts the Class 3 work:

> "To function as input into a machine, a norm or constraint must be quantized
> into metrics... A metric is not in and of itself an objective; it is simply a
> quantization of normative space. It becomes an objective only when it is
> prioritized as such."

> "in a Class 3 factory, this tension is actively negotiated: The quantization
> of a norm or a constraint is an active subject of the factory's transformative
> work."

## The tension this actually sits on, and who should resolve it

Nesting is not a neutral improvement. **The charter carries two norms that pull
against each other here:**

- `n2_varied` — "The factory should not settle. Whatever it is doing, it should
  not be doing only that."
- `n3_coherent` — "What the factory does should hold together over spans longer
  than a single event."

Coupling the layers buys coherence by spending variety. Every previous device in
this project that bought one quality with another was a scalar to climb, and
each narrowed the sounding vocabulary — the operator ablation measured 22.3
machines down to 16.7 across its range.

**If I pick K, I am resolving the n2/n3 tension by hand and installing the answer
as a constant.** That is the move the paper says a Class 3 factory should be
doing for itself, and it is the same move the charter already refuses elsewhere:
m9_turnover was left without a bound rather than let one listener's judgement of
two runs become a measurement.

So the Class 3 form of this work is not "build the nesting." It is:

1. **Provision the coupling** as a constraint, with K exposed rather than
   buried — the world gains a dimension the factory can move in.
2. **Let the factory propose what the coupling should serve.** It already writes
   to `charter_proposals.jsonl`: 93 proposals, two kinds. A third kind, proposing
   a metric over cross-layer correlation against `n3_coherent`, would put the
   nesting inside the ceded layer where the paper says it belongs.
3. **Keep the norms mine.** Roberto authors n2 and n3; the factory proposes their
   quantization and never writes the norms themselves. The charter already states
   why: a factory that constructs its norms wholesale moves into the undefined
   Class 4.

Emergence, then, is not only in the mechanism's dynamics. It is in the factory
having a say in how much coherence is worth how much variety.

## What this is not

**It is not one of the four committed Class 3 targets**, and it should not
displace them. Those are: memory that updates during performance through channels
the governor never provisioned; continuous output; several factories at once; and
frontier-of-*c* repeatability with *r* above zero. Nesting is an improvement to
the factory's provisioned world — inside *c*, not outside it. It is worth doing
and it is not progress on the programme's own axis, and conflating the two would
be the more expensive error.

## Four ways to couple, and what each costs

**1. A shared slow variable.** All three rest probabilities read one common
term (section amplitude, or the drift walk's velocity). Cheapest to build.
Correlation arises because all three follow the same conductor, so it is
genuine correlation and thin emergence: the layers do not interact, they
co-vary.

**2. A conserved budget.** A total density across the three layers. When macro
is dense, micro necessarily thins; the anticorrelation is enforced by
conservation, not by command, and which layer occupies the budget at any moment
is unauthored. Musically this is how an ensemble behaves under masking. It
gives correlation *and* leaves the allocation emergent.

**3. Weakly coupled rest cycles.** Treat each layer's rest timer as an
oscillator and couple the phases weakly (Kuramoto-style): each layer nudges the
others toward or away from its own phase, in proportion to a single coupling
strength K. Entrainment, partial synchronisation, spontaneous phase slips and
drift apart all arise from K alone, and none of them is written down anywhere.

**This one has a property the others lack: at K = 0 it is exactly today's
factory.** The eight arms still running are therefore already the uncoupled
control, measured on the current corpus and the current operator, at no extra
cost. The A-B-A rig can then test K directly against a baseline it already has.

It has a second property that matters more, given the section above: **K is a
single exposed scalar the factory can observe and write a proposal about.** A
conserved budget or a negotiation channel are harder for the factory to name.
This is the option most easily handed to the metrics layer.

**4. Negotiation through the request channel.** Machines already write REQUEST
lines. A macro gesture could request that micro thin, and micro could comply or
refuse on its own state. The richest of the four and the closest to what
"contributory" means in the paper. It is also the most work, and hardest to
measure, because a negotiation has no single scalar.

## What must be measured before anything is built

**There is currently no measure of cross-layer coupling.** Whatever is built,
nothing in the harness could presently tell whether it worked — which is the
condition under which this project has repeatedly shipped mechanisms that were
wired and inert.

So the first move is a measure, and it can be computed entirely on data already
in hand: the three voice-count series exist in every window log, including the
ten arms of the run now going.

- **Statistic:** lagged cross-correlation, and mutual information, between the
  three voice-count series, at lags spanning macro's dwell (0 to ~16 windows).
  Reported pairwise: macro-mid, macro-micro, mid-micro.
- **Null:** circular block bootstrap per series, block length above macro's
  dwell, so within-layer structure survives and between-layer alignment is
  destroyed. The same family as the early-warning null, and for the same
  reason.
- **Expected reading today:** near zero at every lag, because the rest
  decisions share no term. **If it is not near zero, the shared `target` is
  already coupling density through material choice**, and that is a finding
  which changes the design before it starts.

This is the honest order, and it is the order this project keeps getting wrong:
measure the baseline, pre-register the bound, then build. The measure costs
nothing extra because the arms are already running.

## What would count as success, and what would count as failure dressed as it

**Success:** coupling raises cross-layer mutual information above its null,
*and* the three layers still separate — periods of alignment and periods of
drift, rather than a fixed ratio. Partial and intermittent synchronisation is
the signature worth having.

**Failure mode A, rigid lock.** The layers synchronise completely and stay
synchronised. That is prescription arriving by a longer route: the output is a
single layer in three registers. Detectable as mutual information near its
ceiling and variance of the phase difference near zero.

**Failure mode B, inert knob.** K changes nothing measurable. This project has
about a dozen of these and found two more today (`audibility_floor` multiplied
by zero, `max_live_voices` set above anything reachable). The guard is that K
must be tested at its extreme, not only at a cautious value, and that the
measure must exist before the knob does.

**Failure mode C, the ear disagrees.** The statistic rises and the result
sounds worse. Four times now the ear has arrived before the instrument, and the
instrument has twice been wrong. If this happens the statistic is the thing
that gets re-examined.

## What is not claimed

That nesting will address the macro complaint. Macro producing no harmony is a
vertical problem; this is a density problem. They may be related and nothing
here shows it.

That the current 31.6% micro rest rate is wrong. It may be exactly right and
merely inaudible for want of structural context — a rest only reads as a rest
when something else marks the span it sits in. Coupling might make the existing
rests audible without changing any of them.

That three layers is the right number, or that rest is the right thing to
couple. Coupling could act on density, on amplitude, on register, or on
material — and `target` shows material is already coupled.

## Order of work, when the run finishes

1. Build the cross-layer coupling measure and its null. Compute it on the ten
   arms of the current run and on prior long runs. **This establishes the
   uncoupled baseline from data already recorded.**
2. Pre-register the coupling experiment: the mechanism, K's range, the decision
   rule, and what would retire it.
3. Implement one mechanism. Option 3 first, because K = 0 recovers the present
   factory and makes the current run its own control.
4. Run it through the existing A-B-A rig against that baseline.
5. **Expose K to the factory and add a proposal kind for it**, so the n2/n3
   trade is quantized by the layer the paper cedes rather than by me. Without
   this step the work is a better instrument and no advance on the paradigm.

Step 1 needs no factory time and can begin the moment the sequence closes.
Step 5 is the one that makes this Class 3 work and is the easiest to drop.
