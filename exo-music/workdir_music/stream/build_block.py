#!/usr/bin/env python3
"""Split player.html into panel.css, panel.js and a tiny WordPress block.

WHY THE CODE LEFT WORDPRESS.
The first build pasted the whole thing -- style, markup and script -- into a
Custom HTML block. WordPress's content filter encoded every `&&` in the
JavaScript into `&#038;&#038;`, which is a SyntaxError, and the panel rendered as
an empty shell with the markup present and nothing filled in. It failed silently
in the sense that the page still looked like a page.

Dodging the ampersands would have worked and would have been the wrong fix: the
next edit would reintroduce one, or hit a different filter. Code served as
external files cannot be texturized at all, because WordPress never sees it. The
block reduces to markup plus two tags.

The second benefit is larger than the first: updating the panel is now an scp to
the relay. Roberto's site is touched ONCE, and never again for a design change.

    python3 stream/build_block.py            # writes the three artefacts
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "player.html")
BASE = "https://stream.robertoalonsotrillo.com"


def main():
    s = open(SRC, encoding="utf-8").read()

    # Anchor past the leading comment: it discusses <style> and </script>
    # literally, and a naive index() matches the sentence explaining the split.
    after = s.index("-->", s.index("EMBEDDING NOTES")) + 3
    css = s[s.index("<style>", after) + len("<style>"):s.index("</style>", after)]
    body = s[s.index("<main", after):s.index("</main>", after) + len("</main>")]
    js_open = s.index("<script>", after)
    js = s[js_open + len("<script>"):s.rindex("</script>")]

    open(os.path.join(HERE, "panel.css"), "w", encoding="utf-8").write(css.strip() + "\n")
    open(os.path.join(HERE, "panel.js"), "w", encoding="utf-8").write(js.strip() + "\n")

    # NO VERSION QUERY, and that is the point.
    # The first build appended ?v=<content hash>. It cache-busted correctly and
    # quietly reintroduced the problem the split was meant to remove: every
    # rebuild changed the URL, so the WordPress block had to be rewritten to
    # match, and when it was not, visitors kept loading a stale panel while the
    # preview -- which has no query string -- looked fine. Roberto hit exactly
    # that: the page was correct in one browser and broken in another.
    #
    # Freshness now belongs to the server, where it can be enforced once:
    # Caddy sends `Cache-Control: no-cache, must-revalidate` on both files, so a
    # browser revalidates every load and an unchanged file still costs only a
    # 304. The block is now genuinely write-once.
    ver = "%08x" % (abs(hash(css + js)) & 0xFFFFFFFF)   # reported, not embedded
    block = (
        f'<link rel="stylesheet" href="{BASE}/panel.css">\n'
        f'{body}\n'
        f'<script src="{BASE}/panel.js" defer></script>\n'
    )
    open(os.path.join(HERE, "wordpress_block.html"), "w", encoding="utf-8").write(block)

    # SYNTAX-CHECK THE JS, AND FAIL LOUDLY. On 2 Sept an edit left a fragment of
    # HTML outside its template literal; `node --check` caught it, but the check
    # was written as `node --check ... >/dev/null && echo OK`, so the failure
    # printed nothing and the absence of a success line read as silence. A
    # broken panel.js went to the relay and the live page rendered an empty
    # shell. The check now raises, because a verification you can overlook is
    # not a verification.
    import shutil
    import subprocess
    if shutil.which("node"):
        tmp = os.path.join(HERE, ".syntax_check.js")
        open(tmp, "w", encoding="utf-8").write(js)
        r = subprocess.run(["node", "--check", tmp], capture_output=True, text=True)
        os.unlink(tmp)
        if r.returncode != 0:
            print(r.stderr.strip()[:600])
            raise SystemExit("  panel.js DOES NOT PARSE — nothing written")
        print("  panel.js parses")
    else:
        print("  WARNING: node not found, panel.js NOT syntax-checked")

    # The markup must not carry an ampersand either, for the same reason.
    amps = re.findall(r"&(?!(?:amp|lt|gt|quot|#\d+|nbsp);)", body)
    print(f"  panel.css  {len(css):6d} chars")
    print(f"  panel.js   {len(js):6d} chars")
    print(f"  block      {len(block):6d} chars   v={ver}")
    if amps:
        print(f"  WARNING: {len(amps)} bare ampersand(s) in the markup; WordPress "
              f"will encode them")
    return 0


if __name__ == "__main__":
    sys.exit(main())
