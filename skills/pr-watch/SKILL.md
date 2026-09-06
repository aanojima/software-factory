---
name: pr-watch
description: Unattended CI-and-review watcher for a shipped PR. Delegates watching and triage to a cheap intake agent instead of the host session, and routes each event to the model/effort tier it actually needs. Use right after opening or shipping a PR when nobody should babysit CI or review comments by hand.
---

# /pr-watch — delegate CI + review triage off the host session

Resolve and read `../../harness/loops.env` relative to this `SKILL.md` before
launching intake or a reviewer. Pass the exact `PR_WATCH_LOOP_CAP`,
`PR_WATCH_TIMEOUT_MIN`, `PR_WATCH_POLL_INTERVAL_SEC`, and model values relevant
to each assignment; do not assume the target repository contains this checkout.

Treat the current host session as the requester, not the watcher. The point
is to keep an expensive session out of a polling loop — launch the intake
agent and stop.

## 1 · Launch

Launch one cheap native intake subagent with `$PR` set to the target PR, in the
background, with an addressable name such as `pr-intake-$PR`. In Claude, use
the plugin's `pr-intake` agent. In Codex, launch a fresh built-in default
subagent at low effort and give it the complete instructions from
`../../agents/pr-intake.md`; do not depend on a globally registered custom
agent. Translate the named Claude tools in that file to the host's native
spawn, messaging, process, and cancellation tools, and use
`CODEX_EXEC_MODEL` instead of Claude's `EXEC_MODEL` for fix workers. Do not
poll CI or review comments yourself from this session.

The intake subagent needs the `gh-pr-monitor` extension. Install it directly
with `gh extension install aanojima/gh-pr-monitor` when missing. It watches the
PR event-driven instead of hand-rolled polling.

When intake dispatches implementation or repair work, it uses exactly one
implementation worker with the complete event, diff, allowed paths, focused
check, literal `TEST_LOOP_CAP=<value>`, and the resolved fix-worker model.
Claude uses the plugin-bundled worker, Codex uses its built-in worker with the
literal `CODEX_EXEC_MODEL=<value>`, and optional OpenCode uses its bundled
repo-local worker. Workers may edit only supplied paths and may not delegate,
redesign, commit, push, publish, or open a PR; repairs return to that worker
when healthy.

## 2 · Let it route

`pr-intake` classifies every CI result, review, and comment (new or edited)
with `references/pr-classifier.md` and acts per the routing table in
`agents/pr-intake.md`:

- trivial → fixed inline by the intake agent itself
- ordinary → dispatched to the current host's executor model via a fresh worker
- contested (a suggestion that's specific but wrong — contradicts a named
  convention) → replied to on the thread, no dispatch
- high-risk / security-shaped → escalated to read-only conformance plus each
  applicable risk lens,
  then messaged to a human — `pr-intake` keeps running and triaging
  everything else while it waits

For every HEAVY/high-risk review lens, Codex/default dispatches a fresh built-in
`default` subagent at GPT-5.6 Sol/high, never a named or global reviewer type,
with the complete inspection-only lens assignment, and passes the exact review
cap from `../../harness/loops.env`. Claude may use the plugin-bundled reviewer
  agents. Every reviewer receives exactly these semantic inputs: the original user request or authoritative specification, the approved plan, and the frozen diff. They inspect only those inputs; they never edit or run tests,
  builds, linters, validators, or other verification commands.

## 3 · Check in, don't babysit

The intake subagent keeps running and messages the parent session
whenever it needs something — a `HEAVY`/high-risk decision, or its final
report at merge/close/cap/timeout. Don't poll it on a schedule; you'll hear
from it. It has no other way to reach a human, so treat an incoming message
from it as the actual ask, not a status update to skim.

For a `HEAVY`/high-risk message: relay the finding and the reviewer's
assessment to the user, get their call, then `SendMessage` the decision back
to `pr-intake-$PR` by name. It's still running (it didn't stop to ask, and
keeps triaging everything else on the PR meanwhile) — this is a live
exchange, not a resume. Read `.agent-runs/pr-watch/$PR/log.md` for the full
event history any time.

## Hard stops

- Never let `pr-intake` push to `main` or bypass PR review.
- Never let it modify tests to make them pass.
- A HEAVY/high-risk event is always a human gate — report, don't decide for
  the user.
- A repeated identical CI failure after one fix attempt is a stop condition,
  not permission to retry blindly.
