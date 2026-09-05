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

If the task explicitly asks to implement an existing authoritative specification,
load and follow the `implement-spec` skill instead of generating or reinterpreting
requirements. Preserve the spec path as the goal contract.

## 1 · Classify (Stage 1)

Apply the classifier criteria below to the task and produce the JSON decision
`{route, tier, risk, why}`. Reason it yourself — you are already a capable
model; you do not need to shell out.

!`cat ${CLAUDE_PLUGIN_ROOT}/skills/route/classifier.md`

## 2 · Announce

State the decision plainly to the user before doing anything else:

    route=<ROUTE> tier=<TIER> risk=<RISK> — <why>

If `risk=high`, add: "risk=high → human plan approval and cross-model review
are mandatory regardless of route." Do not proceed past a human gate without
explicit approval.

## 3 · Log

Append one line to `.claude/routing-log.md` in the v2 schema (fields you can't
know yet stay `-`, outcome starts `pending`):

    <date> | <task ≤60ch> | <route> | <tier>/<risk> | - | - | - | - | pending

## 4 · Follow the route

- **DIRECT** — Implement directly (from a branch, never push to main), then
  follow `references/implement-and-verify.md`'s core + its T0/DIRECT gate.
  Keep it tight; this is a one-shot.
- **STANDARD** — If the plan depends on unknowns (existing patterns, whether
  something already handles this), delegate exploration to `repo-explorer`
  first rather than guessing. Draft a short plan (one-liner for T1, plan mode
  for T2), implement on the cheap executor, then follow
  `references/implement-and-verify.md`'s core + its T1/STANDARD gate.
- **HEAVY** — Human gates are in force. Delegate exploration to `repo-explorer`.
  Grill the task to a crisp spec, plan at high effort, get a cross-family
  critic on the plan (`harness/review.sh`, GPT-6 Astra by default — cap
  `PLAN_LOOP_CAP_T2`), and **stop for human approval**. Only then implement,
  and follow `references/implement-and-verify.md`'s core + its T2/HEAVY gate
  — the human signs the final diff and merges. Never push to main.
- **RALPH** — Write `tasks/prd.md` plus one spec file per unit in
  `tasks/todo/`, then hand off to the capped loop (`harness/ralph.sh`). Do not
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
