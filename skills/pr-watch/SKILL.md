---
name: pr-watch
description: Unattended CI-and-review watcher for a shipped PR. Delegates watching and triage to a cheap intake agent instead of the host session, and routes each event to the model/effort tier it actually needs. Use right after opening or shipping a PR when nobody should babysit CI or review comments by hand.
---

# /pr-watch — delegate CI + review triage off the host session

Resolve and read `../../harness/loops.env` relative to this `SKILL.md` before
launching intake or a reviewer. Pass the exact `PR_WATCH_LOOP_CAP`,
`PR_WATCH_TIMEOUT_MIN`, `PR_WATCH_POLL_INTERVAL_SEC`, and model values relevant
to each assignment; do not assume the target repository contains this checkout.

For Codex-native receipt mechanics, follow `../route/references/agent-audit.md`.
Use `.agent-runs/pr-watch/$PR` as the explicit `AUDIT_DIR`; record every
returned native ID immediately after spawn with `subagent-start`, terminalize
every observed completion/failure/cancellation/timeout with
`subagent-terminal`, and include `subagent-roster` output in the terminal
report. An abrupt or unobservable runtime loss remains visibly pending until a
later host confirms terminality; do not fabricate an outcome.

Treat the current host session as the requester, not the watcher. The point
is to keep an expensive session out of a polling loop — launch the intake
agent and stop.

## 1 · Launch

Launch one cheap native intake subagent with `$PR` set to the target PR, in the
background, with an addressable name such as `pr-intake-$PR`. In Claude, use
the plugin's `pr-intake` agent. In Codex, launch a fresh built-in default
subagent using `CODEX_PR_INTAKE_MODEL` and `CODEX_PR_INTAKE_EFFORT` and give it
the complete instructions from
`../../agents/pr-intake.md`; do not depend on a globally registered custom
agent. Translate the named Claude tools in that file to the host's native
spawn, messaging, process, and cancellation tools, and use
`CODEX_EXEC_MODEL` instead of Claude's `EXEC_MODEL` for fix workers. Do not
poll CI or review comments yourself from this session.

Immediately after the intake spawn returns, record its returned native/session
ID with `subagent-start`, then send the running intake one immediate
audit-identity handoff containing the exact `AUDIT_DIR`, returned
native/session ID, and attempt number. The initial Codex assignment must tell
intake to wait for this handoff before starting its monitor. After the handoff,
intake owns terminalizing that existing receipt immediately before its
terminal roster/report for normal completion, cap, self-managed timeout, or
failure. If the parent explicitly cancels or interrupts intake, or observes a
launch/runtime failure before the handoff, the parent terminalizes the receipt
when native terminality is confirmed; if terminality cannot be confirmed, keep
the receipt honestly pending until a later host confirms it. Do not fabricate
an outcome for an abrupt or unobservable runtime loss.

The intake subagent needs the `gh-pr-monitor` extension. Install it directly
with `gh extension install aanojima/gh-pr-monitor` when missing. It watches the
PR event-driven instead of hand-rolled polling.

When intake dispatches implementation or repair work, it uses exactly one
implementation worker. The worker assignment contains only the event or
finding, explicit allowed paths, acceptance criteria, smallest relevant focused
checks, literal `TEST_LOOP_CAP=<value>`, and the resolved fix-worker model.
Claude uses the plugin-bundled worker, Codex uses its built-in worker with the
literal `CODEX_EXEC_MODEL=<value>` and `CODEX_EXEC_EFFORT=<value>`, and optional
OpenCode uses its bundled
repo-local worker. Workers may edit only supplied paths and may not delegate,
redesign, commit, push, publish, open a PR, freeze, verify, review, or run
advisories; they run the supplied focused checks and return terminal. Repairs
return to that worker when healthy. After terminality, intake owns candidate
freeze, dedicated verification, identity recheck, advisories, and commit/push.
For worker routes, a verifier command failure or mandatory post-verifier
package identity mismatch invalidates verification and returns to the same
single implementation worker within `TEST_LOOP_CAP`; after that worker returns
terminal, intake refreezes and dispatches a fresh verifier.

Non-writing DIRECT actions stay inline. A DIRECT repository edit uses the
documented trivial host-write exception, then follows the shared core: freeze
the complete diff, run the authoritative command once through exactly one
dedicated read-only verifier, confirm the frozen identity, and run the visible
nonblocking Ponytail/CodeRabbit advisories before committing or pushing. Review
and advisories start only after the authoritative command succeeds and the
frozen package identity is unchanged. It does not spawn a second implementation
worker. A verifier command failure or mandatory post-verifier package identity
mismatch invalidates verification;
either DIRECT failure returns to the same sole host writer under the
documented exception within `TEST_LOOP_CAP`, then refreezes and dispatches a
fresh verifier. Never spawn an implementation worker solely for DIRECT
recovery.

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
`default` subagent, resolving `CODEX_REVIEW_MODEL` and
`CODEX_REVIEW_EFFORT` from `../../harness/loops.env`, never a named or global
reviewer type, with the complete inspection-only lens assignment, and passes
the exact review cap from `../../harness/loops.env`. Claude may use the
plugin-bundled reviewer agents. Before any blocking reviewer is dispatched,
intake rechecks the current
host identity and freezes the complete current PR candidate under the existing
shared freeze/verifier contract. A successful `verified_identity_by_host` entry
for the exact host, frozen package identity, and authoritative command is reused
without rerunning the same command on identical bytes. An absent or stale entry
requires exactly one dedicated read-only verifier; command success and unchanged
host and package identities are required before the mapping is updated and
review starts. Repair, refreeze, reverification, and push each refresh the
mapping; a changed identity invalidates it until verification succeeds again.
Every reviewer receives exactly these semantic inputs: the original user
request or authoritative specification, the approved plan, and the frozen
diff. Never include verifier output or attestation, the verified-identity
mapping, the finding ledger, or repair provenance. Reviewers inspect only their
three inputs; they never edit or run tests, builds, linters, validators, or
other verification commands.

For Codex/default reviewers, resolve `CODEX_REVIEW_MODEL` and
`CODEX_REVIEW_EFFORT` from `../../harness/loops.env`; record each returned ID
immediately after spawn and terminalize it after completion, failure,
cancellation, or timeout using the shared audit commands.

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

At merge, close, cap, or timeout, include the `subagent-roster` table for
`.agent-runs/pr-watch/$PR` in the terminal report. It records requested
dispatch parameters and is not a runtime attestation from the model service.
