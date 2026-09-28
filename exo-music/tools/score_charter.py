#!/usr/bin/env python3
"""Evaluate a run against the charter.

A charter that cannot be evaluated is a mission statement. This turns
charter.json into acceptance tests over a window log and reports, per metric,
whether the run falls inside the acceptable region.

WHAT THIS DELIBERATELY DOES NOT DO
----------------------------------
It does not produce a score. There is no total, no weighted sum, nothing to
maximise. Three evaluation layers here have failed by being scalars a factory
could climb -- E3 at rho = -0.861 against blind ranking, the audibility score
taking the vocabulary from nine machines to four, the transfer operator
narrowing it monotonically with its weight. P520 asks for "acceptable output
distributions... with holdouts, confidence intervals, and sample size
requirements", which is a test, not a hill. If someone later adds a
`--total` flag to this file, that is the moment the same mistake is made a
fourth time.

It also does not act. kernel.json's scrapping conditions are REPORTED and never
invoked. A live-or-die button wired up before its bounds are calibrated kills
the factory for the architect's arithmetic errors.

    python3 tools/score_charter.py --log <windows.log>
    python3 tools/score_charter.py --log <a.log> --log <b.log>      # two runs
"""
import argparse
import collections
import json
import os
import re
import subprocess
import sys
import time

import numpy as np

BR = re.compile(r"^br([a-z]{2})([a-z]{2})\d+$")
HERE = os.path.dirname(os.path.abspath(__file__))

# Where tools/delivered_peak.py writes its reading. Overridable per metric via
# the charter's `reading_from`, so the path is not buried in code.
DELIVERED_PEAK_DEFAULT = "/tmp/superdark_delivered_peak.json"
# live_YYMMDD_HHMMSS / run_YYMMDD_HHMMSS is already the convention level_probe.py
# and factory_status.py rely on, and unlike getmtime it is exact.
RUN_STAMP = re.compile(r"(?:live|run|arm|cmp)_(\d{6})_(\d{6})")


def canon(m):
    g = BR.match(m)
    return f"br:{g.group(1)}>{g.group(2)}" if g else m


def read(path):
    ev, mp, clip, gap, live, cent, mach = [], [], [], [], [], [], []
    amp = []          # the SECTION amplitude the factory chose for this window
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                mp.append(float(p[1])); clip.append(float(p[2]))
            except (ValueError, IndexError):
                pass
        elif line.startswith("OPERATOR"):
            # live_factory.scd:3499 writes
            #   OPERATOR  win, gap, lambda2, cells, dominant, total
            # and the window number is split off above, so p[0] is the window,
            # p[1] is GAP and p[2] is LAMBDA2.
            #
            # This read p[2]. m7_spectral_gap_settles has therefore scored the
            # interquartile range of LAMBDA2 for its entire life, while its name,
            # its derivation and its bound all describe the GAP -- the derivation
            # says in as many words "6h run: gap ran 0.295-0.422 at p10-p90".
            # Off by one field, and invisible because both columns are floats in
            # a plausible range.
            #
            # Safe to correct now and not earlier: m7 reports SUSPENDED, which
            # the charter counts as undecided rather than as a departure, so no
            # verdict on any past or present comparison moves. Doing it mid
            # comparison would still have been wrong -- a scorer that changes
            # between two arms makes them incommensurable whatever it scores.
            p = line.split()[1].split(",")
            try:
                gap.append(float(p[1]))
            except (ValueError, IndexError):
                pass
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                try:
                    cent.append(float(p[5])); live.append(int(p[9]))
                    mach.append(canon(p[2])); ev.append(1)
                    amp.append(float(p[4]))
                except (ValueError, IndexError):
                    pass
    return dict(mp=np.array(mp), clip=np.array(clip), gap=np.array(gap),
                live=np.array(live), cent=np.array(cent), mach=mach,
                amp=np.array(amp), n=len(mp))


# The section amplitude above which the factory is unambiguously driving output.
# Not chosen for roundness: conditional silence falls monotonically with amp
# (34.8% near zero, 19.0% at 1e-4, 4.1% at 2e-3) and reaches 0.2% here, so this
# is where "the factory is trying to make sound" stops being ambiguous.
DRIVING = 1e-2
SILENT = 0.004        # the master peak m1 counts as silence


