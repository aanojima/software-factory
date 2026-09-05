---
name: implement-ticket
description: One command for a single ticket end to end — classify, plan, explore, implement, validate, review, open a PR, then hand off unattended CI/review triage. Accepts free-text, a Linear key (e.g. ENG-1234), or a Linear issue URL. Use when given a ticket/task and asked to just ship it. Not for RALPH/SWARM/CRON/SPEC-shaped work (multi-PR or not yet measurable) — those still go through `/route` directly.
---

# /implement-ticket <ticket> — ticket to mergeable PR, one command

Treat this as `route` + `pr-watch` chained, with one addition: once the PR is
open, hand off immediately instead of stopping.

## 0 · Resolve the ticket

If `$ARGUMENTS` is a Linear key (`[A-Z]{2,10}-\d+`) or a `linear.app` URL,
resolve it before classifying — `route`'s classifier expects task text, and is
documented as zero-external-moving-parts on purpose, so the Linear fetch
happens here, not inside it.

1. Fetch the issue via the `linear` MCP server (`mcp__linear__get_issue` or
   equivalent) — title, description, acceptance criteria, and comments.
2. Pass the resolved title + description + acceptance criteria to `route`'s
   classifier as its task text. Keep the original key/URL alongside it.
3. Carry the key through the rest of the run: reference it in the plan, the
   commit message, and the PR title/description (e.g. "Fixes ENG-1234").
4. Do not post back to Linear automatically. Only comment the PR link on the
   issue if the user explicitly asks for that — it's a write to a shared
   external system, not a default action.

If `$ARGUMENTS` is already plain task text, skip this step — classify it
directly.

## 1 · Classify and follow the route

Follow the `route` skill's steps 1-4 verbatim (classify → announce → log →
follow the route) for the given ticket.

- `DIRECT` / `STANDARD` / `HEAVY` (or an authoritative spec → `implement-spec`):
  continue below once the PR is open.
- `RALPH` / `SWARM` / `CRON` / `SPEC`: stop here and report instead of
  improvising a single-PR shape onto them. These are multi-PR, recurring, or
  not-yet-measurable — hand them to `/route` directly.

`HEAVY` and `risk=high` still hit their human gate inside `route` — this
command does not skip it just because it's one invocation.

## 2 · Open the PR

Whatever the route, the terminal state of step 1 must be an open PR before
moving on. `DIRECT`'s route text only says "commit to a branch" — open the PR
from that branch here if the route itself didn't already.

## 3 · Hand off to unattended triage

Immediately follow the `pr-watch` skill on the PR just opened. Do not poll CI
or review comments from this session afterward — that's `pr-intake`'s job.

## Done condition

This command's job ends when `pr-watch` is launched, not when the PR merges.
Report the PR link and that `pr-intake` is watching it; the human merges.
