#!/usr/bin/env python3
"""Read a catalogue trial (tools/trial_sources.scd) and propose sources to add.
B8 rung 3, second half, 27 Sept 2026.

The rule is the architect's: a catalogue source is proposed for adoption when
at least 3 of its 4 trial machines pass the live admission render AND the mean
n5 score (kind_distance.pitch_structure) of those that passed is above zero.
A source already proposed and open is not proposed again. The proposal goes to
the LIVE charter_proposals.jsonl; adoption is the architect's
(tools/decide_source_proposal.py N adopt|refuse "reason").

  python3 tools/trial_propose.py [--sandbox /tmp/trial_sources] [--dry]
"""
import argparse, collections, json, os, time
HERE = os.path.dirname(os.path.abspath(__file__))
LIVE = os.path.join(HERE, "..", "workdir_music", "mutable")

ap = argparse.ArgumentParser()
ap.add_argument("--sandbox", default="/tmp/trial_sources")
ap.add_argument("--dry", action="store_true")
a = ap.parse_args()

tried = collections.Counter(); passed = collections.Counter()
for line in open(os.path.join(a.sandbox, "trial.log")):
    src, name, out = (line.rstrip("\n").split("\t") + ["", ""])[:3]
    if name == "-":
        continue
    tried[src] += 1
    if "ADMITTED" in out:
        passed[src] += 1
ev = collections.defaultdict(list)
p = os.path.join(a.sandbox, "source_evidence.jsonl")
if os.path.exists(p):
    for line in open(p):
        d = json.loads(line); ev[d["source"]].append(d["pitch"])

props = os.path.join(LIVE, "charter_proposals.jsonl")
open_srcs = set()
for line in open(props):
    d = json.loads(line)
    if d.get("kind") == "source_add" and d.get("status", "open") == "open":
        open_srcs.add(d["source"])

adopted = set(json.load(open(os.path.join(LIVE, "policy.json"))).get("synth_sources_adopted", "").split())
for src in sorted(tried):
    s = ev.get(src, [])
    mean = sum(s) / len(s) if s else None
    ok = passed[src] >= 3 and mean is not None and mean > 0
    msg = f"{src:10} passed {passed[src]}/{tried[src]}  n5 mean {mean if mean is None else round(mean, 2)}  -> " + \
          ("PROPOSE" if ok else "no")
    if ok and (src in open_srcs or src in adopted):
        msg += " (already open or adopted)"; ok = False
    print(msg)
    if ok and not a.dry:
        with open(props, "a") as f:
            f.write(json.dumps({
                "proposed_at": int(time.time()), "kind": "source_add", "status": "open",
                "norm": "n5_new_in_kind", "source": src, "weight": 1.0,
                "evidence": {"trial_passed": passed[src], "trial_tried": tried[src], "mean_pitch": round(mean, 3),
                             "renders": os.path.join(a.sandbox, "renders")},
                "rationale": f"catalogue source {src}: {passed[src]} of {tried[src]} trial machines pass the live "
                             f"admission render; mean n5 score {mean:+.2f}. Proposes adding it to the live sources "
                             f"at weight 1."}) + "\n")
