# Runtime machines

Every file here that ends in `.scd` is a machine the factory can select. It is
loaded with `.load` while the server is running, so **adding one does not stop
the music**. Classes need recompiling; functions do not.

This is what "learning a new behaviour" means in this system. An agent writes a
file into this directory and the factory plays it at the next window boundary,
having never paused.

## The contract

A file must evaluate to a **Function of two arguments** returning an event
pattern:

```supercollider
{ |buf, args|
    // buf  — an Array of Buffers, the whole corpus
    // args — an IdentityDictionary with the seven descriptors:
    //        windowsize percpitch avgflat density avgcent avgrms
    //        mainpitch avgrolloff
    // return any event Pattern; the factory calls .play on it
    Pbind(...)
}
```

The file name without extension becomes the machine's symbol, so
`grind.scd` is selectable as `\grind`.

## Weights

A runtime machine with no entry in `../weights.json` gets a **flat default**:
bias only, no feature coefficients, so it is selectable but never preferred.
To make it responsive to the material, add a block to `weights.json`:

```json
"grind": { "bias": 5.0, "coef": { "density": 0.2, "avgflat": -0.1 },
           "range": [0, 100, 0.0, 1.0] }
```

Both files are re-read at the interval set by `reload_every_n_events` in
`../policy.json`.

## What the existing vocabulary is short of

Run 35 measured it: the sixteen original machines use **five** pattern
constructors, three of which appear in all sixteen. `Ppar`, `Ptpar`, `Pfsm`,
`Pseries`, `Pgeom`, `Pstutter`, `Pclutch`, `Pbind`, `Pmono`, `Plazy`,
`Pswitch`, `Ptuple` and `Pchain` appeared **zero** times. Four of those have
since been used by `dr`, `pu`, `hm` and `me`. The rest are still unused.

## Two traps, both measured the hard way

- **An `Env` in an event slot freezes at its first level** and never advances
  (claim 202). It is not a pattern. Use `Env(...).discretize(n).asArray` inside
  a `Pseq`, or a plain `Pseq` of values.
- **A machine that emits events is not a machine that makes sound.** Six of the
  sixteen originals pass every pattern-level assertion and are inaudible;
  `bu` emits 367 score entries and a file of digital zeros. Check the level.
