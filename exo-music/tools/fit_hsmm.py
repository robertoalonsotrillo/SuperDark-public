#!/usr/bin/env python3
"""Phase B, version design: fit a latent-state model to the factory's wake.

WHAT THIS IS FOR
----------------
P290 asks for "a descriptive medium, read off the factory's wake, in which
genuinely new configurations can be recognized and held as versions". The
factory has a wake -- `memory.json` and the window log -- and nothing reads
versions off it.

Sections are currently two stipulations:

    \\family -> avail.scramble.keep(rrand(4, 8))     membership: a coin toss
    nextSection = rrand(6, 18)                      length: a uniform draw

A hidden state is neither. It is an emission distribution over the vocabulary,
fitted to what the factory actually did, with a dwell distribution measured
rather than declared. That is the difference between a log and a model.

THE ALPHABET, and why it is 34 and not 158
------------------------------------------
The six-hour run played 158 distinct machine NAMES, of which 131 were written by
the factory. But those 131 span only 7 transitions -- `sc->bu` was written 83
times -- so they are near-copies differing in a random interpolation constant.
Modelling 158 symbols would fit noise and reproduce the error that made the run
look like it trebled its vocabulary. Bridges are collapsed to their transition,
giving 27 base machines + 7 bridge types = 34 behaviours.

STAGED, DELIBERATELY
--------------------
A plain HMM is fitted first and the geometric-dwell assumption is then TESTED
against the decoded state sequence, rather than assumed to be wrong. Document 36
argues geometric dwell is untenable given event durations spanning 0.013 s to
11.394 s; that is an argument about events, and this is a claim about sections.
If the measured dwell is close to geometric, the full semi-Markov machinery buys
nothing and should not be built.

ZERO INFLUENCE. This reads the log and writes a report. Nothing feeds back into
the factory. A model fitted to the factory's own history IS self-derived
vocabulary, which is what turned the audibility score into a convergence engine;
when it is eventually wired in it ships at zero influence with an ablation.

    python3 tools/fit_hsmm.py --log <windows.log> --selftest
"""
import argparse
import collections
import json
import re
import sys

import numpy as np

BR = re.compile(r"^br([a-z]{2})([a-z]{2})\d+$")
NEG = -1e300


def canon(m):
    g = BR.match(m)
    return f"br:{g.group(1)}>{g.group(2)}" if g else m


def load_sequence(path):
    """One label per window: the machine that played the most events in it."""
    byw = collections.defaultdict(list)
    for line in open(path, errors="replace"):
        p = line.strip().split(",")
        if len(p) > 5 and p[3] in ("runtime", "class"):
            try:
                byw[int(p[1])].append(canon(p[2]))
            except ValueError:
                pass
    wins = sorted(byw)
    return [collections.Counter(byw[w]).most_common(1)[0][0] for w in wins]


# --------------------------------------------------------------- HMM, log space
def _lse(a, axis=None):
    m = np.max(a, axis=axis, keepdims=True)
    m = np.where(np.isfinite(m), m, 0.0)
    out = m + np.log(np.sum(np.exp(a - m), axis=axis, keepdims=True))
    return np.squeeze(out, axis=axis) if axis is not None else float(out)


def forward_backward(lpi, lA, lB, obs):
    T, K = len(obs), lA.shape[0]
    la = np.full((T, K), NEG)
    la[0] = lpi + lB[:, obs[0]]
    for t in range(1, T):
        la[t] = _lse(la[t - 1][:, None] + lA, axis=0) + lB[:, obs[t]]
    lb = np.full((T, K), NEG)
    lb[T - 1] = 0.0
    for t in range(T - 2, -1, -1):
        lb[t] = _lse(lA + (lB[:, obs[t + 1]] + lb[t + 1])[None, :], axis=1)
    ll = _lse(la[T - 1])
    lg = la + lb - ll
    return la, lb, lg, ll


def fit_hmm(obs, K, V, iters=120, seed=0, tol=1e-4):
    rng = np.random.default_rng(seed)
    A = rng.random((K, K)) + 1.0
    A /= A.sum(1, keepdims=True)
    B = rng.random((K, V)) + 1.0
    B /= B.sum(1, keepdims=True)
    pi = np.full(K, 1.0 / K)
    prev = -np.inf
    for it in range(iters):
        lA, lB, lpi = np.log(A), np.log(B), np.log(pi)
        la, lb, lg, ll = forward_backward(lpi, lA, lB, obs)
        if ll - prev < tol and it > 5:
            break
        prev = ll
        T = len(obs)
        g = np.exp(lg)
        xi = np.zeros((K, K))
        for t in range(T - 1):
            m = la[t][:, None] + lA + (lB[:, obs[t + 1]] + lb[t + 1])[None, :] - ll
            xi += np.exp(m)
        A = xi + 1e-3                       # Dirichlet smoothing: no zero rows
        A /= A.sum(1, keepdims=True)
        Bn = np.zeros((K, V))
        for t in range(T):
            Bn[:, obs[t]] += g[t]
        B = Bn + 1e-3
        B /= B.sum(1, keepdims=True)
        pi = g[0] + 1e-6
        pi /= pi.sum()
    return pi, A, B, prev


def loglik(pi, A, B, obs):
    _, _, _, ll = forward_backward(np.log(pi), np.log(A), np.log(B), obs)
    return ll


def viterbi(pi, A, B, obs):
    T, K = len(obs), A.shape[0]
    lA, lB = np.log(A), np.log(B)
    d = np.full((T, K), NEG)
    psi = np.zeros((T, K), dtype=int)
    d[0] = np.log(pi) + lB[:, obs[0]]
    for t in range(1, T):
        m = d[t - 1][:, None] + lA
        psi[t] = np.argmax(m, axis=0)
        d[t] = m[psi[t], np.arange(K)] + lB[:, obs[t]]
    path = [int(np.argmax(d[T - 1]))]
    for t in range(T - 1, 0, -1):
        path.append(int(psi[t][path[-1]]))
    return path[::-1]


