# Specification readiness

Judge whether the specification is safe to implement, not whether it is polished.

## Required information

- A concrete goal describing the desired behavior or outcome.
- Testable acceptance criteria with observable pass conditions.
- Relevant constraints and explicitly preserved behavior.
- A validation strategy capable of demonstrating completion.
- No unresolved contradiction that changes product intent.

Useful but optional inputs include architecture notes, preferred implementation details, rollout guidance, and success metrics.

## Route uncertainty correctly

- **Technical uncertainty:** where code lives, which existing abstraction to extend, test commands, dependency behavior. Mark the spec ready if intent is clear and resolve these questions through exploration.
- **Intent uncertainty:** who receives behavior, which business rule applies, acceptable data loss, authorization semantics, money movement, or user-visible tradeoffs. Mark `needs_clarification` and stop.
- **Contradiction:** incompatible acceptance criteria or constraint conflicts. Mark `rejected` and identify the exact conflict.

Do not invent missing product decisions. A list of files or implementation steps is not a substitute for acceptance criteria.

## Output

Write `readiness.json` conforming to `schemas/readiness.schema.json`. Use stable criterion identifiers such as `AC-1`. When status is not `ready`, provide the minimum blocking questions needed to make it ready.
