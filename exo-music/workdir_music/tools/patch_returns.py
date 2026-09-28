#!/usr/bin/env python3
"""Make Handler's player methods RETURN their EventStreamPlayer.

SuperCollider methods return `this` unless an explicit `^` says otherwise.
Handler_Local.sc contains exactly ONE caret, in `new`. So every one of the
twenty `*Player` methods returns the Handler, and so does `stateMachine`,
which is why the live factory's guard

    if (pl.isKindOf(EventStreamPlayer)) { live.add([pl, deadline]) }

has never once been true for a class machine. They are never tracked, never
given a deadline, never stopped, and never wrapped in the amplitude arc that
runtime machines get.

The naive fix -- caret the last `.play` in each method -- is wrong for three
of them. `sonorousPlayer`, `stretchPlayer` and `granPlayer` fire a main
pattern and then a SECOND pattern inside `if (choose == 0)`. Caretting the
last play would return from a branch that usually does not execute; caretting
the first would return early and skip the second layer altogether. So the
main pattern is captured into a local and returned at the end of the method,
leaving control flow untouched.

Applied to the LIVE COPY only. lib/Handler_Local.sc and the offline renderer
are never modified.
"""
import re
import sys

TAB = "\t"


def indent(s: str) -> int:
    return len(s) - len(s.lstrip(TAB))


def patch(path: str) -> int:
    src = open(path).read().split("\n")

    # EVERY method, so a player's body is bounded by the next method of any
    # kind. Bounding only by the next *Player let melodyPlayer -- the last one
    # -- run to end of file, and its `^scReturn` landed inside msg_handler.
    allm = [
        (i, re.match(r"^\t(\w+) \{", l).group(1))
        for i, l in enumerate(src)
        if re.match(r"^\t\w+ \{", l)
    ]
    methods = [(i, n) for i, n in allm if n.endswith("Player")]
    if not methods:
        raise SystemExit("no player methods found -- has the file moved?")

    edits = []  # (line_index, kind, text)
    for start, name in methods:
        stop = next((i for i, _ in allm if i > start), len(src))

        # EVERY .play in the method, not just the first. sonorousPlayer,
        # stretchPlayer and granPlayer each fire a second \playgran cloud
        # inside `if (choose == 0)`. Returning only the main pattern left those
        # clouds untracked, so nothing ever stopped them and they accumulated
        # into a permanent noise layer under the music -- Roberto, on the first
        # audible run: "that white noise element is always there as a patina".
        plays = [x for x in range(start, stop) if re.search(r"\.play;?\s*$", src[x])]
        if not plays:
            raise SystemExit(f"{name}: no .play found")

        heads = []
        for play in plays:
            want = indent(src[play])
            head = next(
                (
                    x
                    for x in range(play - 1, start, -1)
                    if indent(src[x]) == want
                    and re.match(r"^\t*(Pkill|Ppar|Pbind)\s*[\(\[]", src[x])
                ),
                None,
            )
            if head is None:
                raise SystemExit(f"{name}: no statement start above line {play + 1}")
            heads.append((head, play))

        # the argument line, so `var` lands legally at the top of the body
        arg = next(
            (x for x in range(start, stop) if re.match(r"^\t*\|buf\|\s*$", src[x])), None
        )
        if arg is None:
            raise SystemExit(f"{name}: no |buf| argument line")

        # the method's closing brace
        close = next(
            (x for x in range(stop - 1, play, -1) if re.match(r"^\t\}\s*$", src[x])), None
        )
        if close is None:
            raise SystemExit(f"{name}: no closing brace")

        # every player is collected, so a machine that starts two patterns
        # hands back two things to track. Control flow is untouched: the
        # conditional cloud still only runs when its condition holds.
        edits.append((arg, "after", TAB * 2 + "var scReturn = List.new;"))
        for head, play in heads:
            edits.append(
                (head, "replace", re.sub(r"^(\t*)", r"\1scReturn.add(", src[head]))
            )
            edits.append((play, "replace", re.sub(r"(\.play);?\s*$", r"\1);", src[play])))
        edits.append((close, "before", TAB * 2 + "^scReturn;"))
        print(
            f"  {name:16} {len(heads)} pattern(s) at "
            f"{', '.join(str(h + 1) for h, _ in heads)}, returns at {close + 1}"
        )

    # apply back to front so indices stay valid
    for line, kind, text in sorted(edits, key=lambda e: -e[0]):
        if kind == "replace":
            src[line] = text
        elif kind == "after":
            src.insert(line + 1, text)
        else:
            src.insert(line, text)

    # stateMachine relays the switch result out
    for i, l in enumerate(src):
        if re.match(r"^\t\tswitch\(state,", l):
            src[i] = l.replace("switch(state,", "^switch(state,")
            print(f"  stateMachine     returns the switch at line {i + 1}")
            break
    else:
        raise SystemExit("stateMachine: no switch(state, ... found")

    open(path, "w").write("\n".join(src))
    return len(methods)


if __name__ == "__main__":
    n = patch(sys.argv[1])
    print(f"  patched {n} player methods + stateMachine")
