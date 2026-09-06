---
description: Route a task through the harness and carry it out, honoring gates and caps.
argument-hint: [task description]
---
Route the task below through the software-factory and carry it out. The full
methodology is the `route` skill in this plugin — apply it:

Task: $ARGUMENTS

If this task explicitly identifies an existing authoritative specification to
implement, use the `implement-spec` skill and its durable workflow instead of
the generic route workstreams below.

Do this in order:
1. **Classify** the task as `{route, tier, risk}` using the classifier criteria:

   !`cat ${CLAUDE_PLUGIN_ROOT}/skills/route/classifier.md`

2. **Announce** the decision in one line before touching anything:
   `route=… tier=… risk=… — <why>`.
3. **Log** the v2 routing-log line to `.claude/routing-log.md` in the current repo.
4. **Follow** the matching workstream (see the `route` skill for each route).

Hard rules: for **HEAVY** or **risk=high**, produce the plan, obtain native plan
review, and STOP for my approval — do not implement. Never push to main; all
merges via PR + CI. Never modify tests to make them pass. When a loop hits its
cap, stop and report — do not improvise past it.
