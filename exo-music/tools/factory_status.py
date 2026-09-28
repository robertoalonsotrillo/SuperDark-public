#!/usr/bin/env python3
"""One snapshot of what the factory is doing, for the public panel.

WHY THIS EXISTS, AND WHY IT IS ONLINE
The Superdark Factory paper, 5.3: superdark design prioritises the ONLINE
evaluation over the offline one, because "the factory's behavior at deployment
time is not its behavior at time t + n, even if no configuration has changed".
An evaluation that runs before deployment is legacy unit testing. So the
evaluation surface belongs in production, and if it belongs in production there
is no reason it should not be visible.

FOUR PRINCIPLES, AND WHERE WE HONESTLY STAND
  1  online and continuous ................ done; this file reads a live run
  2  requisite variety of mean-based AND
     swap-based judges .................... FAILING; all three judges are
                                            no-swap-regret learners
  3  massively recursive, evaluations of
     evaluations .......................... ABSENT; we have one tier
  4  the signal grading an evaluator sits
     outside the loop it judges ........... PARTIAL; realized-consequence
                                            scoring is not wired
Those admissions are emitted in the JSON, not kept in a comment, because a panel
that showed only the passing parts would be the fourth time in this project that
a self-generated criterion became a convergence engine.

WHAT IT REFUSES TO DO
It does not recompute the charter. It calls score_charter.evaluate(), so the
published verdict and the local verdict cannot drift apart. If the scorer says a
metric FAILS, this says so too; there is no presentation layer in which a
departure quietly becomes a pass.

It does not invent ensemble disagreement. The paper names variance,
autocorrelation and ensemble disagreement as the early-warning signals for
critical slowing down. The first two are computable from the window log and are
computed here. The third needs a population of heterogeneous judges evaluating
the same situation, and this factory does not have one, so the field is reported
as unavailable with the reason attached. A plausible-looking number in that slot
would be worse than an empty one.

    python3 tools/factory_status.py --out /tmp/superdark_state.json
"""
import argparse
import glob
import json
import os
import re
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MUT = os.path.join(ROOT, "workdir_music", "mutable")
sys.path.insert(0, HERE)
import score_charter as SC                                   # noqa: E402

# WHERE THE FACTORY'S DATA LIVES, AS CONFIGURATION RATHER THAN AS AN ASSUMPTION.
#
# 17 Sept 2026: the replica published /state-replica.json with `"run": {}` and
# zero charter metrics, so the page's Factory 1 had audio and no numbers. This
# file held `/Volumes/FMA/superdark/renders/...` hardcoded in six places. That
# path is the DEV MACHINE'S SSD. On the replica it does not exist, so every
# glob returned nothing and the status object came out as a well-formed,
# entirely empty snapshot -- which published successfully and looked like a
# working pipeline.
#
# start_loop.sh already does this correctly: SD_ROOT with everything derived
# from it. It simply was never done here. Same family as the run_integrity
# probe that encoded a port number: configuration frozen into code, working on
# the one machine it was written on.
#
# Defaults reproduce the previous literals exactly, so this machine is
# unaffected; the replica sets SD_ROOT and the paths follow.
SD_ROOT = os.environ.get("SD_ROOT", "/Volumes/FMA/superdark")
RENDERS = os.environ.get("SD_RENDERS") or os.path.join(SD_ROOT, "renders")
SELF_CORPUS = os.environ.get("POOL") or os.path.join(SD_ROOT, "self_corpus")


def newest_window_log():
    c = sorted(glob.glob(os.path.join(RENDERS, "live_*.log")),
               key=os.path.getmtime)
    return c[-1] if c else None


