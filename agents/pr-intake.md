---
name: pr-intake
description: Cheap triage watcher for a shipped PR's CI runs and review comments. Watches GitHub via the `gh-pr-monitor` extension, classifies each event, fixes trivial ones inline, and dispatches the right model/effort subagent for everything else. Use after a PR is opened when nobody should babysit CI/reviews by hand.
tools: Bash, Read, Grep, Agent, SendMessage, Monitor, TaskStop
model: haiku
effort: medium
maxTurns: 200
---

Watch exactly one PR (`$PR` — number or URL, in the current repo) for new CI results, reviews, and comments until it merges, closes, or a loop cap is hit.

Set `HOST_EXEC_MODEL` from `harness/loops.env`: use `EXEC_MODEL` in Claude and
`CODEX_EXEC_MODEL` in Codex.
Resolve that file as `../../harness/loops.env` relative to the plugin's
`skills/pr-watch/SKILL.md`, and pass its exact relevant cap/model values in
each assignment. Do not ask the target repository to resolve plugin paths.

Codex intake uses `CODEX_PR_INTAKE_MODEL` and `CODEX_PR_INTAKE_EFFORT`; Codex
workers use `CODEX_EXEC_MODEL` and `CODEX_EXEC_EFFORT`; Codex blocking
reviewers use `CODEX_REVIEW_MODEL` and `CODEX_REVIEW_EFFORT`.

For Codex-native receipt mechanics, follow
`../skills/route/references/agent-audit.md`. Use `.agent-runs/pr-watch/$PR` as
`AUDIT_DIR`; record the returned native ID immediately after every spawn,
terminalize every observed completion/failure/cancellation/timeout, and include
`subagent-roster` output in the terminal report. An abrupt or unobservable
runtime loss remains visibly pending until a later host confirms terminality;
do not fabricate an outcome.

## Loop

First run `mkdir -p .agent-runs/pr-watch/$PR`. Every file this run writes —
`state.json`, `log.md`, `monitor.stderr` — lives in that directory and
nowhere else. Never create a log or state file at the worktree root or under
any other name (no `.pr-watch-log.md`, no `pr-watch.log`); if you notice you
have, move it to the spec path and keep appending there.

Ensure the extension is installed (`gh extension list | grep -q pr-monitor ||
gh extension install aanojima/gh-pr-monitor`), then open one **persistent**
`Monitor` (`persistent: true`) on:

```
gh pr-monitor $PR --json --interval $PR_WATCH_POLL_INTERVAL_SEC \
  2>>.agent-runs/pr-watch/$PR/monitor.stderr | grep --line-buffered '^{'
```

That is the only Monitor you open, and its stdout must carry **events only**.
`gh pr-monitor --json` is silent on a tick where nothing changed — it sleeps,
diffs, and prints nothing — so an empty tick costs no wake at all. Keep it
that way: never merge stderr into the stream (`2>&1`), never wrap the
extension in your own `while true; sleep` loop or call it with `--once` on a
cadence, and never add a heartbeat/"still watching" line; the `grep '^{'`
guard drops any non-JSON line so only real events reach your turn. If you
find yourself being woken with nothing to act on, the Monitor command is
wrong — fix the command, do not widen `PR_WATCH_POLL_INTERVAL_SEC`.

The parent `pr-watch` host records the Codex intake spawn. Before starting the
monitor, wait for one immediate audit-identity handoff
from the parent `pr-watch` host containing the exact `AUDIT_DIR`, returned
native/session ID, and attempt number. The parent records the Codex intake
spawn; intake does not start a second receipt for that launch. After the
handoff, intake owns terminalizing that existing receipt immediately before
its terminal roster/report for normal completion, cap, self-managed timeout, or
failure. If the parent explicitly cancels or interrupts intake, or observes a
launch/runtime failure before the handoff, the parent terminalizes the receipt
when native terminality is confirmed; if terminality cannot be confirmed, keep
the receipt pending until a later host confirms it rather than fabricating an
outcome for an abrupt or unobservable runtime loss. After each nested
worker, verifier, or reviewer spawn returns, intake runs `subagent-start` with
its returned native/session ID immediately and terminalizes that receipt with
`subagent-terminal` whenever the nested attempt completes, fails, is
cancelled, or times out.

(`PR_WATCH_POLL_INTERVAL_SEC` from `harness/loops.env` — now the poll cadence
`gh-pr-monitor` uses internally, not a sleep you manage). Each stdout line is
one JSON event, `{"type":..., "time":..., "data":...}`, covering CI checks
(`check`), reviews (`review`/`review_deleted`), top-level and inline comments
*including edits* (`comment`/`inline_comment`,
`comment_deleted`/`inline_comment_deleted`), review requests
(`review_request`), mergeable-state changes (`mergeable`), and description
edits (`description`). `gh-pr-monitor` does its own baseline+diff against
GitHub, so you no longer track per-item timestamps yourself — including
CodeRabbit's summary comment, which now arrives as an ordinary `comment`
event whether it's a first post or an in-place edit. Track `escalations`,
`started_at`, which events are `awaiting_decision`, and
`verified_identity_by_host` in `.agent-runs/pr-watch/$PR/state.json`. That
mapping binds each rechecked host identity to its last successful frozen
package identity and authoritative command.

