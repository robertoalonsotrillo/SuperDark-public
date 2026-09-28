#!/bin/sh
# Which mechanisms are BUILT but STEERING NOTHING?
#
# The question matters because the paper's Class 3 claim (P36, automation of
# objectives) is a claim about mechanisms that ACT. A mechanism that computes,
# logs, and is then multiplied by zero is evidence of nothing except that it
# compiles. Three are suspected:
#
#   self_ingest_weight   the corpus loop
#   judges / judge_weight the evaluator population (P486, requisite variety)
#   charter              the eight metrics (P271 co-authorship, P518 editioned)
#
# For each: is the knob READ by the live factory at all, and what is it set to?
# A knob nothing reads is worse than a knob set to zero, because zero is a
# decision and unread is an oversight that looks like a decision.
#
# ---- 19 SEPT: THIS AUDIT COUNTED ITS OWN DOCUMENTATION AS WIRING -----------
#
# The test was `grep -c "$K" live_factory.scd`, and live_factory.scd is roughly
# 40% prose. `section_operator_weight` occurs exactly once in that file, on line
# 931, inside a comment that says in capitals that the mechanism steers nothing.
# `self_ingest_weight` occurs exactly once, on line 1735, inside a comment
# listing it as an example of a knob the factory does not read. Both were
# reported READ. The audit was returning a clean bill sourced from the sentence
# admitting the fault.
#
# Three changes, in order of how much they were costing:
#
#   1. COMMENTS ARE STRIPPED before searching, by tools/strip_sc_comments.py,
#      which handles `//`, nesting `/* */`, string literals and $char literals
#      and preserves line numbers. A hit is now a hit in code.
#   2. KEYS BUILT BY CONCATENATION are resolved. `policy["rest_" ++ lay]` and
#      `policy["voice_span_" ++ lay]` read thirteen keys that no literal-string
#      search can see; without this the fix trades false READs for false
#      NOT-READs, which is the same error pointing the other way.
#   3. EVERY non-underscore key in policy.json is checked, not a hand-written
#      list of eight. The list of eight was written from the three mechanisms
#      that were already suspected, so it could only ever confirm them.
#
# `grep -c ... || echo 0` was also wrong: grep -c PRINTS "0" and EXITS 1 on no
# match, so N became the two-line string "0\n0" and `[ "$N" -gt 0 ]` errored out
# on every genuinely-unread key. The three NOT READ lines in the old output were
# reached through an error path, not a test.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/workdir_music"
FACTORY="$W/tools/live_factory.scd"
POLICY="$W/mutable/policy.json"
STRIP="$ROOT/tools/strip_sc_comments.py"
PY="$(command -v python3)"

echo "=== 1. is the knob read by the LIVE FACTORY? (comments stripped) ==="
"$PY" - "$FACTORY" "$POLICY" "$STRIP" <<'PYEOF'
import importlib.util, json, re, sys

factory, policy_path, strip_path = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("strip_sc_comments", strip_path)
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

raw = open(factory).read()
code = mod.strip(raw)

# Keys assembled at runtime: policy["rest_" ++ lay ++ "_min"]. `lay` is whatever
# layerOf returns, and layerOf returns weights[m]["layer"] or "micro"; every
# layer value in weights.json and written_machines.json is macro/mid/micro.
LAYERS = ("macro", "mid", "micro")
concat = []
for m in re.finditer(r'policy\[\s*"([^"]*)"((?:\s*\+\+\s*\w+(?:\s*\+\+\s*"[^"]*")?)+)\]', code):
    head, tail = m.group(1), m.group(2)
    suffixes = re.findall(r'"([^"]*)"', tail) or [""]
    for lay in LAYERS:
        for suf in suffixes:
            concat.append(head + lay + suf)
concat = set(concat)

# A shadowed fallback: policy["a"] ? policy["b"] -- b is unreachable while a is
# present in policy.json. Same for policy["a"] ?? { policy["b"] }.
shadow = {}
for m in re.finditer(r'policy\[\s*"([^"]+)"\s*\]\s*\?\??\s*(?:\{\s*)?policy\[\s*"([^"]+)"\s*\]', code):
    shadow.setdefault(m.group(2), set()).add(m.group(1))
for m in re.finditer(r'policy\[\s*"([^"]+?)"\s*\+\+[^]]*\]\s*\?\??\s*(?:\{\s*)?policy\[\s*"([^"]+)"\s*\]', code):
    for lay in LAYERS:
        shadow.setdefault(m.group(2), set()).add(m.group(1) + lay)

pol = json.load(open(policy_path))
keys = sorted(k for k in pol if not k.startswith("_"))