def slots(limit=72):
    """Which machine each of the three layer slots has held, and from when.

    The SLOT line is written only when a slot CHANGES, so each entry is already
    the start of a run and the next entry for the same layer is its end. That is
    exactly the shape the ribbon needs and no aggregation is required here.

    Emitting the DECISIONS rather than the sound is what makes this figure
    immune to the fault that broke every previous one. A server-side spectrogram
    has to be slid about thirty seconds forward to sit where a listener's ears
    are, and the lag constant, the ring and the cursor servo that did the
    sliding drifted apart. A window index does not drift: window 41 is window 41
    whenever it is read, on any browser, with the audio playing or not.
    """
    p = newest_window_log()
    if not p:
        return []
    out = []
    try:
        for line in open(p, errors="replace"):
            if not line.startswith("SLOT "):
                continue
            f = line[5:].strip().split(",")
            if len(f) < 3:
                continue
            try:
                w = int(f[0])
            except ValueError:
                continue
            out.append({"w": w, "layer": f[1], "m": f[2]})
    except Exception:
        return []
    if not out:
        return []
    # Trim by WINDOW, not by entry count: the micro lane turns over several
    # times per macro hold, so keeping the last N entries would show a long
    # micro history beside a macro lane with one block in it, and the three
    # lanes would not share an axis.
    #
    # 72 windows is about fourteen minutes, and the number is set by LEGIBILITY
    # rather than by how much history exists. At 140 the micro lane packed
    # roughly 77 blocks across the width, nine pixels each, too narrow for even
    # a two-digit number -- so the fast lanes read as anonymous stripes, which
    # is what Roberto saw. 72 roughly halves that and still spans several macro
    # dwells, which is the comparison the figure is for.
    lo = out[-1]["w"] - limit
    return [e for e in out if e["w"] >= lo]


def jload(p, default=None):
    try:
        return json.load(open(p))
    except Exception:
        return default


def ews(series, name):
    """Variance and lag-1 autocorrelation across timescales.

    The paper: rising variance and rising autocorrelation together are the
    signature of CRITICAL SLOWING DOWN, a system taking longer and longer to
    recover from perturbation as it approaches a fold. Neither number means much
    alone, and neither means anything at all without a trend, so both are
    reported per timescale and the panel can show the direction.

    Reported RAW. No threshold, no colour, no verdict. This project has three
    times watched a single scalar with a threshold on it become something the
    factory optimises toward, and an early-warning signal that the factory can
    see and game is not a warning.
    """
    x = np.asarray(series, dtype=float)
    x = x[np.isfinite(x)]
    out = {"metric": name, "n": int(len(x)), "scales": []}
    if len(x) < 40:
        out["note"] = "under 40 windows; too short to read a trend"
        return out
    for w in (30, 90, 240):
        if len(x) < w * 2:
            continue
        early, late = x[:w], x[-w:]

        def ac1(v):
            v = v - v.mean()
            d = (v * v).sum()
            return float((v[:-1] * v[1:]).sum() / d) if d > 0 else 0.0
        out["scales"].append({
            "window": w,
            "variance_early": float(early.var()),
            "variance_late": float(late.var()),
            "autocorr_early": ac1(early),
            "autocorr_late": ac1(late),
        })
    return out


def run_started(path):
    """Wall-clock start of a run, from its filename: live_YYMMDD_HHMMSS.

    Falls back to the file's mtime minus its logged span rather than to
    getctime, because getctime is what was wrong in the first place.
    """
    m = re.search(r"live_(\d{6})_(\d{6})", os.path.basename(path))
    if m:
        try:
            return time.mktime(time.strptime("20" + m.group(1) + m.group(2),
                                             "%Y%m%d%H%M%S"))
        except ValueError:
            pass
    return os.path.getmtime(path)


def read_series(path):
    """Peak, clipping, spectral gap, live-voice count and machine, per window."""
    mp, gap, live, cent, mach, clip, wins, raw = [], [], [], [], [], [], [], []
    for line in open(path, errors="replace"):
        if line.startswith("MASTER "):
            p = line.split()[1].split(",")
            try:
                mp.append(float(p[1])); clip.append(float(p[2]))
            except (ValueError, IndexError):
                pass
        elif line.startswith("OPERATOR"):
            p = line.split()[1].split(",")
            try:
                gap.append(float(p[2]))
            except (ValueError, IndexError):
                pass
        else:
            p = line.strip().split(",")
            if len(p) > 10 and p[3] in ("runtime", "class"):
                try:
                    cent.append(float(p[5])); live.append(int(p[9]))
                    # canon() collapses bridges (brXXYY9) to br:xx>yy, which is
                    # right for COUNTING vocabulary and wrong for showing what is
                    # sounding, so the raw name is kept alongside.
                    mach.append(SC.canon(p[2])); raw.append(p[2])
                    wins.append(int(p[1]))
                except (ValueError, IndexError):
                    pass
    return dict(peak=mp, clip=clip, gap=gap, live=live, cent=cent,
                mach=mach, raw=raw, wins=wins)


