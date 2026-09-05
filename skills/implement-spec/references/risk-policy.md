# Risk and human-gate policy

Classify risk twice: once from the specification and again after repository exploration.

## Low risk

Examples: localized refactors, tests, documentation, reversible internal changes. Continue autonomously.

## Medium risk

Examples: broad API changes, schema additions with safe migration, dependency upgrades, changes with meaningful rollback cost. Continue while recording blast radius, validation, rollout, and rollback. Highlight them at completion.

## High risk

Require explicit approval before writing when the plan affects:

- money movement, balances, ledger or reconciliation;
- authentication, authorization, secrets, or security boundaries;
- privacy, regulated data, retention, or compliance controls;
- destructive or irreversible migrations;
- customer eligibility, pricing, credit, or other material business decisions;
- production actions or external side effects that are difficult to recover;
- unknown-root-cause failures with material blast radius.

Approval covers the stated intent, approach, blast radius, and rollback—not blanket authority for unrelated changes. If exploration changes any of those materially, gate again.

## Frontier-capability trigger

If any model in the loop (writer or cross-family critic) is rated at the
Critical tier for cyber capability under its lab's own preparedness/
responsible-scaling framework (e.g. GPT-6 Astra, used by default as the
HEAVY cross-family critic — see `harness/review.sh`), treat the change as
high risk and require `adversarial-reviewer` in the panel regardless of the
change's apparent scope. The same capability that makes a model good at
finding and exploiting an unknown flaw is exactly what should worry you
about a flaw it introduces, intentionally or not — the review panel this
policy already convenes for high risk is where that gets caught.
