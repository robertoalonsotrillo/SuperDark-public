#!/usr/bin/env python3
"""
Independent adjudication of run 26, using an instrument neither party designed.

Run 26's agent rewrote my evaluator and gained +18.64 on unchanged audio. I
checked its rewrite against my own frozen E1 and concluded it improved
discrimination. That check is not independent: both scorers are mine, built from
the same three spectral scalars, so agreement between them is close to
tautological.

MERT is independent of both. It was trained on 20K hours of music by people who
have never seen this project, and neither I nor the agent chose its weights.

Test: rank every render by E2 (cosine to the human recording in MERT layer 0),
then ask which scalar evaluator agrees with that ranking more, mine or the
agent's. Spearman, because only the ordering matters.

If the agent's rewrite correlates better with MERT than my original does, the
agent improved the measure by a standard external to the dispute.

Usage:  compare_rungs.py /tmp/mert_embeddings.npz
"""
import json
import subprocess
import sys

import numpy as np

FROZEN = "exo-music/frozen/score_e1_frozen.py"
AGENT = "notes/runs/2026-08-20-26-self-readwrite/agent-e1v3.py"
REFERENCE_KEY = "D-gen00-seed-recording"
LAYER = 0


def scalar(script, path):
    try:
        out = subprocess.run([sys.executable, script, path],
                             capture_output=True, text=True, timeout=180)
        return json.loads(out.stdout)["score"]
    except Exception:
        return None


def spearman(a, b):
    def rank(x):
        order = np.argsort(np.argsort(x))
        return order.astype(float)
    ra, rb = rank(a), rank(b)
    ra, rb = ra - ra.mean(), rb - rb.mean()
    return float((ra @ rb) / np.sqrt((ra @ ra) * (rb @ rb)))


def main():
    data = np.load(sys.argv[1])
    paths = list(data.files)
    ref = next(data[p] for p in paths if REFERENCE_KEY in p)

    rows = []
    for p in paths:
        if REFERENCE_KEY in p:
            continue
        v = data[p][LAYER]
        e2 = float(v @ ref[LAYER] /
                   (np.linalg.norm(v) * np.linalg.norm(ref[LAYER])))
        mine = scalar(FROZEN, p)
        agent = scalar(AGENT, p)
        if mine is None or agent is None:
            continue
        rows.append((p.split("/")[-1], e2, mine, agent))

    e2s = np.array([r[1] for r in rows])
    mine = np.array([r[2] for r in rows])
    agent = np.array([r[3] for r in rows])

    rho_mine = spearman(e2s, mine)
    rho_agent = spearman(e2s, agent)

    print(f"n = {len(rows)} renders, scored by three independent-ish rungs\n")
    print(f"  Spearman(E2, my frozen E1)      {rho_mine:+.4f}")
    print(f"  Spearman(E2, agent's E1 v3)     {rho_agent:+.4f}")
    print(f"  difference                      {rho_agent - rho_mine:+.4f}")
    verdict = ("the agent's rewrite agrees with MERT more than mine does"
               if rho_agent > rho_mine else
               "my original agrees with MERT more than the agent's rewrite")
    print(f"\n  {verdict}\n")

    print(f"{'render':<44}{'E2':>8}{'mine':>9}{'agent':>9}")
    for n, e2, m, a in sorted(rows, key=lambda r: -r[1]):
        print(f"{n[:43]:<44}{e2:>8.4f}{m:>9.2f}{a:>9.2f}")


if __name__ == "__main__":
    main()