def audible_when_driving(mp, amp):
    """Of the windows where the factory MEANT to sound, how many did not.

    m1 used to count silence unconditionally, which made it a measure of how
    often the factory chose to be quiet -- a compositional habit, not a fault.
    47% of windows carry an amplitude under 1e-4 and 45% of those are silent by
    design. Judging that as a failure of `n1_audible` mistook the work for a
    defect. This asks the question the norm actually means: when the factory
    drives output, does sound come out.
    """
    if len(mp) == 0 or len(amp) != len(mp):
        return None
    sel = amp >= DRIVING
    if sel.sum() < 50:
        return None
    return float((mp[sel] < SILENT).mean())


def c1_terminal(path):
    """C1 from the pre-registered criterion, via convergence2.py so this file
    cannot quietly disagree with the instrument it was written against."""
    out = subprocess.run(
        ["python3", os.path.join(HERE, "convergence2.py"), path],
        capture_output=True, text=True).stdout
    m = re.search(r"C1 terminal ratio\s+([0-9.]+)", out)
    return float(m.group(1)) if m else None


def turnover(mach):
    """Fraction of consecutive windows in which the sounding machine CHANGES.

    THE COUNTERWEIGHT TO m4, AND THE REASON IT HAD TO EXIST.

    On 2 Sept Roberto described the factory as "endless radio-like fragmentary
    shit". Measured across every run long enough to score, this number had
    climbed monotonically for a week -- 0.736 on 27 Aug to 0.950 on 2 Sept --
    while median master peak fell 0.197 to 0.052. At 0.95 the material changes in
    nineteen windows out of twenty; on 27 Aug it held for two or three.

    Not one charter metric moved. Worse than that: m4_vocabulary_breadth
    IMPROVES under exactly this failure, because a factory that switches material
    every window sounds more behaviours per hundred windows than one that lets a
    behaviour last. The charter was rewarding the thing the listener heard as
    broken, and there was no metric anywhere measuring how long anything lasts.

    `mach` arrives already canonicalised by canon(), so bridges are collapsed to
    their transition exactly as m4 sees them. The two metrics therefore run over
    the same alphabet, and a difference between them is about DURATION and not
    about naming.
    """
    if mach is None or len(mach) < 3:
        return None
    changes = sum(1 for a, b in zip(mach, mach[1:]) if a != b)
    return round(changes / (len(mach) - 1), 4)