buckets = {"CODE": [], "CONCAT": [], "SHADOWED": [], "COMMENT ONLY": [], "NEVER MENTIONED": []}
for k in keys:
    guards = shadow.get(k)
    if guards and all(g in pol for g in guards):
        buckets["SHADOWED"].append((k, "shadowed by " + ", ".join(sorted(guards))))
    elif f'"{k}"' in code:
        buckets["CODE"].append((k, ""))
    elif k in concat:
        buckets["CONCAT"].append((k, "built by ++ concatenation"))
    elif k in raw:
        buckets["COMMENT ONLY"].append((k, "appears in live_factory.scd PROSE ONLY"))
    else:
        buckets["NEVER MENTIONED"].append((k, "absent from live_factory.scd entirely"))

for name in ("CODE", "CONCAT", "SHADOWED", "COMMENT ONLY", "NEVER MENTIONED"):
    rows = buckets[name]
    print(f"\n  -- {name}  ({len(rows)} of {len(keys)})")
    if name == "CODE":
        print("     " + ", ".join(k for k, _ in rows))
        continue
    for k, why in rows:
        print(f"     {k:28} = {str(pol[k]):<22} {why}")
print("\n  CODE means the literal key appears outside every comment. It does NOT")
print("  mean the value can act: audibility_floor is read in code and multiplied")
print("  by audibility_influence = 0.0. Reachability is section 6.")
PYEOF

echo
echo "=== 2. what is it set to? ==="
python3 - "$POLICY" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for k in sorted(d):
    if k.startswith("_"):
        continue
    if any(s in k for s in ("weight", "judge", "charter", "ingest")):
        v = d[k]
        flag = "  <-- ZERO, steering nothing" if str(v) in ("0", "0.0", "0.00") else ""
        print(f"  {k:28} {v}{flag}")
PYEOF

echo
echo "=== 3. does the pool the ingester fills reach the factory? ==="
# The factory loads buffers from GRAINS/MID/MACRO at boot. If those paths are
# the FMA corpora and never the pool, then no ingested grain can ever sound and
# the loop is open no matter what the weight says.
grep -oE '"[^"]*grains[a-z_0-9]*"' "$W/renders/_live.scd" 2>/dev/null | sort -u \
  | sed 's/^/    factory loads: /'
echo "    ingester fills: $(ls -d /Volumes/FMA/superdark/self_corpus/grains_pool_* 2>/dev/null | tr '\n' ' ')"

echo
echo "=== 4. charter: does anything ACT on the score? ==="
for F in "$ROOT/tools/score_charter.py" "$W/tools/score_charter.py"; do
  [ -f "$F" ] || continue
  echo "  $F"
  grep -nE "def |write|json.dump|policy|sys.exit|return" "$F" | head -12 | sed 's/^/    /'
done

echo
echo "=== 5. judges: what does the influence knob do? ==="
for F in "$ROOT/tools/judges.py" "$W/tools/judges.py"; do
  [ -f "$F" ] || continue
  echo "  $F"
  grep -nE "weight|influence|0\.0|def main|def score" "$F" | head -12 | sed 's/^/    /'
done

echo
echo "=== 6. READ, but multiplied by a neighbouring zero ==="
# Section 1 answers "is the key in code". This answers the different and harder
# question "can the value change anything". The cheap, honest version of it:
# where a key is read in the SAME EXPRESSION as another key whose current value
# is zero, the first key is very likely inert at this policy. Not proof -- the
# zero may sit on the other side of a `+` -- so every hit is a lead to read, and
# the line is printed so it can be read.
"$PY" - "$FACTORY" "$POLICY" "$STRIP" <<'PYEOF'
import importlib.util, json, re, sys
factory, policy_path, strip_path = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("strip_sc_comments", strip_path)
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
code = mod.strip(open(factory).read()).splitlines()
pol = json.load(open(policy_path))


def zeroish(v):
    try:
        return float(v) == 0.0
    except (TypeError, ValueError):
        return False


hits = 0
# join continuation lines: an SC expression may wrap, so look at a 2-line window
for i, line in enumerate(code):
    window = line + " " + (code[i + 1] if i + 1 < len(code) else "")
    found = re.findall(r'policy\[\s*"([^"]+)"\s*\]', window)
    if len(found) < 2:
        continue
    zeros = [k for k in found if k in pol and zeroish(pol[k])]
    others = [k for k in found if k not in zeros]
    if zeros and others:
        hits += 1
        print(f"  line {i+1}: {', '.join(sorted(set(others)))}")
        print(f"      is in an expression with {', '.join(sorted(set(zeros)))} = 0")
        print(f"      {line.strip()[:100]}")
if hits == 0:
    print("  none")

# The other half of the same question, and the cheaper half: a key read in code
# whose OWN value is zero. Every `if (x > 0)` and every `v * x` behind one of
# these is dead at this policy. Some are deliberate control arms and say so in
# the comment above them; the audit cannot tell those apart and does not try.
zero_read = sorted(k for k in pol
                   if not k.startswith("_") and zeroish(pol[k])
                   and f'"{k}"' in "\n".join(code))
print("\n  read in code AND set to zero (every branch behind them is dead):")
for k in zero_read:
    print(f"     {k}")
if not zero_read:
    print("     none")
PYEOF
