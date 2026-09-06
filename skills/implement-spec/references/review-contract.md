# Independent review contract

Reviewers must be read-only and independent of the writer. For an initial
review, give them exactly these semantic inputs: the original user request or authoritative specification, the approved plan, and the frozen diff. The diff is supplied in full. For a later review, give them those same inputs plus the host-owned finding ledger and a repair delta when available. The ledger and repair delta provide context;
they do not replace fresh independent inspection. Do not give reviewers the
writer's private reasoning or a suggested verdict.

The approved plan freezes the supported states and assumptions relevant to the
change. Reviewers assess only requirements supported by the original request or
specification and that approved plan; they must not invent unsupported
requirements.

Review is inspection, not verification. Reviewers must not run tests, builds,
linters, validators, or other verification commands. They assess only these
three supplied inputs and report findings. Verification and its evidence
belong to the preceding workflow step.

## Review convergence

The host keeps a compact finding ledger across rounds. Each entry retains a
stable finding identity and root cause, a disposition (`new`, `resolved`,
`unchanged`, `regressed`, `disputed`, or `superseded`), the repair or evidence,
and the primary adjudication. Later reviewer assignments receive that ledger
with the original request or specification, approved plan, frozen full diff,
and repair delta when available.

Later reviews prioritize prior blockers and repaired areas. A new blocker
anywhere must provide all four parts of the concrete blocker bar: a concrete supported precondition, a directly violated acceptance criterion or invariant,
material impact, and the minimum fix. The host adjudicates speculative,
out-of-scope, or style items as residual or nonblocking instead of
automatically repairing them.

## Required review lenses

1. **Goal correctness:** does the resulting behavior satisfy every acceptance criterion?
2. **Plan conformance:** does the diff implement the approved approach, or clearly justify deviations?
3. **Correctness and regressions:** edge cases, error paths, concurrency, compatibility, data handling.
4. **Maintainability:** fit with repository patterns and unnecessary complexity.
5. **Risk-specific concerns:** security, privacy, financial correctness, migrations, performance, or operations as applicable.

## Output

Write JSON conforming to `schemas/review.schema.json`. Blocking findings must identify affected files or criteria and explain what evidence would close them. Minor findings must not be used to block completion.

An approval means no known blocking defect remains; it does not mean the reviewer prefers every implementation choice.