def behaviours_per_100(mach, n):
    """Distinct BEHAVIOURS, not names. The 6 h run of 26 Aug played 158 names
    and ~34 behaviours; a metric over names scored a stutter as a triumph."""
    if n < 100:
        return None
    win = 100
    counts = []
    step = max(1, len(mach) // 20)
    for i in range(0, max(1, len(mach) - win + 1), step):
        counts.append(len(set(mach[i:i + win])))
    return float(np.median(counts)) if counts else None


def run_started(path):
    """Epoch at which the run that produced `path` began, or None.

    Read off the filename convention live_YYMMDD_HHMMSS / run_YYMMDD_HHMMSS,
    which is exact. getmtime is the log's LAST write -- i.e. roughly the END of
    the run -- so it is only the fallback, and it is the STRICTER of the two: a
    capture taken mid-run would read as predating a run dated by its mtime. That
    is the safe direction. An over-strict freshness test costs a NOT MEASURED;
    an under-strict one lets a stale number stand in for a live one on the
    metric that is never tolerated.
    """
    for part in reversed(os.path.abspath(path).split(os.sep)):
        m = RUN_STAMP.search(part)
        if m:
            try:
                return time.mktime(time.strptime(m.group(1) + m.group(2),
                                                 "%y%m%d%H%M%S"))
            except ValueError:
                break
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def delivered_peak_reading(log_path, spec):
    """True peak of the DELIVERED mount. Returns (value, reason).

    NOT COMPUTED FROM THE WINDOW LOG, AND IT CANNOT BE. Every other metric here
    is a statistic over windows the factory itself logged. This one is a network
    capture of the mount a listener connects to, taken on the FAR SIDE of the
    encoder -- which is the entire reason it exists. m3_no_clipping reads the
    signal before the encoder and reported 0.0 through all 410 windows of the
    hour of 3 Sept that delivered a true peak of 1.067.

    So the scorer reads the file tools/delivered_peak.py writes instead, and the
    charter names that file rather than this module hard-coding it.

    ABSENT DATA IS NOT A PASS, AND THIS FUNCTION EXISTS MOSTLY TO SAY SO. Every
    way of failing to get a reading returns None with a reason; the caller then
    reports NOT MEASURED, which counts as UNDECIDED and never as satisfied. A
    never-tolerated clause that reads green on no data is worse than no clause,
    because it puts a verdict where an unknown is -- the same shape of error the
    metric was adopted to fix.

    STALENESS IS CHECKED, not assumed. The capture is a separate act on a
    separate clock; without a date test, one measurement taken once would go on
    certifying every run scored afterwards.
    """
    path = spec.get("reading_from", DELIVERED_PEAK_DEFAULT)
    if not os.path.exists(path):
        return None, f"no capture at {path} -- run tools/delivered_peak.py"
    try:
        rec = json.load(open(path))
    except (ValueError, OSError) as e:
        return None, f"capture at {path} is unreadable ({e})"
    v = rec.get(spec.get("reading_field", "true_peak"))
    if v is None:
        return None, f"capture at {path} carries no true peak"
    t = rec.get("t")
    if t is None:
        return None, (f"capture at {path} is unstamped, so it cannot be dated "
                      "to this run")
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(t))
    start = run_started(log_path)
    if start is not None and t < start:
        return None, (f"capture at {path} is from {when}, which predates this "
                      f"run by {(start - t) / 3600.0:.1f} h")
    secs = float(rec.get("seconds") or 0.0)
    need = float(spec.get("min_seconds") or 0.0)
    if secs < need:
        return None, (f"capture at {path} is {secs:.0f} s; the test asks for at "
                      f"least {need:.0f} s")
    return float(v), (f"{secs:.0f} s of {rec.get('source', 'the mount')}, "
                      f"captured {when}")


