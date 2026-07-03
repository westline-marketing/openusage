#!/usr/bin/env bash
set -euo pipefail

# Keeps the local multi-account build current with upstream OpenUsage releases.
#
# Flow: fetch upstream tags -> pick the newest release tag -> rebase the local branch onto it ->
# run the test suite -> rebuild -> reinstall to /Applications -> relaunch. Fails loudly (exit 1 +
# macOS notification) and leaves the tree untouched when the rebase conflicts or tests fail, so an
# unattended run can never half-apply an update; resolve conflicts in a Claude Code session, then
# re-run.
#
# Usage: script/update_custom.sh [--stable] [--check-only]
#   --stable      only follow stable tags (skip -beta.N pre-releases)
#   --check-only  report whether an update is available; change nothing
#
# Designed to run unattended (launchd) or by hand. Requires a clean working tree.

BRANCH="multi-account"
UPSTREAM="upstream"
INSTALL_PATH="/Applications/OpenUsage.app"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STABLE_ONLY=false
CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --stable) STABLE_ONLY=true ;;
    --check-only) CHECK_ONLY=true ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"OpenUsage Custom Build\"" >/dev/null 2>&1 || true
}

fail() {
  echo "ERROR: $1" >&2
  notify "$1"
  exit 1
}

[ "$(git branch --show-current)" = "$BRANCH" ] || fail "not on $BRANCH branch (on '$(git branch --show-current)')"
git diff --quiet && git diff --cached --quiet || fail "working tree is dirty; commit or stash before updating"

echo "==> fetching $UPSTREAM"
git fetch --quiet "$UPSTREAM" --tags

# Newest release tag by creation date; betas ship near-daily, stables occasionally, and "latest"
# means whichever upstream cut most recently.
if $STABLE_ONLY; then
  TARGET="$(git tag -l 'v*' --sort=-creatordate | grep -v -- '-beta' | head -1)"
else
  TARGET="$(git tag -l 'v*' --sort=-creatordate | head -1)"
fi
[ -n "$TARGET" ] || fail "no upstream release tags found"

# The commit our local patches currently sit on: the fork point from upstream's history.
BASE="$(git merge-base HEAD "$UPSTREAM/main")"
TARGET_COMMIT="$(git rev-parse "$TARGET^{commit}")"

if [ "$BASE" = "$TARGET_COMMIT" ]; then
  # Branch is current — but the installed app may still be an older build (e.g. a conflict was
  # resolved by hand in a session and the rebuild never ran). Rebuild + reinstall in that case.
  INSTALLED="$(defaults read "$INSTALL_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo none)"
  if [ "$INSTALLED" = "${TARGET#v}-dev" ]; then
    echo "==> already based on $TARGET and installed ($INSTALLED); nothing to do"
    exit 0
  fi
  echo "==> branch already on $TARGET but installed app is $INSTALLED; rebuilding"
else
  echo "==> update available: $(git describe --tags "$BASE") -> $TARGET"
  if $CHECK_ONLY; then
    notify "Update available: $TARGET (run update_custom.sh)"
    exit 0
  fi

  echo "==> rebasing $BRANCH onto $TARGET"
  if ! git rebase --onto "$TARGET" "$BASE" "$BRANCH"; then
    git rebase --abort
    fail "rebase onto $TARGET conflicts — resolve in a Claude Code session, tree left unchanged"
  fi

  echo "==> running tests"
  if ! swift test >/tmp/openusage-update-tests.log 2>&1; then
    tail -30 /tmp/openusage-update-tests.log >&2
    fail "tests failed after rebasing onto $TARGET (branch left rebased; see /tmp/openusage-update-tests.log)"
  fi
fi

echo "==> building app bundle"
script/build_and_run.sh build

echo "==> installing to $INSTALL_PATH"
/usr/bin/pkill -x OpenUsage >/dev/null 2>&1 || true
rm -rf "$INSTALL_PATH"
/usr/bin/ditto "$ROOT_DIR/dist/OpenUsage.app" "$INSTALL_PATH"
/usr/bin/open -n "$INSTALL_PATH"

echo "==> updated to $TARGET"
notify "Updated to $TARGET and relaunched"
