# Run artifacts

Use one directory per execution:

```text
.agent-runs/<run-id>/
├── run.json
├── spec.snapshot.md
├── readiness.json
├── exploration/
├── implementation-plan.md
├── decisions.md
├── validation.json
├── reviews/
└── final-summary.md
```

`run.json` is machine state; Markdown files explain human decisions; JSON gate artifacts follow the bundled schemas. Keep `.agent-runs/` ignored by default. Copy selected final plans into version-controlled documentation only when explicitly requested.

Use the state helper to enforce transitions and gates:

```bash
python3 <skill-dir>/scripts/run_state.py transition <run-dir> readiness
python3 <skill-dir>/scripts/run_state.py transition <run-dir> exploring
python3 <skill-dir>/scripts/run_state.py transition <run-dir> planned
python3 <skill-dir>/scripts/run_state.py set <run-dir> --risk low --writer host
python3 <skill-dir>/scripts/run_state.py transition <run-dir> implementing
```

For high risk, transition to `awaiting_approval`, stop, and run `set --approve` only after explicit human approval. The helper prevents entry into implementation without it and refuses writer reassignment. Run `validate` before the guarded `complete` transition.
