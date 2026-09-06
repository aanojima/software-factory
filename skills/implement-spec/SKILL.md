---
name: implement-spec
description: Execute an authoritative engineering specification through readiness checking, read-only repository exploration, implementation planning, risk-based human gates, a single-writer implementation loop, deterministic validation, independent review, and acceptance-criterion goal verification. Use when asked to implement, execute, or deliver an approved spec or design document; do not use to invent product requirements.
---

# Implement an approved specification

Treat the current host session as the technical lead and workflow orchestrator. Keep product intent in the specification, repository facts in exploration artifacts, implementation decisions in the plan, and execution evidence in the run directory.

Resolve bundled script, reference, and schema paths relative to this `SKILL.md`; do not assume the repository working directory contains them.
Resolve one `CAPS_SOURCE`: `../../harness/loops.env` relative to this `SKILL.md`
for Claude/Codex plugin hosts, or `.opencode/software-factory/loops.env` when
copied to `.agents/skills/` for OpenCode. Read that source once before dispatching
roles and pass the exact relevant `PLAN_LOOP_CAP_T2`, review cap,
`TEST_LOOP_CAP`, and model values in assignments; never ask the target
repository to resolve plugin configuration.

## Establish the run

1. Resolve the repository root and authoritative specification path.
2. Initialize `.agent-runs/<run-id>/` with `scripts/run_state.py init --spec <path> --repo <root>` when the script is available. Otherwise create the equivalent artifact structure from `references/artifacts.md`.
3. Snapshot the original user request or authoritative specification. Never
   silently rewrite the snapshot.
4. Record state changes as the workflow advances.

The current host session is the orchestrator. Subagents report facts or review findings to it; they do not become nested orchestrators.

Use native subagents from the current host by default. Use an external CLI
bridge only when the user explicitly requests mixed Claude + Codex review. If
a native launch fails, stop or retry within the applicable cap; never silently
switch providers.

## Apply the workflow

### 1. Gate implementation readiness

Read `references/spec-readiness.md`. Write `readiness.json` using `schemas/readiness.schema.json`.

- Continue only when intent, acceptance criteria, constraints, and validation are sufficiently explicit.
- Resolve technical uncertainty through exploration.
- Stop and request clarification for product or intent uncertainty.
- Do not expand the specification into a different product decision.

### 2. Delegate read-only exploration

Read `references/exploration-contract.md`. Identify the smallest set of codebase unknowns that can change the implementation approach.

When exploration is needed, launch independent read-only explorers directly
from this host session, in parallel where useful. In Claude, use the plugin's
`repo-explorer`; in Codex, use the built-in `explorer`. Require file/symbol
evidence and prohibit edits. If no
repository unknown can change the approach, record that and skip exploration.
If a native explorer cannot launch, retry once at most and then stop; do not
continue through a sequential or external-provider fallback.

Store findings under `exploration/`. Do not ask explorers to choose the final design.

### 3. Produce the implementation plan and reassess risk

Read `references/implementation-plan.md` and `references/risk-policy.md`. Synthesize the spec and exploration facts into `implementation-plan.md`.

The plan must trace every acceptance criterion to code changes and validation evidence. Classify risk again after discovering the actual affected surfaces:

- `low`: continue autonomously.
- `medium`: continue, explicitly record risks and rollback; surface them in the final report.
- `high`: before requesting human approval, ask a fresh read-only native
  subagent to review the plan against the original user request or authoritative
  specification and exploration evidence. In Codex use GPT-6 Astra at high
  effort; in Claude use a
  high-effort native plan critic. Require approval or concrete blockers; the
  plan reviewer does not need an implementation diff. It must inspect only the
  supplied artifacts without running verification commands. Record its verdict
  and any resolved blockers in `decisions.md`. Revise and obtain a fresh review up
  to `PLAN_LOOP_CAP_T2`; after approval, transition to `awaiting_approval`,
  present the plan and risk summary, and stop until explicit human approval.

### 4. Enforce one writer

The host remains the orchestrator and owns the plan, risk, gates, integration,
and final response. Dispatch exactly one implementation worker for the current
worktree with the specification snapshot, approved plan, acceptance criteria,
explicit allowed paths, focused verification command, and the literal
`TEST_LOOP_CAP=<value>` plus the selected model (`EXEC_MODEL=<value>` for
Claude or `CODEX_EXEC_MODEL=<value>` for Codex) resolved from
the resolved `CAPS_SOURCE`. Claude uses the plugin-bundled
`implementation-worker`; Codex uses its built-in worker subagent; optional
OpenCode uses the bundled repo-local implementation worker.

The worker may read, edit only the allowed paths, and run focused verification.
It may not redesign scope, delegate, commit, push, publish, or open a PR.
Repairs return to the same healthy implementation worker and only one writer
may be active at a time. Explorers and reviewers remain read-only. The host
may write only for a genuinely trivial DIRECT change or when native delegation
is unavailable, and must state the reason. Preserve unrelated user changes.

### 5. Validate behavior and the goal

Read `references/goal-validation.md`. Write `validation.json` using
`schemas/validation.schema.json`. Verification is a separate host workflow
step after the worker's focused check; run the repository's deterministic
command with the exact `TEST_LOOP_CAP=<value>` resolved from
the resolved `CAPS_SOURCE`.

Passing tests is necessary but not sufficient. For every acceptance criterion, record status and concrete evidence. Mark `goal_satisfied=true` only when every required criterion passes and no material regression remains.

### 6. Obtain independent review

Read `references/review-contract.md`. Launch read-only reviewers only after
the verification step completes. Treat conformance, security, and adversarial
review as lens assignments rather than required custom agent names. Claude may
use the matching plugin agents. Codex must use a fresh built-in `default`
subagent at GPT-5.6 Sol/high for each lens, never a named or global reviewer
type, with the complete inspection-only lens assignment. Always assign
conformance and add security when the risk policy calls for it.

Every reviewer receives exactly these semantic inputs: the original user request or authoritative specification, the approved plan, and the frozen diff—not the writer's private reasoning or a validation task. Their
assignment must prohibit running tests, builds, linters, validators, or other
verification commands; they inspect those three inputs and report findings
only. Pass the exact
review cap value from the resolved `CAPS_SOURCE`; Codex/default reviewers use
GPT-5.6 Sol/high, while Claude may use the matching plugin reviewer.
Store each response in `reviews/` using `schemas/review.schema.json`.

If blocking findings exist, return to the single writer, fix, revalidate, and obtain a fresh review. Honor the configured review cap. A repeated identical failure or a cap hit is a stop condition, not permission to weaken tests or reinterpret the spec.

### 7. Complete explicitly

Before completion, run `scripts/run_state.py validate <run-dir>` when available. Complete only when:

- readiness is `ready`;
- the implementation plan exists;
- deterministic checks pass;
- every acceptance criterion passes;
- all required independent reviews approve;
- no human gate is outstanding.

Write `final-summary.md` with the implemented scope, evidence, risks, deviations, and remaining follow-ups. Transition the run to `complete`.

## Hard stops

Stop rather than improvise when:

- the spec lacks determinable product intent;
- acceptance criteria contradict each other;
- high-risk execution lacks approval;
- required credentials, authority, or external state are unavailable;
- a loop cap is hit;
- validation cannot demonstrate the goal.

Never change tests merely to make them pass. Never treat plan conformance alone as proof that the specification was achieved.
