#!/usr/bin/env python3
"""Strip SuperCollider comments from stdin (or argv[1]) and write the rest to stdout.

WHY THIS EXISTS. tools/audit_inert_mechanisms.sh used `grep -c KEY factory.scd`
to decide whether a knob is READ. This file is 40% prose: `section_operator_weight`
and `self_ingest_weight` appear ONLY inside `//` comments -- in both cases a
comment that says the mechanism steers nothing -- and the audit reported them
READ. An audit that counts its own documentation as evidence of wiring is worse
than no audit, because it reads as a clean bill.

Line count is preserved (a stripped comment leaves its newlines) so that any
`grep -n` against the output still names the true line in the source.

String literals are respected: a `//` inside "..." is not a comment, nor is a
`$/` char literal, nor is `\\` an escape outside a string. Block comments in
SuperCollider NEST, unlike C, and this handles that.
"""
import sys


def strip(src: str) -> str:
    out = []
    i, n = 0, len(src)
    depth = 0          # /* */ nesting depth
    while i < n:
        c = src[i]
        if depth > 0:
            if src.startswith("/*", i):
                depth += 1; i += 2; continue
            if src.startswith("*/", i):
                depth -= 1; i += 2; continue
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        if c == '"':                      # string literal: copy verbatim
            out.append(c); i += 1
            while i < n:
                if src[i] == "\\" and i + 1 < n:
                    out.append(src[i:i + 2]); i += 2; continue
                out.append(src[i])
                if src[i] == '"':
                    i += 1; break
                i += 1
            continue
        if c == "$" and i + 1 < n:        # char literal, e.g. $/ or $" or $\/
            if src[i + 1] == "\\" and i + 2 < n:
                out.append(src[i:i + 3]); i += 3
            else:
                out.append(src[i:i + 2]); i += 2
            continue
        if src.startswith("//", i):
            while i < n and src[i] != "\n":
                out.append(" "); i += 1
            continue
        if src.startswith("/*", i):
            depth = 1; i += 2; continue
        out.append(c); i += 1
    return "".join(out)


if __name__ == "__main__":
    text = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    sys.stdout.write(strip(text))
