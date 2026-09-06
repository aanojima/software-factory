#!/usr/bin/env bash
# init.sh — wire a target repo to the software-factory plugin and lay down the
# parts a plugin can't carry, so the harness works in CLI *and* web/desktop for
# BOTH families:
#   • Claude Code → committed .claude/settings.json enables the plugin from the
#     marketplace (loads in cloud sessions at startup).
#   • Codex       → committed portable skill, prompts, native roles, and AGENTS.md.
#
#   software-factory init   [target-dir]   # wire plugin + Codex + seed state
#   software-factory update [target-dir]   # refresh managed files + re-pin (keep state)
#
# State (routing-log, tasks/, golden set) is created only when absent, never
# clobbered.
set -euo pipefail

MODE="${1:?usage: init.sh <init|update> [--to <ref>] [target-dir]}"; shift || true
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# args: optional --to <ref> (target release) and a positional target dir
TO_REF=""; POS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) TO_REF="${2:?--to needs a ref}"; shift 2 ;;
    *)    POS+=("$1"); shift ;;
  esac
done
TARGET="${POS[0]:-${AGENTIC_TARGET:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
TARGET="$(cd "$TARGET" && pwd)"
SRC="$SOFTWARE_FACTORY_HOME"
VERSION="$(cat "$SRC/VERSION")"

# marketplace coordinates (override for a fork)
MKT_REPO="${AGENTIC_MARKETPLACE_REPO:-aanojima/software-factory}"
MKT_NAME="${AGENTIC_MARKETPLACE_NAME:-software-factory}"
PLUGIN_NAME="${AGENTIC_PLUGIN_NAME:-software-factory}"
MKT_REF="${TO_REF:-${AGENTIC_MARKETPLACE_REF:-main}}"  # safe default until a release tag exists; --to vX.Y.Z or env overrides
ENABLE_KEY="${PLUGIN_NAME}@${MKT_NAME}"

# read the existing version marker so we can report the transition
MARKER="$TARGET/.claude/.software-factory-version"
OLD_VER="(none)"; OLD_REF="(none)"
if [[ -f "$MARKER" ]]; then
  OLD_VER="$(head -1 "$MARKER" 2>/dev/null || echo '?')"
  OLD_REF="$(awk -F': *' '/^ref:/{print $2; exit}' "$MARKER" 2>/dev/null || echo '?')"
fi

echo "→ $MODE software-factory v$VERSION into $TARGET" >&2
echo "  plugin: $ENABLE_KEY  marketplace: github:$MKT_REPO@$MKT_REF" >&2

BEGIN_MARK='<!-- >>> software-factory (managed block — refresh with `software-factory update`) -->'
END_MARK='<!-- <<< software-factory -->'

read -r -d '' RULES_BODY <<'EOF' || true
## Agentic harness — project rules
1. One task per conversation. Route new tasks through `/software-factory:execute`
   (Claude Code) or `/execute` (Codex), or `software-factory execute "<task>"`.
   Execute an approved specification through `/software-factory:implement-spec`
   (Claude), `$implement-spec` (Codex/OpenCode), or
   `software-factory implement <spec> --runtime <host>`.
   To stop at a staged commit instead of opening a PR, use `stage-ticket`
   (same command style, any runtime).
2. Never edit files under `tasks/done/` or `eval/golden.jsonl`.
3. Never modify test files to make tests pass.
4. All merges go through PR + CI. Never push to main.
5. When a loop hits its cap, stop and report — do not improvise past it.

The routing methodology (classify → announce → log → follow) is the `route`
skill (Claude, from the plugin) and is embedded in `.codex/prompts/execute.md`
(Codex). Gates: **HEAVY** or **risk=high** → produce the plan, obtain native
plan review, and STOP for human approval; do not implement. Codex uses a fresh
native GPT-6 Astra plan critic at high effort and Claude uses a high-effort
native plan critic.