def dwell_runs(path):
    runs, cur, n = [], path[0], 1
    for s in path[1:]:
        if s == cur:
            n += 1
        else:
            runs.append((cur, n)); cur, n = s, 1
    runs.append((cur, n))
    return runs


# ------------------------------------------------------------------- self-test
def selftest():
    """Two well-separated states with LONG dwells. A correct fitter recovers
    them; a broken one does not. Written because the MachineWriter test passed
    vacuously on 26 Aug and asserted nothing."""
    rng = np.random.default_rng(7)
    V, T = 6, 3000
    trueB = np.array([[.6, .3, .05, .02, .02, .01],
                      [.01, .02, .02, .05, .3, .6]])
    obs, st, s = [], [], 0
    while len(obs) < T:
        n = int(rng.integers(15, 40))            # long dwell, far from geometric
        for _ in range(n):
            obs.append(int(rng.choice(V, p=trueB[s]))); st.append(s)
        s = 1 - s
    obs, st = obs[:T], st[:T]
    pi, A, B, ll = fit_hmm(obs, 2, V, seed=1)
    path = viterbi(pi, A, B, obs)
    acc = max(np.mean(np.array(path) == np.array(st)),
              np.mean(np.array(path) != np.array(st)))
    runs = [n for _, n in dwell_runs(path)]
    print(f"  selftest: recovery accuracy {acc:.3f}   mean dwell {np.mean(runs):.1f} (true ~27)")
    ok = acc > 0.9 and 15 < np.mean(runs) < 45
    print("  selftest PASS" if ok else "  selftest FAIL -- do not trust the fit below")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--kmin", type=int, default=2)
    ap.add_argument("--kmax", type=int, default=8)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    if a.selftest and not selftest():
        sys.exit(1)
    print()

    labels = load_sequence(a.log)
    vocab = sorted(set(labels))
    idx = {m: i for i, m in enumerate(vocab)}
    obs = [idx[m] for m in labels]
    V, T = len(vocab), len(obs)
    print(f"  windows {T}   distinct behaviours {V}   (from {a.log.split('/')[-1]})")

    # HELD OUT IN CONTIGUOUS BLOCKS, not at random. Random hold-out on a time
    # series leaks: neighbouring windows are highly dependent, so a shuffled
    # split scores memorisation as generalisation.
    nb = 10
    edges = [round(i * T / nb) for i in range(nb + 1)]
    test_blocks = {3, 7}
    tr = [o for b in range(nb) if b not in test_blocks
          for o in obs[edges[b]:edges[b + 1]]]
    te = [obs[edges[b]:edges[b + 1]] for b in test_blocks]
    print(f"  train {len(tr)}   held out {sum(len(x) for x in te)} in 2 contiguous blocks")
    print()
    print(f"  {'K':>3} {'params':>7} {'obs/param':>10} {'held-out LL/symbol':>20}")
    best, bestK = -np.inf, None
    for K in range(a.kmin, a.kmax + 1):
        pi, A, B, _ = fit_hmm(tr, K, V, seed=0)
        ll = sum(loglik(pi, A, B, x) for x in te)
        n = sum(len(x) for x in te)
        p = K * V + K * K
        print(f"  {K:>3} {p:>7} {len(tr)/p:>10.1f} {ll/n:>20.4f}")
        if ll / n > best:
            best, bestK = ll / n, K
    print(f"\n  best K = {bestK} by held-out likelihood")

    pi, A, B, _ = fit_hmm(obs, bestK, V, seed=0)
    path = viterbi(pi, A, B, obs)
    runs = dwell_runs(path)
    print()
    print("  STATES  (top behaviours by emission probability)")
    for k in range(bestK):
        top = np.argsort(B[k])[::-1][:6]
        occ = np.mean(np.array(path) == k)
        d = [n for s, n in runs if s == k]
        print(f"   s{k}  occupancy {occ:5.1%}  dwell mean {np.mean(d):5.1f} median {int(np.median(d)):3}  "
              + " ".join(f"{vocab[i]}:{B[k][i]:.2f}" for i in top))

    allr = np.array([n for _, n in runs])
    print()
    print("  DWELL: measured vs the two assumptions it replaces")
    print(f"    measured        n={len(allr)}  mean {allr.mean():.1f}  median {int(np.median(allr))}  "
          f"max {allr.max()}  CV {allr.std()/allr.mean():.2f}")
    print(f"    geometric       CV would be ~1.00 (memoryless)")
    print(f"    stipulated      rrand(6,18): mean 12.0, max 18, CV 0.29")
    cv = allr.std() / allr.mean()
    if abs(cv - 1.0) < 0.15:
        print("    -> close to geometric. A plain HMM suffices; the semi-Markov")
        print("       duration machinery would buy little and should not be built yet.")
    else:
        print(f"    -> NOT geometric (CV {cv:.2f}). Explicit durations are justified.")
    if allr.max() > 18:
        print(f"    -> and the longest state persists {allr.max()} windows, which "
              f"rrand(6,18) cannot express at all.")

    if a.out:
        json.dump({"K": int(bestK), "vocab": vocab,
                   "A": A.tolist(), "B": B.tolist(), "pi": pi.tolist(),
                   "path": path,
                   "_note": "Descriptive only. Zero influence on the factory."},
                  open(a.out, "w"))
        print(f"\n  written {a.out}")


if __name__ == "__main__":
    main()
