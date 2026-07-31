#!/usr/bin/env python3
"""Surgically splice the ghost-strata SVG (and its session number) from a
freshly rendered render.svg into docs/index.html, leaving the interactive
board's JS/CSS/controls untouched.

Usage: splice_ghosts.py <render.svg> <docs/index.html>
"""
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


def splice(html_text: str, marks: list[str], session: int) -> str:
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
    return new_html


def main():
    svg_path, html_path = sys.argv[1], sys.argv[2]
    with open(svg_path) as f:
        svg_text = f.read()
    with open(html_path) as f:
        html_text = f.read()

    marks, session = extract_marks_and_session(svg_text)
    new_html = splice(html_text, marks, session)

    if new_html == html_text:
        print("splice_ghosts: no change")
        return

    with open(html_path, "w") as f:
        f.write(new_html)
    print(f"splice_ghosts: spliced {len(marks)} marks, session {session}")


if __name__ == "__main__":
    main()
