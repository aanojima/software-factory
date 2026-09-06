# Review panel — composition by tier

Reuses the lens and output conventions in
`../../implement-spec/references/review-contract.md`: reviewers are
read-only and independent of the writer. Initial reviews receive exactly these
semantic inputs: the original user request or authoritative specification, the
approved plan, and the frozen full diff. Later reviews also receive the
host-owned finding ledger and a repair delta when available. They do not
receive the writer's private reasoning or a validation task, and minor findings
never block completion. They inspect those supplied inputs and report findings;
they do not run tests, builds, linters, validators, or other verification
commands.

The approved plan freezes the supported states and assumptions relevant to the
change, so reviewers do not invent unsupported requirements. Later reviews
prioritize prior blockers and repaired areas. A new blocker anywhere must give
a concrete supported precondition, a directly violated acceptance criterion or
invariant, material impact, and the minimum fix. The host keeps the compact
finding ledger across rounds and adjudicates speculative, out-of-scope, or
style items as residual or nonblocking. Ledger context never replaces fresh,
independent inspection where required.

Launch reviewers as native subagents of the current host. The names below are
lenses, not required globally registered agent types. Claude may use the
matching agents bundled with the plugin. Codex uses a fresh built-in `default`
subagent at GPT-5.6 Sol/high for each lens, never a named or global reviewer
type, and passes the complete inspection-only assignment below. Reviewers
inspect only the original user request or authoritative specification, the approved plan, and the frozen diff; they never edit or run tests, builds,
linters, validators, or other verification commands. An external CLI bridge is reserved for an explicitly requested
mixed Claude + Codex review; native failure never selects it as a fallback.

## Blocking (correctness/security — count toward the review loop cap)

- **Conformance** — always, fixed. Goal correctness, plan conformance, and
  regressions. This is the one baseline lens every route
  above T0 gets regardless of what the task is.
- Add another lens only when the task or diff matches it:
  - **Security** — covers auth, security, payments, money,
    privacy, data integrity (see `risk-policy.md`'s risk=high criteria — they
    line up because this already covers financial correctness, so a separate
    financial reviewer would be redundant).
  - **Adversarial** — covers risk=high or tier=T2 work,
    with a different lens from the two above: it tries to construct a
    concrete failing input, race, or exploit rather than checking
    conformance. A finding without the concrete breaking input/sequence is
    not a finding.

## Advisory (quality — surfaced, never blocks the loop, runs at every tier)

Advisory reviewers never gate or loop, so tiering them by cost doesn't apply
the way it does to the blocking lenses below — they run before every PR at
every tier, DIRECT included, precisely to catch what they catch *before* CI
and a human reviewer do, instead of after.

- `coderabbit:code-reviewer` — always, if available. Style and bug-pattern
  scan.
- `ponytail:ponytail-review` — always. Near-zero cost even when a diff is too
  small to have anything to simplify.

## By tier

- **T0 (DIRECT):** no blocking panel — tests are the gate — but the advisory
  pass above still runs before the PR opens.
- **T1 (STANDARD):** conformance (blocking) added to the advisory
  pass.
- **T2 or risk=high (HEAVY):** all of the above, plus security and/or
  adversarial lenses when applicable.

## Who else reads this file

`pr-intake`'s HEAVY/risk=high escalation (`../../../agents/pr-intake.md`)
uses the same selection rule: conformance plus each applicable risk lens.

## Synthesis before the loop decision

One cheap pass reads every reviewer's output, dedupes findings that are the
same root cause reported by more than one reviewer, and separates blocking
from advisory. Only remaining blocking findings count toward the review loop
cap (`REVIEW_LOOP_CAP` for T1, `REVIEW_LOOP_CAP_T2` for T2/HEAVY — both in
`harness/loops.env`). Advisory findings go into the PR description as
non-blocking suggestions; they are never a reason to loop.
