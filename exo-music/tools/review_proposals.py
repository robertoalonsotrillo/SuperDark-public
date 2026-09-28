#!/usr/bin/env python3
"""The governance half of the contributory arm.

The factory proposes; the architect commits.

P536 cedes the metrics layer: "if you hand it a norm, it will propose a metric
to represent that norm... Every such contribution converts a world-finding into
authored record; the charter takes something the factory encountered as
auxiliary supply and ratifies it as provisioned supply."

P518 makes adoption consequential: "Every change to the input is a new charter,
and every new charter is a new version of the factory."

So adoption is not a config edit. It bumps the charter edition, archives the
previous edition, and records who adopted what and why. That is the anchoring
P290 asks for -- "held as versions, anchored into a singular unit by the
architect's commitment against further alteration."

WHY THIS IS A SEPARATE PROGRAM. P271: "A factory that is not able to participate
in its own charter-writing is again not a superdark factory but instead an
exercise in Class 1 or Class 2 automation." Participation is real only if the
factory's proposals can be refused. Auto-adoption would not be power-sharing, it
would be the factory writing its own acceptance tests unopposed -- and the
project has already watched a self-generated criterion become a convergence
engine three times.

    python3 tools/review_proposals.py --list
    python3 tools/review_proposals.py --adopt 3 --by "Roberto Alonso Trillo"
    python3 tools/review_proposals.py --reject 4 --reason "duplicates m4"
"""
import argparse
import datetime
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(os.path.dirname(HERE), "workdir_music", "mutable")
PROPS = os.path.join(MUT, "charter_proposals.jsonl")
CHARTER = os.path.join(MUT, "charter.json")
DECIDED = os.path.join(MUT, "charter_decisions.jsonl")


def load_props():
    if not os.path.exists(PROPS):
        return []
    out = []
    for i, line in enumerate(open(PROPS)):
        line = line.strip()
        if line:
            try:
                d = json.loads(line)
                d["_n"] = i
                out.append(d)
            except json.JSONDecodeError:
                print(f"  (skipping malformed proposal on line {i})")
    return out


def decided_ids():
    seen = {}
    if os.path.exists(DECIDED):
        for line in open(DECIDED):
            if line.strip():
                d = json.loads(line)
                seen[d["proposal"]] = d
    return seen


def cmd_list():
    props, dec = load_props(), decided_ids()
    if not props:
        print("  no proposals. The factory has not encountered anything it")
        print("  recognised as new, or novelty_threshold is 0, or it has not run")
        print("  since the recognition was added.")
        return
    print(f"  {len(props)} proposal(s), {len(dec)} already decided\n")
    for p in props:
        d = dec.get(p["_n"])
        mark = f"[{d['decision'].upper()}]" if d else "[open]"
        print(f"  {p['_n']:>3} {mark:9} window {p.get('proposed_at'):>5}  "
              f"novelty {p.get('novelty')}  norm {p.get('norm')}")
        print(f"      {p.get('rationale', '')}")
        print(f"      centre {p.get('centre')}  voices {p.get('voices')}")
        print(f"      family {', '.join(p.get('family', []))}")
        if d:
            print(f"      -> {d['decision']} by {d.get('by')} on {d.get('when')}"
                  + (f": {d['reason']}" if d.get("reason") else ""))
        print()


