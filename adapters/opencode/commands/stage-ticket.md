---
description: Ticket to a staged commit on a branch, stopping before a PR opens
agent: build
---

Load and use the `stage-ticket` skill for the ticket at `$ARGUMENTS`.
Read `.opencode/software-factory/loops.env` first and enforce its named caps.

Remain the parent orchestrator. Delegate bounded factual research to
`repo-explorer`, then dispatch exactly one bundled repo-local
`implementation-worker` with the complete approved assignment, explicit
allowed paths, smallest relevant focused checks, and literal cap/model values resolved from the
`.opencode/software-factory/loops.env`. Repairs return to the same worker, one
writer at a time. Stop once the commit is pushed to its branch — do not open a
PR, that's a separate step.

After all writers are terminal, freeze the complete candidate and dispatch
exactly one bundled repo-local `verification-agent` with the frozen package
identity, `cwd`, exact authoritative verification command (including
integration and acceptance checks), acceptance criteria, and
`TEST_LOOP_CAP=<value>`. It runs that command once and reports command/result
evidence. Confirm the candidate identity is unchanged afterward; do not rerun
the same authoritative command on identical bytes. A verifier command failure
or mandatory post-verifier package identity mismatch invalidates verification.
For worker routes, return to the single implementation worker within
`TEST_LOOP_CAP`; after repair, refreeze and get a fresh verifier. For a
trivial DIRECT host edit, return to the same sole host writer under the
documented DIRECT exception within `TEST_LOOP_CAP`, then refreeze and get a
fresh verifier; never spawn an implementation worker solely for DIRECT
recovery. After verification passes, obtain
independent review from `conformance-reviewer` and, when required,
`security-reviewer` and `adversarial-reviewer`; reviewers are inspection-only.
Give every reviewer exactly these semantic inputs: the original user request or
authoritative specification, the approved plan, and the frozen diff. Reviewers
inspect only those inputs and do not run tests, builds, linters, validators, or
other verification commands. Review starts only after authoritative verification
passes: the command succeeded and the frozen package identity is unchanged.
