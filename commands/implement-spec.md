---
description: Implement an authoritative specification through guarded exploration, planning, validation, and review.
argument-hint: [path/to/spec.md]
---

Use the `implement-spec` skill to implement the authoritative specification at:

`$ARGUMENTS`

The current session is the workflow orchestrator and default sole writer. Use the plugin's read-only `repo-explorer`, `conformance-reviewer`, and risk-specific reviewer agents where required. Preserve durable artifacts under `.agent-runs/` and honor every stop condition in the skill.
