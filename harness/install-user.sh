#!/usr/bin/env bash
# Install the portable skill and runtime agent adapters for one local user.
set -euo pipefail

: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="$SOFTWARE_FACTORY_HOME"

# Pull the engine to the latest committed ref before (re-)linking, when asked
# (SOFTWARE_FACTORY_SYNC=1). Off by default so a plain run stays a pure local
# relink with no network call — tests and CI rely on that.
if [[ "${SOFTWARE_FACTORY_SYNC:-0}" == "1" && -d "$SRC/.git" ]]; then
  if git -C "$SRC" diff --quiet && git -C "$SRC" diff --cached --quiet; then
    echo "→ syncing $SRC from origin"
    git -C "$SRC" pull --ff-only
  else
    echo "⚠ $SRC has uncommitted changes; skipping git pull (commit or stash first to sync)" >&2
  fi
fi

link_one() {
  local source="$1" destination="$2"
  mkdir -p "$(dirname "$destination")"
  if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then
    echo "  = $destination"
    return
  fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    echo "refusing to replace existing path: $destination" >&2
    exit 73
  fi
  ln -s "$source" "$destination"
  echo "  + $destination → $source"
}

if command -v gh >/dev/null && [[ "${SOFTWARE_FACTORY_SYNC:-0}" == "1" ]]; then
  if ! gh extension list 2>/dev/null | grep -q 'aanojima/gh-pr-monitor'; then
    echo "→ installing gh extension aanojima/gh-pr-monitor (used by pr-intake)"
    gh extension install aanojima/gh-pr-monitor
  fi
fi

link_one "$SRC/skills/implement-spec" "$HOME/.agents/skills/implement-spec"
link_one "$SRC/skills/implement-spec" "$HOME/.claude/skills/implement-spec"
# stage-ticket is genuinely portable too (no PR, no Agent/SendMessage/Monitor
# dependency) — same dual-link as implement-spec.
link_one "$SRC/skills/stage-ticket" "$HOME/.agents/skills/stage-ticket"
link_one "$SRC/skills/stage-ticket" "$HOME/.claude/skills/stage-ticket"
# Claude-Code-specific skills (use the Agent tool directly) — not portable to
# Codex/OpenCode, so these only go to ~/.claude/skills, not ~/.agents/skills.
link_one "$SRC/skills/route" "$HOME/.claude/skills/route"
link_one "$SRC/skills/pr-watch" "$HOME/.claude/skills/pr-watch"
link_one "$SRC/skills/implement-ticket" "$HOME/.claude/skills/implement-ticket"
for source in "$SRC"/agents/*.md; do
  link_one "$source" "$HOME/.claude/agents/$(basename "$source")"
done
for source in "$SRC"/adapters/opencode/agents/*.md; do
  link_one "$source" "$HOME/.config/opencode/agents/$(basename "$source")"
done
for source in "$SRC"/adapters/opencode/commands/*.md; do
  link_one "$source" "$HOME/.config/opencode/commands/$(basename "$source")"
done

# Register Codex roles without overwriting unrelated user configuration.
CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
mkdir -p "$(dirname "$CODEX_CONFIG")"
touch "$CODEX_CONFIG"
BEGIN='# >>> software-factory implement-spec agents'
END='# <<< software-factory implement-spec agents'
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
awk -v begin="$BEGIN" -v end="$END" '
  $0 == begin { skip=1; next }
  $0 == end { skip=0; next }
  !skip { print }
' "$CODEX_CONFIG" > "$TMP"
if grep -qE '^\[agents\."goal-(explorer|reviewer|security-reviewer)"\]' "$TMP"; then
  echo "existing goal agent registration found outside the managed block in $CODEX_CONFIG" >&2
  echo "remove or rename it before rerunning install-user" >&2
  exit 73
fi
cp "$TMP" "$CODEX_CONFIG"
{
  printf '\n%s\n' "$BEGIN"
  for role in repo-explorer conformance-reviewer security-reviewer adversarial-reviewer; do
    description="Independent read-only $role role for implement-spec"
    printf '[agents."%s"]\n' "$role"
    printf 'description = "%s"\n' "$description"
    printf 'config_file = "%s"\n\n' "$SRC/adapters/codex/agents/$role.toml"
  done
  printf '%s\n' "$END"
} >> "$CODEX_CONFIG"

echo "✓ user installation complete"
echo "  Claude: restart sessions; /implement-spec, /stage-ticket, /route, /pr-watch,"
echo "          /implement-ticket, and the read-only agents are available."
echo "  Codex: restart sessions to load the skills and registered roles."
echo "  OpenCode: restart sessions; /implement-spec, /stage-ticket, and /route are available."
echo "  If OpenCode reports a duplicate skill, set OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1."
