#!/usr/bin/env python3
"""B8 rung 3, first half: the factory's evidence about its own sources, and
its proposals about their weights.

Called by tools/check_machine.sh after a rung 2 machine PASSES its render. It
scores the render with kind_distance.pitch_structure (the factory's reading of
charter norm n5_new_in_kind), appends the score to source_evidence.jsonl in the
mutable dir, and, when a source's evidence disagrees with its current weight,
appends a PROPOSAL to charter_proposals.jsonl. It never changes a weight: the
architect adopts or refuses (tools/triage_proposals.py), and an adoption is a
charter edition. That is the book's route for auxiliary input: 'ratified, in
retrospect, as provisioned input only through the revision of the charter'.

The rule is the architect's and stated here, 27 Sept 2026:
  - evidence per source = mean pitch score over its last 8 admitted renders,
    counted only from 4 renders on;
  - mean > 0 and weight <= the mean weight of all sources -> propose x2, cap 4;
  - mean < 0 and weight >= the mean weight           -> propose x0.5, floor 0.25;
  - at most one open proposal per source.

  python3 tools/source_evidence.py --wav R.wav --machine M.scd --mutable DIR
  python3 tools/source_evidence.py --selftest
"""
import argparse, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kind_distance as K

SOURCES = ["playbuf", "grainbuf", "warp1", "pitchshift", "klank", "wavetable"]


def source_of(text):
    # the grammar writes "// SOURCE <name>;" into every def: read that first
    import re
    m = re.search(r"// SOURCE (\w+);", text)
    if m:
        return m.group(1)
    for tok, s in (("Klank", "klank"), ("PitchShift", "pitchshift"), ("Warp1", "warp1"),
                   ("GrainBuf", "grainbuf"), ("BufRd", "wavetable"), ("PlayBuf", "playbuf")):
        if tok in text:
            return s
    return None


def weights(policy):
    toks = (policy.get("synth_source_weights") or "").split()
    w = {s: 1.0 for s in SOURCES}
    for k, v in zip(toks[0::2], toks[1::2]):
        if k in w:
            w[k] = float(v)
    return w


def open_proposals(path):
    out = set()
    if os.path.exists(path):
        for line in open(path):
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("kind") == "source_weight" and d.get("status", "open") == "open":
                out.add(d.get("source"))
    return out


def decide(src, scores, w):
    last = scores[-8:]
    if src not in w:        # a catalogue source on trial has no live weight to revise
        return None
    if len(last) < 4:
        return None
    mean = sum(last) / len(last)
    avg_w = sum(w.values()) / len(w)
    cur = w[src]
    if mean > 0 and cur <= avg_w and cur < 4:
        return mean, cur, min(4.0, cur * 2)
    if mean < 0 and cur >= avg_w and cur > 0.25:
        return mean, cur, max(0.25, cur * 0.5)
    return None


def run(wav, machine, mutable, corpus):
    text = open(machine).read() if os.path.exists(machine) else ""
    src = source_of(text)
    name = os.path.splitext(os.path.basename(machine))[0]
    med, mad, _ = K.baseline(corpus, 300, os.path.join(mutable, "kind_baseline.json"))
    v = K.summarise(wav)
    if v is None or src is None:
        return None
    _, z = K.distance(v, med, mad)
    score = K.pitch_structure(z)
    ev = os.path.join(mutable, "source_evidence.jsonl")
    with open(ev, "a") as f:
        f.write(json.dumps({"t": int(time.time()), "machine": name, "source": src,
                            "pitch": round(score, 3)}) + "\n")
    scores = [json.loads(l)["pitch"] for l in open(ev) if json.loads(l)["source"] == src]
    policy = json.load(open(os.path.join(mutable, "policy.json")))
    w = weights(policy)
    props = os.path.join(mutable, "charter_proposals.jsonl")
    d = decide(src, scores, w)
    line = f"EVIDENCE {name} {src} pitch {score:+.2f} n {len(scores)}"
    if d and src not in open_proposals(props):
        mean, cur, new = d
        with open(props, "a") as f:
            f.write(json.dumps({
                "proposed_at": int(time.time()), "kind": "source_weight", "status": "open",
                "norm": "n5_new_in_kind", "source": src, "from": cur, "to": new,
                "evidence": {"renders": len(scores[-8:]), "mean_pitch": round(mean, 3)},
                "rationale": f"{src}: mean pitch structure {mean:+.2f} over its last "
                             f"{len(scores[-8:])} admitted renders against weight {cur}; "
                             f"proposes {new}. Pitch structure is the factory's reading of "
                             f"n5, unvalidated beyond the 27 Sept listening."}) + "\n")
        line += f" PROPOSAL {src} {cur}->{new}"
    return line


def selftest():
    w = {s: 1.0 for s in SOURCES}; w["klank"] = 3.0; w["warp1"] = 0.5
    ok = decide("playbuf", [1, 1, 1], w) is None                  # too few
    ok &= decide("playbuf", [1, 1, 1, 1], w) == (1.0, 1.0, 2.0)   # raise
    ok &= decide("klank", [-1] * 4, w) == (-1.0, 3.0, 1.5)        # lower
    ok &= decide("warp1", [-1] * 4, w) is None                    # already low
    ok &= decide("klank", [1] * 4, w) is None                     # already high
    ok &= decide("pluck", [1] * 4, w) is None                     # catalogue, not live
    ok &= source_of("x = Warp1.ar(1, PlayBuf") == "warp1"
    ok &= source_of("    // SOURCE pluck; STAGES none\n Pluck.ar(PlayBuf") == "pluck"
    print("selftest", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--wav"); ap.add_argument("--machine"); ap.add_argument("--mutable")
    ap.add_argument("--corpus", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                     "..", "workdir_music", "grains_play_mid"))
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(selftest())
    r = run(a.wav, a.machine, a.mutable, a.corpus)
    print(r or "EVIDENCE none")
