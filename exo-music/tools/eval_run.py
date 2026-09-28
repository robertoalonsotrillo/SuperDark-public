#!/usr/bin/env python3
"""One arm of one comparison. Writes a bundle of plain files and nothing else.

Called through tools/eval_rig.sh, which verifies the seal first. Run it directly
only when you want to see it fail for the right reason.

The bundle is the source of truth. No service needs to be running to inspect a
completed run, and a run that dies resumes from its directory. That property is
worth more than it looks: the numbers in the proposal have to still mean what
they said when a reviewer opens them in November.

A measure with no `cmd` in harness/measures.json is reported as NOT WIRED and
contributes nothing. That is deliberate. A rig that silently omits a measure
looks exactly like a rig that ran it and found nothing wrong.
"""
import argparse
import datetime as dt
import json
import os
import re
import shlex
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EM = os.path.dirname(HERE)
HARNESS = os.path.join(EM, "harness")
RENDERS = "/Volumes/FMA/superdark/renders"
PY = os.environ.get("PY", sys.executable)


def load(path):
    with open(path) as fh:
        return json.load(fh)


def seal_hash(rel):
    man_path = os.path.join(EM, "frozen", "MANIFEST.json")
    if not os.path.isfile(man_path):
        return None
    return load(man_path)["files"].get(rel, {}).get("sha256")


def newest_log():
    try:
        logs = [f for f in os.listdir(RENDERS)
                if f.startswith("live_") and f.endswith(".log")]
    except OSError:
        return None
    if not logs:
        return None
    logs.sort(key=lambda f: os.path.getmtime(os.path.join(RENDERS, f)))
    return logs[-1]


SEGMENTS = "/Volumes/FMA/superdark/segments"


def build_arm_audio(dest, since, until=None):
    """Concatenate the segments captured DURING this arm, and nothing else.

    An arm's audio has to be the arm's own audio. Scoring a comparison against
    whatever happened to be in the segment directory would silently mix the
    champion's sound into the candidate's number, and the two arms run on the
    same machine minutes apart, so the directory holds both.

    Selection is by mtime inside the arm's wall-clock window. Segments are
    written whole by fifo_splitter, so a segment finishing after `until` began
    before it and is excluded: partial overlap is dropped rather than trimmed,
    because a trimmed segment is a different length in each arm and the frame
    counts stop being comparable.

    Returns (path, n_segments, seconds) or (None, 0, 0).
    """
    if not os.path.isdir(SEGMENTS):
        return None, 0, 0.0
    until = until if until is not None else time.time()
    keep = []
    for f in sorted(os.listdir(SEGMENTS)):
        if not f.endswith(".wav"):
            continue
        p = os.path.join(SEGMENTS, f)
        try:
            mt = os.path.getmtime(p)
        except OSError:
            continue
        # A segment is written when it CLOSES, so its mtime is its end. A
        # segment closing just after the arm began is almost entirely the
        # PREVIOUS arm's audio. Include it only if it also STARTED after the
        # arm did. Duration comes from the file size, because the splitter
        # writes raw f32 stereo at 44100 and a nominal 600 s would be wrong for
        # the final short segment.
        try:
            dur = max(0.0, (os.path.getsize(p) - 44) / float(44100 * 2 * 4))
        except OSError:
            continue
        started = mt - dur
        if started >= since and mt <= until:
            keep.append(p)
    if not keep:
        return None, 0, 0.0

    listing = os.path.join(dest, "arm_segments.txt")
    with open(listing, "w") as fh:
        for p in keep:
            fh.write(f"file '{p}'\n")
    out = os.path.join(dest, "arm_audio.wav")
    try:
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-f", "concat", "-safe", "0", "-i", listing,
             "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", out],
            check=True, capture_output=True, timeout=1800)
    except Exception:
        return None, len(keep), 0.0
    try:
        import wave
        with wave.open(out) as w:
            secs = w.getnframes() / float(w.getframerate())
    except Exception:
        secs = 0.0
    return out, len(keep), secs