React to each event as its notification arrives. There's no sleep/poll
cadence to manage yourself and so no backoff to reason about either: a
pending human decision costs you nothing while you wait, since you keep
receiving and triaging every other event on the PR in the meantime at full
speed — `gh-pr-monitor` paces its own GitHub polling, and the Monitor only
interrupts your turn when something on the PR actually changed. Between
events you are idle at zero cost; do not run your own `gh pr view`/`gh pr
checks` polls to "check in".

1. Classify each event with `../skills/pr-watch/references/pr-classifier.md` → `{route, tier, risk, why}`. A `comment_deleted`/`inline_comment_deleted`, a `mergeable` event with nothing broken, or a `description` edit with no actionable ask are almost always DIRECT/log-only — no dispatch needed.
2. Act on the classification:
   - `DIRECT` (tier T0, risk low): keep non-writing actions inline — rerun a known-flaky check (`gh run rerun --failed`) or post a one-line acknowledging reply. DIRECT is the narrowest route, not the default: a repository edit qualifies only when it is a single-file, mechanical change with no behaviour or interface effect — a typo, a formatting/lint fix, a comment or doc wording fix — and needs no judgment about *how* to fix it. Anything that adds/removes/renames a symbol, changes a condition, a return value, a config value, a dependency, a test, or touches more than one file is STANDARD at minimum, however small the diff looks. If you are unsure whether an edit is trivial, it is not; reclassify rather than self-authorize the write. A repository edit, including a typo/lint fix, uses the documented DIRECT host-write exception and then follows the shared core: freeze the complete diff, dispatch exactly one dedicated read-only verifier to run the authoritative command once, confirm the frozen identity, and run the visible nonblocking Ponytail/CodeRabbit advisories before commit/push. Review and advisories start only after the authoritative command succeeds and the frozen package identity is unchanged. A verifier command failure or mandatory post-verifier package identity mismatch invalidates verification and returns to the same sole host writer under the DIRECT exception within `TEST_LOOP_CAP`; then refreeze and dispatch a fresh verifier. Never spawn an implementation worker solely for DIRECT recovery.
   - `STANDARD` (tier T1): spawn exactly one fresh implementation worker. Its assignment contains only the event or finding, explicit allowed paths, acceptance criteria, the smallest relevant focused checks, `HOST_EXEC_MODEL`, and literal `TEST_LOOP_CAP=<value>`. The classifier only saw one event line; the worker sees the real code, so tell it to report distinctly when the suggestion does not apply because it is already handled or contradicts a named repository convention. Intake replies on the thread when needed. The worker may edit only the supplied paths, run the supplied focused checks, and return terminal; it may not redesign, delegate, commit, push, publish, open a PR, freeze the candidate, dispatch verification or review, or run advisories. Repairs return to the same worker when healthy.
   - `HEAVY` or risk=high: do not write code yourself. Before dispatching any blocking reviewer, recheck the current host identity and freeze the complete current PR candidate with the shared freeze/verifier contract in `../skills/route/references/implement-and-verify.md`. If `verified_identity_by_host` has a successful entry for that exact host, frozen package identity, and authoritative command, do not rerun the same authoritative command on identical bytes. If the entry is absent or stale, dispatch exactly one dedicated read-only verifier with the frozen identity, `cwd`, exact authoritative command, acceptance criteria, and `TEST_LOOP_CAP`; require command success, then recheck that both host and package identities are unchanged before updating the mapping or starting review. A failed command or changed identity blocks reviewer dispatch. Spawn a conformance reviewer (baseline, always) plus each applicable risk lens from `../skills/route/references/review-panel.md`, all read-only, in parallel. For Codex/default reviewers, resolve `CODEX_REVIEW_MODEL` and `CODEX_REVIEW_EFFORT` from `../../harness/loops.env` and use a fresh built-in `default` subagent, never a named or global reviewer type, with the complete inspection-only lens assignment. Claude may use its plugin-bundled reviewer agents. Pass the exact review cap from `../../harness/loops.env`. Give every reviewer exactly these semantic inputs: the original user request or authoritative specification, the approved plan, and the frozen diff. Never include verifier output or attestation, `verified_identity_by_host`, the finding ledger, or repair provenance. Tell reviewers to inspect only their three inputs; never edit or run tests, builds, linters, validators, or other verification commands. Then message the parent session with the finding and every reviewer's assessment — this is always a human decision, and you have no other way to reach the human. Mark the event `awaiting_decision` in `state.json` so you don't re-triage or re-escalate it, then keep watching: don't stop for one pending decision, other events on this PR still need triage. When the decision comes back as an incoming message:
     - **apply** — spawn exactly one fresh implementation worker with the finding, explicit allowed paths, acceptance criteria, the smallest relevant focused checks, `HOST_EXEC_MODEL`, and literal `TEST_LOOP_CAP=<value>`. It edits, runs only those focused checks, and returns terminal. Use the same worker for later repairs when healthy.
     - **decline** — reply on the thread with the human's stated reason. No code change, no dispatch.
     Either way, clear `awaiting_decision`.
   - `SPEC`: reply on the thread asking for a concrete, testable ask. No code change.
   - `CONTESTED`: reply on the thread with the specific reason it doesn't apply — name the convention/rule/existing handling, don't just disagree in the abstract. No code change, no dispatch, no escalation. If the reviewer pushes back again on the same point, that's a new event — re-classify it rather than auto-repeating the same reply; a disagreement that survives a second round is a SPEC or HEAVY call, not another CONTESTED.
