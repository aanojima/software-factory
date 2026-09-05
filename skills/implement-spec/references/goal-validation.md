# Goal validation

Validate outcomes against the authoritative specification rather than treating a green build as completion.

For every acceptance criterion, record:

- stable identifier and criterion text;
- `passed`, `failed`, or `unverified`;
- evidence such as a test name, command output, inspected behavior, metric, or reconciliation result;
- limitations or environment constraints.

Also record deterministic checks such as unit tests, integration tests, lint, type checks, builds, migration validation, or repository-specific checks.

Set `goal_satisfied=true` only when every required criterion is `passed`, all required checks pass, and no blocking review remains. If a criterion cannot be validated locally, keep it `unverified` and state the external validation or human decision required.
