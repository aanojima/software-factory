---
description: Synchronous CI/review triage for one open PR (no live background agent on this runtime)
agent: build
argument-hint: [PR number or URL]
---

Run `software-factory pr-watch $ARGUMENTS` (or `harness/pr-watch.sh
$ARGUMENTS` directly) in a terminal and stay attached to it.

This is the OpenCode-side fallback for CI/review triage on an open PR.
Unlike Claude Code's `pr-intake` agent, it has no addressable background
process and no live message-back channel — it runs synchronously until the
PR merges/closes, `PR_WATCH_LOOP_CAP` escalations have fired, or
`PR_WATCH_TIMEOUT_MIN` elapses. A HEAVY/high-risk event prompts you right in
that terminal if it's interactive; otherwise it logs to
`.agent-runs/pr-watch/<PR>/awaiting.md` and moves on rather than blocking
forever.
