# Independent review contract

Reviewers must be read-only and independent of the writer. Give them the spec snapshot, plan, diff, and validation evidence. Do not give them the writer's private reasoning or a suggested verdict.

## Required review lenses

1. **Goal correctness:** does the resulting behavior satisfy every acceptance criterion?
2. **Plan conformance:** does the diff implement the approved approach, or clearly justify deviations?
3. **Correctness and regressions:** edge cases, error paths, concurrency, compatibility, data handling.
4. **Maintainability:** fit with repository patterns and unnecessary complexity.
5. **Risk-specific concerns:** security, privacy, financial correctness, migrations, performance, or operations as applicable.
6. **Evidence quality:** are tests and other checks sufficient to prove the claims?

## Output

Write JSON conforming to `schemas/review.schema.json`. Blocking findings must identify affected files or criteria and explain what evidence would close them. Minor findings must not be used to block completion.

An approval means no known blocking defect remains; it does not mean the reviewer prefers every implementation choice.