def slice_log(src, dest, win_from, win_to=None):
    """Write only the windows belonging to THIS arm.

    Both arms of a hot-reloaded comparison share one window log, because the
    change is a policy value and needs no restart -- which is the point, since a
    restart would alter the trace and the corpus and break the one-change rule.

    But every log-based measure takes a file and scores all of it. Without this,
    arm B would be scored with arm A's windows still in the file and the
    comparison would be between "arm A" and "arm A plus arm B", which is not a
    comparison at all.

    Lines are kept when their window number is in range. Lines with no window
    number (headers, ALPHABET, and the like) are kept, since they describe the
    run rather than a window.
    """
    kept = dropped = 0
    with open(src, errors="replace") as fh, open(dest, "w") as out:
        for line in fh:
            parts = line.split(None, 1)
            w = None
            if len(parts) == 2:
                head = parts[1].split(",")[0].strip()
                if head.isdigit():
                    w = int(head)
            else:
                # THE LOG HAS TWO LINE FORMATS AND THIS SLICED ONE OF THEM.
                # Window-tagged lines look like "VOICES 854,5,1,1": a keyword, a
                # space, then the window. Event lines look like
                # "20.51,2,cp,class,0.03,..." with no space at all, and the
                # window is the SECOND comma field. The split above found no
                # space, set w = None, and kept every event line of the whole
                # run in every arm. Found 19 Sept: six arms of 853 windows each
                # carried all 7,131 event lines, and m4, m6, m8, m9,
                # m1_audible_when_driving, convergence2 and the judges scored
                # identical values in all six. Every hot-reloaded comparison
                # since slice_log existed (16 Sept) is affected on those
                # measures. The field test mirrors score_charter.read().
                f = line.strip().split(",")
                if len(f) > 10 and f[3] in ("runtime", "class") and f[1].isdigit():
                    w = int(f[1])
            if w is None or (w >= win_from and (win_to is None or w <= win_to)):
                out.write(line); kept += 1
            else:
                dropped += 1
    return kept, dropped


def window_count(log):
    n = 0
    try:
        with open(os.path.join(RENDERS, log), errors="replace") as fh:
            for line in fh:
                if line.startswith("VOICES"):
                    n += 1
    except OSError:
        pass
    return n


