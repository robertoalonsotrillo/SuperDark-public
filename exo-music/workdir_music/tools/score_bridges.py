#!/usr/bin/env python3
"""Score the bridge control.

The PRIMARY outcome is the one the ablation could not report: of the machines
the factory wrote for itself, how many ever SOUNDED.

A written machine leaves three kinds of line in the window log:

    ACQUIRED 60,brbucp2,bu,cp,5.8705,macro     it was written
    LOADED_MACHINE brbucp2                      it became selectable
    1095.64,108,brbucp2,runtime,0.13391,...     it was SELECTED, and field 5
                                                is its amplitude

so "written" counts ACQUIRED, "selected" counts runtime event lines, and
"sounded" counts runtime event lines whose amplitude clears the floor. In the
24 Aug ablation sixteen were written, one sounded, and twelve targeted `bu`.
"""
import sys, os, re, glob, subprocess, statistics as st

AMP_FLOOR = 0.0004          # ampFloor in live_factory.scd


def scan(path):
    written, selected, sounded, targets = [], [], [], []
    for line in open(path, errors="replace"):
        if line.startswith("ACQUIRED "):
            f = line.split(None, 1)[1].strip().split(",")
            if len(f) >= 4:
                written.append(f[1])
                targets.append((f[2], f[3]))
        else:
            f = line.strip().split(",")
            # t, window, machine, kind, amp, ...
            if len(f) > 5 and f[2].startswith("br") and f[3] in ("runtime", "class"):
                selected.append(f[2])
                try:
                    if float(f[4]) > AMP_FLOOR:
                        sounded.append(f[2])
                except ValueError:
                    pass
    return written, selected, sounded, targets


def convergence(path, tools):
    out = subprocess.run(["python3", f"{tools}/tools/convergence2.py", path],
                         capture_output=True, text=True).stdout
    def grab(pat, cast=float):
        m = re.search(pat, out)
        return cast(m.group(1)) if m else None
    return (grab(r"observed rho\s+([+-][0-9.]+)"),
            grab(r"machines used (\d+)", int),
            grab(r"audible (\d+)/(\d+)".replace("(\\d+)/(\\d+)", "(\\d+)"), int),
            out)


def main(out_dir, tools):
    print(f"{'arm':8} {'runs':>4} {'written':>8} {'selected':>9} {'SOUNDED':>8} "
          f"{'sound %':>8} {'rho':>8} {'vocab':>7} {'audible':>8} {'-> bu':>7}")
    summary = {}
    for arm in ("gap", "random"):
        W = S = D = 0
        bu = 0
        rhos, vocabs, auds = [], [], []
        logs = sorted(glob.glob(f"{out_dir}/windows_{arm}_r*.log"))
        for f in logs:
            w, s, d, tg = scan(f)
            W += len(w); S += len(s); D += len(d)
            bu += sum(1 for a, b in tg if "bu" in (a, b))
            r = subprocess.run(["python3", f"{tools}/tools/convergence2.py", f],
                               capture_output=True, text=True).stdout
            m = re.search(r"observed rho\s+([+-][0-9.]+)", r)
            if m: rhos.append(float(m.group(1)))
            m = re.search(r"machines used (\d+)", r)
            if m: vocabs.append(int(m.group(1)))
            m = re.search(r"audible (\d+)/(\d+)", r)
            if m: auds.append(int(m.group(1)) / max(1, int(m.group(2))))
        if not logs:
            continue
        pct = (D / W * 100) if W else 0.0
        summary[arm] = dict(runs=len(logs), written=W, sounded=D, pct=pct,
                            rho=st.mean(rhos) if rhos else 0,
                            vocab=st.mean(vocabs) if vocabs else 0,
                            aud=st.mean(auds) if auds else 0)
        print(f"{arm:8} {len(logs):4} {W:8} {S:9} {D:8} {pct:7.1f}% "
              f"{st.mean(rhos) if rhos else 0:+8.3f} "
              f"{st.mean(vocabs) if vocabs else 0:7.1f} "
              f"{st.mean(auds) if auds else 0:7.1%} {bu:7}")

    if len(summary) == 2:
        g, r = summary["gap"], summary["random"]
        print()
        print("PRE-REGISTERED READING (25 Aug 2026, recorded before the runs):")
        print(f"  sounded    gap {g['pct']:.1f}%   random {r['pct']:.1f}%")
        print(f"  audible    gap {g['aud']:.1%}   random {r['aud']:.1%}")
        print(f"  vocabulary gap {g['vocab']:.1f}    random {r['vocab']:.1f}")
        print()
        if g["pct"] <= r["pct"] and g["aud"] <= r["aud"]:
            print("  RANDOM MATCHES OR BEATS GAP on both primary and secondary.")
            print("  The targeting contributes nothing measurable. Strike the")
            print("  operator-as-generator claim from document 37 before it")
            print("  reaches the proposal.")
        elif g["pct"] > r["pct"] and g["aud"] > r["aud"]:
            print("  GAP BEATS RANDOM on both. The targeting does work, and it")
            print("  passed a test it could not have passed yesterday, when")
            print("  findGap was selecting `bu` on a base-rate artefact.")
        else:
            print("  SPLIT. The arms disagree between primary and secondary, so")
            print("  neither claim is earned. Report the split, do not pick the")
            print("  half that suits the argument.")
        print()
        print("  n=3 per arm. Two 20-minute runs are not a significance test;")
        print("  this is a direction check, and it should be described as one.")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
