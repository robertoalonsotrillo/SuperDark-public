#!/usr/bin/env python3
"""The hard invariants, actually run.

WHY THIS IS A SEPARATE FILE
Each invariant is already a working tool. `seal_rig.py`, `checkpoint.py`,
`archive_guard.py`, `run_integrity.py`, `score_charter.py`. The gate was
recording all seven as UNVERIFIED and blocking on that, which is the right
failure and a useless one. This is the thin wiring that calls them, and it is
deliberately thin: an invariant that reimplements its own check here would drift
from the tool that owns it.

WHAT AN INVARIANT IS
Absolute. No measurement waives one, and an exception in the release policy
waives the win requirement and never these. The seven come from what has
actually gone wrong in this project, and each carries the incident that put it
on the list.

    python3 tools/eval_invariants.py --comparison harness/runs/cmp_260915_163541
    python3 tools/eval_invariants.py --comparison <dir> --json

Exit: 0 all pass, 1 any fail, 2 bad invocation.
"""
import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
HARNESS = os.path.join(EM, "harness")
RENDERS = "/Volumes/FMA/superdark/renders"
ARCHIVE = "/Volumes/FMA/superdark/archive"
# run_integrity.py writes here, on the INTERNAL disk, so that the journal
# survives the external disk vanishing. Kept in step with that module by hand.
INTEGRITY_JOURNAL = "/tmp/superdark_integrity.jsonl"
PY = os.environ.get("PY", sys.executable)