Use native subagents from the current host for exploration and review. Use an
external CLI bridge only when the user explicitly requests mixed Claude +
Codex review. A native launch failure stops or retries within the applicable
cap; it never silently changes providers.
EOF

# splice the managed block into a markdown file, preserving surrounding content
stamp_block() {
  local file="$1"
  local block; block="$(printf '%s\n%s\n%s' "$BEGIN_MARK" "$RULES_BODY" "$END_MARK")"
  mkdir -p "$(dirname "$file")"
  if [[ -f "$file" ]] && grep -qF "$BEGIN_MARK" "$file"; then
    local b e
    b=$(grep -nF "$BEGIN_MARK" "$file" | head -1 | cut -d: -f1)
    e=$(grep -nF "$END_MARK"   "$file" | head -1 | cut -d: -f1)
    {
      (( b <= 1 )) || head -n $((b-1)) "$file"
      printf '%s\n' "$block"
      tail -n +$((e+1)) "$file"
    } > "$file.tmp"
    mv "$file.tmp" "$file"
    echo "  ~ managed block refreshed: ${file#"$TARGET"/}" >&2
  else
    [[ -f "$file" ]] && printf '\n' >> "$file"
    printf '%s\n' "$block" >> "$file"
    echo "  + managed block added: ${file#"$TARGET"/}" >&2
  fi
}

# create a state file only if it does not already exist (never clobber)
seed_state() {
  local rel="$1" src="$2"
  if [[ -e "$TARGET/$rel" ]]; then echo "  = kept existing $rel" >&2; return; fi
  mkdir -p "$(dirname "$TARGET/$rel")"; cp "$src" "$TARGET/$rel"; echo "  + $rel" >&2
}

# Refresh a generated block in a TOML file while preserving unrelated config.
stamp_codex_agents() {
  local file="$TARGET/.codex/config.toml"
  local begin='# >>> software-factory implement-spec agents'
  local end='# <<< software-factory implement-spec agents'
  local tmp="$file.tmp"
  mkdir -p "$(dirname "$file")"; touch "$file"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp"
  if grep -qE '^\[agents\."goal-(explorer|reviewer|security-reviewer)"\]' "$tmp"; then
    rm -f "$tmp"
    echo "  ! kept existing .codex/config.toml goal-agent registrations; merge adapters/codex/config.toml.fragment manually" >&2
    return
  fi
  printf '\n' >> "$tmp"
  cat "$SRC/adapters/codex/config.toml.fragment" >> "$tmp"
  mv "$tmp" "$file"
  echo "  ~ .codex/config.toml (managed native agent registrations)" >&2
}

stamp_gitignore() {
  local file="$TARGET/.gitignore" entry='.agent-runs/'
  touch "$file"
  if ! grep -qxF "$entry" "$file"; then
    [[ ! -s "$file" ]] || printf '\n' >> "$file"
    printf '# Local agent execution artifacts\n%s\n' "$entry" >> "$file"
    echo "  + .gitignore ($entry)" >&2
  fi
}

# --- 1 · Claude layer: enable the plugin via committed settings (loads in cloud) ---
mkdir -p "$TARGET/.claude"
SETTINGS="$TARGET/.claude/settings.json"
existing='{}'; [[ -f "$SETTINGS" ]] && existing="$(cat "$SETTINGS")"
jq \
  --arg mkt "$MKT_NAME" --arg repo "$MKT_REPO" --arg ref "$MKT_REF" --arg enable "$ENABLE_KEY" '
  .extraKnownMarketplaces[$mkt] = {source: {source: "github", repo: $repo, ref: $ref}}
  | .enabledPlugins[$enable] = true
' <<<"$existing" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
echo "  ~ .claude/settings.json (marketplace + enabledPlugins)" >&2

