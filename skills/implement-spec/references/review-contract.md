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

## Required advisory pass

After final verification succeeds, the host freezes the complete candidate
diff, including its immutable base and any untracked files, and runs this
advisory pass once before launching any blocking reviewer. A repair round
repeats verification and freeze first, then runs one pass for the new frozen
candidate. Both advisories receive the original user request or authoritative
specification, the approved plan, and that same complete frozen diff.

The advisory pass is inspection-only and nonblocking. Findings are recorded
and surfaced as advisory output; they never change verification, select or
replace a correctness/security reviewer, trigger a repair, or extend a loop.

### Ponytail advisory

Launch exactly one fresh native read-only advisory subagent. Its assignment
must apply the installed `ponytail:ponytail-review` skill to the frozen diff
and include the original request or specification and approved plan. The
subagent reports complexity-only findings and must never edit, verify, block,
or loop. Ponytail global mode is distinct from this skill invocation. If the
skill is unavailable, record a visible `SKIPPED` advisory result and continue.

### CodeRabbit CLI advisory

When the `coderabbit` executable is available, invoke the external CLI against
the complete candidate diff with its frozen base and untracked-file handling:

```sh
coderabbit review --agent --base-commit "$FROZEN_BASE_COMMIT" \
  --uncommitted --include-untracked --config "$ADVISORY_CONTEXT_FILE"
```

Before the invocation, create a temporary additional-instructions/context
file outside the repository. It must contain the original request or
specification, the approved plan, and the constraint that the review is
inspection-only: do not edit or run verification commands, and report only
nonblocking advisory findings. Capture the CLI output as advisory evidence.
If the executable is unavailable or the CLI is unauthenticated, record a
visible `SKIPPED` result and continue. Any CLI failure remains advisory and
must never fail, block, retry, or loop the task. CodeRabbit is an external CLI
invocation, not a native subagent or a plugin skill.

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
