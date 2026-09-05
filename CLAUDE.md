# Project rules
1. One task per conversation. Route new tasks through /execute (or /route).
2. Never edit files under tasks/done/ or eval/golden.jsonl.
3. Never modify test files to make tests pass.
4. All merges go through PR + CI. Never push to main.
5. When a loop hits its cap, stop and report — do not improvise past it.
6. For an authoritative specification, use `/software-factory:implement-spec`.
   The host session owns the workflow and exactly one writer; explorers and
   reviewers remain read-only.