def run(cmd, timeout=600):
    try:
        p = subprocess.run(cmd, cwd=EM, capture_output=True, text=True,
                           timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timed out"
    except FileNotFoundError as e:
        return 127, "", str(e)


def load(path):
    with open(path) as fh:
        return json.load(fh)


def result(ok, observed, why):
    return {"pass": bool(ok), "observed": observed, "_why_this_is_here": why}


# --------------------------------------------------------------------------
def inv_seal_intact(ctx):
    rc, out, _ = run([PY, "tools/seal_rig.py", "verify"])
    return result(rc == 0, out.strip().splitlines()[-1] if out.strip() else "no output",
                  "A number from an unsealed scorer is not attributable to the "
                  "measure its pre-registration names.")


def inv_checkpoint_verifies(ctx):
    bad = []
    for role in ("candidate", "champion"):
        cid = ctx["comp"].get(f"{role}_checkpoint")
        if not cid:
            bad.append(f"{role}: no checkpoint named")
            continue
        rc, out, _ = run([PY, "tools/checkpoint.py", "verify", cid])
        if rc != 0:
            bad.append(f"{role} {cid}: {out.strip().splitlines()[-1] if out else 'failed'}")
    return result(not bad, "; ".join(bad) or "both arms verify",
                  "A comparison run from a checkpoint that does not restore is "
                  "not a comparison.")


def inv_archive_intact(ctx):
    if not os.path.isdir(ARCHIVE):
        return result(False, f"{ARCHIVE} not present (SSD unmounted?)",
                      "The factory eats its own corpus by design; the duplicate "
                      "has to be real.")
    rc, out, err = run([PY, "tools/archive_guard.py", "verify",
                        "--archive", ARCHIVE], timeout=1800)
    tail = (out or err).strip().splitlines()
    return result(rc == 0, tail[-1] if tail else "no output",
                  "The factory eats its own corpus by design; the duplicate has "
                  "to be real. Convention is not preservation.")


def inv_one_change_at_a_time(ctx):
    """A candidate differs from its champion in exactly one thing.

    THE RULE WAS WRITTEN DOWN AND WIRED TO NOTHING. release_policy.v1.json has
    said since it was authored that "a candidate differs from its champion in
    exactly one thing, and checkpoint diff must show it", and no check ever ran
    it. On 16 Sept a candidate differing in FOUR things -- a Nyquist fix, a voice
    probe, a request channel and a SLOTS line -- passed the gate without comment.
    Fifth instance in this project of a rule believed to be operating and
    connected to no code.

    THE GIT HASH IS NOT THE RUNNING CODE, and conflating them would make this
    check wrong in the common case. A checkpoint records the repo HEAD at the
    moment it was taken. The two arms of a hot-reloaded comparison are minutes or
    hours apart, and commits land in between -- on 16 Sept the hash moved from
    5315ed7 to 0d9876a purely because work was committed while the factory ran.
    The factory did not restart, so the code it was EXECUTING was identical by
    construction. Counting that as a second change would block every honest
    hot-reload comparison, which is the same failure as the pairing rule this
    replaced.

    So a code difference counts only when the arms could actually be running
    different code, which means a restart between them -- detectable as two
    different logs. Same log, no restart, same executing code, whatever the
    repository did meanwhile.
    """
    ms = ctx.get("manifests", {})
    cand, champ = ms.get("candidate"), ms.get("champion")
    if not cand or not champ:
        return result(False, "one or both manifests missing",
                      "the rule cannot be checked, and an unverified invariant "
                      "blocks exactly as a failed one does")

    rc, out, _ = run([PY, "tools/checkpoint.py", "diff",
                      champ["checkpoint"], cand["checkpoint"]])
    if rc != 0:
        return result(False, f"checkpoint diff failed: {out.strip()[:120]}",
                      "the rule says the diff must SHOW the one change; if the "
                      "diff cannot run, nothing has been shown")

    changed_keys, code_moved = [], False
    for line in out.splitlines():
        st = line.strip()
        if st.startswith("code:") and "->" in st:
            code_moved = True
        elif "->" in st and ":" in st and not st.startswith(("policy:", "code:")):
            changed_keys.append(st.split(":")[0].strip())

    same_boot = cand.get("log") == champ.get("log")
    n = len(changed_keys) + (0 if same_boot else int(code_moved))

    detail = ", ".join(changed_keys) if changed_keys else "no policy key"
    if code_moved and same_boot:
        detail += " (repo HEAD also moved, but both arms share one log so no "\
                  "restart occurred and the running code is identical)"
    elif code_moved:
        detail += " + code (arms are separate boots, so the code could differ)"

    if n == 1:
        return result(True, f"exactly one change: {detail}",
                      "attribution is only possible when one thing moved")
    if n == 0:
        # A DECLARED NULL IS A MEASUREMENT, AN UNDECLARED ONE IS A MISTAKE.
        #
        # 17 Sept 2026: comparison 2 concluded under its own pre-registered rule
        # that attention_weight is not distinguishable from noise at these
        # sample sizes. No further comparison that CHANGES something can sharpen
        # that, because what is missing is the noise floor -- and the release
        # policy names it as a prerequisite for margins, "a
        # smallest-reportable-difference below which a result is flat".
        #
        # Measuring it requires two identical arms, which is precisely what this
        # branch was written to forbid. So the exemption is allowed, and it has
        # to be BOUGHT IN ADVANCE: both arms must carry intent="null", recorded
        # in the manifest at scoring time by eval_run.py --intent.
        #
        # The case this rule exists for is unaffected. Someone who means to move
        # a knob and does not will have declared nothing, so n == 0 still fails
        # with the same message it always gave. The exemption cannot be claimed
        # after seeing the result, because the manifests are written before the
        # comparison is assembled.
        intents = {(cand or {}).get("intent"), (champ or {}).get("intent")}
        if intents == {"null"}:
            return result(True,
                          "no change, and both arms declared intent=null",
                          "a null comparison measures how far the measures "
                          "drift when nothing changes. That number is the "
                          "smallest-reportable-difference the release policy "
                          "requires before margins can be set, and it cannot "
                          "be obtained from any comparison that changes "
                          "something. NOTHING IS PROMOTABLE FROM A NULL.")
        return result(False, f"NO change found between the arms: {detail}",
                      "two identical configurations are not a comparison. "
                      "If they are identical ON PURPOSE, say so in advance: "
                      "score both arms with --intent null, which is honoured "
                      "only when both carry it.")
    return result(False, f"{n} changes: {detail}",
                  "On 10 September macro_full_vector, rest_macro_after and the "
                  "-70 dB ingest floor went live together and the result "
                  "document had to record that no movement was attributable to "
                  "any of them. That is the cost this rule buys out.")


def inv_run_not_contaminated(ctx):
    rc, out, _ = run([PY, "tools/run_integrity.py", "--report"])

    # SCOPED TO THE ARMS, NOT TO ALL OF HISTORY.
    #
    # This counted every fault in the journal. On 16 Sept it reported 16 and
    # blocked a gate, and not one of them fell inside either arm: seven sclang
    # deaths from 15 Sept, an SSD unplug at 10:00 with two clock jumps behind
    # it, and four restarts that all preceded the champion. An invariant that
    # can never pass on a machine with a bad week is not protecting anything.
    #
    # The span is the union of both arms' own wall clocks, recorded in their
    # manifests. Faults outside it are reported as context and do not block;
    # faults inside it block exactly as before, which is the whole point.
    import datetime as _dt
    spans = []
    for m in ctx.get("manifests", {}).values():
        s, u = m.get("arm_since"), m.get("arm_until")
        if s:
            spans.append((float(s), float(u) if u else time.time()))
    lo = min(s for s, _ in spans) if spans else None
    hi = max(u for _, u in spans) if spans else None

    inside, outside = 0, 0
    for line in out.splitlines():
        t = line.strip().split(None, 1)
        if len(t) < 2 or "T" not in t[0]:
            continue
        if not any(k in line for k in ("DOWN", "CLOCK_JUMP", "SLEEP",
                                       "FIFO", "SATURAT", "FILL_STALL")):
            continue
        try:
            ts = _dt.datetime.strptime(t[0], "%Y-%m-%dT%H:%M:%S").timestamp()
        except ValueError:
            continue
        if lo is not None and lo <= ts <= hi:
            inside += 1
        else:
            outside += 1

    if lo is None:
        # Old bundles carry no arm_since. Fall back to the whole journal and SAY
        # SO, rather than silently passing something that was never checked.
        faults = None
        for line in out.splitlines():
            if "of them faults" in line:
                toks = line.strip().split()
                for i, t2 in enumerate(toks):
                    if t2 == "of" and i:
                        try:
                            faults = int(toks[i - 1])
                        except ValueError:
                            pass
                        break
        ok = rc == 0 and faults == 0
        return result(ok, (f"{faults} fault(s) across the WHOLE journal; this "
                           f"bundle predates arm_since so the arm's own window "
                           f"could not be isolated")
                      if faults is not None else "could not parse the report",
                      "28 Aug: the clock jumped 20,309 s, the FIFO filled 77,491 "
                      "times, 85% of an 8 h run was unusable, and not one charter "
                      "metric noticed.")

    # The 16 Sept change scoped the COUNT to the arms but left `rc == 0` in the
    # verdict, and rc is the whole journal's -- and is 1 when there is no journal
    # at all. On 18 Sept that produced "FAIL 0 fault(s) inside the arms": an
    # invariant failing while its own message said nothing was wrong. A gate that
    # cannot say why it blocked is not a gate.
    if not os.path.isfile(INTEGRITY_JOURNAL) or "no integrity log" in out:
        return result(False,
                      "NOT CHECKED: the integrity monitor never ran, so there is "
                      "no journal and no sleep, clock jump or FIFO stall during "
                      "these arms could be ruled out",
                      "This is not a clean result, it is an absent one. Start "
                      "tools/run_integrity.py --watch BEFORE the arms, not after.")
    if "of them faults" not in out:
        return result(False, f"the integrity report could not be read (rc={rc})",
                      "An unreadable report is not an absence of faults.")

    ok = inside == 0
    return result(ok, f"{inside} fault(s) inside the arms"
                      + (f" ({outside} elsewhere in the journal, not counted)"
                         if outside else ""),
                  "28 Aug: the clock jumped 20,309 s, the FIFO filled 77,491 "
                  "times, 85% of an 8 h run was unusable, and not one charter "
                  "metric noticed.")


def inv_no_stall(ctx):
    bad = []
    for role in ("candidate", "champion"):
        log = ctx["logs"].get(role)
        if not log:
            bad.append(f"{role}: no log")
            continue
        path = os.path.join(RENDERS, log)
        if not os.path.isfile(path):
            bad.append(f"{role}: {log} missing")
            continue
        stalls = untracked = 0
        with open(path, errors="replace") as fh:
            for line in fh:
                if line.startswith("FILL_STALL"):
                    stalls += 1
                elif line.startswith("UNTRACKED"):
                    untracked += 1
        if stalls or untracked:
            bad.append(f"{role}: {stalls} FILL_STALL, {untracked} UNTRACKED")
    return result(not bad, "; ".join(bad) or "zero stalls in both arms",
                  "An unbounded voice-fill loop once left 16 minutes of -91 dB "
                  "dead air and 42,619 UNTRACKED lines while every process "
                  "reported healthy.")


def inv_charter_not_regressed(ctx):
    m = ctx["comp"]["measures"].get("score_charter", {})
    cand, champ = m.get("candidate"), m.get("champion")
    if not isinstance(cand, dict) or not isinstance(champ, dict):
        return result(False, "score_charter did not produce numbers on both arms",
                      "The charter is the standing record of what must not go "
                      "wrong. It vetoes and never promotes.")
    charter = load(os.path.join(EM, "workdir_music", "mutable", "charter.json"))
    regressed = []
    for key, spec in charter["metrics"].items():
        if key.startswith("_") or not isinstance(spec, dict):
            continue
        lo, hi = (spec.get("acceptable") or [None, None])[:2]
        if lo is None and hi is None:
            continue           # described, not bounded
        a, b = cand.get(key), champ.get(key)
        if a is None or b is None:
            continue

        def inside(v):
            return ((lo is None or v >= lo) and (hi is None or v <= hi))
        if inside(b) and not inside(a):
            regressed.append(f"{key}: champion {b} in [{lo},{hi}], candidate {a} out")
    return result(not regressed, "; ".join(regressed) or
                  "no charter metric that passed for the champion fails for the candidate",
                  "Every charter metric has passed while the output was "
                  "sonically identical, so the charter can only ever block.")


def inv_min_windows(ctx):
    pol = ctx["policy"]
    need = 200
    for c in pol["hard_invariants"]["checks"]:
        if c["key"] == "min_windows":
            for tok in c["test"].split():
                if tok.isdigit():
                    need = int(tok)
                    break
    short = []
    for role in ("candidate", "champion"):
        man = ctx["manifests"].get(role)
        if not man:
            short.append(f"{role}: no manifest")
            continue
        lo, hi = man["windows"]
        scored = hi - lo
        if scored < need:
            short.append(f"{role}: {scored} windows scored, need {need}")
    return result(not short, "; ".join(short) or
                  f"both arms score at least {need} windows",
                  "A 600-3600 s match window once scored 8 frames and put the "
                  "factory above a literal loop.")


def inv_learning_frozen_during_isolation(ctx):
    """An experiment must not feed the channels it is measuring."""
    import glob
    pol_path = os.path.join(EM, "workdir_music", "mutable", "policy.json")
    try:
        layers = load(pol_path).get("layers_active", "macro mid micro").split()
    except Exception as e:
        return result(False, f"cannot read policy: {e}", "isolation check needs policy")
    if len(layers) >= 3:
        return result(True, "not an isolation run; all three layers active",
                      "the check only binds when a layer is silenced")
    rc = subprocess.run(["pgrep", "-f", "self_ingest.py"], capture_output=True)
    n = len(rc.stdout.split()) if rc.returncode == 0 else 0
    quarantined = glob.glob(os.path.join(
        "/Volumes/FMA/superdark/self_corpus", "_quarantine_*"))
    ok = (n == 0)
    return result(ok,
                  f"layers_active='{' '.join(layers)}', {n} ingest daemon(s) "
                  f"running, {len(quarantined)} quarantine dir(s) on record",
                  "15 Sept: a macro-only run admitted macro audio into the micro "
                  "and mid pools while they were silent, and memory.json took on "
                  "20 sections describing a factory that does not exist.")


def inv_one_ingest_daemon(ctx):
    rc = subprocess.run(["pgrep", "-f", "self_ingest.py"], capture_output=True)
    n = len(rc.stdout.split()) if rc.returncode == 0 else 0
    return result(n <= 1, f"{n} self_ingest.py process(es)",
                  "15 Sept: four at once, one per start_loop.sh invocation, "
                  "racing on ingested.json and on admission.")


CHECKS = {
    "learning_frozen_during_isolation": inv_learning_frozen_during_isolation,
    "one_change_at_a_time": inv_one_change_at_a_time,
    "one_ingest_daemon": inv_one_ingest_daemon,
    "seal_intact": inv_seal_intact,
    "checkpoint_verifies": inv_checkpoint_verifies,
    "archive_intact": inv_archive_intact,
    "run_not_contaminated": inv_run_not_contaminated,
    "no_stall": inv_no_stall,
    "charter_not_regressed": inv_charter_not_regressed,
    "min_windows": inv_min_windows,
}


def evaluate(comp_dir, policy_path, skip=()):
    comp = load(os.path.join(comp_dir, "comparison.json"))
    policy = load(policy_path)
    runs_root = os.path.join(HARNESS, "runs")
    manifests, logs = {}, {}
    for role in ("candidate", "champion"):
        rd = os.path.join(runs_root, comp[f"{role}_run"])
        mp = os.path.join(rd, "manifest.json")
        if os.path.isfile(mp):
            manifests[role] = load(mp)
            logs[role] = manifests[role].get("log")
    ctx = {"comp": comp, "policy": policy, "manifests": manifests, "logs": logs}

    out = {}
    for c in policy["hard_invariants"]["checks"]:
        key = c["key"]
        fn = CHECKS.get(key)
        if fn is None:
            out[key] = {"pass": None, "test": c["test"],
                        "observed": "NOT WIRED: no check implements this"}
            continue
        if key in skip:
            out[key] = {"pass": None, "test": c["test"],
                        "observed": "SKIPPED at the caller's request"}
            continue
        r = fn(ctx)
        r["test"] = c["test"]
        out[key] = r
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--comparison", required=True)
    ap.add_argument("--policy", default=os.path.join(
        HARNESS, "release_policy.v1.json"))
    ap.add_argument("--skip", default="",
                    help="comma-separated keys to skip; each is recorded as "
                         "SKIPPED, never as passing")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    comp_dir = args.comparison
    if not os.path.isdir(comp_dir):
        comp_dir = os.path.dirname(comp_dir)
    if not os.path.isfile(os.path.join(comp_dir, "comparison.json")):
        print(f"no comparison.json under {comp_dir}", file=sys.stderr)
        return 2

    res = evaluate(comp_dir, args.policy,
                   skip=tuple(x for x in args.skip.split(",") if x))
    with open(os.path.join(comp_dir, "invariants.json"), "w") as fh:
        json.dump(res, fh, indent=1, sort_keys=True)

    if args.json:
        print(json.dumps(res, indent=1, sort_keys=True))
    else:
        for key, r in res.items():
            mark = {True: "ok  ", False: "FAIL", None: "----"}[r["pass"]]
            print(f"{mark}  {key:24s} {r['observed']}")
        failed = [k for k, r in res.items() if r["pass"] is False]
        unver = [k for k, r in res.items() if r["pass"] is None]
        print()
        if failed:
            print(f"{len(failed)} invariant(s) FAILED. No measurement waives one.")
        if unver:
            print(f"{len(unver)} unverified: {', '.join(unver)}")
        if not failed and not unver:
            print("all invariants pass")
    return 1 if any(r["pass"] is False for r in res.values()) else 0


if __name__ == "__main__":
    sys.exit(main())
