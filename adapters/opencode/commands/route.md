---
description: Classify a task and carry it out through the matching workstream
agent: build
argument-hint: [task]
---

Route the following task through this repo's software factory and
carry it out. This prompt is self-contained (OpenCode has no plugin system
for this, so the routing rules are embedded here).

Task: `$ARGUMENTS`

If the task explicitly identifies an existing authoritative specification to
implement, invoke `$implement-spec` and follow that durable workflow instead of
the generic workstreams below.

## 1 · Classify → {route, tier, risk, why}

Pick exactly one route:
- DIRECT   — trivial, mechanical, one obvious way (typos, renames, doc tweaks).
- STANDARD — ordinary feature/fix mirroring an existing pattern; the default.
- HEAVY    — high-stakes or subtle: security, auth, payments, money, data
             integrity, risky migrations, or an unknown-cause bug. Human gates.
- RALPH    — large but repetitive; decomposes into a long list of near-identical,
             independently-verifiable steps done in sequence.
- SWARM    — large work split into ≤5 INDEPENDENT scopes that run in parallel.
- CRON     — a recurring scheduled chore with a clear done-criterion.
- SPEC     — vague/taste-based ("make it faster"); not measurable yet.

tier: T0 trivial · T1 simple · T2 complex/risky · T4 large-scale · `any` (SPEC only).
risk: low (cosmetic) · medium (broad change) · high (auth/security/payments/data,
or unknown root cause). high ALWAYS forces human plan approval + cross-model review.

Disambiguation: RALPH = sequential list; SWARM = parallel independent scopes.
Unknown-cause bug reports are HEAVY + high. If not objectively checkable → SPEC.

## 2 · Announce

State the decision in one line before touching anything:
`route=… tier=… risk=… — <why>`.

## 3 · Log

Append one line to `.claude/routing-log.md` (fields you can't know yet stay `-`):
`<date> | <task ≤60ch> | <route> | <tier>/<risk> | - | - | - | - | pending`

## 4 · Follow the route

Every route below that reaches implementation runs the same core: implement
→ run the same test command CI itself runs (cap `TEST_LOOP_CAP`) → an
advisory pass (`coderabbit` if available + `ponytail-review`, cheap,
non-blocking, never loops). Only what comes before and after that core
differs by route:

- DIRECT   → implement, core, commit to a branch (never main). No blocking
             panel — tests are the gate.
- STANDARD → short plan (delegate exploration to `repo-explorer` first if the
             plan depends on unknowns) → implement, core → `conformance-reviewer`
             blocking (cap `REVIEW_LOOP_CAP`, capped loop back to implement) → PR.
- HEAVY    → delegate exploration to `repo-explorer` → grill to a crisp spec →
             plan at high effort (cap `PLAN_LOOP_CAP_T2`), get a cross-family
             critic (`harness/review.sh`, GPT-6 Astra by default) → STOP for
             human approval → implement, core → `conformance-reviewer` plus
             `security-reviewer`/`adversarial-reviewer` as applicable, blocking
             (cap `REVIEW_LOOP_CAP_T2`; mandatory if any model in the loop is
             Critical-tier for cyber capability — see risk-policy.md) → PR →
             human signs + merges.
- RALPH    → write `tasks/prd.md` + one spec per file in `tasks/todo/`, then run
             the capped loop (`software-factory ralph`).
- SWARM    → decompose into ≤5 independent scopes; run each in its own worktree.
- CRON     → draft a Routine/Action with an explicit done-criterion. No self-loop.
- SPEC     → grind to a testable acceptance criterion, then re-route the PRD.

Everything up to (not through) the PR — resolve a ticket, classify, run the
core, stop at the commit — is also available on its own via the
`stage-ticket` skill, when you want the branch staged but aren't ready to
open the PR yet.

## Hard rules (see AGENTS.md)

Never push to main; all merges via PR + CI; never modify tests to make them
pass; when a loop hits its cap, stop and report; for HEAVY or risk=high, produce
the plan and STOP for human approval — do not implement.
