---
description: Implement an authoritative specification through guarded exploration, planning, validation, and review.
argument-hint: [path/to/spec.md]
---

Use the `implement-spec` skill to implement the authoritative specification at:

`$ARGUMENTS`

The current session orchestrates the workflow and dispatches the plugin-bundled implementation-worker for implementation and repairs. The worker runs only
the smallest relevant focused checks while editing. After all writers are
terminal, freeze the complete candidate and dispatch exactly one bundled
`verification-agent` with the frozen package identity, `cwd`, exact authoritative
verification command (including integration and acceptance checks), acceptance
criteria, and `TEST_LOOP_CAP=<value>`. The verifier runs that command once and
reports command/result evidence; the host confirms the candidate identity is
unchanged afterward and does not rerun the same command on identical bytes. A
verifier command failure or mandatory post-verifier package identity mismatch
invalidates verification. For worker routes, return to the single
implementation worker within `TEST_LOOP_CAP`; after repair, refreeze and get a
fresh verifier. For a trivial DIRECT host edit, return to the same sole host
writer under the documented DIRECT exception within `TEST_LOOP_CAP`, then
refreeze and get a fresh verifier; never spawn an implementation worker solely
for DIRECT recovery. Review starts only after authoritative verification
passes: the command succeeded and the frozen package identity is unchanged;
run inspection-only review and the existing advisory pass only after that
gate. The host may write only for the documented genuinely trivial DIRECT
change. A native implementation-worker launch failure retries or stops within
`TEST_LOOP_CAP`; it never falls back to host implementation or another
provider. Use native read-only subagents for
exploration, conformance review, and risk-specific review as required. Preserve
durable artifacts under `.agent-runs/` and honor every stop condition in the
skill. This worker is the only writer during implementation and repair turns.
