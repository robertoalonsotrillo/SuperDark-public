#!/usr/bin/env python3
"""Which measures may promote a change, and which may only block one.

WHY THIS EXISTS
---------------
Exo's continual-release proposal splits its evaluation in two. A fixed suite of
everything that ever went wrong, which the candidate has seen, and which
therefore "can only block a candidate". Fresh tasks generated after the
candidate was sealed, which it has not seen, and which are the only thing that
can promote it. The reason is stated plainly: a candidate carrying the
champion's whole history "can score high by remembering, not by being better".

Every measure in SuperDark is a seen measure. Recurrence, the charter metrics,
the judges, generation drift: each was built, then every change after it was
made while watching it. Three of them saturated and nobody noticed until the
calibration arms were run. The project has been promoting changes on seen
measures since late August.

A flat ban would leave nothing able to promote anything. So this uses a budget:
a measure may decide PROMOTION_BUDGET changes, then keeps veto power and loses
promotion power. Spending a budget is the signal that new measurement is owed.

    python3 tools/measure_registry.py status
    python3 tools/measure_registry.py check sonic_variety
    python3 tools/measure_registry.py use sonic_variety --change chg_260915_harness
    python3 tools/measure_registry.py owed

Exit codes for `check`, so a script can branch on them:
    0  may promote
    3  veto only (budget spent, or veto_only by construction, or uncalibrated)
    4  retired, and any number it produced is void
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
REG = os.path.join(EM, "harness", "measures.json")


def load():
    with open(REG) as fh:
        return json.load(fh)


def first_sentence(text, limit=58):
    """First sentence, without cutting inside a decimal like 0.9993."""
    out = []
    for i, ch in enumerate(text):
        out.append(ch)
        if ch == "." and (i + 1 >= len(text) or text[i + 1] in " \n"):
            break
    s = "".join(out).strip()
    return s if len(s) <= limit else s[:limit - 1] + "…"


def save(reg):
    tmp = REG + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(reg, fh, indent=1)
    os.replace(tmp, REG)


def power(reg, key):
    """Return (promote, veto, reason)."""
    if key in reg.get("retired", {}):
        return False, False, "retired: " + first_sentence(
            reg["retired"][key]["why"])
    m = reg["measures"].get(key)
    if m is None:
        return False, False, "not in the registry"
    # A MEASURE THAT CANNOT RUN IN A PAIRED COMPARISON MAY NOT VETO ONE.
    #
    # recurrence_sweep is unwired ON PURPOSE -- its own registry entry says it
    # "takes three calibration arms (loop, factory, diverse) and is not a
    # per-arm scorer", so wiring it into an arm would misuse it. But it still
    # held veto power, and an unwired measure reports NOT WIRED, and NOT WIRED
    # vetoes. So a measure structurally incapable of participating vetoed every
    # paired comparison there will ever be, permanently, by design conflict.
    #
    # Found 16 Sept when it blocked the first comparison that ever ran. It keeps
    # its authority where it applies -- calibration -- and holds none over a
    # comparison it cannot take part in. This is NOT the same as retiring it.
    if m.get("_not_wired_on_purpose") and not m.get("cmd"):
        return False, False, ("calibration-only: not a per-arm scorer, so it "
                              "holds no power over a paired comparison")
    if not m.get("calibrated"):
        return False, True, "uncalibrated: no LOOP/DIVERSE arms on record"
    if m.get("veto_only"):
        return False, True, "veto only by construction"
    spent = len(m.get("judged", []))
    budget = reg["promotion_budget"]
    if spent >= budget:
        return False, True, f"budget spent ({spent}/{budget})"
    return True, True, f"{budget - spent} of {budget} left"


def cmd_status(args):
    reg = load()
    budget = reg["promotion_budget"]
    print(f"promotion budget: {budget} adjudications per measure\n")
    print(f"{'measure':22s} {'promote':8s} {'veto':5s} {'used':5s} reason")
    print("-" * 78)
    for key in sorted(reg["measures"]):
        p, v, why = power(reg, key)
        spent = len(reg["measures"][key].get("judged", []))
        print(f"{key:22s} {'YES' if p else 'no':8s} "
              f"{'YES' if v else 'no':5s} {spent:<5d} {why}")
    print()
    print(f"{'retired':22s} why")
    print("-" * 78)
    for key, r in sorted(reg.get("retired", {}).items()):
        print(f"{key:30s} {first_sentence(r['why'], 46)}")
    n_promote = sum(1 for k in reg["measures"] if power(reg, k)[0])
    print()
    if n_promote == 0:
        print("NOTHING CAN PROMOTE A CHANGE RIGHT NOW.")
        print("Every measure is spent, veto-only or retired. A change made")
        print("today can be blocked and cannot be justified. Pre-register a new")
        print("measure, or say in the record that the change went in on the ear.")
    else:
        print(f"{n_promote} measure(s) can still promote a change.")
    return 0


def cmd_check(args):
    reg = load()
    p, v, why = power(reg, args.key)
    print(f"{args.key}: promote={'yes' if p else 'no'} "
          f"veto={'yes' if v else 'no'}  ({why})")
    if p:
        return 0
    return 3 if v else 4


def cmd_use(args):
    reg = load()
    m = reg["measures"].get(args.key)
    if m is None:
        sys.exit(f"{args.key} is not a live measure (retired, or unknown)")
    if args.change in m.get("judged", []):
        print(f"{args.key} already records {args.change}")
        return 0
    p, v, why = power(reg, args.key)
    m.setdefault("judged", []).append(args.change)
    save(reg)
    spent = len(m["judged"])
    budget = reg["promotion_budget"]
    print(f"{args.key} now records {spent} adjudication(s): "
          f"{', '.join(m['judged'])}")
    if p and spent >= budget:
        print(f"\nBUDGET SPENT. {args.key} keeps veto power and loses promotion")
        print("power from here. The next change it looks at can be blocked by it")
        print("and cannot be justified by it. New measurement is owed.")
    elif not p:
        print(f"\nRecorded, but note: this measure could not promote anyway "
              f"({why}).")
    return 0


def cmd_owed(args):
    reg = load()
    owed = reg.get("owed", {})
    if not owed:
        print("nothing owed")
        return 0
    for key, o in sorted(owed.items()):
        print(f"{key}  (raised {o['raised']})")
        print(f"  {o['why']}")
        print(f"  source: {o['source']}\n")
    return 0


def cmd_owe(args):
    reg = load()
    reg.setdefault("owed", {})[args.key] = {
        "why": args.why, "raised": args.raised, "source": args.source}
    save(reg)
    print(f"recorded as owed: {args.key}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status").set_defaults(fn=cmd_status)

    c = sub.add_parser("check"); c.add_argument("key")
    c.set_defaults(fn=cmd_check)

    c = sub.add_parser("use"); c.add_argument("key")
    c.add_argument("--change", required=True)
    c.set_defaults(fn=cmd_use)

    sub.add_parser("owed").set_defaults(fn=cmd_owed)

    c = sub.add_parser("owe"); c.add_argument("key")
    c.add_argument("--why", required=True)
    c.add_argument("--raised", required=True)
    c.add_argument("--source", default="")
    c.set_defaults(fn=cmd_owe)

    args = ap.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
