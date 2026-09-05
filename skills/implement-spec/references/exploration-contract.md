# Read-only exploration contract

The host session delegates only questions whose answers can materially change the implementation plan.

## Common explorer scopes

- Repository: relevant code paths, ownership boundaries, existing patterns, dependencies.
- Tests: existing test layers, fixtures, commands, and comparable behavior.
- Architecture: data flow, integrations, persistence, compatibility boundaries.
- Risk: authorization, privacy, money, data integrity, migrations, rollout, rollback.

Use no more explorers than useful independent scopes. Run them in parallel only when their scopes do not depend on each other.

## Required delegation prompt

Provide:

- the authoritative spec path and criterion identifiers;
- one bounded research question;
- repository scope and exclusions;
- an explicit prohibition on edits;
- the required output shape.

## Required explorer output

Return factual findings only:

1. Answer to the assigned question.
2. Evidence: files, symbols, commands, or tests.
3. Existing patterns worth reusing.
4. Risks or unresolved facts.
5. Confidence and limits.

Explorers may describe feasible options but must not select the final design. The host session synthesizes all findings and owns the plan.