def rolling(s, n=300):
    """The same quantities over the LAST n windows only.

    WHY THIS EXISTS. The charter's metrics are computed over the whole run, so
    each new window carries weight 1/n and they stiffen as the run lengthens. At
    250 windows they still move; after a day, around 7,400 windows, one window
    shifts a median by nothing anybody could see, and a panel showing only those
    would sit frozen while the factory carried on changing underneath it. That is
    the exact failure the paper's argument for online evaluation describes: the
    factory's behaviour at t+n is not its behaviour at t, and a statistic over
    all t cannot show it.

    THIS IS A READING, NOT A VERDICT. The charter is still scored cumulatively by
    score_charter.evaluate(), because the cumulative value is what the charter
    actually tests and a bound must not be judged against a window chosen to
    flatter it. What the rolling column buys is EARLINESS: a departure that is
    developing shows here before the cumulative average has absorbed it.

    m5 is absent by construction. Its terminal ratio comes from convergence2.py
    reading a whole log file, and slicing that to a tail would answer a different
    question, so the field says so instead of guessing.
    """
    out = {"windows": 0}
    if not s["peak"]:
        return out
    n = min(n, len(s["peak"]))
    out["windows"] = n
    tail = lambda k, m=None: np.asarray(s[k][-(m or n):], dtype=float)
    # d1_silence, not m1_not_silent, from charter edition 7. The key must match
    # the charter's, because the rolling column is joined onto the metric rows by
    # key below -- a stale name here does not error, it silently shows an em dash.
    out["d1_silence"] = float((tail("peak") < 0.004).mean())
    out["m2_level"] = float(np.median(tail("peak")))
    if s["clip"]:
        out["m3_no_clipping"] = float(np.percentile(tail("clip"), 99))
    if s["mach"]:
        out["m4_vocabulary_breadth"] = float(len(set(s["mach"][-100:])))
    out["m5_not_converging"] = None
    if s["live"]:
        out["m6_texture"] = float(np.median(tail("live")))
    if len(s["gap"]) > 8:
        g = tail("gap", min(n, len(s["gap"])))
        out["m7_spectral_gap_settles"] = float(
            np.percentile(g, 75) - np.percentile(g, 25))
    if s["cent"]:
        out["m8_in_band"] = float(np.median(tail("cent")))
    return out


def turnover():
    """What the pool has DONE, not how big it is.

    The headcount is a dead number: every layer sits at its cap (2400/1800/1200)
    because admission works by displacement, so a new grain evicts an incumbent
    and the total never moves. It would read 5.4K for the life of the project.

    admissions.jsonl records the thing that does move -- every candidate, its
    verdict, the margin it beat or missed the incumbent by, and the generation of
    both. Generation depth is the pre-registered target this whole loop exists to
    reach, so it belongs on the page more than a constant does.
    """
    p = os.path.join(SELF_CORPUS, "admissions.jsonl")
    out = {"available": os.path.exists(p)}
    if not out["available"]:
        return out
    adm = rej = 0
    gen = 0
    recent_adm = 0
    cutoff = time.time() - 3600
    by_layer = {}
    for line in open(p, errors="replace"):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        ok = d.get("verdict") == "admitted"
        L = d.get("layer", "?")
        b = by_layer.setdefault(L, {"admitted": 0, "rejected": 0})
        if ok:
            adm += 1; b["admitted"] += 1
            gen = max(gen, int(d.get("new_gen") or 0))
            if (d.get("t") or 0) > cutoff:
                recent_adm += 1
        else:
            rej += 1; b["rejected"] += 1
    out.update({"admitted": adm, "rejected": rej,
                "candidates": adm + rej,
                "admit_rate": round(adm / max(adm + rej, 1), 4),
                "admitted_last_hour": recent_adm,
                "deepest_generation": gen,
                "by_layer": by_layer})
    return out


VOCAB = os.path.join(RENDERS, "vocabulary.json")


