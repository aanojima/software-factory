# AGENTS.md — instructions for Codex (and other agents that read this file)

This repo is a **software factory**: a router + loop system that
classifies each task and runs it through the right workstream. Claude Code reads
`CLAUDE.md`; Codex reads this file. Keep the two in sync.

## Project rules (identical to CLAUDE.md)
1. One task per conversation. Route new tasks through `/execute` (or `/route`).
2. Never edit files under `tasks/done/` or `eval/golden.jsonl`.
3. Never modify test files to make tests pass.
4. All merges go through PR + CI. Never push to main.
5. When a loop hits its cap, stop and report — do not improvise past it.
6. For an authoritative specification, use `/software-factory:implement-spec`.
   The host session owns the workflow and exactly one writer; explorers and
   reviewers remain read-only.

## Running a task
- In a Codex session, type `/execute <task>` (self-contained prompt in
  `.codex/prompts/execute.md`) — or just tell me to "execute" the task.
- For an authoritative specification, use `$implement-spec Implement <spec>` or
  `software-factory implement <spec> --runtime codex`. The host session owns the
  workflow and exactly one writer; explorers and reviewers stay read-only.
- The methodology (classify → announce → log → follow the route) is embedded in
  that prompt. In Claude Code it's the `route` skill and `commands/execute.md`,
  shipped by the plugin. Caps and model tiers are in `harness/loops.env`.

## Gates
- **HEAVY** or **risk=high** → produce the plan and STOP for human approval. Do
  not implement past the gate.
- When acting as the reviewer (the other family — GPT-6 Astra by default for
  HEAVY, via `harness/review.sh`), judge **conformance to the approved plan
  and original acceptance criteria**, not taste. Return JSON that conforms to
  `skills/implement-spec/schemas/review.schema.json`.