def evaluate(path, ch):
    d = read(path)
    n = d["n"]
    vals = {}
    # d1 and d2 carry a d-prefix from charter edition 7. They are DESCRIPTIONS:
    # reported, unbounded, and incapable of passing or failing. The quantities
    # are byte-identical to what m1_not_silent and m9_turnover computed -- only
    # the keys moved -- so any figure quoted against the old names still stands.
    vals["d1_silence"] = float(np.mean(d["mp"] < SILENT)) if n else None
    vals["m1_audible_when_driving"] = audible_when_driving(d["mp"], d["amp"])
    vals["m2_level"] = float(np.median(d["mp"])) if n else None
    vals["m3_no_clipping"] = float(np.percentile(d["clip"], 99)) if n else None
    vals["m4_vocabulary_breadth"] = behaviours_per_100(d["mach"], n)
    vals["m5_not_converging"] = c1_terminal(path)
    vals["m6_texture"] = float(np.median(d["live"])) if len(d["live"]) else None
    vals["m7_spectral_gap_settles"] = (
        float(np.percentile(d["gap"], 75) - np.percentile(d["gap"], 25))
        if len(d["gap"]) else None)
    vals["m8_in_band"] = float(np.median(d["cent"])) if len(d["cent"]) else None
    vals["d2_turnover"] = turnover(d["mach"])
    # The one metric that does not come from the log. See delivered_peak_reading.
    m3b = ch.get("metrics", {}).get("m3b_delivered_peak")
    if m3b is not None:
        vals["m3b_delivered_peak"] = delivered_peak_reading(path, m3b)[0]

    rows, failed, undecided = [], [], []
    for k, spec in ch["metrics"].items():
        if k.startswith("_"):
            continue
        v = vals.get(k)
        lo, hi = spec["acceptable"]
        # A ONE-SIDED BOUND IS WRITTEN AS null. m4_vocabulary_breadth lost its
        # upper bound in charter edition 2: the ceiling was the calibration
        # run's own observed value, and a ceiling on variety contradicts the
        # norm it serves (n2_varied, "the factory should not settle"). Without
        # this, `lo <= v <= hi` raises TypeError on None and the scorer dies on
        # a charter it should simply read.
        lo = float("-inf") if lo is None else lo
        hi = float("inf") if hi is None else hi
        # A SUSPENDED METRIC IS UNDECIDED, NEVER FAILING.
        # m7 was suspended in edition 3: its statistic is the interquartile range
        # of an operator that accumulates without decay AND persists across runs
        # via memory.json, so the spread falls with the operator's age whatever
        # the factory does. Reporting FAIL against a bound known to be
        # unmeasurable is not honesty -- it trains the reader to ignore red, and
        # it would let a genuine failure hide behind a permanent one. The metric
        # stays in the charter so the lineage is visible; it simply cannot be
        # scored until its replacement exists.
        # min_windows may be null for a metric that is not a window statistic
        # (m3b_delivered_peak is a network capture and has no windows to count).
        # `or 0` rather than a default, because the key is PRESENT and null.
        need = spec.get("min_windows") or 0
        # IS THIS A STATISTIC OVER THE WINDOW LOG AT ALL? Nine of the ten are.
        # m3b is not, so gating it on the run's window count would make a
        # perfectly good 120 s capture read as undecided on a short run.
        window_stat = spec.get("window_statistic", True)
        # AN EXCLUSIVE TOP BOUND. m3b_delivered_peak is acceptable on [0.0, 1.0)
        # and must FAIL at exactly 1.0: full scale is where a converter starts
        # clipping, so 1.0 is the first failing value and not the last passing
        # one. The charter states the bound as 1.0 and flags the exclusivity,
        # rather than writing 0.999 -- 0.999 is a number nobody measured, and a
        # reader would have to guess whether it came from the format or a run.
        hi_open = bool(spec.get("exclusive_upper"))
        # A DESCRIPTIVE ENTRY IS REPORTED AND NEVER JUDGED.
        # d1_silence (m1_not_silent until edition 7) became one in edition 4: it
        # counts how often the factory chose a near-zero amplitude, which is a
        # compositional habit and not a failure of n1_audible. It stays visible
        # because the silence is part of the work; it carries no bound because
        # there is nothing to pass. Edition 7 gave it and d2_turnover a d-prefix
        # so the key itself says so.
        if spec.get("descriptive"):
            rows.append((k, spec["norm"], v, float("-inf"), float("inf"),
                         "described"))
            continue
        if spec.get("suspended"):
            verdict = "SUSPENDED"
            undecided.append(k)
        elif v is None and not window_stat:
            # NOT MEASURED IS NOT A PASS AND NOT A FAIL. The instrument did not
            # report. Saying "pass" would certify a signal nobody looked at;
            # saying "FAIL" would accuse the factory of the architect's failure
            # to run a capture. It is undecided, it is named with its own word
            # so it cannot be mistaken for a thin run, and main() calls it out
            # separately when the metric is one of the never-tolerated.
            verdict = "NOT MEASURED"
            undecided.append(k)
        elif v is None or (window_stat and n < need):
            verdict = "UNDECIDED"
            undecided.append(k)
        elif (lo <= v < hi) if hi_open else (lo <= v <= hi):
            verdict = "pass"
        else:
            verdict = "FAIL"
            failed.append(k)
        rows.append((k, spec["norm"], v, lo, hi, verdict))
    return n, rows, failed, undecided


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", action="append", required=True)
    ap.add_argument("--charter", default=None)
    a = ap.parse_args()
    root = os.path.dirname(HERE)
    ch = json.load(open(a.charter or os.path.join(
        root, "workdir_music", "mutable", "charter.json")))
    kern = json.load(open(os.path.join(
        root, "workdir_music", "mutable", "kernel.json")))

    print(f"  charter edition {ch['edition']}, authored {ch['authored']}")
    print(f"  kernel  edition {kern['edition']}   (reported, never invoked)")

    all_failed = []
    for path in a.log:
        n, rows, failed, und = evaluate(path, ch)
        all_failed.append(set(failed))
        print()
        print(f"  === {os.path.basename(path)}   {n} windows ===")
        print(f"  {'metric':26} {'norm':14} {'value':>10}  {'acceptable':>16}   verdict")
        for k, norm, v, lo, hi, verdict in rows:
            vs = "  n/a" if v is None else f"{v:10.3f}"
            # ")" NOT "]" WHEN THE TOP IS EXCLUSIVE, because the difference is
            # the whole point of the bound: m3b fails AT 1.0, not above it.
            shut = ")" if ch["metrics"][k].get("exclusive_upper") else "]"
            print(f"  {k:26} {norm:14} {vs}  [{lo:6.2f},{hi:6.2f}{shut}   {verdict}")
        tol = ch["departures"]["tolerated_failing_metrics"]
        never = set(ch["departures"]["never_tolerated"]) & set(failed)
        # A NEVER-TOLERATED CLAUSE NOBODY MEASURED IS NOT A SATISFIED ONE.
        # m3b_delivered_peak needs a network capture, so unlike the other nine it
        # can be absent on a run that is otherwise fully scored. If that went
        # unsaid, the headline below would read "charter SATISFIED" over a
        # governance clause with no data behind it -- which is the exact shape of
        # the blind spot m3b was adopted to close, moved one level up.
        never_und = set(ch["departures"]["never_tolerated"]) & set(und)
        print()
        if never:
            print(f"  NEVER-TOLERATED metric failed: {sorted(never)}")
        if never_und:
            print(f"  NEVER-TOLERATED metric NOT MEASURED: {sorted(never_und)}")
            print("    Unmeasured is not inside the bound. This run carries no")
            print("    reading on that clause and must not be read as clearing it.")
        if "m3b_delivered_peak" in ch.get("metrics", {}):
            why = delivered_peak_reading(
                path, ch["metrics"]["m3b_delivered_peak"])[1]
            print(f"  m3b_delivered_peak: {why}")
        # SILENCE IS NOT A PASS. With every metric undecided -- a young run, or a
        # charter whose metrics are suspended -- the old code printed "charter
        # SATISFIED", which reads as an endorsement of a factory nothing has
        # been measured on. Caught on a 89-window run under charter edition 3.
        # Descriptions are not metrics. Counting them as satisfied would inflate
        # the headline with entries that cannot fail, which is the arithmetic
        # that let m6 pass ten runs out of ten.
        described = sum(1 for r in rows if r[5] == "described")
        judged = len(rows) - described
        scoreable = judged - len(und)
        if scoreable == 0:
            print("  charter NOT YET SCOREABLE: every metric is undecided or")
            print("  suspended. This is not a pass; nothing has been measured.")
        elif len(failed) == 0:
            print(f"  charter SATISFIED on {scoreable} of {judged} metrics"
                  + (f" ({described} reported as description)" if described else "")
                  + (", BUT SEE THE UNMEASURED NEVER-TOLERATED CLAUSE ABOVE"
                     if never_und else ""))
        elif len(failed) <= tol and not never:
            print(f"  DEPARTURE: {len(failed)} metric(s) failing, tolerance is {tol}.")
            print(f"    {sorted(failed)}")
            print("    P526: departures are acceptable within limits.")
        else:
            print(f"  SCRAPPING CONDITION MET on this run: {len(failed)} failing "
                  f"(tolerance {tol}){' + never-tolerated' if never else ''}")
            print(f"    {sorted(failed)}")
        if und:
            # "insufficient data" no longer covers every case: m3b can be
            # undecided because nobody took a capture, which is a different
            # thing from a run that is too short. Both are still undecided.
            print(f"  undecided (insufficient or absent data): {sorted(und)}")

    if len(a.log) >= 2:
        print()
        sustained = set.intersection(*all_failed)
        tol = ch["departures"]["tolerated_failing_metrics"]
        print(f"  === across {len(a.log)} runs ===")
        print(f"  metrics failing in EVERY run: {sorted(sustained) if sustained else 'none'}")
        if len(sustained) > tol or (set(ch['departures']['never_tolerated']) & sustained):
            print("  kernel scrapping condition WOULD be met (sustained across runs).")
            print("  Not invoked. Re-price the charter as a new edition, or rebuild.")
            print("  Do NOT widen a bound until the run passes -- that makes the")
            print("  charter theatre, and it is the easiest thing in the world to do.")
        else:
            print("  no sustained failure; kernel not implicated.")


if __name__ == "__main__":
    main()
