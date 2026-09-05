#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

for file in "$ROOT"/bin/software-factory "$ROOT"/harness/*.sh "$ROOT"/eval/*.sh; do
  bash -n "$file"
done
jq empty "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json"
python3 -m json.tool "$ROOT/skills/implement-spec/schemas/readiness.schema.json" >/dev/null
python3 -m json.tool "$ROOT/skills/implement-spec/schemas/review.schema.json" >/dev/null
python3 -m json.tool "$ROOT/skills/implement-spec/schemas/validation.schema.json" >/dev/null
python3 -m json.tool "$ROOT/skills/pr-watch/schemas/classify.schema.json" >/dev/null
REPO="$TMP/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q
printf '# Feature\n\nGoal: expose health.\n\nAcceptance: GET /health returns 200.\n' > "$REPO/spec.md"
RUN="$(python3 "$ROOT/skills/implement-spec/scripts/run_state.py" init --repo "$REPO" --spec spec.md --run-id test-run)"
[[ -f "$RUN/spec.snapshot.md" && -f "$RUN/run.json" ]]

python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" readiness >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" exploring >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" planned >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" set "$RUN" --risk low --writer host >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" implementing >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" validating >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" reviewing >/dev/null

printf '%s\n' '{"status":"ready","goal":"Expose health","acceptance_criteria":[{"id":"AC-1","text":"GET /health returns 200"}],"constraints":[],"validation_strategy":["test endpoint"],"intent_ambiguities":[],"blocking_questions":[]}' > "$RUN/readiness.json"
printf '# Plan\n\nImplement and test the endpoint.\n' > "$RUN/implementation-plan.md"
printf '%s\n' '{"goal_satisfied":true,"acceptance_criteria":[{"id":"AC-1","status":"passed","evidence":"endpoint test"}],"deterministic_checks":[{"command":"test","status":"passed","evidence":"ok"}],"regressions":[],"limitations":[]}' > "$RUN/validation.json"
printf '%s\n' '{"reviewer":"test","approved":true,"blocking":[],"minor":[],"criteria_coverage":[{"id":"AC-1","status":"satisfied","evidence":"test"}]}' > "$RUN/reviews/correctness.json"
printf '# Summary\n\nGoal and checks passed.\n' > "$RUN/final-summary.md"
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" validate "$RUN" >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$RUN" complete >/dev/null

if python3 "$ROOT/skills/implement-spec/scripts/run_state.py" set "$RUN" --writer other >/dev/null 2>&1; then
  echo "writer reassignment should have failed" >&2
  exit 1
fi

HIGH_RUN="$(python3 "$ROOT/skills/implement-spec/scripts/run_state.py" init --repo "$REPO" --spec spec.md --run-id high-risk)"
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$HIGH_RUN" readiness >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$HIGH_RUN" exploring >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$HIGH_RUN" planned >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" set "$HIGH_RUN" --risk high --writer host >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$HIGH_RUN" awaiting_approval >/dev/null
if python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$HIGH_RUN" implementing >/dev/null 2>&1; then
  echo "unapproved high-risk implementation should have failed" >&2
  exit 1
fi
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" set "$HIGH_RUN" --approve >/dev/null
python3 "$ROOT/skills/implement-spec/scripts/run_state.py" transition "$HIGH_RUN" implementing >/dev/null

TARGET="$TMP/consumer"; mkdir -p "$TARGET"; git -C "$TARGET" init -q
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" init "$TARGET" >/dev/null
[[ -f "$TARGET/.agents/skills/implement-spec/SKILL.md" ]]
[[ -f "$TARGET/.agents/skills/stage-ticket/SKILL.md" ]]
[[ -f "$TARGET/.codex/agents/repo-explorer.toml" ]]
[[ -f "$TARGET/.codex/agents/adversarial-reviewer.toml" ]]
[[ -f "$TARGET/.codex/prompts/stage-ticket.md" ]]
[[ -f "$TARGET/.codex/prompts/pr-watch.md" ]]
[[ -f "$TARGET/.opencode/agents/conformance-reviewer.md" ]]
[[ -f "$TARGET/.opencode/agents/adversarial-reviewer.md" ]]
[[ -f "$TARGET/.opencode/commands/implement-spec.md" ]]
[[ -f "$TARGET/.opencode/commands/stage-ticket.md" ]]
[[ -f "$TARGET/.opencode/commands/route.md" ]]
[[ -f "$TARGET/.opencode/commands/pr-watch.md" ]]
grep -qF '"adversarial-reviewer"' "$TARGET/.codex/config.toml"
grep -qxF '.agent-runs/' "$TARGET/.gitignore"
python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$TARGET/.codex/config.toml"

mkdir -p "$TMP/home"
HOME="$TMP/home" CODEX_HOME="$TMP/home/.codex" SOFTWARE_FACTORY_HOME="$ROOT" \
  "$ROOT/harness/install-user.sh" >/dev/null
[[ -L "$TMP/home/.agents/skills/implement-spec" ]]
[[ -L "$TMP/home/.agents/skills/stage-ticket" ]]
[[ -L "$TMP/home/.claude/skills/implement-spec" ]]
[[ -L "$TMP/home/.claude/skills/stage-ticket" ]]
[[ -L "$TMP/home/.claude/skills/route" ]]
[[ -L "$TMP/home/.claude/skills/pr-watch" ]]
[[ -L "$TMP/home/.claude/skills/implement-ticket" ]]
[[ -L "$TMP/home/.config/opencode/agents/repo-explorer.md" ]]
[[ -L "$TMP/home/.config/opencode/agents/adversarial-reviewer.md" ]]
[[ -L "$TMP/home/.config/opencode/commands/route.md" ]]
[[ -L "$TMP/home/.config/opencode/commands/stage-ticket.md" ]]
python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$TMP/home/.codex/config.toml"
grep -qF '"adversarial-reviewer"' "$TMP/home/.codex/config.toml"

FAKE_BIN="$TMP/bin"; mkdir -p "$FAKE_BIN"
# Preserve variables for expansion by the generated stub runtime.
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@" > "$FAKE_OUTPUT"' > "$FAKE_BIN/claude"
chmod +x "$FAKE_BIN/claude"
FAKE_OUTPUT="$TMP/launcher.args" PATH="$FAKE_BIN:$PATH" SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" \
  "$ROOT/harness/implement.sh" spec.md --runtime claude --headless --run-id launcher-test >/dev/null
grep -qF 'Use the implement-spec skill' "$TMP/launcher.args"
grep -qF '.agent-runs/launcher-test' "$TMP/launcher.args"

SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$TARGET" >/dev/null
[[ "$(grep -c '^\[agents\."repo-explorer"\]' "$TARGET/.codex/config.toml")" -eq 1 ]]

echo "all tests passed"
