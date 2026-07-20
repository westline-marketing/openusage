#!/usr/bin/env bash
set -euo pipefail

# Daily read-only upstream review: runs Claude Code headless with the prompt in
# script/daily_upstream_review_prompt.md, which diffs upstream/main, checks issue #402,
# does fork-impact analysis, and writes a verdict report + macOS notification.
# Run by launchd daily at 10:00 (~/Library/LaunchAgents/com.jordanknibbe.openusage-daily-review.plist),
# after the 09:30 updater, or by hand. Strictly read-only on the repo.

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

REPO_DIR="/Users/jordanknibbe/Developer/openusage"
PROMPT_FILE="$REPO_DIR/script/daily_upstream_review_prompt.md"
STATE_DIR="$HOME/Library/Application Support/openusage-watch/daily-review"

mkdir -p "$STATE_DIR"
cd "$REPO_DIR"

if claude -p "$(cat "$PROMPT_FILE")" \
    --allowedTools "Bash,Read,Write,Grep,Glob" \
    --max-turns 40; then
  echo "daily review completed $(date '+%Y-%m-%d %H:%M')"
else
  status=$?
  echo "ERROR: claude -p exited with status $status" >&2
  /usr/bin/osascript -e 'display notification "Headless run failed — check /tmp/openusage-daily-review.err.log" with title "OpenUsage Upstream Review — FAILED"' >/dev/null 2>&1 || true
  exit "$status"
fi