def run_measure(key, spec, ctx):
    """Invoke one measure. Returns a result dict, never raises."""
    cmd_tmpl = spec.get("cmd")
    script = spec.get("script")
    out = {"scorer": script,
           "scorer_sha256": seal_hash(script) if script else None,
           "promote": ctx["power"][key][0],
           "veto": ctx["power"][key][1]}
    if not cmd_tmpl:
        out.update({"value": None, "status": "NOT WIRED",
                    "_why": "no cmd in measures.json; this measure contributed "
                            "nothing to this bundle"})
        return out
    if "{audio}" in cmd_tmpl and not ctx["subs"].get("audio"):
        out.update({"value": None, "status": "NO AUDIO",
                    "_why": "this measure scores audio and this arm captured "
                            "none; scoring it against another arm's segments "
                            "would be worse than reporting nothing"})
        return out
    cmd = cmd_tmpl.format(**ctx["subs"])
    t0 = time.time()
    try:
        proc = subprocess.run([PY] + shlex.split(cmd)[1:] if cmd.startswith("python3 ")
                              else shlex.split(cmd),
                              cwd=EM, capture_output=True, text=True,
                              timeout=spec.get("timeout_s", 1800))
    except subprocess.TimeoutExpired:
        out.update({"value": None, "status": "TIMEOUT"})
        return out
    out["elapsed_s"] = round(time.time() - t0, 1)
    out["exit"] = proc.returncode
    out["stdout_tail"] = proc.stdout[-4000:]
    if proc.returncode != 0:
        # AN UNDERPOWERED ARM IS NOT A BROKEN RIG. Several scorers exit non-zero
        # when handed too few windows -- charter_honesty needs 100, judges a few
        # hundred. Both block a verdict, and they block it for opposite reasons:
        # one says "collect more data", the other says "fix the tooling". A
        # bundle that renders them identically wastes the next reader's hour.
        blob = (proc.stdout + proc.stderr).lower()
        short = any(m in blob for m in
                    ("too short", "no runs long enough", "insufficient data",
                     "not enough windows"))
        out.update({"value": None,
                    "status": "TOO SHORT" if short else "FAILED",
                    "stderr_tail": proc.stderr[-2000:]})
        if short:
            out["_why"] = ("the scorer refused this arm for want of windows, "
                           "which is a statement about the arm and not about "
                           "the rig")
        return out
    # Extracting numbers from a scorer's stdout, NEVER by editing the scorer.
    # A sealed scorer that grows a --json flag for the rig's convenience is a
    # sealed scorer that changed, and every earlier number then needs a hash
    # beside it. So the rig adapts to the scorer's existing output instead.
    value = {}
    if spec.get("parse"):
        pat = re.compile(spec["parse"], re.M)
        for m in pat.finditer(proc.stdout):
            g = m.groupdict()
            k = (g.get("key") or f"m{len(value)}").strip()
            # A pattern with no `value` group is a PRESENCE match: the fact that
            # the line exists is the signal. charter_honesty says which metrics
            # can never pass and attaches no number to them, and "this metric is
            # structurally unable to fail" is exactly the thing worth recording.
            if "value" not in g or g.get("value") is None:
                value[k] = 1.0
                continue
            try:
                value[k] = float(g["value"])
            except (TypeError, ValueError):
                value[k] = g.get("value")
    else:
        for line in proc.stdout.strip().splitlines()[-12:]:
            if "=" in line and " " not in line.split("=")[0]:
                k, _, v = line.partition("=")
                try:
                    value[k.strip()] = float(v.strip())
                except ValueError:
                    value[k.strip()] = v.strip()
    # A PRESENCE measure that matches nothing has said something: nothing was
    # flagged. charter_honesty naming no structurally-unfailable metric is a
    # clean result, and rendering it as NO NUMBER PARSED would file a pass as a
    # malfunction -- the same confusion as TOO SHORT against FAILED.
    if spec.get("presence") and not value:
        out.update({"value": {}, "status": "ok",
                    "_why": "presence measure, nothing matched, which is the "
                            "clean outcome and not a parse failure"})
        return out
    out.update({"value": value or None,
                "status": "ok" if value else "NO NUMBER PARSED"})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", required=True)
    ap.add_argument("--policy", required=True)
    ap.add_argument("--arm", default="champion")
    ap.add_argument("--intent", default="promotion",
                    choices=["promotion", "null"],
                    help="what this run is for. 'null' declares that the "
                         "two arms are identical ON PURPOSE, to measure the "
                         "noise floor; it must be declared before scoring "
                         "and is honoured only when BOTH arms carry it.")
    ap.add_argument("--dest", required=True)
    ap.add_argument("--log", default=None)
    ap.add_argument("--win-from", type=int, default=None,
                    help="first window of this arm; earlier windows belong to "
                         "another arm and are sliced out of the log the measures "
                         "see")
    ap.add_argument("--win-to", type=int, default=None)
    ap.add_argument("--since", type=float, default=None,
                    help="epoch at which this arm began; segments before it are "
                         "another arm's audio and are excluded")
    # --until WAS MISSING AND build_arm_audio HAS ALWAYS TAKEN IT.
    #
    # Without it `until` defaulted to now, so a champion arm's audio ran from its
    # start to the present -- swallowing every segment the CANDIDATE produced
    # afterwards. The function's own docstring names this as the thing it exists
    # to prevent: "the two arms run on the same machine minutes apart, so the
    # directory holds both". It was prevented in the function and unreachable
    # from the command line.
    #
    # Seventh instance this month of a capability built and wired to nothing.
    # Found 16 Sept while scoring the first paired comparison that ever ran.
    ap.add_argument("--until", type=float, default=None,
                    help="epoch at which this arm ended; segments after it "
                         "belong to the next arm and are excluded. Omit only "
                         "for the arm that is still running.")
    args = ap.parse_args()

    reg = load(os.path.join(HARNESS, "measures.json"))
    pol = load(os.path.join(HARNESS, "release_policy.v1.json"))
    warm = pol["champion_and_candidate"]["warm_up_windows"]

    log = args.log or newest_log()
    if log is None:
        sys.exit("no window log found; is the SSD mounted?")
    total = window_count(log)

    sys.path.insert(0, HERE)
    import measure_registry as mr
    power = {k: mr.power(reg, k)[:2] for k in reg["measures"]}

    # The arm's own audio. Without it the audio measures have nothing to score,
    # and with the WRONG audio they would score the other arm.
    audio, nseg, asecs = build_arm_audio(
        args.dest, args.since if args.since else os.path.getctime(
            os.path.join(RENDERS, log)), args.until)
    print(f"  arm audio: {nseg} segment(s), {asecs/60:.1f} min"
          + ("" if audio else "  NONE -- audio measures will report NOT WIRED"),
          flush=True)

    log_for_measures = os.path.join(RENDERS, log)
    if args.win_from is not None:
        sliced = os.path.join(args.dest, "arm_windows.log")
        kept, dropped = slice_log(log_for_measures, sliced,
                                  args.win_from, args.win_to)
        print(f"  arm log: windows {args.win_from}"
              f"{'-' + str(args.win_to) if args.win_to else '+'}, "
              f"{kept} lines kept, {dropped} from other arms removed", flush=True)
        log_for_measures = sliced

    ctx = {"power": power,
           "subs": {"log": log_for_measures,
                    "renders": RENDERS,
                    "checkpoint": args.checkpoint,
                    "audio": audio or "",
                    # the arm's own bundle: anything a measure writes goes HERE,
                    # so two arms minutes apart cannot overwrite each other
                    "dest": args.dest,
                    "ring": "/Volumes/FMA/superdark/self_corpus",
                    "charter": os.path.join(EM, "workdir_music", "mutable",
                                            "charter.json"),
                    "warm": warm}}

    manifest = {
        "run_id": os.path.basename(args.dest),
        "created": time.time(),
        "created_iso": dt.datetime.now().isoformat(timespec="seconds"),
        "checkpoint": args.checkpoint,
        "policy": args.policy,
        "arm": args.arm,
        # WHAT THIS RUN IS FOR, DECLARED BEFORE IT IS SCORED.
        #
        # 17 Sept 2026. Comparison 2 concluded, under its own pre-registered
        # rule, that attention_weight's effect is not distinguishable from noise
        # at these sample sizes. That verdict cannot be sharpened by another
        # comparison that changes something: what is missing is the NOISE FLOOR
        # -- how far the measures drift when NOTHING changes -- and the release
        # policy names exactly that as a prerequisite for margins, "a
        # smallest-reportable-difference below which a result is flat".
        #
        # A null run has two identical arms on purpose, which
        # inv_one_change_at_a_time refuses with "two identical configurations
        # are not a comparison". That refusal is correct for a promotion
        # attempt and backwards for a deliberate null.
        #
        # So intent is recorded HERE, at scoring time, and the invariant honours
        # it only when BOTH arms declare it. An accidental no-change comparison
        # -- the case the rule was written for, where someone means to move a
        # knob and does not -- still fails exactly as before, because nobody
        # will have declared it. The exemption has to be bought in advance.
        "intent": args.intent,
        "log": log,
        # THE ARM'S RANGE, NOT THE WHOLE LOG'S.
        #
        # This recorded [warm, total] regardless of --win-from/--win-to, so a
        # sliced arm reported the entire log as its scope. The SCORING was
        # correct -- arm_windows.log held the right 808 windows and the measures
        # read that -- but the manifest said otherwise, and the manifest is what
        # a reader opens. This file's own header says the numbers "have to still
        # mean what they said when a reviewer opens them in November"; a scope
        # field that overstates the range by a factor of three does not.
        #
        # Caught 16 Sept on the first paired comparison that ever ran, by
        # reading the manifest against the sliced log instead of trusting it.
        "windows": [args.win_from if args.win_from is not None else warm,
                    args.win_to if args.win_to is not None else total],
        "windows_scored": None if args.win_from is None else "see arm_windows.log",
        # THE ARM'S OWN WALL CLOCK, so an invariant can ask "did anything go
        # wrong DURING THIS ARM" instead of "has anything ever gone wrong".
        # run_not_contaminated counted the entire integrity journal and reported
        # 16 faults on 16 Sept, including sclang deaths from the day before and
        # an SSD unplug at 10:00 -- none of which touched either arm. An
        # invariant that can never pass on a machine with a bad week is not
        # protecting anything; it is just always red.
        "arm_since": args.since,
        "arm_until": args.until,
        "warm_up_discarded": warm,
        "_warm_up": "45 windows, the measured warm-up. Every verdict before "
                    "27 Aug was taken on a warm factory without saying so.",
        "measures": sorted(reg["measures"]),
    }

    results = {}
    for key in sorted(reg["measures"]):
        print(f"  {key} ...", flush=True)
        results[key] = run_measure(key, reg["measures"][key], ctx)
        print(f"  {key}: {results[key]['status']}", flush=True)

    prov = {
        "git_head": subprocess.run(["git", "-C", EM, "rev-parse", "HEAD"],
                                   capture_output=True, text=True).stdout.strip(),
        "seal": load(os.path.join(EM, "frozen", "MANIFEST.json"))["sealed_iso"],
        "registry_promotion_budget": reg["promotion_budget"],
        "python": sys.version.split()[0],
        "_the_bundle_is_the_source_of_truth": True,
    }

    for name, obj in (("manifest.json", manifest),
                      ("results.json", results),
                      ("provenance.json", prov)):
        with open(os.path.join(args.dest, name), "w") as fh:
            json.dump(obj, fh, indent=1, sort_keys=True)

    wired = sum(1 for r in results.values() if r["status"] == "ok")
    unwired = sum(1 for r in results.values() if r["status"] == "NOT WIRED")
    print(f"\n{args.dest}")
    print(f"  {wired} measure(s) ran, {unwired} NOT WIRED, "
          f"{len(results) - wired - unwired} failed")
    if unwired:
        print("  NOT WIRED measures contributed nothing. A bundle that omits a")
        print("  measure looks exactly like one that ran it and found nothing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