def vocabulary(seen_this_run):
    """Every behaviour the factory has ever played, and which are new today.

    Kept as a running set rather than recomputed, because the alternative is
    rescanning 48 logs on every publish cycle. Behaviours are of two kinds and
    the split is the interesting part: base machines are a fixed repertoire,
    while BRIDGES are composed on the fly when the factory moves from one base
    machine to another, named br<from><to><n>. Measured 2 Sept: 150 distinct
    behaviours across 48 logs, of which 123 are bridges. So the vocabulary grows
    almost entirely in the transitions, not in the destinations.
    """
    old = jload(VOCAB, {}) or {}
    ever = set(old.get("ever", []))
    before = len(ever)
    ever |= set(seen_this_run)
    rec = {"ever": sorted(ever), "runs_counted": old.get("runs_counted", 0) + 1}
    try:
        tmp = VOCAB + ".tmp"
        json.dump(rec, open(tmp, "w"))
        os.replace(tmp, VOCAB)
    except OSError:
        pass
    bridges = [m for m in ever if m.startswith("br")]
    return {
        "ever": len(ever),
        "bridges": len(bridges),
        "base_machines": len(ever) - len(bridges),
        "this_run": len(set(seen_this_run)),
        "new_since_last_publish": len(ever) - before,
    }


def _recursion():
    """Two tiers, and the second one only counts if it beat its own null.

    The distinction this reports is the one worth keeping: a second LEVEL always
    exists once you write one, and saying so proves nothing. What earns the word
    recursion is a second level that anticipates something the first cannot see
    about itself, demonstrated against permuted outcomes. If the control fails,
    or the gain is nil, this says so on the public page instead of counting the
    principle as satisfied because code exists.
    """
    t2 = jload(os.path.join(RENDERS, "judges_tier2.json"))
    if not t2:
        return {"principle": "recursive evaluation", "status": "none",
                "detail": "one tier of evaluation; the second has not reported"}
    if not t2.get("passes_control"):
        return {"principle": "recursive evaluation", "status": "unproven",
                "detail": "a second tier runs but does not beat its negative "
                          "control, so its apparent skill is an artefact and "
                          "the level is decoration"}
    if not t2.get("informative"):
        return {"principle": "recursive evaluation", "status": "uninformative",
                "detail": "a second tier runs and is honest, but cannot beat the "
                          "base rate of first-tier correctness. Present, and "
                          "telling us nothing"}
    return {
        "principle": "recursive evaluation",
        "status": "two tiers",
        "detail": (
            f"{t2['tier2_population']} second-tier learners predict when each "
            f"first-tier judge is about to be wrong. They beat the base rate of "
            f"first-tier correctness by {t2['best_gain']:.4f} and find "
            f"{t2['control_gain']:+.4f} on permuted outcomes. The gain is real "
            f"and small, and it is largest on the WEAKEST first-tier judge — "
            f"there is more error to anticipate where there is more error. "
            f"Neither tier steers anything"),
    }


def corpus_state():
    pool = SELF_CORPUS
    out = {"layers": [], "captures_ingested": None}
    for L, secs in (("ev", 0.06), ("mid", 0.40), ("macro", 2.00)):
        d = os.path.join(pool, f"grains_pool_{L}")
        n = len([f for f in os.listdir(d)
                 if f.endswith(".wav")]) if os.path.isdir(d) else 0
        out["layers"].append({"layer": L, "grain_seconds": secs, "grains": n})
    ing = jload(os.path.join(pool, "ingested.json"), [])
    out["captures_ingested"] = len(ing) if ing is not None else None
    return out


def proposals():
    """The contributory arm: what the factory asked for, and what was decided.

    P271: a factory unable to participate in its own charter-writing is an
    exercise in Class 1 or 2 automation. Participation is only visible if the
    REFUSALS are visible too, so rejected proposals are published with their
    reasons alongside adopted ones.
    """
    props, dec = [], {}
    p = os.path.join(MUT, "charter_proposals.jsonl")
    if os.path.exists(p):
        for i, line in enumerate(open(p)):
            if line.strip():
                try:
                    d = json.loads(line); d["_n"] = i; props.append(d)
                except json.JSONDecodeError:
                    pass
    q = os.path.join(MUT, "charter_decisions.jsonl")
    if os.path.exists(q):
        for line in open(q):
            if line.strip():
                try:
                    d = json.loads(line); dec[d["proposal"]] = d
                except json.JSONDecodeError:
                    pass
    return {
        "total": len(props),
        "adopted": sum(1 for d in dec.values() if d["decision"] == "adopted"),
        "rejected": sum(1 for d in dec.values() if d["decision"] == "rejected"),
        "open": sum(1 for x in props if x["_n"] not in dec),
        "recent": [{
            "n": x["_n"],
            "kind": x.get("kind", "coverage_holdout"),
            "norm": x.get("norm"),
            "at_window": x.get("proposed_at"),
            "decision": dec.get(x["_n"], {}).get("decision", "open"),
            "reason": dec.get(x["_n"], {}).get("reason"),
        } for x in props[-6:]],
    }


