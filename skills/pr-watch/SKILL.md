---
name: pr-watch
description: Unattended CI-and-review watcher for a shipped PR. Delegates watching and triage to a cheap intake agent instead of the host session, and routes each event to the model/effort tier it actually needs. Use right after opening or shipping a PR when nobody should babysit CI or review comments by hand.
---

# /pr-watch — delegate CI + review triage off the host session

Treat the current host session as the requester, not the watcher. The point
is to keep an expensive session out of a polling loop — launch the intake
agent and stop.

## 1 · Launch

Spawn the plugin's `pr-intake` agent (haiku, low effort — see `harness/loops.env`'s
`TRIAGE_MODEL`) with `$PR` set to the target PR, in the background, with an
addressable name (e.g. `pr-intake-$PR`) — required so it can `SendMessage`
you and be messaged back. Do not poll CI or review comments yourself from
this session. `pr-intake` needs the `gh-pr-monitor` extension
(`gh extension install aanojima/gh-pr-monitor`, or run
`SOFTWARE_FACTORY_SYNC=1 harness/install-user.sh` once to install it) — it
watches the PR event-driven via that extension instead of hand-rolled
polling.

## 2 · Let it route

`pr-intake` classifies every CI result, review, and comment (new or edited)
with `references/pr-classifier.md` and acts per the routing table in
`agents/pr-intake.md`:

- trivial → fixed inline by the intake agent itself
- ordinary → dispatched to `$EXEC_MODEL` (sonnet) via a fresh `general-purpose` agent
- contested (a suggestion that's specific but wrong — contradicts a named
  convention) → replied to on the thread, no dispatch
- high-risk / security-shaped → escalated read-only to `conformance-reviewer`
  plus any other `*-reviewer` agent whose description matches the finding,
  then messaged to a human — `pr-intake` keeps running and triaging
  everything else while it waits

## 3 · Check in, don't babysit

`pr-intake` keeps running and messages you (`SendMessage(to: "main", ...)`)
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
