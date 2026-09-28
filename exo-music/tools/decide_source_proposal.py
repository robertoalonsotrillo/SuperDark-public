#!/usr/bin/env python3
"""The architect's answer to a source_weight proposal (B8 rung 3, 27 Sept 2026).

  python3 tools/decide_source_proposal.py --list
  python3 tools/decide_source_proposal.py N adopt  "reason"
  python3 tools/decide_source_proposal.py N refuse "reason"

N is the proposal's line number in charter_proposals.jsonl (1-based, the
numbering charter_decisions.jsonl already uses). Adopt: the weight in
policy.json synth_source_weights changes, the charter gets a new edition whose
note records it (every change to the input is a new version, P518), and the
decision is logged. Refuse: only the decision is logged. Either way the
proposal is closed, so the factory may propose again on new evidence. Nothing
here runs without a person typing it.
"""
import collections, json, os, sys, time
M = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "workdir_music", "mutable")
P, D = os.path.join(M, "charter_proposals.jsonl"), os.path.join(M, "charter_decisions.jsonl")
OD = collections.OrderedDict


def lines():
    return open(P).read().splitlines()


def main():
    L = lines()
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        for i, l in enumerate(L, 1):
            d = json.loads(l)
            if d.get("kind") == "source_weight":
                print(f"#{i} [{d.get('status','open')}] weight {d['source']} {d['from']} -> {d['to']}  {d['evidence']}")
            elif d.get("kind") == "source_add":
                print(f"#{i} [{d.get('status','open')}] ADD {d['source']}  {d['evidence']}")
        return 0
    n, verb, reason = int(sys.argv[1]), sys.argv[2], " ".join(sys.argv[3:])
    d = json.loads(L[n - 1], object_pairs_hook=OD)
    assert d.get("kind") in ("source_weight", "source_add") and d.get("status", "open") == "open", "not an open source proposal"
    assert verb in ("adopt", "refuse") and reason, "usage: N adopt|refuse reason"
    if verb == "adopt":
        pp = os.path.join(M, "policy.json")
        pol = json.load(open(pp), object_pairs_hook=OD)
        toks = pol["synth_source_weights"].split()
        w = OD(zip(toks[0::2], toks[1::2]))
        if d["kind"] == "source_add":
            ad = pol.get("synth_sources_adopted", "").split()
            if d["source"] not in ad:
                ad.append(d["source"])
            pol["synth_sources_adopted"] = " ".join(ad)
            w[d["source"]] = f"{float(d.get('weight', 1.0)):g}"
        else:
            w[d["source"]] = f"{float(d['to']):g}"
        pol["synth_source_weights"] = " ".join(f"{k} {v}" for k, v in w.items())
        json.dump(pol, open(pp, "w"), indent=2)
        cp = os.path.join(M, "charter.json")
        c = json.load(open(cp), object_pairs_hook=OD)
        e = int(c["edition"]) + 1
        c["edition"] = e
        c["authored"] = time.strftime("%Y-%m-%d")
        what = (f"source {d['source']} ADDED at weight {d.get('weight', 1.0)}" if d["kind"] == "source_add"
                else f"{d['source']} weight {d['from']} -> {d['to']}")
        c[f"_edition_{e}"] = (f"Edition {e}: adopted proposal {n} (the factory's, B8 rung 3): "
                              f"{what} under n5_new_in_kind. {reason}")
        json.dump(c, open(cp, "w"), indent=1)
        json.dump(c, open(os.path.join(M, f"charter_edition_{e}.json"), "w"), indent=1)
    d["status"] = "adopted" if verb == "adopt" else "rejected"
    L[n - 1] = json.dumps(d)
    open(P, "w").write("\n".join(L) + "\n")
    with open(D, "a") as f:
        f.write(json.dumps({"proposal": n, "decision": d["status"],
                            "by": "Roberto Alonso Trillo", "reason": reason}) + "\n")
    print(f"proposal {n} {d['status']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
