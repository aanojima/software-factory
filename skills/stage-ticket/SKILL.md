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
  genuinely trivial host-write exception; state that reason. If the mandatory
  post-verifier package identity differs, return to the same sole host writer
  under this exception within `TEST_LOOP_CAP`, then refreeze and dispatch a
  fresh verifier; do not spawn an implementation worker solely for DIRECT
  recovery. No blocking panel — tests are the gate. After the host edit, skip
  worker dispatch and begin at freeze step 2 below.
- **STANDARD**: if the plan depends on unknowns, delegate exploration to a
  native read-only explorer first rather than guessing. Draft a one-line plan,
  then dispatch exactly one implementation worker with the complete plan,
  allowed paths, smallest relevant focused checks, and literal cap/model values.
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

Then run the same completion core in order. Step 1 applies only to STANDARD and
HEAVY; DIRECT begins at step 2 after its host edit.

1. For STANDARD or HEAVY, dispatch exactly one implementation worker for the
   fix or feature. DIRECT never dispatches an implementation worker. Claude
   uses the plugin-bundled `implementation-worker`, Codex uses its built-in
   worker with the literal `CODEX_EXEC_MODEL` from the resolved `CAPS_SOURCE`,
   and optional OpenCode uses its bundled repo-local worker. The assignment
   must include the approved plan, explicit allowed paths, acceptance criteria,
   smallest relevant focused checks, and literal `TEST_LOOP_CAP=<value>` and
   model values. The
   worker may read, edit allowed paths, and run only the smallest relevant
   focused checks while editing; do not use the full suite unless it is the only
   meaningful focused check. It may not redesign, delegate, commit, push,
   publish, or open a PR. Repairs return to the same healthy worker, one writer
   at a time. The host writes only for a genuinely trivial DIRECT change and
   states why. A native implementation-worker launch failure retries or stops
   within `TEST_LOOP_CAP`; it never falls back to host implementation or
   silently switches providers.
2. After all writers are terminal, the host freezes the complete candidate,
   including its immutable base and any untracked files. Resolve the same
   authoritative final command CI uses for this repo, including integration and
   acceptance checks, then dispatch exactly one dedicated verification agent
   with the frozen package identity, `cwd`, exact command, acceptance criteria,
   and `TEST_LOOP_CAP=<value>`. Claude uses the bundled `verification-agent`;
   Codex uses one fresh built-in `default` subagent with the literal
   `CODEX_EXEC_MODEL` value, never a named or global Codex role; optional
   OpenCode uses its bundled repo-local `verification-agent`. The verifier is
   read-only, runs the supplied command once, and reports command/result
   evidence. The host confirms the candidate identity is unchanged afterward
   and does not rerun the same authoritative command on identical bytes. A
   verifier command failure or mandatory post-verifier package identity
   mismatch invalidates verification. For worker routes, return to the single
   implementation worker within `TEST_LOOP_CAP`; after repair, refreeze and
   dispatch a fresh verifier. For a trivial DIRECT host edit, return to the
   same sole host writer under the documented DIRECT exception within
   `TEST_LOOP_CAP`, then refreeze and dispatch a fresh verifier; never spawn
   an implementation worker solely for DIRECT recovery. Review starts only
   after authoritative verification passes: the command succeeded and the
   frozen package identity is unchanged.
3. After the verifier passes and the host confirms the frozen candidate is
   unchanged, follow the required advisory pass in
   `../implement-spec/references/review-contract.md` before the blocking panel.
   It is inspection-only, cheap, non-blocking, and never loops; that shared
   contract owns the Ponytail and CodeRabbit invocation details and visible
   skip handling.
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
