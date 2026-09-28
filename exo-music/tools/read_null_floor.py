#!/usr/bin/env python3
"""Read a null comparison against the pre-registered rule and the two real ones.

    python3 tools/read_null_floor.py harness/runs/cmp_260918_084817
"""
import json
import os
import sys

EM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NULL = sys.argv[1] if len(sys.argv) > 1 else "harness/runs/cmp_260918_084817"
CMP1 = "harness/runs/cmp_260916_202659"     # attention_weight 0.15 -> 0.3, comparison 1
CMP2 = "harness/runs/cmp_260917_201044"     # attention_weight 0.15 -> 0.3, comparison 2


def load(p):
    return json.load(open(os.path.join(EM, p, "comparison.json")))["measures"]


def delta(m, key, sub):
    return ((m.get(key) or {}).get("delta") or {}).get(sub)


def fmt(x):
    return f"{x:+.4f}" if isinstance(x, (int, float)) else "—"


n, c1, c2 = load(NULL), load(CMP1), load(CMP2)
rows = [("sonic_variety", "recurrence"),
        ("version_operator", "dwell -1/ln|l2|"),
        ("version_operator", "empirical dwell"),
        ("version_operator", "theta from null"),
        ("generation_drift", "0->1"),
        ("judges", "judge")]

print(f"\n  {'measure':<20}{'field':<18}{'NULL':>10}{'cmp1':>10}{'cmp2':>10}")
print("  " + "-" * 68)
for k, s in rows:
    print(f"  {k:<20}{s:<18}{fmt(delta(n,k,s)):>10}{fmt(delta(c1,k,s)):>10}{fmt(delta(c2,k,s)):>10}")

print("\n  pre-registered rule, sonic_variety recurrence:")
dn = abs(delta(n, "sonic_variety", "recurrence"))
d1 = abs(delta(c1, "sonic_variety", "recurrence"))
d2 = abs(delta(c2, "sonic_variety", "recurrence"))
print(f"    |d_null| = {dn:.4f}    |d_1| = {d1:.4f}    |d_2| = {d2:.4f}")
if dn >= d1:
    print("    outcome 1: |d_null| >= |d_1|. Comparison 1's movement is INSIDE the drift")
    print("               and cannot be claimed as an effect.")
else:
    print("    outcome 2: |d_null| < |d_1|. Comparison 1 exceeded one draw of drift.")
    print("               Not significance. d_null is a candidate floor, pending more nulls.")

print("\n  version_operator dwell -1/ln|l2|:")
vn = abs(delta(n, "version_operator", "dwell -1/ln|l2|"))
v1 = abs(delta(c1, "version_operator", "dwell -1/ln|l2|"))
v2 = abs(delta(c2, "version_operator", "dwell -1/ln|l2|"))
print(f"    |d_null| = {vn:.2f}    |d_1| = {v1:.2f}    |d_2| = {v2:.2f}")
print(f"    {'inside drift' if vn >= v1 else 'comparison 1 exceeded one draw of drift'}; "
      f"{'inside drift' if vn >= v2 else 'comparison 2 exceeded one draw of drift'}")

sc = (n.get("score_charter") or {}).get("delta") or {}
moved = {k: v for k, v in sc.items() if v}
print("\n  charter metrics that differ between two IDENTICAL arms:")
print("   ", moved if moved else "none")
print()
