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

# Host-native review is the default; the CLI bridge is explicit mixed mode.
grep -qF 'This is a Codex-native flow.' "$ROOT/.codex/prompts/execute.md"
grep -qF 'model `gpt-6-astra`' "$ROOT/.codex/prompts/execute.md"
grep -qF 'only when the user explicitly requests mixed Claude + Codex review' \
  "$ROOT/.codex/prompts/execute.md"
if grep -qF 'harness/review.sh' "$ROOT/.codex/prompts/execute.md"; then
  echo "Codex-native execute prompt must not invoke the external CLI bridge" >&2
  exit 1
fi
grep -qF 'In Codex use GPT-6 Astra at high effort' \
  "$ROOT/skills/implement-spec/SKILL.md"
if grep -qF 'Otherwise explore sequentially' "$ROOT/skills/implement-spec/SKILL.md"; then
  echo "implement-spec must not fall back from native exploration" >&2
  exit 1
fi
grep -qF 'fresh native GPT-6 Astra critic at high effort' \
  "$ROOT/harness/dispatch.sh"
if grep -R -qF 'mixed-provider review' \
  "$ROOT/skills" "$ROOT/.codex/prompts" "$ROOT/adapters"; then
  echo "review mode must name the explicit mixed Claude + Codex exception" >&2
  exit 1
fi
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
grep -qF 'This is a Codex-native flow.' "$TARGET/.codex/prompts/execute.md"
[[ -f "$TARGET/.opencode/agents/conformance-reviewer.md" ]]
[[ -f "$TARGET/.opencode/agents/adversarial-reviewer.md" ]]
[[ -f "$TARGET/.opencode/commands/implement-spec.md" ]]
[[ -f "$TARGET/.opencode/commands/stage-ticket.md" ]]
[[ -f "$TARGET/.opencode/commands/route.md" ]]
[[ -f "$TARGET/.opencode/commands/pr-watch.md" ]]
grep -qF '"adversarial-reviewer"' "$TARGET/.codex/config.toml"
grep -qF 'Use native subagents from the current host' "$TARGET/AGENTS.md"
grep -qF 'GPT-6 Astra plan critic at high effort' "$TARGET/AGENTS.md"
grep -qxF '.agent-runs/' "$TARGET/.gitignore"
python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$TARGET/.codex/config.toml"

mkdir -p "$TMP/home"
HOME="$TMP/home" CODEX_HOME="$TMP/home/.codex" SOFTWARE_FACTORY_HOME="$ROOT" \
  "$ROOT/harness/install-user.sh" >/dev/null
[[ -L "$TMP/home/.claude/skills/implement-spec" ]]
[[ ! -e "$TMP/home/.agents/skills/implement-spec" ]]
[[ ! -e "$TMP/home/.agents/skills/stage-ticket" ]]
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

# Codex-only headless execution uses Codex for triage and enables subagents.
cat > "$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'BEGIN' "$@" 'END' >> "$FAKE_CODEX_LOG"
case "$*" in
  *'Complete exactly this ONE task'*)
    mkdir -p tasks/done
    mv tasks/todo/001.md tasks/done/
    ;;
  *'high-risk batch'*)
    printf '%s\n' '{"route":"RALPH","tier":"T4","risk":"high","why":"fixture"}'
    ;;
  *'split across modules'*)
    printf '%s\n' '{"route":"SWARM","tier":"T4","risk":"medium","why":"fixture"}'
    ;;
  *'You are the triage classifier'*)
    printf '%s\n' '{"route":"STANDARD","tier":"T1","risk":"low","why":"fixture"}'
    ;;
esac
EOF
chmod +x "$FAKE_BIN/codex"
printf '%s\n' '#!/usr/bin/env bash' 'exit 99' > "$FAKE_BIN/claude"
chmod +x "$FAKE_BIN/claude"
FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/execute.sh" 'add a hello helper' >/dev/null
grep -qF -- '--enable' "$TMP/codex.args"
grep -qF 'multi_agent' "$TMP/codex.args"
FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/dispatch.sh" 'split across modules' > "$TMP/codex-swarm.txt"
grep -qF 'SWARM in Codex' "$TMP/codex-swarm.txt"
if grep -qi 'claude' "$TMP/codex-swarm.txt"; then
  echo "Codex-selected SWARM dispatch must not switch providers" >&2
  exit 1
fi
grep -qF 'codex) OUT=' "$ROOT/harness/ralph.sh"
if FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/dispatch.sh" 'high-risk batch' > "$TMP/codex-high-risk.txt"; then
  echo "high-risk dispatch must stop at the approval gate" >&2
  exit 1
fi
grep -qF 'fresh native GPT-6 Astra critic at high effort' "$TMP/codex-high-risk.txt"
if grep -qF 'software-factory ralph' "$TMP/codex-high-risk.txt"; then
  echo "high-risk dispatch must not print route execution guidance" >&2
  exit 1
fi

# An explicit executor beats a conflicting repo default in every shell path.
printf '%s\n' 'AGENTIC_EXECUTOR=claude' > "$REPO/.software-factory.env"
FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/triage.sh" 'add another helper' > "$TMP/codex-triage.json"
grep -qF '"route":"STANDARD"' "$TMP/codex-triage.json"
FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/execute.sh" 'add another helper' >/dev/null
FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/dispatch.sh" 'split across modules' > "$TMP/codex-conflict.txt"
grep -qF 'SWARM in Codex' "$TMP/codex-conflict.txt"
mkdir -p "$REPO/tasks/todo" "$REPO/tasks/done"
printf '%s\n' '# fixture' > "$REPO/tasks/todo/001.md"
FAKE_CODEX_LOG="$TMP/codex.args" PATH="$FAKE_BIN:$PATH" \
  SOFTWARE_FACTORY_HOME="$ROOT" AGENTIC_TARGET="$REPO" AGENTIC_EXECUTOR=codex \
  "$ROOT/harness/ralph.sh" >/dev/null
[[ -f "$REPO/tasks/done/001.md" ]]

SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$TARGET" >/dev/null
[[ "$(grep -c '^\[agents\."repo-explorer"\]' "$TARGET/.codex/config.toml")" -eq 1 ]]

echo "all tests passed"
