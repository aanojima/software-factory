---
name: implement-spec
description: Execute an authoritative engineering specification through readiness checking, read-only repository exploration, implementation planning, risk-based human gates, a single-writer implementation loop, deterministic validation, independent review, and acceptance-criterion goal verification. Use when asked to implement, execute, or deliver an approved spec or design document; do not use to invent product requirements.
---

# Implement an approved specification

Treat the current host session as the technical lead and workflow orchestrator. Keep product intent in the specification, repository facts in exploration artifacts, implementation decisions in the plan, and execution evidence in the run directory.

Resolve bundled script, reference, and schema paths relative to this `SKILL.md`; do not assume the repository working directory contains them.

## Establish the run

1. Resolve the repository root and authoritative specification path.
2. Initialize `.agent-runs/<run-id>/` with `scripts/run_state.py init --spec <path> --repo <root>` when the script is available. Otherwise create the equivalent artifact structure from `references/artifacts.md`.
3. Snapshot the specification. Never silently rewrite the snapshot.
4. Record state changes as the workflow advances.

The current host session is the orchestrator. Subagents report facts or review findings to it; they do not become nested orchestrators.

## Apply the workflow

### 1. Gate implementation readiness

Read `references/spec-readiness.md`. Write `readiness.json` using `schemas/readiness.schema.json`.

- Continue only when intent, acceptance criteria, constraints, and validation are sufficiently explicit.
- Resolve technical uncertainty through exploration.
- Stop and request clarification for product or intent uncertainty.
- Do not expand the specification into a different product decision.

### 2. Delegate read-only exploration

Read `references/exploration-contract.md`. Identify the smallest set of codebase unknowns that can change the implementation approach.

When native subagents are available, launch independent read-only explorers directly from this host session, in parallel where useful. Prefer the runtime's `repo-explorer` role. Otherwise explore sequentially. Require file/symbol evidence and prohibit edits.

Store findings under `exploration/`. Do not ask explorers to choose the final design.

### 3. Produce the implementation plan and reassess risk

Read `references/implementation-plan.md` and `references/risk-policy.md`. Synthesize the spec and exploration facts into `implementation-plan.md`.

The plan must trace every acceptance criterion to code changes and validation evidence. Classify risk again after discovering the actual affected surfaces:

- `low`: continue autonomously.
- `medium`: continue, explicitly record risks and rollback; surface them in the final report.
- `high`: transition to `awaiting_approval`, present the plan and risk summary, and stop until explicit human approval.

### 4. Enforce one writer

Designate exactly one writer for the current worktree. By default, the host session is the writer.

- Explorers and reviewers remain read-only.
- Do not let multiple agents edit the same worktree concurrently.
- If parallel implementation is necessary, use a separate workflow with non-overlapping worktrees and explicit integration ownership.

Implement the smallest correct change that satisfies the approved plan. Preserve unrelated user changes. Run relevant deterministic checks after each meaningful increment.

### 5. Validate behavior and the goal

Read `references/goal-validation.md`. Write `validation.json` using `schemas/validation.schema.json`.

Passing tests is necessary but not sufficient. For every acceptance criterion, record status and concrete evidence. Mark `goal_satisfied=true` only when every required criterion passes and no material regression remains.

### 6. Obtain independent review

Read `references/review-contract.md`. Launch read-only reviewers only after implementation evidence exists. Prefer the runtime's `conformance-reviewer`; add `security-reviewer` when the risk policy calls for it.

Reviewers receive the spec snapshot, implementation plan, diff, and validation evidence—not the writer's private reasoning. Store each response in `reviews/` using `schemas/review.schema.json`.

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