def _adopt_voice_range(ch, p, old):
    """Widen m6_texture to admit a voice density the factory demonstrated.

    WHY THIS METRIC NEEDED RESCUING. m6_texture tests the median concurrent
    voice count against [2, 5] while policy.json pins voices_min..voices_max to
    [2, 4]. The bound sits outside the clamp, so the metric cannot depart while
    that policy holds: it restates a setting instead of testing the factory, and
    it passed ten runs out of ten by arithmetic. P518 asks for "acceptable
    PROBABILITY states"; a quantity with zero probability of departing cannot
    express one.

    THE REPAIR IS NOT TO MOVE THE BOUND. Widening [2,5] to [2,10] changes
    nothing while policy still caps at 4, and tightening it to [3,4] would make
    it bite on a number the architect typed into another file. The repair is to
    widen the POLICY so the factory can choose, and let the CHARTER bound be a
    record of what it has demonstrated it can do while satisfying the other
    norms. Then the metric binds and the policy does not.

    WHY THE FACTORY PROPOSES THE OUTLIER AND NOT ITS AVERAGE. A factory that
    proposed "acceptable voice count = what I currently do" would ratify its own
    behaviour, which is a mirror and not a criterion -- and is exactly how a
    self-generated criterion became a convergence engine three times here (E3,
    the audibility score, the transfer operator). So the proposal fires on
    NOVELTY, the same rule the coverage_holdout proposals use: a density this
    factory has not used before, reached while the run was not silent. The
    architect then decides whether that density should be permitted to future
    versions. The factory finds it; ratifying it is the architect's act.
    """
    m = ch["metrics"].get("m6_texture")
    if m is None:
        raise SystemExit("  no m6_texture in this charter; nothing to widen")
    lo, hi = float(m["acceptable"][0]), float(m["acceptable"][1])
    v = float(p["voices"])
    new_lo, new_hi = min(lo, v), max(hi, v)
    if (new_lo, new_hi) == (lo, hi):
        raise SystemExit(
            f"  voice density {v:g} already inside [{lo:g}, {hi:g}]; adopting "
            f"would change nothing. Reject it instead, so the record says the "
            f"proposal was seen and found redundant.")

    prev = list(m["acceptable"])
    m["acceptable"] = [new_lo, new_hi]
    m["test"] = "median concurrent voices"
    m["_provenance"] = (
        f"Bound widened from {prev} to [{new_lo:g}, {new_hi:g}] in edition "
        f"{old + 1}, adopting a proposal the factory made at window "
        f"{p['proposed_at']}: it reached a median of {v:g} concurrent voices, a "
        f"density it had not previously used, while the run was sounding. "
        f"Before this, m6_texture was DECORATIVE -- policy.json pinned voices to "
        f"[{p.get('policy_min','?')}, {p.get('policy_max','?')}] inside the "
        f"bound, so the metric restated a setting and passed ten runs of ten by "
        f"arithmetic. It now records demonstrated behaviour instead.")
    m["_untested"] = (
        "This bound has never been evaluated against a run that did not produce "
        "it. Read it as pre-registered for future versions, not as calibrated. "
        "It will only stay honest while policy.json's clamp is WIDER than this "
        "bound; if the clamp is ever narrowed back inside it, the metric becomes "
        "decorative again and this note is the thing that should catch it.")
    return "m6_texture"


def _finish(ch, old, n, by, key):
    """The bookkeeping half of adoption, shared by every proposal kind."""
    ch["edition"] = old + 1
    ch["authored"] = datetime.date.today().isoformat()
    ch.setdefault("_lineage", []).append(
        {"edition": old + 1, "from": old, "adopted_proposal": n,
         "by": by, "when": datetime.datetime.now().isoformat(timespec="seconds")})
    json.dump(ch, open(CHARTER, "w"), indent=2)
    with open(DECIDED, "a") as f:
        f.write(json.dumps({"proposal": n, "decision": "adopted", "by": by,
                            "when": datetime.datetime.now().isoformat(timespec="seconds"),
                            "metric": key, "edition": old + 1}) + "\n")
    print(f"  adopted proposal {n} as metric '{key}'")
    print(f"  charter edition {old} -> {old + 1}   (previous archived as "
          f"charter_edition_{old}.json)")


def cmd_adopt(n, by):
    props, dec = load_props(), decided_ids()
    p = next((x for x in props if x["_n"] == n), None)
    if p is None:
        raise SystemExit(f"  no proposal {n}")
    if n in dec:
        raise SystemExit(f"  proposal {n} already {dec[n]['decision']}")

    ch = json.load(open(CHARTER))
    old = ch["edition"]
    # ARCHIVE, never edit in place. P518: every change is a new charter and a new
    # version of the factory. A version you can silently rewrite is not a version.
    arch = os.path.join(MUT, f"charter_edition_{old}.json")
    if not os.path.exists(arch):
        shutil.copy2(CHARTER, arch)

    # DISPATCH ON KIND. Until 1 Sept this function assumed every proposal was a
    # coverage_holdout and minted a new metric for it. A voice_range proposal
    # must instead WIDEN AN EXISTING metric, because m6_texture already asks the
    # question and the whole problem with it is that policy.json answers it.
    if p.get("kind") == "voice_range":
        key = _adopt_voice_range(ch, p, old)
        _finish(ch, old, n, by, key)
        return

    key = f"m{len([k for k in ch['metrics'] if not k.startswith('_')]) + 1}_coverage_s{p['section']}"
    ch["metrics"][key] = {
        "norm": p["norm"],
        "test": ("minimum euclidean distance, in descriptor space, from any "
                 "section centre in the run to the anchored centre below"),
        "acceptable": [0.0, round(float(p["novelty"]), 3)],
        "min_windows": 100,
        "anchored_centre": p["centre"],
        "_provenance": (
            f"PROPOSED BY THE FACTORY at window {p['proposed_at']}, adopted "
            f"into edition {old + 1}. It reached a region {p['novelty']} from "
            f"anything it had previously occupied. P536: this converts a "
            f"world-finding into authored record. The factory found the region; "
            f"the requirement that future versions still reach it is the "
            f"architect's commitment, not the factory's."),
        "_untested": (
            "This bound has never been evaluated against a run that did not "
            "produce it. It is a prediction about future versions and should be "
            "read as pre-registered, not as calibrated.")
    }
    ch["edition"] = old + 1
    ch["authored"] = datetime.date.today().isoformat()
    ch.setdefault("_lineage", []).append(
        {"edition": old + 1, "from": old, "adopted_proposal": n,
         "by": by, "when": datetime.datetime.now().isoformat(timespec="seconds")})
    json.dump(ch, open(CHARTER, "w"), indent=2)

    with open(DECIDED, "a") as f:
        f.write(json.dumps({"proposal": n, "decision": "adopted", "by": by,
                            "when": datetime.datetime.now().isoformat(timespec="seconds"),
                            "metric": key, "edition": old + 1}) + "\n")
    print(f"  adopted proposal {n} as metric '{key}'")
    print(f"  charter edition {old} -> {old + 1}   (previous archived as "
          f"charter_edition_{old}.json)")
    print(f"  P518: this is a new version of the factory.")


