# Native subagent audit contract

Use the existing `skills/implement-spec/scripts/run_state.py` helper for every
Codex-native dispatch. The helper accepts an explicit audit directory whether
or not that directory contains `run.json`; use the implement-spec run
directory for specs, `.agent-runs/route/<task-id>` for route and stage-ticket,
and `.agent-runs/pr-watch/$PR` for PR-watch and intake.

Immediately after a native spawn returns, record the returned native agent or
session ID. Do not record a nickname or an ID guessed before spawn:

```sh
python3 <skill-dir>/../implement-spec/scripts/run_state.py subagent-start \
  "$AUDIT_DIR" \
  --role explorer \
  --agent-type explorer \
  --model "$CODEX_EXPLORER_MODEL" \
  --reasoning-effort "$CODEX_EXPLORER_EFFORT" \
  --agent-id "$RETURNED_NATIVE_ID" \
  --attempt 1
```

After the current owner observes an attempt complete, fail, be cancelled, or
time out, terminalize the same identity exactly once:

```sh
python3 <skill-dir>/../implement-spec/scripts/run_state.py subagent-terminal \
  "$AUDIT_DIR" \
  --agent-id "$RETURNED_NATIVE_ID" \
  --attempt 1 \
  --status completed|failed|cancelled|timed_out
```

The helper atomically maintains one `subagents.json` file. Each receipt keeps
the role, requested built-in `agent_type` (`explorer`, `worker`, or `default`),
exact requested `model`, exact requested `reasoning_effort`, returned
`agent_id`, attempt number, start time, terminal time, and terminal status. It
rejects duplicate `(agent_id, attempt)` pairs, terminalization without a
matching start, and re-terminalization.

Resolve `../../harness/loops.env` relative to the plugin skill before dispatch
and pass the exact values for the role being launched:

| Role | Agent type | Model | Effort |
| --- | --- | --- | --- |
| explorer | `explorer` | `CODEX_EXPLORER_MODEL` | `CODEX_EXPLORER_EFFORT` |
| plan critic | `default` | `CODEX_PLAN_CRITIC_MODEL` | `CODEX_PLAN_CRITIC_EFFORT` |
| implementation or repair worker | `worker` | `CODEX_EXEC_MODEL` | `CODEX_EXEC_EFFORT` |
| verifier | `default` | `CODEX_VERIFIER_MODEL` | `CODEX_VERIFIER_EFFORT` |
| blocking reviewer | `default` | `CODEX_REVIEW_MODEL` | `CODEX_REVIEW_EFFORT` |
| Ponytail advisory | `default` with the `ponytail:ponytail-review` skill in its assignment | `CODEX_PONYTAIL_MODEL` | `CODEX_PONYTAIL_EFFORT` |
| PR intake | `default` | `CODEX_PR_INTAKE_MODEL` | `CODEX_PR_INTAKE_EFFORT` |

At the terminal user-visible report, render the same directory with:

```sh
python3 <skill-dir>/../implement-spec/scripts/run_state.py subagent-roster \
  "$AUDIT_DIR"
```

The roster is a dispatch receipt: it proves the requested parameters recorded
by the workflow, not a runtime attestation from the model service.

If the runtime disappears abruptly or its terminality is otherwise
unobservable, leave `status` and `terminal_at` null; `subagent-roster` renders
those fields as `pending`. A later host may terminalize that receipt only after
confirming terminality and knowing the terminal status. Never fabricate a
failure or other outcome.