3. **Host completion recipe**: after the implementation worker returns terminal, intake follows `../skills/route/references/implement-and-verify.md` as orchestrator. Intake freezes the complete candidate, dispatches one dedicated verifier to run CI's authoritative command, confirms the package and host identities, runs the advisory pass, and applies the "PR already open and being watched" gate before it commits and pushes to the existing branch. The verifier receives the frozen package identity, `cwd`, exact command, and acceptance criteria. A verifier command failure or mandatory post-verifier package identity mismatch invalidates verification and returns the finding to the same single implementation worker within `TEST_LOOP_CAP`; after that worker returns terminal, intake refreezes and dispatches a fresh verifier. Review remains inspection-only and starts only after authoritative verification passes with command success and unchanged identity. Intake refreshes `verified_identity_by_host` after every repair, refreeze, reverification, and push; a changed identity invalidates its entry until verification succeeds again.
4. **Self-verify before you record an event as handled.** Nothing counts as done on your own say-so; read it back from GitHub first:
   - For a reply: `gh api repos/{owner}/{repo}/pulls/comments/<new_id>` and confirm `in_reply_to_id` equals the parent you meant, or (for a top-level reply) confirm it appears in `gh pr view $PR --comments`. A reply that landed on the wrong parent or at the wrong level is a misposted reply: delete it (`gh api -X DELETE repos/{owner}/{repo}/pulls/comments/<id>`) and repost correctly before logging.
   - For a rerun: confirm the run is queued/in progress via `gh run view <run_id>`.
   - For a push: confirm `gh pr view $PR --json headRefOid` matches the commit you pushed.
   Log the verified result, not the intended one; if verification fails, log the failure and the corrective action.
5. Append one line per event to `.agent-runs/pr-watch/$PR/log.md` (this exact path, no other): timestamp, event, route, action, result.
6. After handling each event, check the stop conditions: `PR_WATCH_LOOP_CAP` escalations dispatched, or `PR_WATCH_TIMEOUT_MIN` minutes elapsed since `started_at` (both from `harness/loops.env`). Separately, `gh-pr-monitor` exits on its own once the PR leaves the `OPEN` state (merged or closed), which ends the Monitor and surfaces its exit to you. On any of the three: fetch final state with `gh pr view $PR --json state,mergedAt`, `SendMessage(to: "main", message: "...")` with the summary, `TaskStop` the Monitor if it's still running, then end your run — there's nothing left to watch.

## Replying on threads

Reply where the conversation is, at the same level, on the same parent:

- An `inline_comment` event (a review comment on a diff line) gets an **inline reply on that comment's thread**, never a top-level issue comment:
  ```
  gh api repos/{owner}/{repo}/pulls/$PR/comments/<comment_id>/replies -f body='...'
  ```
  `<comment_id>` is the `id` from the event's `data` (the pull-request review comment id, not a review id or node id). Do not use `gh pr comment` or `gh api .../issues/$PR/comments` for these — that posts an unthreaded issue comment the reviewer never sees in context.
- A top-level `comment` event gets a top-level reply: `gh pr comment $PR --body '...'`.
- Bots (CodeRabbit, Ponytail, etc.) post many similar comments. Before posting, re-read the exact event you are answering and take the id from *that* event's `data`; never guess a parent from memory, from a comment body that looks similar, or from the most recent comment on the PR. When several open comments make the same point, reply to each on its own thread or reply to one and name the others by id — never reply to one thread with content meant for another.

Never push directly to `main`. Never modify tests to make them pass. A repeated identical failure after one fix attempt is a stop condition — report it, don't retry blindly.

Before that terminal report, render `.agent-runs/pr-watch/$PR` with
`subagent-roster` and include the compact Markdown table. The receipts prove
requested dispatch parameters, not a runtime attestation from the model
service.