def cmd_reject(n, by, reason):
    props, dec = load_props(), decided_ids()
    if not any(x["_n"] == n for x in props):
        raise SystemExit(f"  no proposal {n}")
    if n in dec:
        raise SystemExit(f"  proposal {n} already {dec[n]['decision']}")
    with open(DECIDED, "a") as f:
        f.write(json.dumps({"proposal": n, "decision": "rejected", "by": by,
                            "reason": reason,
                            "when": datetime.datetime.now().isoformat(timespec="seconds")}) + "\n")
    print(f"  rejected proposal {n}: {reason}")
    print("  Recorded rather than deleted. A contributory arm whose refusals")
    print("  leave no trace is indistinguishable from one that was never read.")


def cmd_reject_kind(kind, by, reason, doc, dry):
    """Refuse every undecided proposal of one kind, ONE DECISION LINE EACH.

    WHY NOT A SINGLE COLLECTIVE LINE. 89 of the 93 proposals are the same
    proposal restated: the coverage proposer measures novelty against the run's
    own history, so it never saturates and a factory that runs forever proposes
    forever. It is tempting to answer the class once. But P271 makes
    participation real only if proposals can be refused, and a refusal that does
    not attach to the proposal it refuses cannot be audited later -- proposal 47
    would have no answer, only a policy that happened to cover it. Each gets its
    own record, all pointing at one written reason.

    The reason is required and a document reference is required with it, because
    89 identical one-line refusals with no argument behind them would be
    indistinguishable from deleting the file.
    """
    props, dec = load_props(), decided_ids()
    todo = [p for p in props if p.get("kind") == kind and p["_n"] not in dec]
    if not todo:
        print(f"  no undecided proposals of kind '{kind}'")
        return
    print(f"  {len(todo)} undecided proposals of kind '{kind}'")
    print(f"  reason: {reason}")
    print(f"  see:    {doc}")
    if dry:
        print(f"\n  DRY RUN. Re-run with --commit to write {len(todo)} decisions.")
        print(f"  proposals: {todo[0]['_n']}..{todo[-1]['_n']}")
        return
    when = datetime.datetime.now().isoformat(timespec="seconds")
    with open(DECIDED, "a") as f:
        for p in todo:
            f.write(json.dumps({"proposal": p["_n"], "decision": "rejected",
                                "by": by, "reason": reason, "see": doc,
                                "kind": kind, "when": when}) + "\n")
    print(f"\n  recorded {len(todo)} refusals, one per proposal.")
    print("  Recorded rather than deleted. A contributory arm whose refusals")
    print("  leave no trace is indistinguishable from one that was never read.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--adopt", type=int)
    ap.add_argument("--reject", type=int)
    ap.add_argument("--reject-kind", default=None,
                    help="refuse every undecided proposal of this kind, one "
                         "decision line each")
    ap.add_argument("--see", default="",
                    help="document carrying the argument for the refusal")
    ap.add_argument("--commit", action="store_true",
                    help="without this, --reject-kind only reports")
    ap.add_argument("--by", default="Roberto Alonso Trillo")
    ap.add_argument("--reason", default="")
    a = ap.parse_args()
    if a.adopt is not None:
        cmd_adopt(a.adopt, a.by)
    elif a.reject_kind:
        if not a.reason or not a.see:
            raise SystemExit("  --reject-kind requires --reason AND --see. "
                             "Refusing a whole class on one line, with no "
                             "document behind it, is deletion with extra steps.")
        cmd_reject_kind(a.reject_kind, a.by, a.reason, a.see, not a.commit)
    elif a.reject is not None:
        if not a.reason:
            raise SystemExit("  --reject requires --reason. An unexplained "
                             "refusal is not governance.")
        cmd_reject(a.reject, a.by, a.reason)
    else:
        cmd_list()


if __name__ == "__main__":
    main()
