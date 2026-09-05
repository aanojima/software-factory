# Review panel — composition by tier

Reuses the lens and output conventions in
`../../implement-spec/references/review-contract.md`: reviewers are
read-only and independent of the writer, get the plan/diff/validation
evidence but not the writer's private reasoning, and minor findings never
block completion.

## Blocking (correctness/security — count toward the review loop cap)

- `conformance-reviewer` — always, fixed. Goal correctness, plan conformance,
  regressions, evidence quality. This is the one baseline lens every route
  above T0 gets regardless of what the task is.
- Every other `*-reviewer` agent is auto-included by matching the task/diff
  against its frontmatter `description:` — not a fixed name list here. Adding
  a new specialized reviewer (say `privacy-reviewer`) means writing that
  agent file with a description stating what it covers; nothing in this file
  or `/route`/`pr-intake` needs an edit for it to start being selected.
  Currently installed, as concrete examples of the pattern:
  - `security-reviewer` — description covers auth, security, payments, money,
    privacy, data integrity (see `risk-policy.md`'s risk=high criteria — they
    line up because this already covers financial correctness, so a separate
    financial reviewer would be redundant).
  - `adversarial-reviewer` — description covers risk=high or tier=T2 work,
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
- **T1 (STANDARD):** `conformance-reviewer` (blocking) added to the advisory
  pass.
- **T2 or risk=high (HEAVY):** all of the above, plus every other
  `*-reviewer` agent whose description matches this task (currently
  `security-reviewer` and/or `adversarial-reviewer`, but not limited to
  those two as more get added).

## Who else reads this file

`pr-intake`'s HEAVY/risk=high escalation (`../../../agents/pr-intake.md`)
uses the same selection rule — `conformance-reviewer` as baseline plus any
`*-reviewer` whose description matches the finding — so a new specialized
reviewer is picked up by both the pre-PR panel and post-PR escalation the
moment its agent file exists, with no change needed in either place.

## Synthesis before the loop decision

One cheap pass reads every reviewer's output, dedupes findings that are the
same root cause reported by more than one reviewer, and separates blocking
from advisory. Only remaining blocking findings count toward the review loop
cap (`REVIEW_LOOP_CAP` for T1, `REVIEW_LOOP_CAP_T2` for T2/HEAVY — both in
`harness/loops.env`). Advisory findings go into the PR description as
non-blocking suggestions; they are never a reason to loop.