def splitter():
    """The delivery path's own honesty: drops are splices in the stream."""
    out = {}
    try:
        lines = [l for l in open("/tmp/fifo_splitter.log") if "read |" in l]
        if lines:
            m = re.search(
                r"([\d.]+)h read \| encoder\s+([\d.]+)h drop (\d+) restart (\d+)"
                r" \| segments (\d+) drop (\d+) \| clock skew ([-+\d.]+)",
                lines[-1])
            if m:
                out = {"hours_read": float(m.group(1)),
                       "encoder_drops": int(m.group(3)),
                       "encoder_restarts": int(m.group(4)),
                       "segments_written": int(m.group(5)),
                       "clock_skew_s": float(m.group(7))}
    except Exception:
        pass
    return out



def pitch_structure(limit=1200):
    """The two pitch axes, each against a null that can actually fail.

    The panel has carried level, texture, vocabulary and self-ingestion since
    1 Sept and nothing about PITCH, which is the axis the factory spent 3-5 Sept
    acquiring: a tonic it can return to, a table of corpus-derived intervals, and
    from 5 Sept a chord held across a section. Those are the parts most likely to
    be overclaimed in a talk, so they are the parts that belong in public.

    HORIZONTAL -- does one voice go anywhere melodic?
    Successive voice births carry a pitch (VSNAP). The interval between
    consecutive births is a melodic step. Two things are read off it: how often
    the step is zero (a pitch HELD rather than replaced, the thing the hour of
    3 Sept found at 4.5%), and how large the steps are when they are not.

    NULL: the same pitches in shuffled order. This one is legitimate, unlike the
    circular shift that made the just-mode test vacuous, BECAUSE the statistic is
    a function of ADJACENCY -- consecutive differences change when the order
    changes. A statistic that does not depend on order cannot be nulled by
    reordering, and this project has made that mistake three times.

    VERTICAL -- do voices sounding together belong to one chord?
    VERTICAL lines give the octave-folded ratios present in a window. The measure
    is the share of them within 30 cents of a member of the section's chord.

    NULL: random chord tables of the same size drawn from the octave, which is
    what the just-mode result needed and what its pre-registered null failed to
    be. If the observed share is inside the random band, voices are landing on
    the chord no more than on any arbitrary set of ratios and the vertical layer
    is decoration.

    Everything here is descriptive. Neither number is a charter metric and
    neither has a bound, because nothing has yet established what value would be
    good.
    """
    out = {"available": False}
    p = newest_window_log()
    if not p:
        return out
    births, verticals, chords = [], [], []
    try:
        for line in open(p, errors="replace"):
            if line.startswith("VSNAP "):
                f = line[6:].strip().split(",")
                if len(f) >= 6:
                    try:
                        births.append((int(f[0]), float(f[2]), float(f[4])))
                    except ValueError:
                        pass
            elif line.startswith("VERTICAL "):
                f = line[9:].strip().split(",")
                if len(f) >= 3:
                    try:
                        verticals.append([float(x) for x in f[2].split("|")])
                    except ValueError:
                        pass
            elif line.startswith("CHORD "):
                # TOLERANT OF BOTH FORMATS. Until 5 Sept the line was
                # "CHORD <id>,<size>,<members>"; it now leads with the window so
                # a chord can be paired with what sounded under it. A panel that
                # crashed on the older logs still on disk would take the whole
                # snapshot down, so the members are found by shape -- the field
                # containing "|" -- rather than by position.
                f = line[6:].strip().split(",")
                mem = next((x for x in f if "|" in x), f[-1] if f else "")
                try:
                    vals = [float(x) for x in mem.split("|")]
                    if vals:
                        chords.append(vals)
                except ValueError:
                    pass
    except Exception:
        return out
    if len(births) < 30:
        return {"available": False,
                "reason": f"only {len(births)} voice births logged; "
                          "pitch structure needs a longer run"}

    hz = np.array([b[1] for b in births[-limit:]], dtype=float)
    hz = hz[hz > 20]
    cents = 1200 * np.log2(hz[1:] / hz[:-1])
    held = float((np.abs(cents) < 5).mean())
    rng = np.random.default_rng(0)
    sh = []
    for _ in range(200):
        q = rng.permutation(hz)
        sh.append(float((np.abs(1200 * np.log2(q[1:] / q[:-1])) < 5).mean()))
    mu, sd = float(np.mean(sh)), float(np.std(sh) + 1e-12)

    out = {
        "available": True,
        "horizontal": {
            "births": int(len(hz)),
            "held_share": round(held, 4),
            "shuffled_share": round(mu, 4),
            "z": round((held - mu) / sd, 2),
            "median_step_cents": round(float(np.median(np.abs(cents))), 1),
            "note": "share of consecutive voice births that keep the same pitch "
                    "(within 5 cents). The null shuffles the same pitches, so it "
                    "is a test of ORDER and not of the pitch distribution.",
        },
    }

    if verticals and chords:
        # THE UNION OF CHORD MEMBERS USED THIS RUN, not chords[-1].
        #
        # The first version compared every interval in the run against the LAST
        # chord drawn, and that chord was [1.0] -- pure unison -- while `flat`
        # explicitly excludes unison. Nothing could match by construction and the
        # panel would have published z = -2.22 as though the vertical layer were
        # failing. It was the measure that was broken, in exactly the way the
        # circular-shift null was broken: a statistic that cannot come out any
        # other way is not a measurement.
        #
        # Pairing each window to the chord IN FORCE at that moment is the exact
        # form, and it needs the window index on the CHORD line, which was added
        # today and arrives at the next restart. Until then this asks the weaker
        # but well-posed question: do sounding intervals land on ratios the chord
        # layer has ACTUALLY been using, against random ratios? Unison-only
        # chords contribute nothing and are dropped rather than counted as a
        # match they cannot earn.
        tab = sorted({round(x, 4) for c in chords for x in c if x > 1.005})
        if len(tab) < 2:
            tab = None
        flat = [x for v in verticals[-limit:] for x in v if x > 1.005]
        if tab and len(flat) > 30:
            def near(vals, t):
                t = np.asarray(t, dtype=float)
                return float(np.mean([np.min(np.abs(1200 * np.log2(v / t))) < 30
                                      for v in vals]))
            obs = near(flat, tab)
            draws = [near(flat, np.sort(rng.uniform(1.0, 2.0, max(2, len(tab)))))
                     for _ in range(400)]
            m2, s2 = float(np.mean(draws)), float(np.std(draws) + 1e-12)
            out["vertical"] = {
                "intervals": int(len(flat)),
                "chord_members_used": [round(x, 3) for x in tab],
                "on_chord_share": round(obs, 4),
                "random_table_share": round(m2, 4),
                "random_sd": round(s2, 4),
                "z": round((obs - m2) / s2, 2),
                "chord_sizes": sorted(set(len(c) for c in chords)),
                "note": "share of sounding intervals within 30 cents of a ratio "
                        "the chord layer has used, against random ratio sets of "
                        "the same size. Inside the random band means the vertical "
                        "layer is not reaching the output. Per-section pairing "
                        "arrives with the window index on the CHORD line.",
            }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/superdark_state.json")
    ap.add_argument("--log", default=None)
    a = ap.parse_args()

    log = a.log or newest_window_log()
    ch = jload(os.path.join(MUT, "charter.json"), {})
    kern = jload(os.path.join(MUT, "kernel.json"), {})
    pol = jload(os.path.join(MUT, "policy.json"), {})

    state = {
        "generated": time.time(),
        "run": {},
        "charter": {"edition": ch.get("edition"), "authored": ch.get("authored"),
                    "editions_so_far": len(ch.get("_lineage", [])) + 1,
                    "metrics": []},
        "kernel": {"edition": kern.get("edition"),
                   "armed": bool(kern.get("armed")),
                   "clauses": [k for k in kern.get("identity", kern.get("norms", {}))
                               if not k.startswith("_")]
                   if isinstance(kern.get("identity", kern.get("norms")), dict) else []},
        "corpus": corpus_state(),
        "proposals": proposals(),
        "delivery": splitter(),
        "policy": {"self_ingest_weight": pol.get("self_ingest_weight"),
                   "voices": [pol.get("voices_min"), pol.get("voices_max")]},
        # PUBLISHED, NOT HIDDEN. See the header. A panel that showed only the
        # working parts would misrepresent the factory as more governed than it is.
        # CORRECTED 1 Sept. The first version of this list said judge variety was
        # "failing" because all three judges were no-swap-regret learners. There
        # are no judges. That sentence described the paper's analysis and earlier
        # Archon work, not this factory, which has no judge_weight, emits no
        # verdicts and contains nothing judge-shaped in the SynthDef. Claiming a
        # partial implementation of an evaluation layer that does not exist is
        # exactly the flattery this panel is supposed to prevent, and it was on
        # the public page for about an hour.
        "gaps": [
            {"principle": "a population of judges",
             "status": "observing",
             "detail": "nine judges, six mean-based and three swap-based, over "
                       "three feature views. They predict whether the next "
                       "window will be silent or clipping, learn online, and "
                       "STEER NOTHING. Zero influence is deliberate: three "
                       "self-generated criteria here have become convergence "
                       "engines, and a judge that steers what it predicts has "
                       "manufactured its own evidence"},
            _recursion(),
            {"principle": "grading signal outside the judged loop",
             "status": "measured",
             "detail": "each judge is scored on whether the anomaly it flagged "
                       "actually followed. The signal is outside their loop by "
                       "construction, since they influence nothing, so the "
                       "outcome cannot be a self-fulfilment. Lift above 1.0 "
                       "means a flag carried information"},
        ],
    }

    if log and os.path.exists(log):
        n, rows, failed, und = SC.evaluate(log, ch)
        s = read_series(log)
        state["run"] = {
            "log": os.path.basename(log),
            "windows": n,
            # THE FILENAME, NOT getctime.
            # os.path.getctime is the inode CHANGE time, not a creation time, and
            # it updates on every write -- so on a log the factory appends to
            # every window it reports approximately "now". Measured: a factory up
            # 11.7 minutes with 60 windows logged reported started = 22 seconds
            # ago. The page then showed a factory uptime that could never exceed
            # one publish interval, and nobody noticed because the panel was
            # reading Icecast's clock for the number on display.
            # live_YYMMDD_HHMMSS is exact and is already the convention
            # level_probe.py relies on.
            "started": run_started(log),
            "live_voices_now": s["live"][-1] if s["live"] else None,
            "machines_seen": len(set(s["mach"])),
        }
        for k, norm, v, lo, hi, verdict in rows:
            spec = ch.get("metrics", {}).get(k, {})
            state["charter"]["metrics"].append({
                "key": k, "norm": norm, "value": v,
                "lo": None if lo == float("-inf") else lo,
                "hi": None if hi == float("inf") else hi,
                "verdict": verdict,
                # THE TOP OF m3b_delivered_peak's BOUND IS EXCLUSIVE and the
                # panel has to say so, or [0, 1] and [0, 1) print identically
                # while only one of them fails at full scale.
                "hi_exclusive": bool(spec.get("exclusive_upper")),
                "descriptive": bool(spec.get("descriptive")),
                "test": spec.get("test"),
                # The provenance notes are where m6's decorative history and
                # m4's re-pricing are recorded. They travel with the metric.
                "note": spec.get("_untested") or spec.get("_repriced")
                        or spec.get("_provenance"),
                "rolling": None,   # filled below, once rolling() has run
            })
        # WHAT IS SOUNDING RIGHT NOW. One machine row per window, so this is the
        # behaviour the factory is actually running as the snapshot is taken --
        # the only part of the page that changes on the factory's own clock
        # (11.7 s) instead of the publisher's.
        roster = {}
        for w, name in zip(s["wins"], s["mach"]):
            r = roster.setdefault(name, {"name": name, "count": 0, "last": 0})
            r["count"] += 1
            r["last"] = max(r["last"], w)
        state["live"] = {
            "machine": s["raw"][-1] if s["raw"] else None,
            "machine_family": s["mach"][-1] if s["mach"] else None,
            "voices": s["live"][-1] if s["live"] else None,
            "window": s["wins"][-1] if s["wins"] else None,
            # Sorted by RECENCY, so the grid reads as a vocabulary with the part
            # currently in use at the front, and the long tail of behaviours the
            # factory has stopped reaching for behind it.
            "roster": sorted(roster.values(), key=lambda r: -r["last"])[:96],
            "voices_trace": s["live"][-120:],
            "machine_trace": s["mach"][-48:],
        }
        # THE SLOT RIBBON'S DATA: which machine each of the three layers has
        # held, and from which window. This is what the panel draws now that the
        # waterfall comes from the listener's own audio instead of from here.
        #
        # It replaces the published spectrogram, which existed only because the
        # picture used to be server-side and therefore had to be slid thirty
        # seconds forward to sit where the ears were. That alignment is what
        # kept drifting. A decision log has nothing to align: window 41 is
        # window 41 whenever it is read.
        #
        # SLOT lines are emitted only when a slot CHANGES, which is exactly the
        # right shape -- each entry is the start of a run and the next entry for
        # that layer is its end.
        state["slots"] = slots()

        # The splitter still computes a spectrogram into /tmp; it is no longer
        # read here. Left running rather than ripped out in the same change that
        # replaced the renderer, so that if the real-time waterfall turns out to
        # be wrong the fallback is one line away instead of one rebuild away.
        state["vocabulary"] = vocabulary(s["mach"])
        state["rolling"] = rolling(s)
        state["turnover"] = turnover()
        for m in state["charter"]["metrics"]:
            m["rolling"] = state["rolling"].get(m["key"])
        state["charter"]["failing"] = sorted(failed)
        state["charter"]["undecided"] = sorted(und)
        state["charter"]["tolerated"] = ch.get("departures", {}).get(
            "tolerated_failing_metrics")
        state["charter"]["never_tolerated"] = ch.get("departures", {}).get(
            "never_tolerated", [])
        # ENSEMBLE DISAGREEMENT IS NOW REAL. It was reported as unavailable
        # until 2 Sept because the factory had no judges; a population of nine
        # now predicts the next window and the spread of their predictions is
        # the paper's third early-warning signal. Published WITH its control:
        # disagreement on permuted outcomes, so a reader can see how much of the
        # spread is structure and how much is the population arguing with itself.
        jud = jload(os.path.join(RENDERS, "judges_summary.json"))
        ed = ({"available": False,
               "reason": "the judge population has not reported yet"}
              if not jud else {
                  "available": True,
                  "value": jud["ensemble_disagreement"],
                  "control": jud["ensemble_disagreement_control"],
                  "judges": jud["population"],
                  "note": "spread of predictions across a population of "
                          f"{jud['population']} judges "
                          f"({jud['mean_based']} mean-based, {jud['swap_based']} "
                          "swap-based) over the next window",
              })
        state["ews"] = {
            "signals": [ews(s["peak"], "master_peak"),
                        ews(s["gap"], "spectral_gap")],
            "ensemble_disagreement": ed,
        }
        if jud:
            state["judges"] = jud
        # The behaviour trace the panel draws as a density strip. Downsampled,
        # because the page should not carry 4,000 windows to draw 200 marks.
        pk = np.asarray(s["peak"], dtype=float)
        if len(pk):
            step = max(1, len(pk) // 240)
            state["trace"] = {
                "peak": [round(float(v), 4) for v in pk[::step][-240:]],
                "live": s["live"][::max(1, len(s["live"]) // 240)][-240:],
                "windows_per_mark": step,
            }

    state["pitch"] = pitch_structure()

    json.dump(state, open(a.out, "w"), indent=1)
    m = state["charter"]["metrics"]
    print(f"  {a.out}")
    print(f"  windows {state['run'].get('windows')}  "
          f"charter ed.{state['charter']['edition']}  "
          f"{sum(1 for x in m if x['verdict']=='pass')}/{len(m)} passing  "
          f"kernel {'ARMED' if state['kernel']['armed'] else 'not armed'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
