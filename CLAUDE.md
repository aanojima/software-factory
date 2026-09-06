# Project rules
1. One task per conversation. Route new tasks through
   `/software-factory:execute` (Claude) or `$route` (Codex).
2. Never edit files under tasks/done/ or eval/golden.jsonl.
3. Never modify test files to make tests pass.
4. All merges go through PR + CI. Never push to main.
5. When a loop hits its cap, stop and report — do not improvise past it.
6. For an authoritative specification, use `/software-factory:implement-spec`
   (Claude) or `$implement-spec` (Codex).
   The host session owns the workflow, plan, risk, gates, integration, and
   final response. Exactly one implementation-worker owns worktree writes for
   implementation and repairs; explorers and reviewers remain read-only.
   The host writes directly only for a genuinely trivial DIRECT change or
   unavailable native delegation, and states why.
7. Use native subagents from the current host by default. Use an external CLI
   bridge only when the user explicitly requests mixed Claude + Codex review.
