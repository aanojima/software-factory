#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

for file in "$ROOT"/bin/software-factory "$ROOT"/harness/*.sh "$ROOT"/eval/*.sh; do
  bash -n "$file"
done
jq empty "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json" \
  "$ROOT/.codex-plugin/plugin.json"
VERSION="$(cat "$ROOT/VERSION")"
[[ "$(jq -r .version "$ROOT/.claude-plugin/plugin.json")" == "$VERSION" ]]
[[ "$(jq -r .version "$ROOT/.codex-plugin/plugin.json")" == "$VERSION" ]]
[[ "$(jq -r '.plugins[0].version' "$ROOT/.claude-plugin/marketplace.json")" == "$VERSION" ]]
[[ -f "$ROOT/skills/factory-setup/SKILL.md" ]]
[[ -f "$ROOT/commands/setup.md" ]]
grep -qF 'never create a PATH or' "$ROOT/skills/factory-setup/SKILL.md"
python3 -m json.tool "$ROOT/skills/implement-spec/schemas/readiness.schema.json" >/dev/null
python3 -m json.tool "$ROOT/skills/implement-spec/schemas/review.schema.json" >/dev/null
python3 -m json.tool "$ROOT/skills/implement-spec/schemas/validation.schema.json" >/dev/null
python3 -m json.tool "$ROOT/skills/pr-watch/schemas/classify.schema.json" >/dev/null

# Host-native review is delivered by the plugin; the CLI bridge is explicit mixed mode.
grep -qF 'In Codex' "$ROOT/skills/route/SKILL.md"
grep -qF 'use GPT-6 Astra at high effort' "$ROOT/skills/route/SKILL.md"
grep -qF 'Read `classifier.md` next to this `SKILL.md`' "$ROOT/skills/route/SKILL.md"
grep -qF 'only when the user explicitly requests a mixed Claude + Codex review' \
  "$ROOT/skills/route/SKILL.md"
grep -qF 'built-in `explorer`' "$ROOT/skills/implement-spec/SKILL.md"
grep -qF 'do not depend on a globally registered custom' "$ROOT/skills/pr-watch/SKILL.md"
grep -qF 'CODEX_EXEC_MODEL' "$ROOT/skills/pr-watch/SKILL.md"
grep -qF 'CODEX_EXEC_MODEL' "$ROOT/agents/pr-intake.md"
grep -qF '../../harness/loops.env' "$ROOT/skills/route/SKILL.md"
grep -qF '../../harness/loops.env' "$ROOT/skills/implement-spec/SKILL.md"
grep -qF '../../harness/loops.env' "$ROOT/skills/stage-ticket/SKILL.md"
grep -qF '../../harness/loops.env' "$ROOT/skills/pr-watch/SKILL.md"
grep -qF 'implementation-worker' "$ROOT/skills/route/SKILL.md"
grep -qF 'implementation-worker' "$ROOT/skills/implement-spec/SKILL.md"
for reviewer_doc in \
  "$ROOT/skills/route/SKILL.md" \
  "$ROOT/skills/route/references/review-panel.md" \
  "$ROOT/skills/implement-spec/SKILL.md" \
  "$ROOT/skills/pr-watch/SKILL.md" \
  "$ROOT/agents/pr-intake.md"; do
  grep -qF '`default`' "$reviewer_doc"
  grep -qF 'GPT-5.6 Sol/high' "$reviewer_doc"
done
grep -qF 'never a named or global reviewer type' "$ROOT/skills/route/SKILL.md"
grep -qF 'never edit or run' "$ROOT/skills/route/references/review-panel.md"
grep -qF 'tests, builds,' "$ROOT/skills/route/references/review-panel.md"
grep -qF 'linters, validators' "$ROOT/skills/route/references/review-panel.md"
grep -qF 'plugin-bundled implementation-worker for implementation and repairs' \
  "$ROOT/commands/implement-spec.md"
grep -qF 'only writer for an implementation or repair turn' \
  "$ROOT/agents/implementation-worker.md"
grep -qF 'permission:' "$ROOT/adapters/opencode/agents/implementation-worker.md"
grep -qF 'implementation-worker' "$ROOT/adapters/opencode/commands/route.md"
grep -qF 'In Codex' "$ROOT/skills/implement-spec/SKILL.md"
grep -qF 'use GPT-6 Astra at high effort' \
  < <(tr -s '[:space:]' ' ' < "$ROOT/skills/implement-spec/SKILL.md")
grep -qF 'Review is inspection, not verification.' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'original user request or authoritative specification' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'approved plan, and the frozen diff' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'finding ledger' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'supported states and assumptions' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'concrete supported precondition' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'After final verification succeeds' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'before launching any blocking reviewer' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'fresh native read-only advisory subagent' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'ponytail:ponytail-review' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'complexity-only findings' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'Ponytail global mode is distinct' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'coderabbit review --agent' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF -- '--base-commit' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF -- '--include-untracked' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF -- '--config' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'additional-instructions/context' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'visible `SKIPPED`' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'never fail, block, retry, or loop' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
grep -qF 'not a native subagent or a plugin skill' \
  "$ROOT/skills/implement-spec/references/review-contract.md"
if grep -qF 'coderabbit:code-reviewer' \
  "$ROOT/skills/route/references/review-panel.md"; then
  echo "review panel must not name a CodeRabbit plugin reviewer" >&2
  exit 1
fi
grep -qF 'The advisory pass is defined once' \
  "$ROOT/skills/route/references/review-panel.md"
grep -qF 'required advisory pass from' "$ROOT/skills/implement-spec/SKILL.md"
grep -qF 'review-contract.md' \
  "$ROOT/skills/route/references/implement-and-verify.md"
grep -qF 'review-contract.md' "$ROOT/skills/stage-ticket/SKILL.md"
grep -qF 'Except for DIRECT' \
  "$ROOT/skills/route/references/implement-and-verify.md"
grep -qF 'STANDARD and HEAVY always retain exactly-one-worker semantics' \
  "$ROOT/skills/route/references/implement-and-verify.md"
for reviewer in \
  "$ROOT"/agents/{adversarial,conformance,security}-reviewer.md \
  "$ROOT"/adapters/opencode/agents/{adversarial,conformance,security}-reviewer.md; do
  grep -qF 'run tests, builds, linters,' "$reviewer"
done
if grep -qF 'Otherwise explore sequentially' "$ROOT/skills/implement-spec/SKILL.md"; then
  echo "implement-spec must not fall back from native exploration" >&2
  exit 1
fi
grep -qF 'fresh native GPT-6 Astra critic at high effort' \
  "$ROOT/harness/dispatch.sh"
if grep -R -qF 'mixed-provider review' "$ROOT/skills" "$ROOT/adapters"; then
  echo "review mode must name the explicit mixed Claude + Codex exception" >&2
  exit 1
fi
if grep -R -Eq 'software-factory (ralph|pr-watch)|harness/pr-watch' "$ROOT/adapters/opencode"; then
  echo "OpenCode adapter must not depend on the checkout CLI" >&2
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
[[ ! -e "$TARGET/.agents/skills/implement-spec" ]]
[[ ! -e "$TARGET/.codex/prompts/execute.md" ]]
[[ ! -e "$TARGET/.codex/agents/repo-explorer.toml" ]]
[[ ! -e "$TARGET/.opencode/commands/route.md" ]]
grep -qF 'Use native subagents from the current host' "$TARGET/AGENTS.md"
grep -qF 'implementation-worker' "$TARGET/AGENTS.md"
grep -qF 'GPT-6 Astra plan critic at high effort' "$TARGET/AGENTS.md"
grep -qF 'software-factory@software-factory' "$TARGET/.claude/settings.json"
grep -qxF '.agent-runs/' "$TARGET/.gitignore"

# Native managed files may be symlinked by a consumer; refresh the target and
# preserve each link rather than replacing it with a generated regular file.
LINK_TARGET="$TMP/symlink-consumer"; mkdir -p "$LINK_TARGET/.claude"; git -C "$LINK_TARGET" init -q
printf '{}\n' > "$TMP/settings-target.json"
printf 'keep agents\n' > "$TMP/agents-target.md"
printf 'keep claude\n' > "$TMP/claude-target.md"
chmod 640 "$TMP/settings-target.json"
ln -s "$TMP/settings-target.json" "$LINK_TARGET/.claude/settings.json"
ln -s "$TMP/agents-target.md" "$LINK_TARGET/AGENTS.md"
ln -s "$TMP/claude-target.md" "$LINK_TARGET/CLAUDE.md"
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$LINK_TARGET" >/dev/null
[[ -L "$LINK_TARGET/.claude/settings.json" && -L "$LINK_TARGET/AGENTS.md" && -L "$LINK_TARGET/CLAUDE.md" ]]
MODE="$(stat -c '%a' "$TMP/settings-target.json" 2>/dev/null || stat -f '%Lp' "$TMP/settings-target.json")"
[[ "$MODE" == 640 ]]
jq -e '.enabledPlugins["software-factory@software-factory"] == true' \
  "$TMP/settings-target.json" >/dev/null
grep -qF 'software-factory' "$TMP/agents-target.md"
grep -qF 'software-factory' "$TMP/claude-target.md"

# A dangling managed-file link is left in place and fails safely.
DANGLING="$TMP/dangling-consumer"; mkdir -p "$DANGLING/.claude"; git -C "$DANGLING" init -q
ln -s "$TMP/no-settings-target.json" "$DANGLING/.claude/settings.json"
if SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$DANGLING" >/dev/null 2>&1; then
  echo "dangling settings link should have failed" >&2
  exit 1
fi
[[ -L "$DANGLING/.claude/settings.json" ]]

# Unsafe AGENTS/CLAUDE destinations fail before settings or legacy cleanup.
for unsafe_name in agents-dangling claude-loop; do
  UNSAFE="$TMP/$unsafe_name"; mkdir -p "$UNSAFE/.claude"; git -C "$UNSAFE" init -q
  printf '%s\n' '{"keep":true}' > "$UNSAFE/.claude/settings.json"
  printf '%s\n' \
    '0.2.0' \
    'plugin:  agentic-harness@agentic-harness' \
    'ref:     main' \
    'stamped: 2026-09-06' \
    'engine:  unknown' \
    > "$UNSAFE/.claude/.agentic-harness-version"
  if [[ "$unsafe_name" == agents-dangling ]]; then
    ln -s "$UNSAFE/missing-agents.md" "$UNSAFE/AGENTS.md"
  else
    ln -s "claude-loop" "$UNSAFE/CLAUDE.md"
    ln -s "CLAUDE.md" "$UNSAFE/claude-loop"
  fi
  cp "$UNSAFE/.claude/settings.json" "$TMP/$unsafe_name.settings.before"
  cp "$UNSAFE/.claude/.agentic-harness-version" "$TMP/$unsafe_name.marker.before"
  if SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$UNSAFE" >/dev/null 2>&1; then
    echo "unsafe $unsafe_name destination should have failed" >&2
    exit 1
  fi
  cmp -s "$UNSAFE/.claude/settings.json" "$TMP/$unsafe_name.settings.before"
  cmp -s "$UNSAFE/.claude/.agentic-harness-version" "$TMP/$unsafe_name.marker.before"
done

UNSAFE_SETTINGS="$TMP/settings-directory"; mkdir -p "$UNSAFE_SETTINGS/.claude/settings.json"; git -C "$UNSAFE_SETTINGS" init -q
if SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$UNSAFE_SETTINGS" >/dev/null 2>&1; then
  echo "directory settings destination should have failed" >&2
  exit 1
fi
[[ -d "$UNSAFE_SETTINGS/.claude/settings.json" ]]

# A source-identical managed file is a successful refresh even when it is not
# present in the historical managed-file manifest.
IDENTICAL_TARGET="$TMP/identical-consumer"; mkdir -p "$IDENTICAL_TARGET/.opencode/agents"; git -C "$IDENTICAL_TARGET" init -q
cp "$ROOT/adapters/opencode/agents/implementation-worker.md" \
  "$IDENTICAL_TARGET/.opencode/agents/implementation-worker.md"
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update --opencode "$IDENTICAL_TARGET" >/dev/null
cmp -s "$ROOT/adapters/opencode/agents/implementation-worker.md" \
  "$IDENTICAL_TARGET/.opencode/agents/implementation-worker.md"

# A source-identical in-target symlink is preserved, while a stale one keeps
# recognized global OpenCode links in place and fails the migration.
OPENCODE_SYMLINK_TARGET="$TMP/opencode-symlink-target"
mkdir -p "$OPENCODE_SYMLINK_TARGET/.opencode/agents" "$OPENCODE_SYMLINK_TARGET/managed"
git -C "$OPENCODE_SYMLINK_TARGET" init -q
cp "$ROOT/adapters/opencode/agents/implementation-worker.md" \
  "$OPENCODE_SYMLINK_TARGET/managed/implementation-worker.md"
ln -s "$OPENCODE_SYMLINK_TARGET/managed/implementation-worker.md" \
  "$OPENCODE_SYMLINK_TARGET/.opencode/agents/implementation-worker.md"
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update --opencode "$OPENCODE_SYMLINK_TARGET" >/dev/null
[[ -L "$OPENCODE_SYMLINK_TARGET/.opencode/agents/implementation-worker.md" ]]
printf 'stale OpenCode target\n' > "$OPENCODE_SYMLINK_TARGET/managed/implementation-worker.md"
OPENCODE_SYMLINK_HOME="$TMP/opencode-symlink-home"
mkdir -p "$OPENCODE_SYMLINK_HOME/.config/opencode/agents"
ln -s "$ROOT/adapters/opencode/agents/implementation-worker.md" \
  "$OPENCODE_SYMLINK_HOME/.config/opencode/agents/implementation-worker.md"
if HOME="$OPENCODE_SYMLINK_HOME" SOFTWARE_FACTORY_HOME="$ROOT" \
  "$ROOT/harness/init.sh" update --opencode "$OPENCODE_SYMLINK_TARGET" \
  > "$TMP/opencode-symlink-stale.log" 2>&1; then
  echo "stale in-target OpenCode symlink should have failed" >&2
  exit 1
fi
grep -qF 'OpenCode migration incomplete' "$TMP/opencode-symlink-stale.log"
[[ -L "$OPENCODE_SYMLINK_TARGET/.opencode/agents/implementation-worker.md" ]]
[[ -L "$OPENCODE_SYMLINK_HOME/.config/opencode/agents/implementation-worker.md" ]]

# A historically managed symlink target upgrades atomically in place while its
# link and mode survive. The fixture uses a temporary manifest entry instead of
# depending on repository history.
HISTORICAL_HOME="$TMP/historical-package"
mkdir -p "$HISTORICAL_HOME/harness"
cp -R "$ROOT/adapters" "$HISTORICAL_HOME/"
cp -R "$ROOT/skills" "$HISTORICAL_HOME/"
cp "$ROOT/VERSION" "$HISTORICAL_HOME/VERSION"
cp "$ROOT/harness/legacy-links.sh" "$HISTORICAL_HOME/harness/legacy-links.sh"
cp "$ROOT/harness/loops.env" "$HISTORICAL_HOME/harness/loops.env"
cp "$ROOT/harness/legacy-managed.sha256" "$HISTORICAL_HOME/harness/legacy-managed.sha256"
printf 'new packaged OpenCode adapter\n' \
  > "$HISTORICAL_HOME/adapters/opencode/agents/implementation-worker.md"
HISTORICAL_HASH="$(printf 'historical OpenCode adapter\n' | shasum -a 256 | awk '{print $1}')"
printf '.opencode/agents/implementation-worker.md\t%s\tfixture:historical\n' \
  "$HISTORICAL_HASH" >> "$HISTORICAL_HOME/harness/legacy-managed.sha256"
HISTORICAL_TARGET="$TMP/historical-symlink-target"
mkdir -p "$HISTORICAL_TARGET/.opencode/agents" "$HISTORICAL_TARGET/managed"
git -C "$HISTORICAL_TARGET" init -q
printf 'historical OpenCode adapter\n' \
  > "$HISTORICAL_TARGET/managed/implementation-worker.md"
chmod 640 "$HISTORICAL_TARGET/managed/implementation-worker.md"
ln -s "$HISTORICAL_TARGET/managed/implementation-worker.md" \
  "$HISTORICAL_TARGET/.opencode/agents/implementation-worker.md"
SOFTWARE_FACTORY_HOME="$HISTORICAL_HOME" "$ROOT/harness/init.sh" \
  update --opencode "$HISTORICAL_TARGET" >/dev/null
[[ -L "$HISTORICAL_TARGET/.opencode/agents/implementation-worker.md" ]]
cmp -s "$HISTORICAL_HOME/adapters/opencode/agents/implementation-worker.md" \
  "$HISTORICAL_TARGET/managed/implementation-worker.md"
MODE="$(stat -c '%a' "$HISTORICAL_TARGET/managed/implementation-worker.md" 2>/dev/null || \
  stat -f '%Lp' "$HISTORICAL_TARGET/managed/implementation-worker.md")"
[[ "$MODE" == 640 ]]

# OpenCode remains an explicit repo-local compatibility option.
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update --opencode "$TARGET" >/dev/null
[[ -f "$TARGET/.agents/skills/implement-spec/SKILL.md" ]]
[[ -f "$TARGET/.agents/skills/stage-ticket/SKILL.md" ]]
[[ -f "$TARGET/.opencode/agents/conformance-reviewer.md" ]]
[[ -f "$TARGET/.opencode/commands/route.md" ]]
[[ -f "$TARGET/.opencode/software-factory/loops.env" ]]
grep -qF 'PLAN_LOOP_CAP_T2=' "$TARGET/.opencode/software-factory/loops.env"
grep -qF '.opencode/software-factory/loops.env' "$TARGET/.agents/skills/implement-spec/SKILL.md"
grep -qF '.opencode/software-factory/loops.env' "$TARGET/.agents/skills/stage-ticket/SKILL.md"
if grep -R -qF 'plugin-relative `../../harness/loops.env`' "$TARGET/.opencode"; then
  echo "generated OpenCode files must use repo-local loop caps" >&2
  exit 1
fi
[[ ! -e "$TARGET/.opencode/commands/pr-watch.md" ]]
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$TARGET" >/dev/null
[[ -f "$TARGET/.agents/skills/implement-spec/SKILL.md" ]]
[[ -f "$TARGET/.opencode/commands/route.md" ]]

# A modified required repo-local OpenCode file fails the migration and keeps
# proven global links in place for a later retry.
OPENCODE_INCOMPLETE_TARGET="$TMP/opencode-incomplete-target"; mkdir -p "$OPENCODE_INCOMPLETE_TARGET"; git -C "$OPENCODE_INCOMPLETE_TARGET" init -q
HOME="$TMP/no-opencode-links" SOFTWARE_FACTORY_HOME="$ROOT" \
  "$ROOT/harness/init.sh" update --opencode "$OPENCODE_INCOMPLETE_TARGET" >/dev/null
printf 'user-modified OpenCode adapter\n' \
  > "$OPENCODE_INCOMPLETE_TARGET/.opencode/agents/implementation-worker.md"
OPENCODE_LINK_HOME="$TMP/opencode-link-home"
mkdir -p "$OPENCODE_LINK_HOME/.config/opencode/agents" \
  "$OPENCODE_LINK_HOME/.config/opencode/commands"
ln -s "$ROOT/adapters/opencode/agents/implementation-worker.md" \
  "$OPENCODE_LINK_HOME/.config/opencode/agents/implementation-worker.md"
ln -s "$ROOT/adapters/opencode/commands/route.md" \
  "$OPENCODE_LINK_HOME/.config/opencode/commands/route.md"
if HOME="$OPENCODE_LINK_HOME" SOFTWARE_FACTORY_HOME="$ROOT" \
  "$ROOT/harness/init.sh" update --opencode "$OPENCODE_INCOMPLETE_TARGET" \
  > "$TMP/opencode-incomplete.log" 2>&1; then
  echo "modified required OpenCode file should have failed" >&2
  exit 1
fi
grep -qF 'OpenCode migration incomplete' "$TMP/opencode-incomplete.log"
[[ -L "$OPENCODE_LINK_HOME/.config/opencode/agents/implementation-worker.md" ]]
[[ -L "$OPENCODE_LINK_HOME/.config/opencode/commands/route.md" ]]

# Global OpenCode fallbacks survive a later project-write failure because
# cleanup is deferred until the complete explicit migration succeeds.
make_global_opencode_links() {
  local home="$1"
  mkdir -p "$home/.config/opencode/agents" "$home/.config/opencode/commands"
  ln -s "$ROOT/adapters/opencode/agents/implementation-worker.md" \
    "$home/.config/opencode/agents/implementation-worker.md"
  ln -s "$ROOT/adapters/opencode/commands/route.md" \
    "$home/.config/opencode/commands/route.md"
}
DEFERRED_HOME="$TMP/deferred-opencode-home"
DEFERRED_TARGET="$TMP/deferred-opencode-target"
mkdir -p "$DEFERRED_TARGET" "$DEFERRED_TARGET/.gitignore"
git -C "$DEFERRED_TARGET" init -q
make_global_opencode_links "$DEFERRED_HOME"
if HOME="$DEFERRED_HOME" SOFTWARE_FACTORY_HOME="$ROOT" \
  "$ROOT/harness/init.sh" update --opencode "$DEFERRED_TARGET" \
  > "$TMP/deferred-opencode.log" 2>&1; then
  echo "unsafe .gitignore destination should have failed" >&2
  exit 1
fi
[[ -L "$DEFERRED_HOME/.config/opencode/agents/implementation-worker.md" ]]
[[ -L "$DEFERRED_HOME/.config/opencode/commands/route.md" ]]
[[ ! -e "$DEFERRED_TARGET/.opencode/agents/implementation-worker.md" ]]
[[ -d "$DEFERRED_TARGET/.gitignore" ]]

# A non-file .gitignore is rejected before recognized legacy cleanup can touch
# settings, the marker, or a managed legacy asset.
GITIGNORE_PREFLIGHT_HOME="$TMP/gitignore-preflight-home"
GITIGNORE_PREFLIGHT_TARGET="$TMP/gitignore-preflight-target"
mkdir -p "$GITIGNORE_PREFLIGHT_HOME/harness" \
  "$GITIGNORE_PREFLIGHT_TARGET/.claude" \
  "$GITIGNORE_PREFLIGHT_TARGET/.agents/skills/implement-spec" \
  "$GITIGNORE_PREFLIGHT_TARGET/.gitignore"
git -C "$GITIGNORE_PREFLIGHT_TARGET" init -q
cp "$ROOT/VERSION" "$GITIGNORE_PREFLIGHT_HOME/VERSION"
cp "$ROOT/harness/legacy-links.sh" "$GITIGNORE_PREFLIGHT_HOME/harness/legacy-links.sh"
printf 'legacy preflight asset\n' > "$TMP/gitignore-preflight-asset"
GITIGNORE_PREFLIGHT_HASH="$(shasum -a 256 "$TMP/gitignore-preflight-asset" | awk '{print $1}')"
printf '.agents/skills/implement-spec/SKILL.md\t%s\tfixture:preflight\n' \
  "$GITIGNORE_PREFLIGHT_HASH" \
  > "$GITIGNORE_PREFLIGHT_HOME/harness/legacy-managed.sha256"
cp "$TMP/gitignore-preflight-asset" \
  "$GITIGNORE_PREFLIGHT_TARGET/.agents/skills/implement-spec/SKILL.md"
printf '%s\n' \
  '0.2.0' \
  'plugin:  agentic-harness@agentic-harness' \
  'ref:     main' \
  'stamped: 2026-09-06' \
  'engine:  unknown' \
  > "$GITIGNORE_PREFLIGHT_TARGET/.claude/.agentic-harness-version"
printf '%s\n' '{"keep":true}' > "$GITIGNORE_PREFLIGHT_TARGET/.claude/settings.json"
cp "$GITIGNORE_PREFLIGHT_TARGET/.claude/.agentic-harness-version" \
  "$TMP/gitignore-preflight.marker.before"
cp "$GITIGNORE_PREFLIGHT_TARGET/.claude/settings.json" \
  "$TMP/gitignore-preflight.settings.before"
if SOFTWARE_FACTORY_HOME="$GITIGNORE_PREFLIGHT_HOME" \
  "$ROOT/harness/init.sh" update "$GITIGNORE_PREFLIGHT_TARGET" \
  > "$TMP/gitignore-preflight.log" 2>&1; then
  echo "non-file .gitignore should have failed during preflight" >&2
  exit 1
fi
grep -qF 'non-file destination' "$TMP/gitignore-preflight.log"
cmp -s "$GITIGNORE_PREFLIGHT_TARGET/.claude/.agentic-harness-version" \
  "$TMP/gitignore-preflight.marker.before"
cmp -s "$GITIGNORE_PREFLIGHT_TARGET/.claude/settings.json" \
  "$TMP/gitignore-preflight.settings.before"
cmp -s "$GITIGNORE_PREFLIGHT_TARGET/.agents/skills/implement-spec/SKILL.md" \
  "$TMP/gitignore-preflight-asset"
[[ ! -e "$GITIGNORE_PREFLIGHT_TARGET/.claude/.software-factory-version" ]]

# OpenCode destination ancestors must remain within the target before mkdir or
# copy; an external .agents or .opencode link cannot receive generated files.
for ancestor_name in agents opencode; do
  ANCESTOR_HOME="$TMP/ancestor-$ancestor_name-home"
  ANCESTOR_TARGET="$TMP/ancestor-$ancestor_name-target"
  ANCESTOR_EXTERNAL="$TMP/ancestor-$ancestor_name-external"
  mkdir -p "$ANCESTOR_TARGET" "$ANCESTOR_EXTERNAL"
  git -C "$ANCESTOR_TARGET" init -q
  ln -s "$ANCESTOR_EXTERNAL" "$ANCESTOR_TARGET/.$ancestor_name"
  make_global_opencode_links "$ANCESTOR_HOME"
  if HOME="$ANCESTOR_HOME" SOFTWARE_FACTORY_HOME="$ROOT" \
    "$ROOT/harness/init.sh" update --opencode "$ANCESTOR_TARGET" \
    > "$TMP/ancestor-$ancestor_name.log" 2>&1; then
    echo "external .$ancestor_name ancestor should have failed" >&2
    exit 1
  fi
  [[ -L "$ANCESTOR_TARGET/.$ancestor_name" ]]
  [[ -z "$(find "$ANCESTOR_EXTERNAL" -mindepth 1 -print -prune)" ]]
  [[ -L "$ANCESTOR_HOME/.config/opencode/agents/implementation-worker.md" ]]
[[ -L "$ANCESTOR_HOME/.config/opencode/commands/route.md" ]]
done

# A raw dot component in an intermediate OpenCode link must be rejected before
# any generated directory or settings file can be written.
for ancestor_name in agents opencode; do
  RAW_TARGET="$TMP/raw-$ancestor_name-target"
  RAW_HOME="$TMP/raw-$ancestor_name-home"
  mkdir -p "$RAW_TARGET" "$RAW_HOME"
  git -C "$RAW_TARGET" init -q
  ln -s .. "$RAW_TARGET/.$ancestor_name"
  if HOME="$RAW_HOME" SOFTWARE_FACTORY_HOME="$ROOT" \
    "$ROOT/harness/init.sh" update --opencode "$RAW_TARGET" \
    > "$TMP/raw-$ancestor_name.log" 2>&1; then
    echo "raw .$ancestor_name ancestor should have failed" >&2
    exit 1
  fi
  grep -qF 'symlink ancestor' "$TMP/raw-$ancestor_name.log"
  [[ ! -e "$RAW_TARGET/.claude/settings.json" ]]
  [[ ! -e "$RAW_TARGET/.gitignore" ]]
  if [[ "$ancestor_name" == agents ]]; then
    [[ ! -e "$RAW_TARGET/skills" ]]
  else
    [[ ! -e "$RAW_TARGET/agents" ]]
  fi
done

# A recognized legacy migration rejects an intermediate external symlink before
# settings, markers, or the historical-hash target can change.
LEGACY_PREFLIGHT_HOME="$TMP/legacy-preflight-home"
LEGACY_PREFLIGHT_TARGET="$TMP/legacy-preflight-target"
LEGACY_PREFLIGHT_EXTERNAL="$TMP/legacy-preflight-external.md"
mkdir -p "$LEGACY_PREFLIGHT_HOME/harness" "$LEGACY_PREFLIGHT_TARGET/.claude" \
  "$LEGACY_PREFLIGHT_TARGET/.agents/skills"
git -C "$LEGACY_PREFLIGHT_TARGET" init -q
cp "$ROOT/VERSION" "$LEGACY_PREFLIGHT_HOME/VERSION"
cp "$ROOT/harness/legacy-links.sh" "$LEGACY_PREFLIGHT_HOME/harness/legacy-links.sh"
awk -F '\t' '$1 != ".agents/skills/implement-spec/SKILL.md"' \
  "$ROOT/harness/legacy-managed.sha256" \
  > "$LEGACY_PREFLIGHT_HOME/harness/legacy-managed.sha256"
printf 'historical preflight file\n' > "$LEGACY_PREFLIGHT_EXTERNAL"
LEGACY_PREFLIGHT_HASH="$(shasum -a 256 "$LEGACY_PREFLIGHT_EXTERNAL" | awk '{print $1}')"
printf '.agents/skills/implement-spec/SKILL.md\t%s\tfixture:historical\n' \
  "$LEGACY_PREFLIGHT_HASH" >> "$LEGACY_PREFLIGHT_HOME/harness/legacy-managed.sha256"
printf '%s\n' \
  '0.2.0' \
  'plugin:  agentic-harness@agentic-harness' \
  'ref:     main' \
  'stamped: 2026-09-06' \
  'engine:  unknown' \
  > "$LEGACY_PREFLIGHT_TARGET/.claude/.agentic-harness-version"
printf '%s\n' '{"keep":true}' > "$LEGACY_PREFLIGHT_TARGET/.claude/settings.json"
ln -s "$LEGACY_PREFLIGHT_EXTERNAL" \
  "$LEGACY_PREFLIGHT_TARGET/.agents/skills/implement-spec"
cp "$LEGACY_PREFLIGHT_TARGET/.claude/settings.json" \
  "$TMP/legacy-preflight.settings.before"
cp "$LEGACY_PREFLIGHT_TARGET/.claude/.agentic-harness-version" \
  "$TMP/legacy-preflight.marker.before"
cp "$LEGACY_PREFLIGHT_EXTERNAL" "$TMP/legacy-preflight.external.before"
if SOFTWARE_FACTORY_HOME="$LEGACY_PREFLIGHT_HOME" "$ROOT/harness/init.sh" \
  update "$LEGACY_PREFLIGHT_TARGET" > "$TMP/legacy-preflight.log" 2>&1; then
  echo "legacy migration through an intermediate symlink should have failed" >&2
  exit 1
fi
grep -qF 'symlink ancestor' "$TMP/legacy-preflight.log"
cmp -s "$LEGACY_PREFLIGHT_TARGET/.claude/settings.json" \
  "$TMP/legacy-preflight.settings.before"
cmp -s "$LEGACY_PREFLIGHT_TARGET/.claude/.agentic-harness-version" \
  "$TMP/legacy-preflight.marker.before"
cmp -s "$LEGACY_PREFLIGHT_EXTERNAL" "$TMP/legacy-preflight.external.before"
[[ -L "$LEGACY_PREFLIGHT_TARGET/.agents/skills/implement-spec" ]]
[[ ! -e "$LEGACY_PREFLIGHT_TARGET/.claude/.software-factory-version" ]]

# Updating a pre-0.2.1 repo removes only the old managed runtime kit.
rm -f "$TARGET/.claude/.software-factory-version"
printf '%s\n' \
  '0.2.0' \
  'plugin:  agentic-harness@agentic-harness' \
  'ref:     main' \
  'stamped: 2026-09-06' \
  'engine:  unknown' \
  > "$TARGET/.claude/.agentic-harness-version"
jq '.extraKnownMarketplaces["agentic-harness"] = {source: {source: "github", repo: "aanojima/agentic-harness", ref: "main"}}
  | .enabledPlugins["agentic-harness@agentic-harness"] = true' \
  "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
for rules_file in AGENTS.md CLAUDE.md; do
  cat > "$TARGET/$rules_file" <<'EOF'
keep this line
<!-- >>> agentic-harness (managed block — refresh with `agentic-harness update`) -->
old managed rules
<!-- <<< agentic-harness -->
<!-- >>> software-factory (managed block — refresh with `software-factory update`) -->
old later managed rules
<!-- <<< software-factory -->
EOF
done
mkdir -p "$TARGET/.codex/prompts" "$TARGET/.codex/agents" "$TARGET/.agents/skills/implement-spec"
cat > "$TARGET/.codex/agents/goal-explorer.toml" <<'EOF'
model_reasoning_effort = "low"
sandbox_mode = "read-only"
EOF
cp "$ROOT/skills/implement-spec/SKILL.md" "$TARGET/.agents/skills/implement-spec/SKILL.md"
mkdir -p "$TARGET/.agents/skills/implement-spec/references"
cp "$ROOT/skills/implement-spec/references/artifacts.md" \
  "$TARGET/.agents/skills/implement-spec/references/artifacts.md"
ARTIFACT_HASH="$(shasum -a 256 "$TARGET/.agents/skills/implement-spec/references/artifacts.md" | awk '{print $1}')"
grep -qF ".agents/skills/implement-spec/references/artifacts.md	$ARTIFACT_HASH	" \
  "$ROOT/harness/legacy-managed.sha256"
printf 'user-added\n' > "$TARGET/.agents/skills/implement-spec/references/user-added.md"
cat > "$TARGET/.opencode/agents/goal-explorer.md" <<'EOF'
---
description: Read-only repository explorer for bounded implement-spec questions
mode: subagent
permission:
  edit: deny
  bash: deny
  task: deny
  webfetch: deny
  websearch: deny
---

Answer exactly the bounded repository question delegated by the parent. Do not select the final design.

Return a direct answer, file and symbol evidence, existing patterns, unresolved risks, and confidence limits.
EOF
cat > "$TARGET/.codex/config.toml" <<'EOF'
[unrelated]
keep = true
# >>> agentic-harness implement-spec agents
[agents."goal-explorer"]
config_file = "agents/goal-explorer.toml"
# <<< agentic-harness implement-spec agents
# >>> software-factory implement-spec agents
[agents."repo-explorer"]
config_file = "agents/repo-explorer.toml"
# <<< software-factory implement-spec agents
EOF
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$TARGET" >/dev/null
[[ ! -e "$TARGET/.codex/prompts/execute.md" ]]
[[ ! -e "$TARGET/.codex/agents/goal-explorer.toml" ]]
[[ ! -e "$TARGET/.agents/skills/implement-spec/references/artifacts.md" ]]
[[ -f "$TARGET/.agents/skills/implement-spec/references/user-added.md" ]]
[[ ! -e "$TARGET/.opencode/agents/goal-explorer.md" ]]
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update --opencode "$TARGET" >/dev/null
[[ -f "$TARGET/.agents/skills/implement-spec/SKILL.md" ]]
[[ -f "$TARGET/.agents/skills/implement-spec/references/artifacts.md" ]]
[[ -f "$TARGET/.agents/skills/implement-spec/references/user-added.md" ]]
[[ -f "$TARGET/.opencode/commands/route.md" ]]
[[ -f "$TARGET/.opencode/agents/implementation-worker.md" ]]
[[ -f "$TARGET/.opencode/software-factory/loops.env" ]]
[[ ! -e "$TARGET/.opencode/commands/pr-watch.md" ]]
[[ ! -e "$TARGET/.opencode/agents/goal-explorer.md" ]]
[[ ! -e "$TARGET/.claude/.agentic-harness-version" ]]
jq -e '.extraKnownMarketplaces["agentic-harness"] == null
  and .enabledPlugins["agentic-harness@agentic-harness"] == null
  and .enabledPlugins["software-factory@software-factory"] == true' \
  "$TARGET/.claude/settings.json" >/dev/null
for rules_file in AGENTS.md CLAUDE.md; do
  ! grep -qF 'agentic-harness' "$TARGET/$rules_file"
  [[ "$(grep -c '<!-- >>> software-factory' "$TARGET/$rules_file")" -eq 1 ]]
  grep -qF 'keep this line' "$TARGET/$rules_file"
done
grep -qF '[unrelated]' "$TARGET/.codex/config.toml"
if grep -qF 'implement-spec agents' "$TARGET/.codex/config.toml"; then
  echo "legacy Codex agent registration was not removed" >&2
  exit 1
fi
mkdir -p "$TARGET/.codex/prompts"
printf 'user-owned prompt\n' > "$TARGET/.codex/prompts/execute.md"
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$TARGET" >/dev/null
grep -qxF 'user-owned prompt' "$TARGET/.codex/prompts/execute.md"

# An unknown legacy marker and colliding Claude settings are preserved.
UNKNOWN_LEGACY="$TMP/unknown-legacy"; mkdir -p "$UNKNOWN_LEGACY/.claude"; git -C "$UNKNOWN_LEGACY" init -q
cat > "$UNKNOWN_LEGACY/.claude/.agentic-harness-version" <<'EOF'
0.2.0
plugin:  agentic-harness@custom-marketplace
ref:     main
stamped: 2026-09-06
engine:  unknown
EOF
cp "$UNKNOWN_LEGACY/.claude/.agentic-harness-version" "$TMP/unknown-legacy.marker"
jq -n '{extraKnownMarketplaces:{"agentic-harness":{source:{source:"github",repo:"custom/agentic-harness"}}},enabledPlugins:{"agentic-harness@agentic-harness":"user"}}' \
  > "$UNKNOWN_LEGACY/.claude/settings.json"
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$UNKNOWN_LEGACY" >/dev/null
cmp -s "$UNKNOWN_LEGACY/.claude/.agentic-harness-version" "$TMP/unknown-legacy.marker"
jq -e '.extraKnownMarketplaces["agentic-harness"].source.repo == "custom/agentic-harness"
  and .enabledPlugins["agentic-harness@agentic-harness"] == "user"' \
  "$UNKNOWN_LEGACY/.claude/settings.json" >/dev/null

# A recognized marker enables migration, but modified legacy settings remain.
COLLIDING_LEGACY="$TMP/colliding-legacy"; mkdir -p "$COLLIDING_LEGACY/.claude"; git -C "$COLLIDING_LEGACY" init -q
printf '%s\n' \
  '0.2.0' \
  'plugin:  agentic-harness@agentic-harness' \
  'ref:     main' \
  'stamped: 2026-09-06' \
  'engine:  unknown' \
  > "$COLLIDING_LEGACY/.claude/.agentic-harness-version"
jq -n '{extraKnownMarketplaces:{"agentic-harness":{source:{source:"github",repo:"custom/agentic-harness"}}},enabledPlugins:{"agentic-harness@agentic-harness":false}}' \
  > "$COLLIDING_LEGACY/.claude/settings.json"
SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$COLLIDING_LEGACY" >/dev/null
[[ ! -e "$COLLIDING_LEGACY/.claude/.agentic-harness-version" ]]
jq -e '.extraKnownMarketplaces["agentic-harness"].source.repo == "custom/agentic-harness"
  and .enabledPlugins["agentic-harness@agentic-harness"] == false' \
  "$COLLIDING_LEGACY/.claude/settings.json" >/dev/null

# A modified current marker refuses migration before settings or legacy assets
# can change, even when its version would otherwise authorize cleanup.
MODIFIED_MARKER="$TMP/modified-current-marker"
mkdir -p "$MODIFIED_MARKER/.claude" \
  "$MODIFIED_MARKER/.agents/skills/implement-spec/references"
git -C "$MODIFIED_MARKER" init -q
printf '%s\n' '{"keep":true}' > "$MODIFIED_MARKER/.claude/settings.json"
printf '%s\n' \
  '0.2.0' \
  'plugin:  software-factory@software-factory' \
  'ref:' \
  'stamped: 2026-09-06' \
  'engine:  unknown' \
  > "$MODIFIED_MARKER/.claude/.software-factory-version"
cp "$ROOT/skills/implement-spec/references/artifacts.md" \
  "$MODIFIED_MARKER/.agents/skills/implement-spec/references/artifacts.md"
cp "$MODIFIED_MARKER/.claude/settings.json" "$TMP/modified-marker.settings.before"
cp "$MODIFIED_MARKER/.claude/.software-factory-version" "$TMP/modified-marker.marker.before"
MODIFIED_ASSET_HASH="$(shasum -a 256 \
  "$MODIFIED_MARKER/.agents/skills/implement-spec/references/artifacts.md" | awk '{print $1}')"
if SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$MODIFIED_MARKER" \
  > "$TMP/modified-marker.log" 2>&1; then
  echo "modified current marker should have failed" >&2
  exit 1
fi
grep -qF 'unknown or modified current marker' "$TMP/modified-marker.log"
cmp -s "$MODIFIED_MARKER/.claude/settings.json" "$TMP/modified-marker.settings.before"
cmp -s "$MODIFIED_MARKER/.claude/.software-factory-version" \
  "$TMP/modified-marker.marker.before"
[[ "$(shasum -a 256 \
  "$MODIFIED_MARKER/.agents/skills/implement-spec/references/artifacts.md" | awk '{print $1}')" == \
  "$MODIFIED_ASSET_HASH" ]]

# install-user migrates legacy links and invokes native plugin managers only.
PLUGIN_HOME="$TMP/plugin-home"; PLUGIN_BIN="$TMP/plugin-bin"
mkdir -p "$PLUGIN_HOME/.claude/skills" "$PLUGIN_HOME/.claude/agents" \
  "$PLUGIN_HOME/.agents/skills" \
  "$PLUGIN_HOME/.config/opencode/agents" "$PLUGIN_HOME/.config/opencode/commands" \
  "$PLUGIN_HOME/.codex" "$PLUGIN_HOME/dotfiles" "$PLUGIN_BIN"
LEGACY_ROOT="$TMP/agentic-harness"
mkdir -p "$LEGACY_ROOT/bin" "$LEGACY_ROOT/.claude-plugin" \
  "$LEGACY_ROOT/skills/implement-spec" "$LEGACY_ROOT/skills/stage-ticket" "$LEGACY_ROOT/agents" \
  "$LEGACY_ROOT/adapters/opencode/agents" "$LEGACY_ROOT/adapters/opencode/commands"
printf '%s\n' '{"name":"agentic-harness","version":"0.2.0"}' \
  > "$LEGACY_ROOT/.claude-plugin/plugin.json"
printf '#!/usr/bin/env bash\n' > "$LEGACY_ROOT/bin/agentic-harness"
chmod +x "$LEGACY_ROOT/bin/agentic-harness"
touch "$LEGACY_ROOT/agents/goal-explorer.md" \
  "$LEGACY_ROOT/adapters/opencode/agents/goal-explorer.md" \
  "$LEGACY_ROOT/adapters/opencode/commands/implement-spec.md" \
  "$LEGACY_ROOT/adapters/opencode/commands/stage-ticket.md"
ln -s "$ROOT/bin/software-factory" "$PLUGIN_BIN/software-factory"
ln -s "$LEGACY_ROOT/bin/agentic-harness" "$PLUGIN_BIN/agentic-harness"
ln -s "$ROOT/skills/route" "$PLUGIN_HOME/.claude/skills/route"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$PLUGIN_HOME/.claude/skills/implement-spec"
ln -s "$LEGACY_ROOT/skills/stage-ticket" "$PLUGIN_HOME/.claude/skills/stage-ticket"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$PLUGIN_HOME/.agents/skills/implement-spec"
ln -s "$LEGACY_ROOT/skills/stage-ticket" "$PLUGIN_HOME/.agents/skills/stage-ticket"
ln -s "$ROOT/agents/repo-explorer.md" "$PLUGIN_HOME/.claude/agents/repo-explorer.md"
ln -s "$LEGACY_ROOT/agents/goal-explorer.md" "$PLUGIN_HOME/.claude/agents/goal-explorer.md"
ln -s "$ROOT/adapters/opencode/agents/repo-explorer.md" "$PLUGIN_HOME/.config/opencode/agents/repo-explorer.md"
ln -s "$LEGACY_ROOT/adapters/opencode/agents/goal-explorer.md" "$PLUGIN_HOME/.config/opencode/agents/goal-explorer.md"
ln -s "$ROOT/adapters/opencode/commands/route.md" "$PLUGIN_HOME/.config/opencode/commands/route.md"
ln -s "$LEGACY_ROOT/adapters/opencode/commands/implement-spec.md" "$PLUGIN_HOME/.config/opencode/commands/implement-spec.md"
cat > "$PLUGIN_HOME/dotfiles/codex.toml" <<'EOF'
[unrelated]
keep = true
# >>> agentic-harness implement-spec agents
[agents."goal-explorer"]
config_file = "/checkout/software-factory/adapters/codex/agents/goal-explorer.toml"
# <<< agentic-harness implement-spec agents
# >>> software-factory implement-spec agents
[agents."repo-explorer"]
config_file = "/checkout/software-factory/adapters/codex/agents/repo-explorer.toml"
# <<< software-factory implement-spec agents
EOF
chmod 640 "$PLUGIN_HOME/dotfiles/codex.toml"
ln -s "$PLUGIN_HOME/dotfiles/codex.toml" "$PLUGIN_HOME/.codex/config.toml"
cat > "$PLUGIN_BIN/claude" <<'EOF'
#!/usr/bin/env bash
printf 'claude %s\n' "$*" >> "$PLUGIN_LOG"
[[ "${FAKE_CLAUDE_FAILURE:-${FAKE_PLUGIN_FAILURE:-0}}" == "1" ]] && exit 99
[[ "$*" == 'plugin marketplace list --json' ]] && printf '[]\n'
[[ "$*" == 'plugin list --json' ]] && printf '[]\n'
exit 0
EOF
cat > "$PLUGIN_BIN/codex" <<'EOF'
#!/usr/bin/env bash
printf 'codex %s\n' "$*" >> "$PLUGIN_LOG"
[[ "${FAKE_CODEX_FAILURE:-${FAKE_PLUGIN_FAILURE:-0}}" == "1" ]] && exit 99
if [[ "$*" == 'plugin marketplace list --json' ]]; then
  if [[ "${FAKE_LOCAL_MARKETPLACE:-0}" == "1" ]]; then
    printf '{"marketplaces":[{"name":"software-factory","marketplaceSource":{"sourceType":"local"}}]}\n'
  else
    printf '{"marketplaces":[]}\n'
  fi
fi
[[ "${FAKE_LOCAL_MARKETPLACE:-0}" == "1" && "$*" == 'plugin marketplace upgrade '* ]] && exit 99
exit 0
EOF
chmod +x "$PLUGIN_BIN/claude" "$PLUGIN_BIN/codex"
if PLUGIN_LOG="$TMP/plugin.log" HOME="$PLUGIN_HOME" CODEX_HOME="$PLUGIN_HOME/.codex" \
  FAKE_PLUGIN_FAILURE=1 PATH="$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" >/dev/null 2>&1; then
  echo "failed plugin installation should return nonzero" >&2
  exit 1
fi
[[ -L "$PLUGIN_BIN/software-factory" ]]
[[ -L "$PLUGIN_BIN/agentic-harness" ]]
[[ -L "$PLUGIN_HOME/.claude/skills/route" ]]
PLUGIN_LOG="$TMP/plugin.log" HOME="$PLUGIN_HOME" CODEX_HOME="$PLUGIN_HOME/.codex" \
  PATH="$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" > "$TMP/plugin-install.out" 2>&1
[[ -L "$PLUGIN_BIN/software-factory" ]]
[[ -L "$PLUGIN_BIN/agentic-harness" ]]
[[ -L "$PLUGIN_HOME/.codex/config.toml" ]]
[[ "$(readlink "$PLUGIN_HOME/.codex/config.toml")" == "$PLUGIN_HOME/dotfiles/codex.toml" ]]
MODE="$(stat -c '%a' "$PLUGIN_HOME/dotfiles/codex.toml" 2>/dev/null || \
  stat -f '%Lp' "$PLUGIN_HOME/dotfiles/codex.toml")"
[[ "$MODE" == 640 ]]
[[ ! -e "$PLUGIN_HOME/.claude/skills/route" ]]
[[ -L "$PLUGIN_HOME/.claude/skills/implement-spec" ]]
[[ -L "$PLUGIN_HOME/.claude/skills/stage-ticket" ]]
[[ -L "$PLUGIN_HOME/.agents/skills/implement-spec" ]]
[[ -L "$PLUGIN_HOME/.agents/skills/stage-ticket" ]]
[[ ! -e "$PLUGIN_HOME/.claude/agents/repo-explorer.md" ]]
[[ ! -L "$PLUGIN_HOME/.claude/agents/goal-explorer.md" ]]
[[ -L "$PLUGIN_HOME/.config/opencode/agents/repo-explorer.md" ]]
[[ -L "$PLUGIN_HOME/.config/opencode/agents/goal-explorer.md" ]]
[[ -L "$PLUGIN_HOME/.config/opencode/commands/route.md" ]]
[[ -L "$PLUGIN_HOME/.config/opencode/commands/implement-spec.md" ]]
grep -qF 'preserving shared PATH links: recognized global OpenCode links remain' "$TMP/plugin-install.out"
grep -qF '[unrelated]' "$PLUGIN_HOME/dotfiles/codex.toml"
if grep -qF 'implement-spec agents' "$PLUGIN_HOME/dotfiles/codex.toml"; then
  echo "legacy global Codex registration was not removed" >&2
  exit 1
fi
grep -qF 'claude plugin marketplace add --scope user aanojima/software-factory' "$TMP/plugin.log"
grep -qF 'claude plugin install --scope user --yes software-factory@software-factory' "$TMP/plugin.log"
grep -qF 'codex plugin marketplace add aanojima/software-factory' "$TMP/plugin.log"
grep -qF 'codex plugin add software-factory@software-factory' "$TMP/plugin.log"

# Cleanup through an intermediate HOME symlink is skipped while the leaf link
# and its external target tree remain unchanged.
LEGACY_PARENT_HOME="$TMP/legacy-parent-home"
LEGACY_PARENT_EXTERNAL="$TMP/legacy-parent-external"
mkdir -p "$LEGACY_PARENT_HOME" "$LEGACY_PARENT_EXTERNAL/skills"
printf 'preserve this tree\n' > "$LEGACY_PARENT_EXTERNAL/sentinel"
ln -s "$LEGACY_ROOT/skills/implement-spec" \
  "$LEGACY_PARENT_EXTERNAL/skills/implement-spec"
ln -s "$LEGACY_PARENT_EXTERNAL" "$LEGACY_PARENT_HOME/.agents"
cp "$LEGACY_PARENT_EXTERNAL/sentinel" "$TMP/legacy-parent.sentinel.before"
PLUGIN_LOG="$TMP/legacy-parent-plugin.log" HOME="$LEGACY_PARENT_HOME" \
  CODEX_HOME="$LEGACY_PARENT_HOME/.codex" PATH="$PLUGIN_BIN:$PATH" \
  "$ROOT/harness/install-user.sh" > "$TMP/legacy-parent.out" 2>&1
grep -qF 'symlink ancestor' "$TMP/legacy-parent.out"
[[ -L "$LEGACY_PARENT_HOME/.agents" ]]
[[ -L "$LEGACY_PARENT_EXTERNAL/skills/implement-spec" ]]
cmp -s "$LEGACY_PARENT_EXTERNAL/sentinel" \
  "$TMP/legacy-parent.sentinel.before"

# Once recognized global OpenCode links are gone, a clean two-manager success
# may remove the shared PATH checkout links.
for name in goal-explorer goal-reviewer goal-security-reviewer repo-explorer \
  conformance-reviewer security-reviewer adversarial-reviewer implementation-worker; do
  unlink "$PLUGIN_HOME/.config/opencode/agents/$name.md" 2>/dev/null || true
done
for name in route implement-spec stage-ticket pr-watch; do
  unlink "$PLUGIN_HOME/.config/opencode/commands/$name.md" 2>/dev/null || true
done
PLUGIN_LOG="$TMP/plugin.log" HOME="$PLUGIN_HOME" CODEX_HOME="$PLUGIN_HOME/.codex" \
  PATH="$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" >/dev/null
[[ ! -e "$PLUGIN_BIN/software-factory" ]]
[[ ! -e "$PLUGIN_BIN/agentic-harness" ]]
[[ ! -e "$PLUGIN_HOME/.claude/skills/implement-spec" ]]
[[ ! -e "$PLUGIN_HOME/.claude/skills/stage-ticket" ]]
[[ ! -e "$PLUGIN_HOME/.agents/skills/implement-spec" ]]
[[ ! -e "$PLUGIN_HOME/.agents/skills/stage-ticket" ]]
cp "$TMP/plugin.log" "$TMP/plugin.before-collision"
# Recreate the historical legacy link after the successful migration cleanup;
# the collision run must preserve this failed-runtime state.
ln -s "$LEGACY_ROOT/skills/implement-spec" \
  "$PLUGIN_HOME/.agents/skills/implement-spec"
if PLUGIN_LOG="$TMP/plugin.log" HOME="$PLUGIN_HOME" CODEX_HOME="$PLUGIN_HOME/.codex" \
  FAKE_LOCAL_MARKETPLACE=1 PATH="$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" >/dev/null 2>&1; then
  echo "marketplace collision should fail" >&2
  exit 1
fi
if tail -n +"$(($(wc -l < "$TMP/plugin.before-collision") + 1))" "$TMP/plugin.log" | \
   grep -Eq 'codex plugin marketplace (remove|add)'; then
  echo "marketplace collision must not replace configured source" >&2
  exit 1
fi
[[ -L "$PLUGIN_HOME/.agents/skills/implement-spec" ]]

# A user-owned symlink with a matching suffix but no plugin checkout marker is
# preserved.
USER_OWNED_ROOT="$TMP/user-owned"
mkdir -p "$USER_OWNED_ROOT/skills/route"
printf 'user-owned\n' > "$USER_OWNED_ROOT/skills/route/README"
ln -s "$USER_OWNED_ROOT/skills/route" "$PLUGIN_HOME/.claude/skills/route"
PLUGIN_LOG="$TMP/plugin.log" HOME="$PLUGIN_HOME" CODEX_HOME="$PLUGIN_HOME/.codex" \
  PATH="$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" >/dev/null
[[ -L "$PLUGIN_HOME/.claude/skills/route" ]]

# Malformed legacy Codex markers fail before the original config changes.
MALFORMED_INIT="$TMP/malformed-init"; mkdir -p "$MALFORMED_INIT/.claude"; git -C "$MALFORMED_INIT" init -q
printf '%s\n' \
  '0.2.0' \
  'plugin:  agentic-harness@agentic-harness' \
  'ref:     main' \
  'stamped: 2026-09-06' \
  'engine:  unknown' \
  > "$MALFORMED_INIT/.claude/.agentic-harness-version"
mkdir -p "$MALFORMED_INIT/.codex"
cat > "$MALFORMED_INIT/.codex/config.toml" <<'EOF'
[unrelated]
keep = true
# >>> software-factory implement-spec agents
# >>> agentic-harness implement-spec agents
# <<< software-factory implement-spec agents
# <<< agentic-harness implement-spec agents
EOF
cp "$MALFORMED_INIT/.codex/config.toml" "$TMP/malformed-init.before"
if SOFTWARE_FACTORY_HOME="$ROOT" "$ROOT/harness/init.sh" update "$MALFORMED_INIT" >/dev/null 2>&1; then
  echo "malformed init Codex markers should have failed" >&2
  exit 1
fi
cmp -s "$MALFORMED_INIT/.codex/config.toml" "$TMP/malformed-init.before"

# The install cleanup applies the same all-or-nothing marker validation and
# keeps a symlinked Codex config intact on failure.
cat > "$PLUGIN_HOME/dotfiles/codex.toml" <<'EOF'
[unrelated]
keep = true
# >>> software-factory implement-spec agents
# >>> agentic-harness implement-spec agents
# <<< software-factory implement-spec agents
# <<< agentic-harness implement-spec agents
EOF
cp "$PLUGIN_HOME/dotfiles/codex.toml" "$TMP/codex.before"
if PLUGIN_LOG="$TMP/plugin.log" HOME="$PLUGIN_HOME" CODEX_HOME="$PLUGIN_HOME/.codex" \
  PATH="$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" >/dev/null 2>&1; then
  echo "malformed install Codex markers should have failed" >&2
  exit 1
fi
cmp -s "$PLUGIN_HOME/dotfiles/codex.toml" "$TMP/codex.before"
[[ -L "$PLUGIN_HOME/.codex/config.toml" ]]
cp "$TMP/codex.before" "$PLUGIN_HOME/dotfiles/codex.toml"

# A dangling Codex config symlink fails before plugin-manager calls or writes.
UNSAFE_CODEX_HOME="$TMP/unsafe-codex-home"
mkdir -p "$UNSAFE_CODEX_HOME/.codex"
ln -s "$UNSAFE_CODEX_HOME/missing-config.toml" \
  "$UNSAFE_CODEX_HOME/.codex/config.toml"
if PLUGIN_LOG="$TMP/unsafe-codex-plugin.log" HOME="$UNSAFE_CODEX_HOME" \
  CODEX_HOME="$UNSAFE_CODEX_HOME/.codex" PATH="$PLUGIN_BIN:$PATH" \
  "$ROOT/harness/install-user.sh" > "$TMP/unsafe-codex.out" 2>&1; then
  echo "dangling Codex config symlink should have failed" >&2
  exit 1
fi
grep -qF 'unsafe, dangling, or non-file Codex config target' "$TMP/unsafe-codex.out"
[[ -L "$UNSAFE_CODEX_HOME/.codex/config.toml" ]]
[[ ! -e "$TMP/unsafe-codex-plugin.log" ]]

# Runtime-specific cleanup: an absent manager preserves shared links, while
# its own runtime can still migrate successfully.
CLAUDE_ONLY_HOME="$TMP/claude-only-home"; CLAUDE_ONLY_BIN="$TMP/claude-only-bin"
mkdir -p "$CLAUDE_ONLY_HOME/.claude/skills" "$CLAUDE_ONLY_HOME/.agents/skills" "$CLAUDE_ONLY_BIN"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CLAUDE_ONLY_HOME/.claude/skills/implement-spec"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CLAUDE_ONLY_HOME/.agents/skills/implement-spec"
ln -s "$ROOT/bin/software-factory" "$CLAUDE_ONLY_BIN/software-factory"
ln -s "$PLUGIN_BIN/claude" "$CLAUDE_ONLY_BIN/claude"
ln -s "$(command -v jq)" "$CLAUDE_ONLY_BIN/jq"
PLUGIN_LOG="$TMP/claude-only.log" HOME="$CLAUDE_ONLY_HOME" \
  CODEX_HOME="$CLAUDE_ONLY_HOME/.codex" PATH="$CLAUDE_ONLY_BIN:/usr/bin:/bin" \
  "$ROOT/harness/install-user.sh" > "$TMP/claude-only.out" 2>&1
[[ ! -L "$CLAUDE_ONLY_HOME/.claude/skills/implement-spec" ]]
[[ -L "$CLAUDE_ONLY_HOME/.agents/skills/implement-spec" ]]
[[ -L "$CLAUDE_ONLY_BIN/software-factory" ]]
grep -qF 'Codex manager is absent' "$TMP/claude-only.out"
grep -qF 'preserving shared PATH links' "$TMP/claude-only.out"

CODEX_ONLY_HOME="$TMP/codex-only-home"; CODEX_ONLY_BIN="$TMP/codex-only-bin"
mkdir -p "$CODEX_ONLY_HOME/.claude/skills" "$CODEX_ONLY_HOME/.agents/skills" "$CODEX_ONLY_BIN"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CODEX_ONLY_HOME/.claude/skills/implement-spec"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CODEX_ONLY_HOME/.agents/skills/implement-spec"
ln -s "$ROOT/bin/software-factory" "$CODEX_ONLY_BIN/software-factory"
ln -s "$PLUGIN_BIN/codex" "$CODEX_ONLY_BIN/codex"
ln -s "$(command -v jq)" "$CODEX_ONLY_BIN/jq"
PLUGIN_LOG="$TMP/codex-only.log" HOME="$CODEX_ONLY_HOME" \
  CODEX_HOME="$CODEX_ONLY_HOME/.codex" PATH="$CODEX_ONLY_BIN:/usr/bin:/bin" \
  "$ROOT/harness/install-user.sh" > "$TMP/codex-only.out" 2>&1
[[ -L "$CODEX_ONLY_HOME/.claude/skills/implement-spec" ]]
[[ ! -L "$CODEX_ONLY_HOME/.agents/skills/implement-spec" ]]
[[ -L "$CODEX_ONLY_BIN/software-factory" ]]
grep -qF 'Claude manager is absent' "$TMP/codex-only.out"
grep -qF 'preserving shared PATH links' "$TMP/codex-only.out"

# If one available manager fails, only the successful runtime is migrated and
# the shared PATH links remain for the failed runtime's retry.
CLAUDE_FAIL_HOME="$TMP/claude-fail-home"; CLAUDE_FAIL_BIN="$TMP/claude-fail-bin"
mkdir -p "$CLAUDE_FAIL_HOME/.claude/skills" "$CLAUDE_FAIL_HOME/.agents/skills" "$CLAUDE_FAIL_BIN"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CLAUDE_FAIL_HOME/.claude/skills/implement-spec"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CLAUDE_FAIL_HOME/.agents/skills/implement-spec"
ln -s "$ROOT/bin/software-factory" "$CLAUDE_FAIL_BIN/software-factory"
if PLUGIN_LOG="$TMP/claude-fail.log" HOME="$CLAUDE_FAIL_HOME" CODEX_HOME="$CLAUDE_FAIL_HOME/.codex" \
  FAKE_CLAUDE_FAILURE=1 PATH="$CLAUDE_FAIL_BIN:$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" \
  > "$TMP/claude-fail.out" 2>&1; then
  echo "one-manager failure should return nonzero" >&2
  exit 1
fi
[[ -L "$CLAUDE_FAIL_HOME/.claude/skills/implement-spec" ]]
[[ ! -L "$CLAUDE_FAIL_HOME/.agents/skills/implement-spec" ]]
[[ -L "$CLAUDE_FAIL_BIN/software-factory" ]]
grep -qF 'Claude plugin installation did not succeed' "$TMP/claude-fail.out"
grep -qF 'preserving shared PATH links' "$TMP/claude-fail.out"

CODEX_FAIL_HOME="$TMP/codex-fail-home"; CODEX_FAIL_BIN="$TMP/codex-fail-bin"
mkdir -p "$CODEX_FAIL_HOME/.claude/skills" "$CODEX_FAIL_HOME/.agents/skills" "$CODEX_FAIL_BIN"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CODEX_FAIL_HOME/.claude/skills/implement-spec"
ln -s "$LEGACY_ROOT/skills/implement-spec" "$CODEX_FAIL_HOME/.agents/skills/implement-spec"
ln -s "$ROOT/bin/software-factory" "$CODEX_FAIL_BIN/software-factory"
if PLUGIN_LOG="$TMP/codex-fail.log" HOME="$CODEX_FAIL_HOME" CODEX_HOME="$CODEX_FAIL_HOME/.codex" \
  FAKE_CODEX_FAILURE=1 PATH="$CODEX_FAIL_BIN:$PLUGIN_BIN:$PATH" "$ROOT/harness/install-user.sh" \
  > "$TMP/codex-fail.out" 2>&1; then
  echo "one-manager failure should return nonzero" >&2
  exit 1
fi
[[ ! -L "$CODEX_FAIL_HOME/.claude/skills/implement-spec" ]]
[[ -L "$CODEX_FAIL_HOME/.agents/skills/implement-spec" ]]
[[ -L "$CODEX_FAIL_BIN/software-factory" ]]
grep -qF 'Codex plugin installation did not succeed' "$TMP/codex-fail.out"
grep -qF 'preserving shared PATH links' "$TMP/codex-fail.out"

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
[[ "$(grep -c '<!-- >>> software-factory' "$TARGET/AGENTS.md")" -eq 1 ]]
[[ ! -e "$TARGET/.codex/agents" ]]

echo "all tests passed"
