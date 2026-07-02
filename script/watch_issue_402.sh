#!/usr/bin/env bash
set -euo pipefail

# Watches upstream issue #402 (multi-account support) for movement and raises a macOS
# notification when anything changes: a new comment, a label change (the `approved` label is
# the signal to start splitting feat/multi-account into small PRs), or the issue reopening.
#
# Keeps a JSON snapshot of the last-seen state and compares on each run; first run just
# stores the baseline silently. Run by launchd every 2 hours
# (~/Library/LaunchAgents/com.jordanknibbe.openusage-issue-watch.plist) or by hand.

REPO="robinebers/openusage"
ISSUE=402
STATE_DIR="$HOME/Library/Application Support/openusage-watch"
STATE_FILE="$STATE_DIR/issue-$ISSUE.json"

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"OpenUsage Issue #$ISSUE\"" >/dev/null 2>&1 || true
}

CURRENT="$(gh api "repos/$REPO/issues/$ISSUE" \
  --jq '{state: .state, comments: .comments, labels: [.labels[].name] | sort, updated: .updated_at}')" \
  || { echo "ERROR: gh api failed (network/auth?)" >&2; exit 1; }

mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_FILE" ]; then
  printf '%s\n' "$CURRENT" >"$STATE_FILE"
  echo "baseline stored: $CURRENT"
  exit 0
fi

PREVIOUS="$(cat "$STATE_FILE")"
if [ "$CURRENT" = "$PREVIOUS" ]; then
  echo "no change"
  exit 0
fi

# Describe what moved, most important signal first.
CHANGES=()
prev() { printf '%s' "$PREVIOUS" | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }
curr() { printf '%s' "$CURRENT"  | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }

if curr "['labels']" | grep -q "approved" && ! prev "['labels']" | grep -q "approved"; then
  CHANGES+=("APPROVED label added — time to split the PRs!")
fi
[ "$(curr "['state']")" != "$(prev "['state']")" ] && CHANGES+=("state: $(prev "['state']") -> $(curr "['state']")")
if [ "$(curr "['comments']")" != "$(prev "['comments']")" ]; then
  LATEST="$(gh api "repos/$REPO/issues/$ISSUE/comments?per_page=100" --paginate \
    --jq '.[-1] | "\(.user.login): \(.body[0:80])"' 2>/dev/null | tail -1 || echo "new comment")"
  LATEST="${LATEST:-new comment}"
  CHANGES+=("comment from $LATEST")
fi
[ "$(curr "['labels']")" != "$(prev "['labels']")" ] && CHANGES+=("labels now: $(curr "['labels']")")
[ ${#CHANGES[@]} -eq 0 ] && CHANGES=("updated: $(curr "['updated']")")

printf '%s\n' "$CURRENT" >"$STATE_FILE"
MSG="${CHANGES[*]}"
echo "changed: $MSG"
notify "${MSG:0:200}"
