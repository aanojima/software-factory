---
name: stage-ticket
description: Resolve a ticket (free text, a Linear key, or a Linear URL), classify it, implement, verify, and get it to a tested, reviewed-enough commit pushed to a branch — then stop. No PR opens, nothing watches CI afterward; that's a separate, deliberate step you take when ready. Portable — works the same in Claude Code, Codex, and OpenCode. Not for RALPH/SWARM/CRON/SPEC-shaped work — those still need the route skill directly.
---

# /stage-ticket <ticket> — ticket to a staged commit, nothing further

Resolve one `CAPS_SOURCE`: `../../harness/loops.env` relative to this `SKILL.md`
for Claude/Codex plugin hosts, or `.opencode/software-factory/loops.env` when
copied to `.agents/skills/` for OpenCode. Read that source once before dispatching
a role and pass its exact relevant cap and model values in every assignment.

Everything `implement-ticket` does, minus opening the PR and everything
after it. Use this when the code should be ready and sitting on a branch,
but opening the PR (and whatever watches it afterward) is a separate call
you're not ready to make yet — or on a runtime with no automated
post-PR triage to hand off to.

## 0 · Resolve the ticket

If the input is a Linear key (`[A-Z]{2,10}-\d+`) or a `linear.app` URL,
resolve it first — fetch title, description, acceptance criteria, and
comments (via the `linear` MCP server where available, or by asking for the
info you need). Carry the key through the plan, commit message, and any
notes, but do not post back to Linear unless explicitly asked. If the input
is already plain task text, skip this step.

## 1 · Classify

Produce `{route, tier, risk, why}`:

- **DIRECT** (T0, risk low) — trivial, mechanical, one obvious way (typos,
  renames, doc tweaks).
- **STANDARD** (T1, risk low-medium) — ordinary feature/fix mirroring an
  existing pattern. The default.
- **HEAVY** (T2, risk high) — auth, security, payments, money, data
  integrity, risky migrations, or an unknown-cause bug. Human gates apply.
- **RALPH / SWARM / CRON / SPEC** — stop here and report instead of forcing
  a single-branch shape onto them. These are multi-PR, parallel, recurring,
  or not-yet-measurable; hand them to the full routing methodology instead
  (`/software-factory:route` in Claude Code, `$route` in Codex).

State the decision in one line before touching anything:
`route=<ROUTE> tier=<TIER> risk=<RISK> — <why>`.

## 2 · Follow the route up to (not through) a PR

- **DIRECT**: implement directly on a branch (never main). This is the
  genuinely trivial host-write exception; state that reason. No blocking panel
  — tests are the gate.
- **STANDARD**: if the plan depends on unknowns, delegate exploration to a
  native read-only explorer first rather than guessing. Draft a one-line plan,
  then dispatch exactly one implementation worker with the complete plan,
  allowed paths, focused check, and literal cap/model values.
- **HEAVY**: delegate exploration to a native read-only explorer. Grill the task to a
  crisp spec, plan at high effort, then ask a fresh, read-only native subagent
  to review the plan against the task/spec and exploration evidence. In Codex
  use GPT-6 Astra at high effort; in Claude use a high-effort native plan
  critic. The plan review returns approval or concrete blockers and does not
  require an implementation diff. It inspects only the supplied artifacts and
  does not run verification commands. Honor `PLAN_LOOP_CAP_T2`, then **stop for
  human plan approval** before dispatching the implementation worker.

Use native subagents from the current host throughout this workflow. Use an
external CLI bridge only when the user explicitly requests mixed Claude +
Codex review. A failed native launch stops or retries within the existing cap;
it never silently changes providers.

Then, for every route that reaches this point, run the same core in order:

1. Dispatch exactly one implementation worker for the fix or feature. Claude
   uses the plugin-bundled `implementation-worker`, Codex uses its built-in
   worker with the literal `CODEX_EXEC_MODEL` from the resolved `CAPS_SOURCE`,
   and optional OpenCode uses its bundled repo-local worker. The assignment
   must include the approved plan, explicit allowed paths, acceptance criteria,
   focused verification command, and literal `TEST_LOOP_CAP=<value>` and model
   values. The worker may read, edit allowed paths, and run focused checks, but
   may not redesign, delegate, commit, push, publish, or open a PR. Repairs
   return to the same healthy worker, one writer at a time. The host writes only
   for a genuinely trivial DIRECT change or unavailable native delegation and
   states why.
2. Discover and run the same test command CI itself runs for this repo —
   check the relevant workflow file or the repo's existing test
   scripts/Makefile, don't guess a different one. Capped at `TEST_LOOP_CAP`
   from the resolved `CAPS_SOURCE`.
3. After final verification and freeze, follow the required advisory pass in
   `../implement-spec/references/review-contract.md` before the blocking
   panel. It is inspection-only, cheap, non-blocking, and never loops; that
   shared contract owns the Ponytail and CodeRabbit invocation details and
   visible skip handling.
4. Blocking panel by tier, with a capped loop back to step 1 on any blocking
   finding:
   - DIRECT: none — tests are the gate.
   - STANDARD: the conformance lens (cap `REVIEW_LOOP_CAP`).
   - HEAVY: conformance plus security and/or adversarial lenses, whichever apply to this change (cap
     `REVIEW_LOOP_CAP_T2`) — mandatory if any model in the loop is rated
     Critical-tier for cyber capability (see `risk-policy.md`).
5. Commit to the branch and push it to `origin`. **Stop here.** Push, not a
   PR — the branch should exist remotely (visible to CI, reachable from
   another machine) without inviting review yet. No `gh pr create`, no
   merge, no CI watch — the human opens the PR (or runs
   `implement-ticket`/`pr-watch` where that's available) when ready.

## Hard rules

Never push to `main`. Never modify tests to make them pass. A repeated
identical failure after one fix attempt is a stop condition — report it,
don't retry blindly. When a loop hits its cap, stop and report.
