---
name: route
description: >-
  Triage-and-dispatch a single engineering task. Classifies the task (route /
  tier / risk), announces the decision, logs it, and then follows the matching
  workstream inline. Use at the start of any new task, or when the user types
  /route <task>. This is Mode A (Level 1) — zero external moving parts.
---

# /route — classify, announce, follow

You are the router for this repo's software factory. When invoked
with a task, do these steps in order.

Resolve bundled references and harness paths relative to this `SKILL.md`; do
not assume the target repository contains a Software Factory checkout.
Before dispatching a role, resolve and read `../../harness/loops.env` relative
to this `SKILL.md`. Pass the exact relevant cap and model values read from that
file in the assignment; do not pass a target-repository path or ask a
subagent to discover plugin configuration.

If the task explicitly asks to implement an existing authoritative specification,
load and follow the `implement-spec` skill instead of generating or reinterpreting
requirements. Preserve the spec path as the goal contract.

## 1 · Classify (Stage 1)

Apply the classifier criteria below to the task and produce the JSON decision
`{route, tier, risk, why}`. Reason it yourself — you are already a capable
model; you do not need to shell out.

Read `classifier.md` next to this `SKILL.md` and apply its routing criteria.

## 2 · Announce

State the decision plainly to the user before doing anything else:

    route=<ROUTE> tier=<TIER> risk=<RISK> — <why>

If `risk=high`, add: "risk=high → human plan approval and independent review
are mandatory regardless of route." Do not proceed past a human gate without
explicit approval.

## 3 · Log

Append one line to `.claude/routing-log.md` in the v2 schema (fields you can't
know yet stay `-`, outcome starts `pending`):

    <date> | <task ≤60ch> | <route> | <tier>/<risk> | - | - | - | - | pending

## 4 · Follow the route

- **DIRECT** — Implement directly (from a branch, never push to main), then
  follow `references/implement-and-verify.md`'s core + its T0/DIRECT gate.
  This is the genuinely trivial host-write exception; say that the host is
  writing directly. Keep it tight; this is a one-shot.
- **STANDARD** — If the plan depends on unknowns (existing patterns, whether
  something already handles this), delegate exploration to a native read-only
  explorer first rather than guessing. Draft a short plan (one-liner for T1, plan mode
  for T2), then dispatch exactly one implementation worker with the complete
  assignment and the resolved `EXEC_MODEL`/`CODEX_EXEC_MODEL` and
  `TEST_LOOP_CAP` values before following
  `references/implement-and-verify.md`'s core + its T1/STANDARD gate.
- **HEAVY** — Human gates are in force. Delegate exploration to a native read-only explorer.
  Grill the task to a crisp spec, plan at high effort, then ask a fresh,
  read-only native subagent to review the plan against the original user
  request or authoritative specification and exploration evidence. In Codex
  use GPT-6 Astra at high effort; in Claude use
  a high-effort native plan critic. A plan review returns approval or concrete
  blockers and does not require an implementation diff. It inspects only the
  supplied artifacts and does not run verification commands. Honor
  `PLAN_LOOP_CAP_T2`, then **stop for human approval**. Only then dispatch
  exactly one implementation worker with the complete approved assignment and
  the resolved model and cap values, then follow
  `references/implement-and-verify.md`'s core + its T2/HEAVY gate — the human
  signs the final diff and merges. Never push to main.

Use native subagents from the current host for exploration, plan review, and
implementation review. Use the bundled external CLI bridge at
`../../harness/review.sh`
only when the user explicitly requests a mixed Claude + Codex review. A native
launch failure must stop or retry within the existing cap; it must not silently
switch providers.

Claude may use the named agents bundled with this plugin. Codex uses its
built-in `explorer` for research and a fresh built-in `default` subagent at
GPT-5.6 Sol/high for each review lens, never a named or global reviewer type.
Give each reviewer the complete inspection-only lens assignment with exactly these semantic inputs: the original user request or authoritative specification, the approved plan, and the frozen diff. Reviewers must inspect
only those inputs; never edit or run tests, builds, linters, validators, or
other verification commands.

Implementation and repair turns have one writer: Claude dispatches the
plugin-bundled `implementation-worker`; Codex dispatches its built-in worker
subagent with the complete assignment and the literal `CODEX_EXEC_MODEL` value
from `../../harness/loops.env`; OpenCode, when enabled, dispatches the bundled
repo-local `.opencode/agents/implementation-worker.md`. The assignment must
list the allowed paths, approved plan, acceptance criteria, focused check, and
literal cap/model values. Workers may read, edit those paths, and run the
focused check, but may not redesign, delegate, commit, push, publish, or open a
PR. Repairs return to the same healthy worker, one writer at a time. The host
may write only for a genuinely trivial DIRECT change or when native delegation
is unavailable, and must state which exception applies.
- **RALPH** — Write `tasks/prd.md` plus one spec file per unit in
  `tasks/todo/`, then hand off to the bundled capped loop at
  `../../harness/ralph.sh`, resolved from this skill directory. Do not
  hand-run the loop past its cap.
- **SWARM** — Decompose into ≤5 independent scopes and run each in its own
  worktree. Keep scopes non-overlapping.
- **CRON** — Draft a Routine/Action with an explicit done-criterion. Do not
  build a self-looping agent.
- **SPEC** — The task isn't measurable yet. Grill it until there's a testable
  acceptance criterion, write it up, then re-route the resulting PRD.

## 5 · Caps are hard stops

Every loop (plan / review / test / ralph) has a cap in `harness/loops.env`.
When a cap is hit, stop and report — do not improvise past it. A repeated
identical failure is a spec defect, not a model failure: fix the spec, don't
retry blindly.

## Ground rules (see CLAUDE.md)

One task per conversation · never edit `tasks/done/` or `eval/golden.jsonl` ·
never modify tests to make them pass · all merges via PR + CI, never push to
main.
