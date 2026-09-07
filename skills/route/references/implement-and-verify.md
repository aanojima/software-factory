# Implement, verify, advise — shared core

The same writer → verifier → advisory sequence runs everywhere code gets written
and pushed, whether
that's the first commit before a PR exists (`/route`'s DIRECT/STANDARD/HEAVY)
or a follow-up commit on a PR that's already open and being watched
(`pr-intake`'s STANDARD dispatch and HEAVY apply-decision dispatch). Only the
gate that follows this core differs by context.

Every agent in this core is native to the current host unless the user
explicitly requests mixed Claude + Codex review.

Every implementation review assignment gives the reviewer exactly these semantic inputs: the original user request or authoritative specification, the approved plan, and the frozen diff. Reviewers inspect only those inputs and do
not run tests, builds, linters, validators, or other verification commands.

The owning plugin skill must resolve `../../harness/loops.env` relative to its
own `SKILL.md` before dispatching. Pass the exact values relevant to the turn
in each assignment, including `TEST_LOOP_CAP` and the selected executor model;
Codex implementation workers receive the literal `CODEX_EXEC_MODEL` value.
The target repository is not a source of plugin configuration.

## Core (always, in order)

1. Except for DIRECT, the host dispatches exactly one implementation worker
   with the complete specification or approved plan, explicit allowed paths,
   acceptance criteria, smallest relevant focused checks, and resolved cap/model
   values.
   STANDARD and HEAVY always retain exactly-one-worker semantics. DIRECT uses
   the host-write exception documented in `../SKILL.md` for a genuinely trivial
   change, with the reason recorded.
   Claude uses the plugin-bundled `implementation-worker`, Codex uses its
   built-in worker subagent with `CODEX_EXEC_MODEL`, and optional OpenCode uses
   its bundled repo-local worker. The worker may read, edit allowed paths, and
   run only the smallest relevant focused checks while editing; do not use the
   full suite unless it is the only meaningful focused check. It may not
   redesign, delegate, commit, push, publish, or open a PR. Repairs return to
   the same healthy worker; only one writer is active. The host writes directly
   only for a genuinely trivial DIRECT change and records why. A native
   implementation-worker launch failure retries or stops within
   `TEST_LOOP_CAP`; it never falls back to host implementation or silently
   switches providers.
   For DIRECT, non-writing actions remain inline; a trivial host repository
   edit is the only write; steps 2–3 still run exactly once before any commit or push.
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
   unchanged, run the required advisory pass in
   `../../implement-spec/references/review-contract.md` before any blocking
   panel. It is inspection-only, cheap, non-blocking, and never loops; keep
   the Ponytail and CodeRabbit invocation details in that shared contract.

## Then the gate — depends on context

- **No PR yet, tier T0/DIRECT:** no blocking panel — tests are the gate.
  Open a PR.
- **No PR yet, tier T1/STANDARD:** add the T1 blocking panel
  (`review-panel.md`, cap `REVIEW_LOOP_CAP`) before opening a PR.
- **No PR yet, tier T2/HEAVY:** add the T2 blocking panel (cap
  `REVIEW_LOOP_CAP_T2`), then stop for the human to sign the diff before
  opening a PR — never auto-merged.
- **PR already open and being watched** (`pr-intake` dispatched this): no
  blocking-panel re-run. The PR is already under continuous watch, so
  whatever CI or a reviewer does in reaction to this push arrives as the
  next event `pr-intake` triages — re-running the full panel here would
  duplicate that loop instead of feeding it. Push to the existing branch;
  there's no new PR to open.