# --- 2 · Codex layer: committed prompt, native roles, and AGENTS rules ---
mkdir -p "$TARGET/.codex/prompts"
cp "$SRC/.codex/prompts/execute.md" "$TARGET/.codex/prompts/execute.md"
cp "$SRC/.codex/prompts/implement-spec.md" "$TARGET/.codex/prompts/implement-spec.md"
cp "$SRC/.codex/prompts/stage-ticket.md" "$TARGET/.codex/prompts/stage-ticket.md"
cp "$SRC/.codex/prompts/pr-watch.md" "$TARGET/.codex/prompts/pr-watch.md"
mkdir -p "$TARGET/.codex/agents"
cp "$SRC"/adapters/codex/agents/*.toml "$TARGET/.codex/agents/"
stamp_codex_agents
echo "  ~ .codex/prompts/{execute,implement-spec,stage-ticket,pr-watch}.md + .codex/agents/" >&2
stamp_block "$TARGET/AGENTS.md"
stamp_block "$TARGET/CLAUDE.md"

# --- 3 · portable skills + OpenCode adapter ---
mkdir -p "$TARGET/.agents/skills/implement-spec"
cp -R "$SRC/skills/implement-spec/." "$TARGET/.agents/skills/implement-spec/"
mkdir -p "$TARGET/.agents/skills/stage-ticket"
cp -R "$SRC/skills/stage-ticket/." "$TARGET/.agents/skills/stage-ticket/"
mkdir -p "$TARGET/.opencode/agents" "$TARGET/.opencode/commands"
cp "$SRC"/adapters/opencode/agents/*.md "$TARGET/.opencode/agents/"
cp "$SRC"/adapters/opencode/commands/*.md "$TARGET/.opencode/commands/"
stamp_gitignore
echo "  ~ .agents/skills/{implement-spec,stage-ticket} + .opencode/{agents,commands}/" >&2

# --- 4 · state (seeded on init only; update leaves it alone) ---
if [[ "$MODE" == "init" ]]; then
  seed_state ".claude/routing-log.md" "$SRC/templates/routing-log.md"
  seed_state "eval/golden.jsonl"      "$SRC/eval/golden.jsonl"
  mkdir -p "$TARGET/tasks/todo" "$TARGET/tasks/done"
  [[ -e "$TARGET/tasks/todo/.gitkeep" ]] || : > "$TARGET/tasks/todo/.gitkeep"
  [[ -e "$TARGET/tasks/done/.gitkeep" ]] || : > "$TARGET/tasks/done/.gitkeep"
  echo "  + tasks/{todo,done}/" >&2
fi

# --- 5 · version marker ---
{
  echo "$VERSION"
  echo "plugin:  $ENABLE_KEY"
  echo "ref:     $MKT_REF"
  echo "stamped: $(date +%F)"
  echo "engine:  $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} > "$TARGET/.claude/.software-factory-version"
echo "  ~ .claude/.software-factory-version → $VERSION" >&2

echo "  → version: $OLD_VER → $VERSION   ref: $OLD_REF → $MKT_REF" >&2
cat >&2 <<EOF
✓ $MODE complete. Next:
  1. Commit the changes (so web/desktop sessions pick them up).
  2. In Claude Code, trust the repo when prompted; the plugin installs at
     session start (re-installs at the new ref after an update). Type
     /$PLUGIN_NAME:execute <task>.
  3. In Codex, /execute <task> (uses .codex/prompts/execute.md).
     For approved specs, use \$implement-spec or /implement-spec <spec>.
     To stop before a PR opens, use \$stage-ticket or /stage-ticket <ticket>.
     After opening a PR, \$pr-watch <PR> triages CI/reviews synchronously
     (no live background agent on this runtime — see .codex/prompts/pr-watch.md).
  4. In OpenCode, use /route <task>, /implement-spec <spec>, or
     /stage-ticket <ticket> to stop before a PR opens; /pr-watch <PR> for the
     same synchronous triage fallback after a PR is open.
EOF
