#!/usr/bin/env bash
# One breath: advance the palimpsest by exactly one session, re-render, splice
# the new ghost strata into the published docs/index.html, commit, push.
# Safe to run headless (e.g. from a daily cron) and safe to re-run — a run
# that produces no changes to commit exits cleanly without pushing.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

BUILD_LOG="$(mktemp)"
RUN_LOG="$(mktemp)"
trap 'rm -f "$BUILD_LOG" "$RUN_LOG"' EXIT

swift build -c release --package-path PalimpsestKit >"$BUILD_LOG" 2>&1 || {
  echo "breath.sh: swift build failed — see $BUILD_LOG" >&2
  cat "$BUILD_LOG" >&2
  exit 1
}

BIN="$REPO_DIR/PalimpsestKit/.build/release/palimpsest-run"
"$BIN" "$REPO_DIR" >"$RUN_LOG" 2>&1 || {
  echo "breath.sh: palimpsest-run failed — see $RUN_LOG" >&2
  cat "$RUN_LOG" >&2
  exit 1
}

SESSION="$(python3 -c "import json; print(json.load(open('$REPO_DIR/palimpsest.json'))['sessionIndex'])")"

# Rasterize render.svg -> render.png. Best-effort: a missing/broken headless
# Chrome shouldn't fail the whole breath, just skip the PNG refresh.
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$CHROME" ]; then
  "$CHROME" --headless --disable-gpu --screenshot="$REPO_DIR/render.png" \
    --window-size=900,900 --hide-scrollbars "file://$REPO_DIR/render.svg" \
    >/dev/null 2>&1 || echo "breath.sh: PNG rasterization skipped (headless Chrome unavailable)" >&2
fi

# Regenerate the full Timeline history (a fresh deterministic replay from
# session 1, not an incremental append — cheap even at hundreds of
# sessions, and self-healing: it can never drift from palimpsest.json since
# history-dump aborts if its replay doesn't land on it exactly).
HISTORY_LOG="$(mktemp)"
"$REPO_DIR/PalimpsestKit/.build/release/history-dump" "$REPO_DIR" "$REPO_DIR/history.json" >"$HISTORY_LOG" 2>&1 || {
  echo "breath.sh: history-dump failed — see $HISTORY_LOG" >&2
  cat "$HISTORY_LOG" >&2
  rm -f "$HISTORY_LOG"
  exit 1
}
rm -f "$HISTORY_LOG"

# Surgical splice: the ghost-strata SVG block, its session-number text, the
# "at a glance" facts, and the embedded Timeline history. The interactive
# board's JS/CSS/controls are untouched.
python3 "$REPO_DIR/splice_ghosts.py" "$REPO_DIR/render.svg" "$REPO_DIR/docs/index.html"

git add palimpsest.json render.svg render.png history.json docs/index.html

if git diff --cached --quiet; then
  echo "breath.sh: session $SESSION produced no file changes — nothing to commit"
  exit 0
fi

git commit -q -m "Breath: advance to session $SESSION"
# HEAD:main rather than plain 'main' — works whether HEAD is a local branch
# (the normal case, run by hand) or detached at a commit (actions/checkout's
# default in CI), pushing whatever HEAD currently points at either way.
git push origin HEAD:main

echo "breath.sh: advanced to session $SESSION and pushed"
