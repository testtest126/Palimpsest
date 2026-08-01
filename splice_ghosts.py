#!/usr/bin/env python3
"""Surgically splice the ghost-strata SVG, session number, and "at a glance"
facts from a freshly rendered render.svg (+ its sibling palimpsest.json) into
docs/index.html, leaving the interactive board's JS/CSS/controls untouched.

Usage: splice_ghosts.py <render.svg> <docs/index.html>
"""
import json
import os
import re
import sys


def extract_marks_and_session(svg_text: str) -> tuple[list[str], int]:
    lines = svg_text.splitlines()
    session = int(re.search(r"session (\d+)", svg_text).group(1))

    hoshi_last = next(
        i for i, l in enumerate(lines)
        if 'cx="450.00" cy="450.00" r="4.5"' in l
    )
    assert lines[hoshi_last + 1].strip() == "</g>", "unexpected renderer output shape"
    marks_start = hoshi_last + 2
    marks_end = next(i for i in range(marks_start, len(lines)) if lines[i].strip() == "</svg>")
    marks = [l.strip() for l in lines[marks_start:marks_end]]
    return marks, session


def stats_from_state(state_path: str) -> tuple[int, int]:
    with open(state_path) as f:
        state = json.load(f)
    points = len(state["points"])
    scars = sum(1 for p in state["points"] if p.get("scar"))
    return points, scars


def scar_fact(scars: int) -> str:
    if scars == 0:
        return '<div class="fact"><b>0</b><span>scars so far — no capture has landed yet</span></div>'
    if scars == 1:
        return '<div class="fact"><b>1</b><span>scar so far — a capture that outlasted its stone</span></div>'
    return (
        f'<div class="fact"><b>{scars}</b>'
        "<span>scars so far — captures that outlasted their stones</span></div>"
    )


def splice(html_text: str, marks: list[str], session: int, points: int, scars: int) -> str:
    ghost_open = '<g id="ghostLayer">'
    ghost_close_marker = '<g id="liveLayer">'
    start = html_text.index(ghost_open) + len(ghost_open)
    end = html_text.index(ghost_close_marker, start)
    # end currently points at the start of '<g id="liveLayer">'; back up over
    # the ghostLayer's own closing </g> and its indentation/newline.
    close_tag_pos = html_text.rindex("</g>", start, end)

    new_marks_block = "\n" + "\n".join("        " + m for m in marks) + "\n        "
    new_html = html_text[:start] + new_marks_block + html_text[close_tag_pos:]

    new_html = re.sub(r"session \d+", f"session {session}", new_html)

    # "At a glance" heading — evergreen wording, no longer tied to one
    # particular session count, so it never goes stale under automation.
    new_html = re.sub(
        r"(<div class=\"sec-eyebrow\">At a glance</div>\s*<h3>)[^<]*(</h3>)",
        r"\g<1>Still layering, one session at a time\g<2>",
        new_html,
    )

    # Sessions fact.
    new_html = re.sub(
        r'<div class="fact"><b>\d+</b><span>sessions run so far[^<]*</span></div>',
        f'<div class="fact"><b>{session}</b><span>sessions run so far</span></div>',
        new_html,
    )
    # Points fact.
    new_html = re.sub(
        r'<div class="fact"><b>\d+</b><span>points on the board carrying some trace of memory</span></div>',
        f'<div class="fact"><b>{points}</b><span>points on the board carrying some trace of memory</span></div>',
        new_html,
    )
    # Scar fact — wording depends on count (0 / 1 / many), so replace the
    # whole fact block, anchored between the points fact and the board-size
    # fact so it matches regardless of the previous count's wording.
    new_html = re.sub(
        r'<div class="fact"><b>\d+</b><span>(?:scars? so far|no scars)[^<]*</span></div>',
        scar_fact(scars),
        new_html,
    )

    # "What's next" panel's automation claim — true only until automation
    # actually exists; once it does, this line must stop claiming otherwise.
    new_html = new_html.replace(
        "No scheduled or automated runs — every session so far was advanced by hand",
        "Scheduled now, not by hand — it advances one session a day, on its own",
    )

    return new_html


def main():
    svg_path, html_path = sys.argv[1], sys.argv[2]
    state_path = os.path.join(os.path.dirname(svg_path), "palimpsest.json")

    with open(svg_path) as f:
        svg_text = f.read()
    with open(html_path) as f:
        html_text = f.read()

    marks, session = extract_marks_and_session(svg_text)
    points, scars = stats_from_state(state_path)
    new_html = splice(html_text, marks, session, points, scars)

    if new_html == html_text:
        print("splice_ghosts: no change")
        return

    with open(html_path, "w") as f:
        f.write(new_html)
    print(
        f"splice_ghosts: spliced {len(marks)} marks, session {session}, "
        f"{points} points, {scars} scar(s)"
    )


if __name__ == "__main__":
    main()
