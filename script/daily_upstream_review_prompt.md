# Daily upstream review — OpenUsage multi-account fork

You are running unattended as a daily check for Jordan's custom OpenUsage build. Work in
`/Users/jordanknibbe/Developer/openusage` (branch `multi-account`, remotes: `upstream` =
robinebers/openusage, `fork` = westline-marketing/openusage). Do NOT commit, rebase, push, or
modify the branch — this job is read-only analysis; the separate 09:30 launchd updater owns the
actual rebase/build.

## Background (stable facts)

- The fork = newest upstream release tag + a multi-account feature commit (per-account
  `CLAUDE_CONFIG_DIR`/`CODEX_HOME` cards for Claude and Codex) + a few `local:` tooling commits.
- Upstream maintainer robinebers is building multi-account natively: see
  `docs/research/account-first-plan.md` on `upstream/main` (6 phases, one PR per phase, shipped
  to the beta channel with soak periods). Phase 0 merged 2026-07-18 (PR #1026).
- Canonical upstream issue: #402 (open, `enhancement`, no `approved` label). Do not suggest
  opening PRs — the maintainer is implementing this himself.
- Endgame: when upstream's Phase 2+ (Claude config-dir discovery) ships in a release and covers
  Jordan's use case, the fork retires and Jordan switches to the official app with the Sparkle
  Early Access (beta) channel enabled.
- State dir for this job: `~/Library/Application Support/openusage-watch/daily-review/` —
  read `last_seen.json` there at the start (contains the upstream/main SHA, newest tag, and #402
  updatedAt from the previous run) and write it back updated at the end. If the file is missing,
  treat everything as new.

## What to check (read-only)

1. `git fetch upstream --tags`, then look at what's new on `upstream/main` since the SHA in
   `last_seen.json` (`git log --oneline <old>..upstream/main`). Flag especially:
   - commits/PRs that are part of the account-first plan (mention which phase they look like),
   - changes to `docs/research/account-first-plan.md` (diff it),
   - any new release tag (stable or `-beta.N`).
2. Check issue #402 with `gh issue view 402 --repo robinebers/openusage` — new comments, label
   changes (call out `approved` specially), state changes.
3. Fork-impact analysis: for the new upstream commits, check which files they touch
   (`git diff --name-only <old>..upstream/main`) and compare against the files the feature
   commit touches (`git show --name-only <feature-commit>` — it's the first non-`local:` commit
   above the base tag). Use `--name-only`, not `--stat` — git truncates long paths in stat
   output and the overlap comparison silently misses files. Overlapping files = likely rebase
   conflicts at the next tagged release; say which files and roughly how hairy it looks (use
   `--stat` after that if line counts help).
4. Local health (cheap checks only, no builds): is the working tree clean, is the installed
   `/Applications/OpenUsage.app` version consistent with the branch base, is the OpenUsage
   process running, and did the last `com.jordanknibbe.openusage-update` launchd run succeed
   (check its log if one exists under `~/Library/Logs` or wherever the plist points).
5. Retirement check: based on the plan doc and shipped tags, has upstream's native multi-account
   reached the point where it covers the fork's use case (multiple Claude/Codex accounts as
   side-by-side cards)? That means Phase 2 (Claude) and/or Phase 5 (Codex) actually shipping in
   a release tag — not just merging to main.

## Output

Write a short report to
`~/Library/Application Support/openusage-watch/daily-review/report-<YYYY-MM-DD>.md` and keep only
the 14 most recent reports. Structure it as:

- **Verdict** (first line, one of):
  - `ALL QUIET` — nothing relevant happened; say so in one sentence.
  - `HEADS-UP` — relevant movement (plan progress, #402 activity, overlapping upstream changes)
    but nothing Jordan must do yet.
  - `ACTION NEEDED` — something requires a decision or a manual session: e.g. a new tag whose
    rebase will conflict, an upstream change that breaks the feature's assumptions, #402 got
    `approved`, or a failed launchd update run.
  - `RETIREMENT CANDIDATE` — a shipped release appears to cover the fork's use case; recommend
    testing the official app and describe what would be lost by switching.
- **What happened** — plain-English bullets with PR/issue numbers and phase names.
- **Fork impact** — which of the fork's files are affected and what to expect at the next rebase.
- **Recommendation** — what, if anything, Jordan should do, in one or two sentences.

Then fire a macOS notification via
`osascript -e 'display notification "<one-line summary>" with title "OpenUsage Upstream Review — <VERDICT>"'`
— always send it, even for ALL QUIET (keep that one to a few words). Finally, update
`last_seen.json`.

Keep the report skimmable — this is read over morning coffee, not a full audit.
