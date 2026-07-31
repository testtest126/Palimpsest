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

# Surgical splice: only the ghost-strata SVG block and its session-number
# text change. The interactive board's JS/CSS/controls are untouched.
python3 "$REPO_DIR/splice_ghosts.py" "$REPO_DIR/render.svg" "$REPO_DIR/docs/index.html"

git add palimpsest.json render.svg render.png docs/index.html

if git diff --cached --quiet; then
  echo "breath.sh: session $SESSION produced no file changes — nothing to commit"
  exit 0
fi

git commit -q -m "Breath: advance to session $SESSION"
git push origin main

echo "breath.sh: advanced to session $SESSION and pushed"
